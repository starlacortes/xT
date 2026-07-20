//
//  NotificationManager.swift
//  xT
//
//  Manages dose and journal reminder notifications via UNUserNotificationCenter.
//

import Foundation
import UserNotifications
import SwiftData

/// Manages all local notification scheduling and permission state.
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    enum NotificationType: String {
        case doseReminder = "dose_reminder"
        case journalReminder = "journal_reminder"
    }

    // MARK: - Properties
    var modelContext: ModelContext?

    @Published var isDoseNotificationsAuthorized = false
    @Published var isJournalNotificationsAuthorized = false
    @Published var doseReminderEnabled = UserDefaults.standard.bool(forKey: "doseReminderEnabled")
    @Published var doseReminderHour = UserDefaults.standard.integer(forKey: "doseReminderHour")
    @Published var doseReminderMinute = UserDefaults.standard.integer(forKey: "doseReminderMinute")
    @Published var journalReminderEnabled = UserDefaults.standard.bool(forKey: "journalReminderEnabled")
    @Published var journalReminderHour = UserDefaults.standard.integer(forKey: "journalReminderHour")
    @Published var journalReminderMinute = UserDefaults.standard.integer(forKey: "journalReminderMinute")

    /// The dosing frequency in days, derived from MedicationManager.
    /// Drives whether the dose reminder is daily or on specific days.
    var doseFrequencyDays: Int {
        let mgr = MedicationManager.shared
        if let custom = mgr.customFrequencyDays, custom > 0 {
            return custom
        }
        if let methodStr = mgr.selectedAdministrationMethod,
           let method = MedicationManager.AdministrationMethod(rawValue: methodStr) {
            return method.frequencyDays
        }
        return 1 // default to daily if unconfigured
    }

    private let doseNotificationRequestKey = "dose_reminder_request"
    private let journalNotificationRequestKey = "journal_reminder_request"

    // MARK: - Initialization
    init() {
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
    func scheduleAllReminders() {
        let center = UNUserNotificationCenter.current()

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
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d 'at' h:mm a"
                print("[NotificationManager] Dose reminder rescheduled for \(formatter.string(from: nextDoseDate))")
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
    private func doseNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time for your dose"
        content.body = "Tap to log your dose in xT"
        content.sound = .default
        content.categoryIdentifier = NotificationType.doseReminder.rawValue

        if let medInfo = getMedicationContext() {
            content.body = "Time for your \(medInfo) dose"
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
        content.title = "Journal check-in"
        content.body = "How are you feeling today? Take a moment to write in your journal."
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

    /// Cancel a specific type of notification.
    func cancelReminder(for type: NotificationType) {
        let center = UNUserNotificationCenter.current()
        let requestId = type == .doseReminder ? doseNotificationRequestKey : journalNotificationRequestKey
        center.removePendingNotificationRequests(withIdentifiers: [requestId])
        print("[NotificationManager] Cancelled \(type.rawValue) reminder")
    }

    /// Cancel all scheduled notifications.
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[NotificationManager] All reminders cancelled")
    }

    /// Calculate the count of active reminders.
    var activeRemindersCount: Int {
        return (doseReminderEnabled ? 1 : 0) + (journalReminderEnabled ? 1 : 0)
    }

    // MARK: - Notification Response Handling

    /// Handle when the user taps on a notification.
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let identifier = response.notification.request.content.categoryIdentifier

        switch identifier {
        case NotificationType.doseReminder.rawValue:
            // Open the dose recording interface
            await handleDoseNotificationTap()
        case NotificationType.journalReminder.rawValue:
            // Open the journal interface
            await handleJournalNotificationTap()
        default:
            print("[NotificationManager] Unknown notification tapped: \(identifier)")
        }
    }

    private func handleDoseNotificationTap() async {
        print("[NotificationManager] Opening dose recording screen")
        // In a real app, this would navigate to the dose recording view
        // For now, we can't easily control navigation from the manager
        // This could be enhanced with a coordinator pattern or app delegate
    }

    private func handleJournalNotificationTap() async {
        print("[NotificationManager] Opening journal screen")
        // In a real app, this would navigate to the journal view
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
        scheduleAllReminders()

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
        scheduleAllReminders()

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

    /// Get current medication context for notification content.
    private func getMedicationContext() -> String? {
        // This would ideally come from MedicationManager
        // For now, return a generic string or medication info if accessible
        return nil
    }

    // MARK: - Notification Categories

    /// Set up notification categories for actions (future feature).
    func setupNotificationCategories() {
        let doseAction = UNNotificationAction(
            identifier: "dose_action_log",
            title: "Log Dose",
            options: [.foreground]
        )

        let doseCategory = UNNotificationCategory(
            identifier: NotificationType.doseReminder.rawValue,
            actions: [doseAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Dose reminder"
        )

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([doseCategory])
    }

    // MARK: - Utility

    /// Get the next scheduled dose reminder time (for display in settings).
    var nextDoseReminderDate: Date? {
        guard doseReminderEnabled else { return nil }

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = doseReminderHour
        components.minute = doseReminderMinute
        components.second = 0

        var candidate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()

        // If the time is already past today, move to tomorrow
        if candidate.timeIntervalSinceNow < 0 {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        return candidate
    }

    /// Get the next scheduled journal reminder time (for display in settings).
    var nextJournalReminderDate: Date? {
        guard journalReminderEnabled else { return nil }

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = journalReminderHour
        components.minute = journalReminderMinute
        components.second = 0

        let candidate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
        return candidate >= Date() ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)
    }
}
