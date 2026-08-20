//
//  SettingsView+Helpers.swift
//  xT
//
//  Section/row layout primitives (settingsSection, settingsRowContent,
//  settingsIconView, settingsDivider), the row subtitle strings, the reminder
//  change handlers, and the shared date formatter.
//  (Split from SettingsView.swift — same `SettingsView`, different file.)
//

import SwiftUI

extension SettingsView {

    // MARK: - Layout helpers

    // These four route to the shared implementations in
    // Shared/Components/SettingsRowKit.swift — they measured byte-identical to the
    // hand-rolled versions they replaced (22pt gutter, 10pt label gap, 32x32 tiles,
    // hairline dividers aligned to row text).
    func settingsSection<Content: View>(label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        SettingsSection(label: label, content: content)
    }

    func settingsRowContent<Trailing: View>(
        icon: String,
        iconBg: Color,
        iconColor: Color,
        title: String,
        subtitle: LocalizedStringResource?,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        SettingsRow(icon: icon, iconBackground: iconBg, iconColor: iconColor,
                    title: title, subtitle: subtitle, trailing: trailing)
    }

    func settingsIconView(icon: String, bg: Color, color: Color) -> some View {
        SettingsIconTile(icon: icon, background: bg, color: color)
    }

    func settingsDivider() -> some View {
        SettingsRowDivider()
    }

    // MARK: - Computed strings
    //
    // These return `LocalizedStringResource` (not `String`) so that the
    // `^[…](inflect: true)` Markdown grammar they carry is parsed by
    // `Text(_:LocalizedStringResource)` at the render site. A `String` return
    // would route through `Text(_:StringProtocol)` (verbatim) and the
    // `^[N day](inflect: true)` marker would show up on screen.
    //
    // The explicit `LocalizedStringResource(_:comment:)` initializer is used
    // instead of string-literal coercion so the localization comment travels
    // with the key for the string catalog.

    var nextDoseSubtitle: LocalizedStringResource {
        if let next = medicationManager.nextDoseDate {
            return LocalizedStringResource("Next: \(formatDate(next))")
        }
        return "No schedule set"
    }

    var hrtStartSubtitle: LocalizedStringResource {
        guard let start = medicationManager.hrtStartDate else {
            return "When you started HRT"
        }
        let months = medicationManager.monthsOnHRT
        if months == 0 {
            return LocalizedStringResource("Started \(formatDate(start))")
        }
        return LocalizedStringResource(
            "^[\(months) month](inflect: true) on HRT · \(formatDate(start))",
            comment: "Settings row subtitle: months on HRT plus the start date"
        )
    }

    var adherenceSubtitle: LocalizedStringResource {
        guard medicationManager.isFullyConfigured else {
            return LocalizedStringResource(
                "No medication configured",
                comment: "Settings row subtitle when adherence data is unavailable"
            )
        }
        if let rate = medicationManager.adherenceRate {
            return LocalizedStringResource(
                "\(AppNumberFormatters.percent.string(rate * 100))% of scheduled doses recorded",
                comment: "Settings row subtitle summarising 30-day adherence"
            )
        }
        return LocalizedStringResource(
            "Regimen history and dose intensity",
            comment: "Settings row subtitle for the adherence screen before any adherence data exists"
        )
    }

    var doseHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.doseHistory.count
        if count == 0 { return "No doses recorded yet" }
        return LocalizedStringResource(
            "Review and correct ^[\(count) dose](inflect: true)",
            comment: "Settings row subtitle counting doses that need review"
        )
    }

    var bloodTestHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.bloodTestHistory.count
        if count == 0 { return "No blood tests logged yet" }
        return LocalizedStringResource(
            "^[\(count) blood test](inflect: true) logged",
            comment: "Settings row subtitle counting logged blood tests"
        )
    }

    var screeningHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.screeningRecords.count
        if count == 0 { return "No screenings logged yet" }
        return LocalizedStringResource(
            "^[\(count) screening](inflect: true) logged",
            comment: "Settings row subtitle counting logged health screenings"
        )
    }

    var avoidZonesSubtitle: LocalizedStringResource {
        let count = medicationManager.avoidZones.count
        if count == 0 { return "No zones marked" }
        return LocalizedStringResource(
            "^[\(count) zone](inflect: true) marked",
            comment: "Settings row subtitle counting marked body zones"
        )
    }

    var formatDoseReminderSubtitle: String {
        let freq = notificationManager.doseFrequencyDays
        if freq <= 1 {
            return String(format: "Daily at %02d:%02d", doseReminderHour, doseReminderMinute)
        } else {
            return String(format: "Every %d days at %02d:%02d", freq, doseReminderHour, doseReminderMinute)
        }
    }

    var formatJournalReminderSubtitle: String {
        String(format: "Daily at %02d:%02d", journalReminderHour, journalReminderMinute)
    }

    // MARK: - Notification Handlers

    func onDoseReminderToggle(_ enabled: Bool) {
        notificationManager.configureDoseReminder(enabled: enabled, hour: doseReminderHour, minute: doseReminderMinute)
    }

    func onDoseTimeChange() {
        notificationManager.configureDoseReminder(enabled: doseRemindersEnabled, hour: doseReminderHour, minute: doseReminderMinute)
    }

    func onJournalReminderToggle(_ enabled: Bool) {
        notificationManager.configureJournalReminder(enabled: enabled, hour: journalReminderHour, minute: journalReminderMinute)
    }

    func onJournalTimeChange() {
        notificationManager.configureJournalReminder(enabled: journalRemindersEnabled, hour: journalReminderHour, minute: journalReminderMinute)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
