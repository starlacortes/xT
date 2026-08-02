//
//  SettingsView.swift
//  xT
//
//  Flat design matching Home screen — centered profile block at top,
//  section rows separated by hairline dividers.
//

import SwiftUI
import PhotosUI
import SwiftData

struct SettingsView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.notificationManager) private var notificationManager
    @Environment(\.authenticationManager) private var authManager
    @State private var showingResetAlert = false
    @State private var showingAuthRequest = false
    @State private var showingTypeMethodSheet = false
    @State private var showingDoseScheduleSheet = false
    @State private var doseRemindersEnabled = true
    @State private var journalRemindersEnabled = false
    @State private var doseReminderHour = 9
    @State private var doseReminderMinute = 0
    @State private var journalReminderHour = 21
    @State private var journalReminderMinute = 0
    @State private var showingDoseTimePicker = false
    @State private var showingJournalTimePicker = false
    @AppStorage("bodyType") private var bodyTypeRaw: String = BodyType.neutral.rawValue

    // Therapeutic target state
    @State private var useCustomTargets: Bool = false
    @State private var targetTroughMin: Double = 100
    @State private var targetTroughMax: Double = 200
    @State private var targetPeakCeiling: Double = 600
    @FocusState private var targetFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeaderBlock
                        .entrance(delay: 0.04)

                    Divider()
                        .opacity(0.5)

                    VStack(spacing: 32) {
                        settingsMedicationSection
                        settingsBodyZonesSection
                        settingsLevelsTargetsSection
                        settingsHistorySection
                        settingsNotificationsSection
                        settingsPrivacySection
                        settingsAboutSection
                        settingsResetSection
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
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
            .alert("Notifications disabled", isPresented: $showingAuthRequest) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("To receive dose and journal reminders, please enable notifications in System Settings.")
            }
            .alert("Are you sure?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetAppData() }
            } message: {
                Text("xT will close and restart the onboarding process.")
            }
        }
    }

    // MARK: - Profile Header Block

    private var profileHeaderBlock: some View {
        VStack(spacing: 14) {
            if let img = profileManager.profileImage {
                // Large borderless circle photo
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())

                Text(profileManager.profileDisplayName)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(.primary)

            } else if !profileManager.profileName.isEmpty {
                // Name in large gradient text (no photo)
                Text(profileManager.profileName)
                    .font(.system(size: 48, weight: .bold))
                    .tracking(-1.0)
                    .foregroundStyle(
                        LinearGradient(
                            colors: Theme.Gradients.brandColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)

            } else {
                // No photo, no name — gradient circle placeholder
                Circle()
                    .fill(Theme.Gradients.brand)
                    .frame(width: 120, height: 120)
            }

            NavigationLink(destination: ProfileEditorView()) {
                Text("Edit Profile")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)

            // Stats strip
            if medicationManager.isFullyConfigured {
                HStack(spacing: 0) {
                    statItem(value: levelString, label: "level")
                    Divider().frame(height: 28)
                    statItem(value: nextDoseString, label: "next dose")
                    Divider().frame(height: 28)
                    statItem(value: "\(medicationManager.monthsOnHRT) mo", label: "on HRT")
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 28)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Fonts.callout)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.Fonts.micro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Medication Section

    private var settingsMedicationSection: some View {
        settingsSection(label: "Medication") {
            Button {
                showingTypeMethodSheet = true
            } label: {
                settingsRowContent(
                    icon: "pills.fill",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Type & method",
                    subtitle: medicationManager.medicationDisplayInfo,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            Button {
                showingDoseScheduleSheet = true
            } label: {
                settingsRowContent(
                    icon: "flask",
                    iconBg: Theme.Colors.Time.mind.surface,
                    iconColor: Theme.Colors.Time.mind.base,
                    title: "Dose & frequency",
                    subtitle: nextDoseSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Body & Zones Section

    private var settingsBodyZonesSection: some View {
        settingsSection(label: "Body & zones") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    settingsIconView(icon: "figure.stand", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Body silhouette")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(.primary)
                        Text("Silhouette used in the 3D body picker")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Picker("", selection: $bodyTypeRaw) {
                    ForEach(BodyType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 50)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            settingsDivider()

            NavigationLink(destination: PreferredZonesListView()) {
                settingsRowContent(
                    icon: "star",
                    iconBg: Theme.Colors.accent.opacity(0.13),
                    iconColor: Theme.Colors.accent,
                    title: "Preferred zones",
                    subtitle: "Favoured injection & application sites",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: AvoidZonesEditorView()) {
                settingsRowContent(
                    icon: "exclamationmark.shield",
                    iconBg: Theme.Colors.warning.opacity(0.13),
                    iconColor: Theme.Colors.warning,
                    title: "Avoid zones",
                    subtitle: avoidZonesSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            Button {
                UserDefaults.standard.set(false, forKey: "hasSeenRecommendedZonesInfo")
            } label: {
                settingsRowContent(
                    icon: "lightspectral.horizontal",
                    iconBg: Theme.Colors.accent.opacity(0.13),
                    iconColor: Theme.Colors.accent,
                    title: "Re-show recommended zones",
                    subtitle: "Show the clinical zones info overlay again",
                    trailing: { EmptyView() }
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - History Section

    private var settingsHistorySection: some View {
        settingsSection(label: "History") {
            NavigationLink(destination: AdherenceView()) {
                settingsRowContent(
                    icon: "chart.line.uptrend.xyaxis",
                    iconBg: Theme.Colors.Time.body.surface,
                    iconColor: Theme.Colors.Time.body.base,
                    title: "Adherence & history",
                    subtitle: adherenceSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: DoseHistoryView()) {
                settingsRowContent(
                    icon: "clock.arrow.circlepath",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Dose history",
                    subtitle: doseHistorySubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Levels & Targets Section

    private var settingsLevelsTargetsSection: some View {
        settingsSection(label: "Levels & targets") {
            // Dose-intensity insights toggle
            HStack(spacing: 14) {
                settingsIconView(icon: "gauge.with.dots.needle.33percent",
                                 bg: Theme.Colors.Time.mind.surface,
                                 color: Theme.Colors.Time.mind.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose intensity insights")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(medicationManager.showDoseIntensityInsights ? "On — personalised dose intensity shown" : "Off — use clinical defaults")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { medicationManager.showDoseIntensityInsights },
                    set: {
                        medicationManager.showDoseIntensityInsights = $0
                        medicationManager.persistUserPreferences()
                        medicationManager.refreshState()
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())

            settingsDivider()

            // Toggle to enable custom targets
            HStack(spacing: 14) {
                settingsIconView(icon: "target", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use personal targets")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(useCustomTargets ? targetSummary : "Use clinical defaults")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $useCustomTargets)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    .onChange(of: useCustomTargets) { _, enabled in
                        if enabled { saveTherapeuticTargets() } else { clearTherapeuticTargets() }
                    }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())

            if useCustomTargets {
                settingsDivider()

                // Trough Min
                targetValueRow(label: "Trough lower bound",
                               value: $targetTroughMin,
                               unit: medicationUnit,
                               range: 0...9999,
                               description: "Your target floor at trough time")

                settingsDivider()

                // Trough Max
                targetValueRow(label: "Trough upper bound",
                               value: $targetTroughMax,
                               unit: medicationUnit,
                               range: min(targetTroughMin + 1, 9999)...9999,
                               description: "Your target ceiling at trough time")

                settingsDivider()

                // Peak Ceiling
                targetValueRow(label: "Peak ceiling",
                               value: $targetPeakCeiling,
                               unit: medicationUnit,
                               range: min(targetTroughMax, 9999)...9999,
                               description: "Upper safety limit near peak")

                settingsDivider()

                // Info footer
                VStack(alignment: .leading, spacing: 4) {
                    // This is the switch that turns on comparative copy across the
                    // app, so the footer says exactly that. Without a range set,
                    // xT reports the estimate and makes no comparison.
                    Text("Setting a range lets xT report where an estimate falls relative to it. Without one, xT shows the estimate on its own.")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { targetFieldFocused = false }
            }
        }
    }

    private var targetSummary: String {
        "Trough \(Int(targetTroughMin))–\(Int(targetTroughMax)) \(medicationUnit) · Peak ceiling \(Int(targetPeakCeiling)) \(medicationUnit)"
    }

    private var medicationUnit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    @ViewBuilder
    private func targetValueRow(label: String, value: Binding<Double>, unit: String,
                                 range: ClosedRange<Double>, description: String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .focused($targetFieldFocused)
                    .submitLabel(.done)
                    .onChange(of: value.wrappedValue) { _, newVal in
                        // Clamp to range
                        if newVal < range.lowerBound { value.wrappedValue = range.lowerBound }
                        if newVal > range.upperBound { value.wrappedValue = range.upperBound }
                        saveTherapeuticTargets()
                    }

                Text(unit)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    private func saveTherapeuticTargets() {
        guard useCustomTargets else { return }
        let target = MedicationManager.TherapeuticTarget(
            troughMin: targetTroughMin,
            troughMax: targetTroughMax,
            peakCeiling: targetPeakCeiling
        )
        medicationManager.userTherapeuticTarget = target
        medicationManager.refreshState()
    }

    private func clearTherapeuticTargets() {
        medicationManager.userTherapeuticTarget = nil
        medicationManager.refreshState()
    }

    // MARK: - Notifications Section

    private var settingsNotificationsSection: some View {
        settingsSection(label: "Notifications") {
            HStack(spacing: 14) {
                settingsIconView(icon: "bell.fill", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose reminders")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(doseRemindersEnabled ? formatDoseReminderSubtitle : "Off")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $doseRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture { if doseRemindersEnabled { showingDoseTimePicker = true } }

            settingsDivider()

            HStack(spacing: 14) {
                settingsIconView(icon: "book.fill", bg: Theme.Colors.Time.cycle.surface, color: Theme.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal reminders")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(journalRemindersEnabled ? formatJournalReminderSubtitle : "Off")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $journalRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture { if journalRemindersEnabled { showingJournalTimePicker = true } }
        }
    }

    private var privacyLockSubtitle: String {
        let biometric = authManager.biometricType().description
        let timeout = authManager.timeoutLabel
        return String(localized: "\(biometric) · \(timeout) timeout")
    }

    // MARK: - Privacy Section

    private var settingsPrivacySection: some View {
        settingsSection(label: "Privacy & security") {
            NavigationLink(destination: AppLockSettingsView()) {
                settingsRowContent(
                    icon: "lock.fill",
                    iconBg: Color(.systemGray6),
                    iconColor: .secondary,
                    title: "App lock",
                    subtitle: privacyLockSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: DataExportView()) {
                settingsRowContent(
                    icon: "square.and.arrow.up",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Export data",
                    subtitle: "CSV or JSON — dose history, journal, blood tests",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - About Section

    private var settingsAboutSection: some View {
        settingsSection(label: "About") {
            settingsRowContent(
                icon: "info.circle.fill",
                iconBg: Color(.systemGray6),
                iconColor: .secondary,
                title: "Version",
                subtitle: nil,
                trailing: { Text("0.8.5").font(.system(size: 13)).foregroundStyle(.secondary) }
            )
#if DEBUG
            settingsDivider()
            NavigationLink(destination: DeveloperSettingsView()) {
                settingsRowContent(
                    icon: "wrench.and.screwdriver",
                    iconBg: Color(.systemGray6),
                    iconColor: .secondary,
                    title: "Developer",
                    subtitle: "Tools & test options",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
#endif
        }
    }

    // MARK: - Reset Section

    private var settingsResetSection: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            Button(role: .destructive, action: { showingResetAlert = true }) {
                settingsRowContent(
                    icon: "trash.fill",
                    iconBg: Theme.Colors.error.opacity(0.1),
                    iconColor: Theme.Colors.error,
                    title: "Reset app data",
                    subtitle: nil,
                    trailing: { EmptyView() }
                )
            }
            .buttonStyle(.plain)
            Divider().opacity(0.5)
        }
    }

    // MARK: - Layout helpers

    private func settingsSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(0.5)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            Divider().opacity(0.5)
            content()
            Divider().opacity(0.5)
        }
    }

    private func settingsRowContent<Trailing: View>(
        icon: String,
        iconBg: Color,
        iconColor: Color,
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            settingsIconView(icon: icon, bg: iconBg, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func settingsIconView(icon: String, bg: Color, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 22 + 32 + 14) // align with text
    }

    // MARK: - Computed strings

    private var levelString: String {
        medicationManager.currentHormoneLevel?.valueDescription ?? "—"
    }

    private var nextDoseString: String {
        guard let next = medicationManager.nextDoseDate else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return String(localized: "In \(days)d")
    }

    private var nextDoseSubtitle: String {
        if let next = medicationManager.nextDoseDate {
            return String(localized: "Next: \(formatDate(next))")
        }
        return String(localized: "No schedule set")
    }

    private var adherenceSubtitle: String {
        guard medicationManager.isFullyConfigured else {
            return String(localized: "No medication configured",
                          comment: "Settings row subtitle when adherence data is unavailable")
        }
        if let rate = medicationManager.adherenceRate {
            return String(localized: "\(AppNumberFormatters.percent.string(rate * 100))% of scheduled doses recorded",
                          comment: "Settings row subtitle summarising 30-day adherence")
        }
        return String(localized: "Regimen history and dose intensity",
                      comment: "Settings row subtitle for the adherence screen before any adherence data exists")
    }

    private var doseHistorySubtitle: String {
        let count = medicationManager.doseHistory.count
        if count == 0 { return "No doses recorded yet" }
        return String(localized: "Review and correct ^[\(count) dose](inflect: true)",
                      comment: "Settings row subtitle counting doses that need review")
    }

    private var avoidZonesSubtitle: String {
        let count = medicationManager.avoidZones.count
        if count == 0 { return "No zones marked" }
        return String(localized: "^[\(count) zone](inflect: true) marked",
                      comment: "Settings row subtitle counting marked body zones")
    }

    private var formatDoseReminderSubtitle: String {
        let freq = notificationManager.doseFrequencyDays
        if freq <= 1 {
            return String(format: "Daily at %02d:%02d", doseReminderHour, doseReminderMinute)
        } else {
            return String(format: "Every %d days at %02d:%02d", freq, doseReminderHour, doseReminderMinute)
        }
    }

    private var formatJournalReminderSubtitle: String {
        String(format: "Daily at %02d:%02d", journalReminderHour, journalReminderMinute)
    }

    // MARK: - Notification Handlers

    private func onDoseReminderToggle(_ enabled: Bool) {
        notificationManager.configureDoseReminder(enabled: enabled, hour: doseReminderHour, minute: doseReminderMinute)
    }

    private func onDoseTimeChange() {
        notificationManager.configureDoseReminder(enabled: doseRemindersEnabled, hour: doseReminderHour, minute: doseReminderMinute)
    }

    private func onJournalReminderToggle(_ enabled: Bool) {
        notificationManager.configureJournalReminder(enabled: enabled, hour: journalReminderHour, minute: journalReminderMinute)
    }

    private func onJournalTimeChange() {
        notificationManager.configureJournalReminder(enabled: journalRemindersEnabled, hour: journalReminderHour, minute: journalReminderMinute)
    }

    // MARK: - Persistence helpers

    private func loadSettings() {
        doseRemindersEnabled = UserDefaults.standard.bool(forKey: "doseReminderEnabled")
        doseReminderHour = UserDefaults.standard.integer(forKey: "doseReminderHour")
        doseReminderMinute = UserDefaults.standard.integer(forKey: "doseReminderMinute")
        journalRemindersEnabled = UserDefaults.standard.bool(forKey: "journalReminderEnabled")
        journalReminderHour = UserDefaults.standard.integer(forKey: "journalReminderHour")
        journalReminderMinute = UserDefaults.standard.integer(forKey: "journalReminderMinute")

        if UserDefaults.standard.object(forKey: "doseReminderEnabled") == nil {
            doseReminderHour = 9
            doseReminderMinute = 0
            doseRemindersEnabled = true
            journalReminderHour = 21
            journalReminderMinute = 0
            journalRemindersEnabled = false
        }
    }

    private func resetAppData() {
        let defaults = UserDefaults.standard

        // 1. Clear in-memory profile state
        profileManager.profileName = ""
        profileManager.profileImage = nil
        profileManager.profileImageData = nil
        profileManager.dateOfBirth = nil

        // 2. Clear in-memory medication + dose state
        medicationManager.selectedMedication = nil
        medicationManager.selectedAdministrationMethod = nil
        medicationManager.selectedEster = nil
        medicationManager.lastDoseDate = nil
        medicationManager.nextDoseDate = nil
        medicationManager.hrtStartDate = nil
        medicationManager.currentHormoneLevel = nil
        medicationManager.recentLevels = []
        medicationManager.doseHistory = []
        medicationManager.bloodTestHistory = []
        medicationManager.screeningRecords = []
        medicationManager.predictedTroughDrop = nil
        medicationManager.avoidZones = [:]
        medicationManager.regimenTransitionHistory = []
        medicationManager.doseRecordedCount = 0
        medicationManager.userTherapeuticTarget = nil

        // 3. Delete all SwiftData records from the active model context
        if let ctx = medicationManager.modelContext {
            do {
                for dose in try ctx.fetch(FetchDescriptor<DoseRecord>()) { ctx.delete(dose) }
                for test in try ctx.fetch(FetchDescriptor<BloodTestRecord>()) { ctx.delete(test) }
                for screening in try ctx.fetch(FetchDescriptor<ScreeningRecord>()) { ctx.delete(screening) }
                for pref in try ctx.fetch(FetchDescriptor<UserPreferences>()) { ctx.delete(pref) }
                try ctx.save()
            } catch {
                print("[resetAppData] SwiftData clear error: \(error)")
            }
        }

        // 4. Clear journal in-memory state + SwiftData
        JournalManager.shared.entries = []
        JournalManager.shared.currentSymptoms = []
        if let ctx = JournalManager.shared.modelContext {
            do {
                for entry in try ctx.fetch(FetchDescriptor<JournalEntry>()) { ctx.delete(entry) }
                try ctx.save()
            } catch {
                print("[resetAppData] Journal clear error: \(error)")
            }
        }
        // If SpoofProfile was applied, clear its flag so a fresh start works
        UserDefaults.standard.removeObject(forKey: "com.xt.spoofProfile_jan_v1")

        // 5. Wipe ALL UserDefaults (must come LAST to clear any keys re-created by the steps above)
        defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }

        // 6. Set onboarding flag after the wipe
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
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

// MARK: - Preview
#if DEBUG
#Preview {
    SpoofPreview {
        SettingsView()
            .environment(\.profileManager, ProfileManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
