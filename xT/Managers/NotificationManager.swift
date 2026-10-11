//
//  NotificationManager.swift
//  xT
//
//  Manages dose and journal reminder notifications via UNUserNotificationCenter.
//

import Foundation
import UserNotifications
import Observation

/// Manages all local notification scheduling, permission state and tap handling.
///
/// The manager is also the app's `UNUserNotificationCenterDelegate`; `registerNotificationHandling()`
/// must be called once during startup or notifications will neither appear in the foreground nor
/// route anywhere when tapped.
@MainActor
@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    enum NotificationType: String {
        case doseReminder = "dose_reminder"
        case journalReminder = "journal_reminder"
    }

    /// A screen the user asked for by acting on a notification.
    enum Route: String {
        case logDose
        case journal
    }

    // MARK: - UserDefaults Keys & Defaults

    /// Device-local reminder preferences (per-device by design — never CloudKit-synced).
    /// Every read and write of these keys must go through this enum; the raw strings
    /// used to be hand-typed in six different files.
    enum Keys {
        static let doseReminderEnabled = "doseReminderEnabled"
        static let doseReminderHour = "doseReminderHour"
        static let doseReminderMinute = "doseReminderMinute"
        static let journalReminderEnabled = "journalReminderEnabled"
        static let journalReminderHour = "journalReminderHour"
        static let journalReminderMinute = "journalReminderMinute"
    }

    /// Fallback times used when a key has never been written. Chosen once here:
    /// xTApp's registered defaults, the Settings screen's fallbacks, and the spoof
    /// seeder had drifted apart (20:00 vs 21:00 for the journal reminder).
    enum Defaults {
        static let doseHour = 9
        static let doseMinute = 0
        static let journalHour = 21
        static let journalMinute = 0
    }

    /// Which reminder settings triple a `configure` call targets.
    enum ReminderKind {
        case dose, journal
    }

    // MARK: - Properties

    /// Set when the user taps a reminder (or its action button); cleared by `consumePendingRoute()`
    /// once the UI has navigated.
    private(set) var pendingRoute: Route?

    var isDoseNotificationsAuthorized = false
    var isJournalNotificationsAuthorized = false
    /// True when the system notification permission is `.denied` — the app can
    /// no longer prompt, and reminders will not fire until the user re-enables
    /// notifications in System Settings. Observed by the Settings screen to
    /// show its "Notifications disabled" alert.
    private(set) var isAuthorizationDenied = false
    var doseReminderEnabled = false
    var doseReminderHour = Defaults.doseHour
    var doseReminderMinute = Defaults.doseMinute
    var journalReminderEnabled = false
    var journalReminderHour = Defaults.journalHour
    var journalReminderMinute = Defaults.journalMinute

    /// The dosing frequency in days. Drives whether the dose reminder is daily or on
    /// specific days. Single derivation lives on `MedicationManager` — the ester-aware
    /// due interval, so a TU user's next reminder sits 10 weeks out, not weekly.
    var doseFrequencyDays: Int { MedicationManager.shared.effectiveDueIntervalDays }

    private let doseNotificationRequestKey = "dose_reminder_request"
    private let journalNotificationRequestKey = "journal_reminder_request"

    /// Identifier of the "Log Dose" button attached to dose reminders.
    private static let logDoseActionIdentifier = "dose_action_log"

    // MARK: - Initialization
    override init() {
        super.init()
        loadFromDefaults()
        Task { await checkAuthorizationStatus() }
    }

    // MARK: - Permission Management

    /// Request notification authorization from the user.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                print("[NotificationManager] Authorization granted")
            } else {
                print("[NotificationManager] Authorization denied")
            }
        } catch {
            print("[NotificationManager] Error requesting authorization: \(error)")
        }
        await checkAuthorizationStatus()
        // Now that permission may have just been granted, schedule any reminders
        // the user already configured (e.g. during onboarding). Without this, reminders
        // configured before authorization would never be scheduled.
        await scheduleAllReminders()
    }

    /// Check current authorization status for both notification types.
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        switch status {
        case .authorized, .provisional:
            isAuthorizationDenied = false
            isDoseNotificationsAuthorized = doseReminderEnabled
            isJournalNotificationsAuthorized = journalReminderEnabled
        case .denied:
            isAuthorizationDenied = true
            isDoseNotificationsAuthorized = false
            isJournalNotificationsAuthorized = false
        case .notDetermined:
            isDoseNotificationsAuthorized = false
            isJournalNotificationsAuthorized = false
        default:
            isDoseNotificationsAuthorized = false
            isJournalNotificationsAuthorized = false
        }
    }

    // MARK: - Scheduling

    /// Schedule or reschedule all active reminders.
    ///
    /// Scheduling is gated on notification authorization: `UNUserNotificationCenter`
    /// rejects `add(_:)` with "Source is not authorized" when permission hasn't been
    /// granted, so we check first and skip otherwise. Reminders are re-scheduled
    /// automatically once permission is granted (see `requestAuthorization()`).
    func scheduleAllReminders() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else {
            print("[NotificationManager] Skipping schedule — not authorized (\(status.rawValue))")
            return
        }

        // Cancel existing notifications first to avoid duplicates
        center.removeAllPendingNotificationRequests()

        if doseReminderEnabled {
            scheduleDoseReminder()
        }

        if journalReminderEnabled {
            scheduleJournalReminder()
        }

        print("[NotificationManager] Scheduled \(activeRemindersCount) active reminders")
    }

    /// Schedule a dose reminder based on the user's dosing frequency.
    ///
    /// - For daily users (frequencyDays == 1): uses a repeating daily trigger.
    /// - For non-daily users (frequencyDays > 1): schedules a **single** non-repeating
    ///   notification for the next scheduled dose date. Each logged dose re-triggers
    ///   `rescheduleAfterDose(nextDoseDate:)` to keep the chain alive.
    private func scheduleDoseReminder() {
        let center = UNUserNotificationCenter.current()

        // Remove any existing dose reminder before scheduling a new one
        center.removePendingNotificationRequests(withIdentifiers: [doseNotificationRequestKey])

        let hour = doseReminderHour
        let minute = doseReminderMinute
        let freq = doseFrequencyDays

        // Daily user — repeating trigger at the chosen time every day;
        // non-daily — one-time notification for the next scheduled dose. When the
        // manager knows the next dose date, aim the one-time trigger at it directly:
        // advancing `Date()` by the frequency lands on schedule only right after a
        // dose, and drifts wrong (up to a full interval) for anyone mid-cycle.
        let referenceDate = MedicationManager.shared.nextDoseDate ?? Date()
        let trigger = doseReminderTrigger(from: referenceDate, frequencyDays: freq)

        let content = doseNotificationContent()
        let request = UNNotificationRequest(identifier: doseNotificationRequestKey, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Error scheduling dose reminder: \(error.localizedDescription)")
            } else {
                let freqLabel = freq <= 1 ? "daily" : "every \(freq) days"
                print("[NotificationManager] Dose reminder scheduled (\(freqLabel)) at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// Reschedule the dose reminder to fire on a specific next dose date.
    ///
    /// Called by MedicationManager after a dose is logged so the reminder
    /// always points to the next upcoming dose.
    func rescheduleAfterDose(nextDoseDate: Date) {
        guard doseReminderEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [doseNotificationRequestKey])

        // For daily users, just use the repeating daily trigger (simpler and more reliable)
        let freq = doseFrequencyDays
        let trigger = doseReminderTrigger(from: nextDoseDate, frequencyDays: freq)

        let content = doseNotificationContent()
        let request = UNNotificationRequest(identifier: doseNotificationRequestKey, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Error rescheduling dose reminder: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] Dose reminder rescheduled for \(AppDateFormatters.dateTime.string(from: nextDoseDate))")
            }
        }
    }

    /// Repeating-daily trigger for daily users, otherwise a one-time trigger
    /// aimed at the next dose — shared by `scheduleDoseReminder()` and
    /// `rescheduleAfterDose(nextDoseDate:)`, which used to each hand-roll the
    /// same branch.
    private func doseReminderTrigger(from referenceDate: Date, frequencyDays: Int) -> UNNotificationTrigger {
        if frequencyDays <= 1 {
            var dateComponents = DateComponents()
            dateComponents.hour = doseReminderHour
            dateComponents.minute = doseReminderMinute
            dateComponents.second = 0
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }
        return oneTimeTrigger(forNextDoseFrom: referenceDate, frequencyDays: frequencyDays)
    }

    /// Creates a one-time notification trigger for a specific dose date.
    private func oneTimeTrigger(forNextDoseFrom referenceDate: Date, frequencyDays: Int) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.current

        // Find the next dose date that is in the future and matches the reminder time
        var candidate = referenceDate
        if candidate <= Date() {
            // If the reference date is in the past, advance to the next dose date
            candidate = calendar.date(byAdding: .day, value: frequencyDays, to: referenceDate) ?? referenceDate
        }

        // Ensure candidate is in the future
        while candidate <= Date() {
            candidate = calendar.date(byAdding: .day, value: frequencyDays, to: candidate) ?? candidate
        }

        var components = calendar.dateComponents([.year, .month, .day], from: candidate)
        components.hour = doseReminderHour
        components.minute = doseReminderMinute
        components.second = 0

        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// Builds the notification content for dose reminders.
    ///
    /// The notification reports that a scheduled dose has come due and names what
    /// it is. It does not instruct the user to take it or to open the app — they
    /// asked to be told the time; what they do with it is theirs.
    private func doseNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dose scheduled",
                               comment: "Notification title when a scheduled dose comes due")
        content.sound = .default
        content.categoryIdentifier = NotificationType.doseReminder.rawValue

        if let medInfo = getMedicationContext() {
            content.body = medInfo
        }

        return content
    }

    /// Schedule a daily journal reminder at the configured time.
    private func scheduleJournalReminder() {
        let center = UNUserNotificationCenter.current()

        // Capture values before closure
        let hour = journalReminderHour
        let minute = journalReminderMinute

        // Create a daily repeating trigger at the specified time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        // The user set this reminder; it tells them it has fired. It does not ask
        // them how they feel or urge them to write. No body — the title says
        // everything the notification knows.
        content.title = String(localized: "Journal reminder",
                               comment: "Notification title for the daily journal reminder the user scheduled")
        content.sound = .default
        content.categoryIdentifier = NotificationType.journalReminder.rawValue

        let request = UNNotificationRequest(identifier: journalNotificationRequestKey, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Error scheduling journal reminder: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] Journal reminder scheduled at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// Calculate the count of active reminders.
    var activeRemindersCount: Int {
        return (doseReminderEnabled ? 1 : 0) + (journalReminderEnabled ? 1 : 0)
    }

    // MARK: - Notification Response Handling

    /// Translate a notification the user acted on into a `pendingRoute` for the UI.
    ///
    /// Takes plain identifiers rather than the `UNNotificationResponse` so the delegate
    /// callback — which arrives off the main actor — has nothing non-`Sendable` to hand over.
    func handleNotificationResponse(category: String, actionIdentifier: String) {
        // Swiping a reminder away is an explicit "not now" — never navigate on it.
        guard actionIdentifier != UNNotificationDismissActionIdentifier else { return }

        // The "Log Dose" button goes to dose logging regardless of which reminder carried it.
        if actionIdentifier == Self.logDoseActionIdentifier {
            pendingRoute = .logDose
            return
        }

        switch category {
        case NotificationType.doseReminder.rawValue:
            pendingRoute = .logDose
        case NotificationType.journalReminder.rawValue:
            pendingRoute = .journal
        default:
            print("[NotificationManager] Unknown notification tapped: \(category)")
        }
    }

    /// Clear the pending route once the UI has navigated, so a later re-render
    /// does not navigate a second time.
    func consumePendingRoute() {
        pendingRoute = nil
    }

    // MARK: - Settings Management

    /// Configure dose reminders with medication context.
    func configureDoseReminder(enabled: Bool, hour: Int, minute: Int) {
        configureReminder(.dose, enabled: enabled, hour: hour, minute: minute)
    }

    /// Configure journal reminders.
    func configureJournalReminder(enabled: Bool, hour: Int, minute: Int) {
        configureReminder(.journal, enabled: enabled, hour: hour, minute: minute)
    }

    /// Shared body of the two `configure*Reminder` entry points: assign the
    /// in-memory triple, persist it, reschedule.
    private func configureReminder(_ kind: ReminderKind, enabled: Bool, hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        switch kind {
        case .dose:
            doseReminderEnabled = enabled
            doseReminderHour = hour
            doseReminderMinute = minute
            defaults.set(enabled, forKey: Keys.doseReminderEnabled)
            defaults.set(hour, forKey: Keys.doseReminderHour)
            defaults.set(minute, forKey: Keys.doseReminderMinute)
        case .journal:
            journalReminderEnabled = enabled
            journalReminderHour = hour
            journalReminderMinute = minute
            defaults.set(enabled, forKey: Keys.journalReminderEnabled)
            defaults.set(hour, forKey: Keys.journalReminderHour)
            defaults.set(minute, forKey: Keys.journalReminderMinute)
        }

        // Reschedule. When enabling, request authorization first: a fresh
        // install, a device set up via iCloud restore, or a post-reset state
        // starts `.notDetermined`, and nothing else in the app ever prompts.
        // `scheduleAllReminders()` skips while not authorized, so without this
        // the toggles persisted flags but no reminder ever fired.
        // `requestAuthorization()` ends with its own `scheduleAllReminders()`.
        if enabled {
            Task { await requestAuthorization() }
        } else {
            Task { await scheduleAllReminders() }
        }

        let name = kind == .dose ? "Dose" : "Journal"
        let label = enabled ? "\(name) reminder enabled" : "\(name) reminder disabled"
        print("[NotificationManager] \(label) at \(hour):\(String(format: "%02d", minute))")
    }

    /// (Re)loads reminder settings from UserDefaults. Called at init and again
    /// after a snapshot/spoof dataset swap rewrites the keys behind the manager's
    /// back.
    func loadFromDefaults() {
        let defaults = UserDefaults.standard
        doseReminderEnabled = defaults.bool(forKey: Keys.doseReminderEnabled)
        doseReminderHour = defaults.object(forKey: Keys.doseReminderHour) != nil
            ? defaults.integer(forKey: Keys.doseReminderHour) : Defaults.doseHour
        doseReminderMinute = defaults.object(forKey: Keys.doseReminderMinute) != nil
            ? defaults.integer(forKey: Keys.doseReminderMinute) : Defaults.doseMinute
        journalReminderEnabled = defaults.bool(forKey: Keys.journalReminderEnabled)
        journalReminderHour = defaults.object(forKey: Keys.journalReminderHour) != nil
            ? defaults.integer(forKey: Keys.journalReminderHour) : Defaults.journalHour
        journalReminderMinute = defaults.object(forKey: Keys.journalReminderMinute) != nil
            ? defaults.integer(forKey: Keys.journalReminderMinute) : Defaults.journalMinute
    }

    /// A short description of the configured dose, for the reminder body.
    ///
    /// Returns `nil` until a medication is chosen, in which case the generic copy stands.
    private func getMedicationContext() -> String? {
        let mgr = MedicationManager.shared
        guard let medication = mgr.selectedMedication else { return nil }
        guard let amount = mgr.defaultDoseAmount, amount > 0 else { return medication }
        return String(localized: "\(AppNumberFormatters.dose.string(amount)) mg \(medication)",
                      comment: "Dose amount and medication name, e.g. '4 mg Estrogen'")
    }

    // MARK: - Notification Categories

    /// Install the delegate and notification categories. Call once during app startup —
    /// without the delegate, foreground reminders are suppressed and taps go nowhere.
    func registerNotificationHandling() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let doseAction = UNNotificationAction(
            identifier: Self.logDoseActionIdentifier,
            title: String(localized: "Record dose",
                          comment: "Notification action button that opens the dose entry screen"),
            options: [.foreground]
        )

        let doseCategory = UNNotificationCategory(
            identifier: NotificationType.doseReminder.rawValue,
            actions: [doseAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: String(localized: "Dose reminder",
                comment: "Placeholder shown instead of the notification body when previews are hidden")
        )

        let journalCategory = UNNotificationCategory(
            identifier: NotificationType.journalReminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: String(localized: "Journal reminder",
                comment: "Placeholder shown instead of the notification body when previews are hidden")
        )

        center.setNotificationCategories([doseCategory, journalCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Show reminders even while the app is open. Without this the system drops any
    /// notification that fires in the foreground, so a user with xT on screen at
    /// dose time is never told.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Entry point for every notification tap and action button.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // `UNNotificationResponse` is not Sendable — read what we need before hopping.
        let category = response.notification.request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor in
            self.handleNotificationResponse(category: category, actionIdentifier: actionIdentifier)
            completionHandler()
        }
    }
}
