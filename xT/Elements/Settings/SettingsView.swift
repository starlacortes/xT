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
    @State private var doseRemindersEnabled = true
    @State private var journalRemindersEnabled = false
    @State private var doseReminderHour = 9
    @State private var doseReminderMinute = 0
    @State private var journalReminderHour = 21
    @State private var journalReminderMinute = 0
    @State private var showingDoseTimePicker = false
    @State private var showingJournalTimePicker = false
    
    // Therapeutic target state
    @State private var useCustomTargets: Bool = false
    @State private var targetTroughMin: Double = 100
    @State private var targetTroughMax: Double = 200
    @State private var targetPeakCeiling: Double = 600

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
                        settingsTherapeuticTargetsSection
                        settingsNotificationsSection
                        settingsPrivacySection
                        settingsAboutSection
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .sheet(isPresented: $showingDoseTimePicker) {
                TimePickerSheet(title: "Dose reminder time", hour: $doseReminderHour, minute: $doseReminderMinute, isPresented: $showingDoseTimePicker)
            }
            .sheet(isPresented: $showingJournalTimePicker) {
                TimePickerSheet(title: "Journal reminder time", hour: $journalReminderHour, minute: $journalReminderMinute, isPresented: $showingJournalTimePicker)
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
            settingsRow(
                icon: "pills.fill",
                iconBg: Theme.Colors.Bloom.cycle.surface,
                iconColor: Theme.Colors.Bloom.cycle.base,
                title: "Type & method",
                subtitle: medicationManager.medicationDisplayInfo
            ) {
                NavigationLink(destination: UnifiedScheduleView(isFromSettings: true)) {
                    EmptyView()
                }
                .opacity(0)
            }

            settingsDivider()

            settingsRow(
                icon: "calendar",
                iconBg: Theme.Colors.Bloom.mind.surface,
                iconColor: Theme.Colors.Bloom.mind.base,
                title: "Dose schedule",
                subtitle: nextDoseSubtitle
            ) {
                NavigationLink(destination: UnifiedScheduleView(isFromSettings: true)) {
                    EmptyView()
                }
                .opacity(0)
            }

            settingsDivider()

            Button(action: {
                medicationManager.recordDose(on: Date())
            }) {
                settingsRowContent(
                    icon: "checkmark",
                    iconBg: Theme.Colors.Bloom.skin.surface,
                    iconColor: Theme.Colors.Bloom.skin.base,
                    title: "Record a dose",
                    subtitle: lastDoseSubtitle,
                    trailing: { Image(systemName: "checkmark.circle").font(.system(size: 16)).foregroundStyle(Theme.Colors.Bloom.skin.base) }
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Therapeutic Targets Section

    private var settingsTherapeuticTargetsSection: some View {
        settingsSection(label: "Therapeutic targets") {
            // Toggle to enable custom targets
            HStack(spacing: 14) {
                settingsIconView(icon: "target", bg: Theme.Colors.Bloom.body.surface, color: Theme.Colors.Bloom.body.base)

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
                               range: (targetTroughMin + 1)...9999,
                               description: "Your target ceiling at trough time")

                settingsDivider()

                // Peak Ceiling
                targetValueRow(label: "Peak ceiling",
                               value: $targetPeakCeiling,
                               unit: medicationUnit,
                               range: (targetTroughMax)...9999,
                               description: "Upper safety limit near peak")

                settingsDivider()

                // Info footer
                VStack(alignment: .leading, spacing: 4) {
                    Text("These targets replace the clinical defaults. Your classifications will show \"Your Target\" instead of \"Target Trough\" or \"Expected Peak.\"")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
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
                settingsIconView(icon: "bell.fill", bg: Theme.Colors.Bloom.body.surface, color: Theme.Colors.Bloom.body.base)

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
                settingsIconView(icon: "book.fill", bg: Theme.Colors.Bloom.cycle.surface, color: Theme.Colors.accent)

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
        return "\(biometric) · \(timeout) timeout"
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
                trailing: { Text("1.0.0").font(.system(size: 13)).foregroundStyle(.secondary) }
            )

            settingsDivider()

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

    private func settingsRow<Destination: View>(
        icon: String,
        iconBg: Color,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            settingsRowContent(
                icon: icon,
                iconBg: iconBg,
                iconColor: iconColor,
                title: title,
                subtitle: subtitle,
                trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
            )
        }
        .buttonStyle(.plain)
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
        if let level = medicationManager.currentHormoneLevel?.value {
            return "\(Int(level)) \(medicationManager.currentHormoneLevel?.unit ?? "pg/mL")"
        }
        return "—"
    }

    private var nextDoseString: String {
        guard let next = medicationManager.nextDoseDate else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }

    private var nextDoseSubtitle: String {
        if let next = medicationManager.nextDoseDate {
            return "Next: \(formatDate(next))"
        }
        return "No schedule set"
    }

    private var lastDoseSubtitle: String {
        if let last = medicationManager.lastDoseDate {
            return "Last: \(formatDate(last))"
        }
        return "No doses recorded"
    }

    private var formatDoseReminderSubtitle: String {
        String(format: "Daily at %02d:%02d", doseReminderHour, doseReminderMinute)
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

        Task { await notificationManager.requestAuthorization() }

        notificationManager.configureDoseReminder(enabled: doseRemindersEnabled, hour: doseReminderHour, minute: doseReminderMinute)
        notificationManager.configureJournalReminder(enabled: journalRemindersEnabled, hour: journalReminderHour, minute: journalReminderMinute)
    }

    private func resetAppData() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }
        profileManager.clearProfileImage()
        profileManager.updateProfileName("")
        medicationManager.clearSelection()
        clearSwiftData()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    private func clearSwiftData() {
        do {
            let schema = Schema([JournalEntry.self])
            let container = try ModelContainer(for: schema)
            try container.mainContext.delete(model: JournalEntry.self)
        } catch {
            print("Error clearing SwiftData: \(error)")
        }
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
#Preview {
    SettingsView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}
