//
//  SettingsView.swift
//  xT
//
//  Redesigned settings. The profile section now acts as a mini-dashboard
//  with key stats. Section grouping and row styling are more intentional.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile + stats header (replaces generic title)
                    profileHeader
                        .padding(.bottom, 8)

                    // Sections
                    VStack(spacing: 20) {
                        settingsMedicationSection
                        settingsNotificationsSection
                        settingsPrivacySection
                        settingsAboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Gradients.brand)
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 0) {
            // Gradient banner
            Theme.Gradients.brand
                .frame(height: 56)

            // Profile card overlapping the banner
            VStack(spacing: 12) {
                NavigationLink(destination: ProfileEditorView()) {
                    HStack(spacing: 12) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.brand)
                                .frame(width: 52, height: 52)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))

                            if let img = profileManager.profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            } else {
                                Text(profileManager.profileDisplayName.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .offset(y: -20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profileManager.profileDisplayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(profileSubtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: -10)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .offset(y: -10)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Stats strip
                HStack(spacing: 8) {
                    statChip(value: levelString, label: "current level")
                    statChip(value: nextDoseString, label: "next dose")
                    statChip(value: "\(medicationManager.monthsOnHRT) mo", label: "on HRT")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
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

    // MARK: - Notifications Section

    private var settingsNotificationsSection: some View {
        settingsSection(label: "Notifications") {
            HStack(spacing: 12) {
                settingsIconView(icon: "bell.fill", bg: Theme.Colors.Bloom.body.surface, color: Theme.Colors.Bloom.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose reminders")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Text(doseRemindersEnabled ? formatDoseReminderSubtitle : "Off")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $doseRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture { if doseRemindersEnabled { showingDoseTimePicker = true } }

            settingsDivider()

            HStack(spacing: 12) {
                settingsIconView(icon: "book.fill", bg: Theme.Colors.Bloom.cycle.surface, color: Theme.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal reminders")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Text(journalRemindersEnabled ? formatJournalReminderSubtitle : "Off")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $journalRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(12)
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
                    iconBg: Color(UIColor.systemGray6),
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
                iconBg: Color(UIColor.systemGray6),
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

    // MARK: - Reusable layout helpers

    private func settingsSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.05)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
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
        HStack(spacing: 12) {
            settingsIconView(icon: icon, bg: iconBg, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func settingsIconView(icon: String, bg: Color, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .padding(.leading, 56)
    }

    // MARK: - Computed strings

    private var profileSubtitle: String {
        if medicationManager.isFullyConfigured {
            return "\(medicationManager.monthsOnHRT) months · \(medicationManager.medicationDisplayInfo)"
        }
        return "Tap to edit profile"
    }

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

    // MARK: - Computed display strings

    private var formatDoseReminderSubtitle: String {
        let timeStr = String(format: "%02d:%02d", doseReminderHour, doseReminderMinute)
        return "Daily at \(timeStr)"
    }

    private var formatJournalReminderSubtitle: String {
        let timeStr = String(format: "%02d:%02d", journalReminderHour, journalReminderMinute)
        return "Daily at \(timeStr)"
    }

    // MARK: - Notification Handlers

    private func onDoseReminderToggle(_ enabled: Bool) {
        notificationManager.configureDoseReminder(
            enabled: enabled,
            hour: doseReminderHour,
            minute: doseReminderMinute
        )
    }

    private func onDoseTimeChange() {
        notificationManager.configureDoseReminder(
            enabled: doseRemindersEnabled,
            hour: doseReminderHour,
            minute: doseReminderMinute
        )
    }

    private func onJournalReminderToggle(_ enabled: Bool) {
        notificationManager.configureJournalReminder(
            enabled: enabled,
            hour: journalReminderHour,
            minute: journalReminderMinute
        )
    }

    private func onJournalTimeChange() {
        notificationManager.configureJournalReminder(
            enabled: journalRemindersEnabled,
            hour: journalReminderHour,
            minute: journalReminderMinute
        )
    }

    // MARK: - Persistence helpers

    private func loadSettings() {
        doseRemindersEnabled = UserDefaults.standard.bool(forKey: "doseReminderEnabled")
        doseReminderHour = UserDefaults.standard.integer(forKey: "doseReminderHour")
        doseReminderMinute = UserDefaults.standard.integer(forKey: "doseReminderMinute")
        journalRemindersEnabled = UserDefaults.standard.bool(forKey: "journalReminderEnabled")
        journalReminderHour = UserDefaults.standard.integer(forKey: "journalReminderHour")
        journalReminderMinute = UserDefaults.standard.integer(forKey: "journalReminderMinute")

        // If no notification settings have been saved yet, use defaults
        if UserDefaults.standard.object(forKey: "doseReminderEnabled") == nil {
            doseReminderHour = 9
            doseReminderMinute = 0
            doseRemindersEnabled = true
            journalReminderHour = 21
            journalReminderMinute = 0
            journalRemindersEnabled = false
        }

        // Request authorization on first launch
        Task { await notificationManager.requestAuthorization() }

        // Apply loaded settings to NotificationManager
        notificationManager.configureDoseReminder(
            enabled: doseRemindersEnabled,
            hour: doseReminderHour,
            minute: doseReminderMinute
        )
        notificationManager.configureJournalReminder(
            enabled: journalRemindersEnabled,
            hour: journalReminderHour,
            minute: journalReminderMinute
        )
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

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}