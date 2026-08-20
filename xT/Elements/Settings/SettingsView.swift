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
import UserNotifications

struct SettingsView: View {
    @Environment(\.profileManager) var profileManager
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.notificationManager) var notificationManager
    @Environment(\.authenticationManager) var authManager
    @Environment(\.themeManager) var themeManager
    @State var showingResetAlert = false
    @State var showingAuthRequest = false
    @State var showingTypeMethodSheet = false
    @State var showingDoseScheduleSheet = false
    @State var doseRemindersEnabled = true
    @State var journalRemindersEnabled = false
    @State var doseReminderHour = 9
    @State var doseReminderMinute = 0
    @State var journalReminderHour = 21
    @State var journalReminderMinute = 0
    @State var showingDoseTimePicker = false
    @State var showingJournalTimePicker = false

    // iCloud sync
    @State var icloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "icloudSyncEnabled")
    @State var showingRestartAlert = false

    // Therapeutic target state
    @State var useCustomTargets: Bool = false
    @State var targetTroughMin: Double = 100
    @State var targetTroughMax: Double = 200
    @State var targetPeakCeiling: Double = 600
    @FocusState var targetFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeaderBlock
                        .entrance(delay: 0.04)

                    Divider()
                        .opacity(0.5)

                    quickAccessCards
                        .padding(.top, 24)

                     VStack(spacing: 32) {
                        settingsMedicationBodySection
                        settingsHealthHistorySection
                        settingsAppSection
                        settingsAboutSection
                        settingsResetSection
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Colors.appBackground)
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

    // MARK: - Persistence helpers

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

    func resetAppData() {
        let defaults = UserDefaults.standard

        // 1-2. Clear in-memory profile + medication/dose state (shared implementation,
        //      so a spoof/persona swap and a full reset can no longer drift apart).
        DatasetReset.resetManagerState()
        medicationManager.invalidateHeatMapCache()

        // 3-4. Delete all SwiftData records, including journal entries.
        if let ctx = medicationManager.modelContext {
            do {
                try DatasetReset.wipeSwiftData(in: ctx)
            } catch {
                print("[resetAppData] SwiftData clear error: \(error)")
            }
        }

        // If SpoofProfile was applied, clear its flag so a fresh start works.
        // (Raw string: SpoofProfile.spfKey is DEBUG-only and cannot be referenced here.)
        defaults.removeObject(forKey: "com.xt.spoofProfile_jan_v1")

        // 5. Cancel all pending notifications (dose / journal reminders)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // 6. Wipe ALL UserDefaults (must come LAST to clear any keys re-created by the steps above)
        defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }

        // 7. Set onboarding flag after the wipe
        defaults.set(false, forKey: "hasCompletedOnboarding")
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
