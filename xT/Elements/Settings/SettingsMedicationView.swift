//
//  SettingsMedicationView.swift
//  xT
//
//  Settings → Medication & Dose (ST1). Everything that shapes the regimen:
//  type & method, dose & frequency, the schedule overview (which moved here
//  from Home, per H11 step 4), the HRT start date, reminders (X25), and the
//  body-zone rows. Rows were **moved** out of `SettingsView+Sections.swift`,
//  not rewritten; the sheets and state moved with them.
//

import SwiftUI
import UserNotifications

struct SettingsMedicationView: View {
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.notificationManager) var notificationManager
    @Environment(\.profileManager) var profileManager

    @State var showingTypeMethodSheet = false
    @State var showingDoseScheduleSheet = false

    // Reminder state, moved from SettingsView.
    @State var doseRemindersEnabled = true
    @State var journalRemindersEnabled = false
    @State var doseReminderHour = 9
    @State var doseReminderMinute = 0
    @State var journalReminderHour = 21
    @State var journalReminderMinute = 0
    @State var showingDoseTimePicker = false
    @State var showingJournalTimePicker = false
    @State var showingAuthRequest = false

    private var currentRouteClass: RouteClass {
        RouteClass.from(method: medicationManager.selectedAdministrationMethod ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                ScheduleGroup
                RemindersGroup
                BodyGroup
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Medication & Dose")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDoseTimePicker) {
            TimePickerSheet(title: "Dose reminder time", hour: $doseReminderHour, minute: $doseReminderMinute, isPresented: $showingDoseTimePicker)
        }
        .sheet(isPresented: $showingJournalTimePicker) {
            TimePickerSheet(title: "Journal reminder time", hour: $journalReminderHour, minute: $journalReminderMinute, isPresented: $showingJournalTimePicker)
        }
        .sheet(isPresented: $showingTypeMethodSheet) {
            TypeMethodSettingsView()
        }
        .sheet(isPresented: $showingDoseScheduleSheet) {
            DoseScheduleSettingsView()
        }
        .onAppear { loadSettings() }
        .onChange(of: doseRemindersEnabled) { _, newValue in onDoseReminderToggle(newValue) }
        .onChange(of: doseReminderHour) { _, _ in onDoseTimeChange() }
        .onChange(of: doseReminderMinute) { _, _ in onDoseTimeChange() }
        .onChange(of: journalRemindersEnabled) { _, newValue in onJournalReminderToggle(newValue) }
        .onChange(of: journalReminderHour) { _, _ in onJournalTimeChange() }
        .onChange(of: journalReminderMinute) { _, _ in onJournalTimeChange() }
        .onChange(of: notificationManager.isAuthorizationDenied) { _, denied in
            if denied { showingAuthRequest = true }
        }
        .alert("Notifications disabled", isPresented: $showingAuthRequest) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To receive dose and journal reminders, please enable notifications in System Settings.")
        }
    }

    // MARK: - Schedule

    private var ScheduleGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Schedule", emphasis: .accent)
            SettingsGroup {
                Button {
                    showingTypeMethodSheet = true
                } label: {
                    SettingsRow(icon: "pills.fill",
                                title: "Type & method",
                                subtitle: medicationManager.medicationDisplayInfo) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                Button {
                    showingDoseScheduleSheet = true
                } label: {
                    SettingsRow(icon: "flask",
                                title: "Dose & frequency",
                                subtitle: nextDoseSubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                NavigationLink {
                    UnifiedScheduleView()
                } label: {
                    SettingsRow(icon: "calendar.badge.clock",
                                title: "Schedule overview",
                                subtitle: nil) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                HStack(spacing: Theme.Spacing.card) {
                    SettingsIconTile(icon: "calendar")

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("HRT start date")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(hrtStartSubtitle)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    DatePicker("", selection: Binding(
                        get: { medicationManager.hrtStartDate ?? Date() },
                        set: { newValue in
                            medicationManager.hrtStartDate = newValue
                            medicationManager.refreshState()
                        }
                    ), in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale.current)
                }
                .padding(.horizontal, Theme.Spacing.card)
                .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Reminders (X25)

    private var RemindersGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Reminders", emphasis: .accent)
            SettingsGroup {
                HStack(spacing: Theme.Spacing.card) {
                    SettingsIconTile(icon: "bell.fill")

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Dose reminders")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(doseRemindersEnabled ? formatDoseReminderSubtitle : "Off")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    SettingsToggle(isOn: $doseRemindersEnabled)
                }
                .padding(.horizontal, Theme.Spacing.card)
                .padding(.vertical, Theme.Spacing.md)
                .contentShape(Rectangle())
                .onTapGesture { if doseRemindersEnabled { showingDoseTimePicker = true } }

                SettingsGroupDivider()

                HStack(spacing: Theme.Spacing.card) {
                    SettingsIconTile(icon: "book.fill")

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Journal reminders")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(journalRemindersEnabled ? formatJournalReminderSubtitle : "Off")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    SettingsToggle(isOn: $journalRemindersEnabled)
                }
                .padding(.horizontal, Theme.Spacing.card)
                .padding(.vertical, Theme.Spacing.md)
                .contentShape(Rectangle())
                .onTapGesture { if journalRemindersEnabled { showingJournalTimePicker = true } }
            }
        }
    }

    // MARK: - Body & zones

    @ViewBuilder
    private var BodyGroup: some View {
        if currentRouteClass != .oral {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(text: "Body & zones", emphasis: .accent)
                SettingsGroup {
                    // The segmented picker sits under the row's title block, so
                    // this row is hand-built rather than routed through
                    // `SettingsRow`'s HStack.
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack(spacing: Theme.Spacing.card) {
                            SettingsIconTile(icon: "figure.stand")
                            Text("Body silhouette")
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                        }
                        Picker("", selection: Binding(
                            get: { medicationManager.bodyTypeRaw },
                            set: { medicationManager.bodyTypeRaw = $0 }
                        )) {
                            ForEach(BodyType.allCases) { type in
                                Text(type.displayName).tag(type.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.leading, SettingsIconTile.side + Theme.Spacing.card)
                    }
                    .padding(.horizontal, Theme.Spacing.card)
                    .padding(.vertical, Theme.Spacing.md)

                    SettingsGroupDivider()

                    NavigationLink {
                        PreferredZonesListView()
                    } label: {
                        SettingsRow(icon: "star",
                                    title: "Preferred zones",
                                    subtitle: preferredZonesSubtitle) {
                            SettingsChevron()
                        }
                    }
                    .buttonStyle(.plain)

                    SettingsGroupDivider()

                    NavigationLink {
                        AvoidZonesEditorView()
                    } label: {
                        SettingsRow(icon: "exclamationmark.shield",
                                    title: "Avoid zones",
                                    subtitle: avoidZonesSubtitle) {
                            SettingsChevron()
                        }
                    }
                    .buttonStyle(.plain)

                    SettingsGroupDivider()

                    Button {
                        UserDefaults.standard.set(false, forKey: "hasSeenRecommendedZonesInfo")
                    } label: {
                        SettingsRow(icon: "lightspectral.horizontal",
                                    title: "Re-show recommended zones",
                                    subtitle: "Show the clinical zones info overlay again")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Subtitles

    private var preferredZonesSubtitle: LocalizedStringResource {
        // The list reads the persisted set; the count here mirrors its lookup.
        let medication = medicationManager.selectedMedication ?? ""
        let route = currentRouteClass
        let key = "\(medication)|\(route.rawValue)"
        let stored = UserDefaults.standard.data(forKey: "mm.userPreferredZones")
        if let decoded = try? JSONDecoder().decode([String: [String]].self, from: stored ?? Data()),
           let zones = decoded[key], !zones.isEmpty {
            return LocalizedStringResource(
                "^[\(zones.count) zone](inflect: true)",
                comment: "Settings row subtitle counting preferred zones"
            )
        }
        let fallback = ZoneCentroidStore.preferredZones(medication: medication, routeClass: route).count
        return LocalizedStringResource(
            "^[\(fallback) zone](inflect: true)",
            comment: "Settings row subtitle counting preferred zones"
        )
    }

    private var avoidZonesSubtitle: LocalizedStringResource {
        let count = medicationManager.avoidZones.count
        if count == 0 { return "No zones marked" }
        return LocalizedStringResource(
            "^[\(count) zone](inflect: true) marked",
            comment: "Settings row subtitle counting marked body zones"
        )
    }

    private var nextDoseSubtitle: LocalizedStringResource {
        if let next = medicationManager.nextDoseDate {
            return LocalizedStringResource("Next: \(formatDate(next))")
        }
        return "No schedule set"
    }

    private var hrtStartSubtitle: LocalizedStringResource {
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

    // MARK: - Reminder persistence (moved from SettingsView)

    func loadSettings() {
        let defaults = UserDefaults.standard
        doseRemindersEnabled = defaults.bool(forKey: NotificationManager.Keys.doseReminderEnabled)
        doseReminderHour = defaults.integer(forKey: NotificationManager.Keys.doseReminderHour)
        doseReminderMinute = defaults.integer(forKey: NotificationManager.Keys.doseReminderMinute)
        journalRemindersEnabled = defaults.bool(forKey: NotificationManager.Keys.journalReminderEnabled)
        journalReminderHour = defaults.integer(forKey: NotificationManager.Keys.journalReminderHour)
        journalReminderMinute = defaults.integer(forKey: NotificationManager.Keys.journalReminderMinute)

        if defaults.object(forKey: NotificationManager.Keys.doseReminderEnabled) == nil {
            doseReminderHour = NotificationManager.Defaults.doseHour
            doseReminderMinute = NotificationManager.Defaults.doseMinute
            doseRemindersEnabled = true
            journalReminderHour = NotificationManager.Defaults.journalHour
            journalReminderMinute = NotificationManager.Defaults.journalMinute
            journalRemindersEnabled = false
        }
    }

    // ST5: localized format strings, `Date.FormatStyle` for the time itself.
    private var formatDoseReminderSubtitle: LocalizedStringResource {
        let freq = notificationManager.doseFrequencyDays
        let time = reminderTime(doseReminderHour, doseReminderMinute)
        if freq <= 1 {
            return LocalizedStringResource(
                "Daily at \(time)",
                comment: "Dose reminder row subtitle, daily schedule"
            )
        }
        return LocalizedStringResource(
            "Every \(freq) days at \(time)",
            comment: "Dose reminder row subtitle, multi-day interval"
        )
    }

    private var formatJournalReminderSubtitle: LocalizedStringResource {
        LocalizedStringResource(
            "Daily at \(reminderTime(journalReminderHour, journalReminderMinute))",
            comment: "Journal reminder row subtitle, daily schedule"
        )
    }

    /// A localized clock time from hour/minute ints, via `Date.FormatStyle` (ST5).
    private func reminderTime(_ hour: Int, _ minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            SettingsMedicationView()
                .environment(\.medicationManager, MedicationManager.shared)
                .environment(\.notificationManager, NotificationManager.shared)
                .environment(\.profileManager, ProfileManager.shared)
        }
    }
}
#endif
