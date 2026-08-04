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

    // MARK: - Properties

    /// Set when the user taps a reminder (or its action button); cleared by `consumePendingRoute()`
    /// once the UI has navigated.
    private(set) var pendingRoute: Route?

    var isDoseNotificationsAuthorized = false
    var isJournalNotificationsAuthorized = false
    var doseReminderEnabled = UserDefaults.standard.bool(forKey: "doseReminderEnabled")
    var doseReminderHour = UserDefaults.standard.integer(forKey: "doseReminderHour")
    var doseReminderMinute = UserDefaults.standard.integer(forKey: "doseReminderMinute")
    var journalReminderEnabled = UserDefaults.standard.bool(forKey: "journalReminderEnabled")
    var journalReminderHour = UserDefaults.standard.integer(forKey: "journalReminderHour")
    var journalReminderMinute = UserDefaults.standard.integer(forKey: "journalReminderMinute")

    /// The dosing frequency in days. Drives whether the dose reminder is daily or on
    /// specific days. Single derivation lives on `MedicationManager`.
    var doseFrequencyDays: Int { MedicationManager.shared.effectiveFrequencyDays }

    private let doseNotificationRequestKey = "dose_reminder_request"
    private let journalNotificationRequestKey = "journal_reminder_request"

    /// Identifier of the "Log Dose" button attached to dose reminders.
    private static let logDoseActionIdentifier = "dose_action_log"

    // MARK: - Initialization
    override init() {
        super.init()
        loadSettings()
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
            isDoseNotificationsAuthorized = doseReminderEnabled
            isJournalNotificationsAuthorized = journalReminderEnabled
        case .denied:
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

        let trigger: UNNotificationTrigger

        if freq <= 1 {
            // Daily user — repeating trigger at the chosen time every day
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            // Non-daily user — one-time notification for the next scheduled dose
            trigger = oneTimeTrigger(forNextDoseFrom: Date(), frequencyDays: freq)
        }

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
        let trigger: UNNotificationTrigger

        if freq <= 1 {
            var dateComponents = DateComponents()
            dateComponents.hour = doseReminderHour
            dateComponents.minute = doseReminderMinute
            dateComponents.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            trigger = oneTimeTrigger(forNextDoseFrom: nextDoseDate, frequencyDays: freq)
        }

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
    func configureDoseReminder(
        enabled: Bool,
        hour: Int,
        minute: Int
    ) {
        doseReminderEnabled = enabled
        doseReminderHour = hour
        doseReminderMinute = minute

        // Persist settings
        UserDefaults.standard.set(enabled, forKey: "doseReminderEnabled")
        UserDefaults.standard.set(hour, forKey: "doseReminderHour")
        UserDefaults.standard.set(minute, forKey: "doseReminderMinute")

        // Reschedule
        Task { await scheduleAllReminders() }

        let label = enabled ? "Dose reminder enabled" : "Dose reminder disabled"
        print("[NotificationManager] \(label) at \(hour):\(String(format: "%02d", minute))")
    }

    /// Configure journal reminders.
    func configureJournalReminder(
        enabled: Bool,
        hour: Int,
        minute: Int
    ) {
        journalReminderEnabled = enabled
        journalReminderHour = hour
        journalReminderMinute = minute

        // Persist settings
        UserDefaults.standard.set(enabled, forKey: "journalReminderEnabled")
        UserDefaults.standard.set(hour, forKey: "journalReminderHour")
        UserDefaults.standard.set(minute, forKey: "journalReminderMinute")

        // Reschedule
        Task { await scheduleAllReminders() }

        let label = enabled ? "Journal reminder enabled" : "Journal reminder disabled"
        print("[NotificationManager] \(label) at \(hour):\(String(format: "%02d", minute))")
    }

    /// Load reminder settings from UserDefaults.
    private func loadSettings() {
        doseReminderEnabled = UserDefaults.standard.bool(forKey: "doseReminderEnabled")
        doseReminderHour = UserDefaults.standard.integer(forKey: "doseReminderHour")
        doseReminderMinute = UserDefaults.standard.integer(forKey: "doseReminderMinute")
        journalReminderEnabled = UserDefaults.standard.bool(forKey: "journalReminderEnabled")
        journalReminderHour = UserDefaults.standard.integer(forKey: "journalReminderHour")
        journalReminderMinute = UserDefaults.standard.integer(forKey: "journalReminderMinute")
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
