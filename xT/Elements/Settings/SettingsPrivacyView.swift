//
//  SettingsPrivacyView.swift
//  xT
//
//  Settings → Privacy & Data (ST1). App lock, iCloud sync (+ Restore / Sync
//  now), data export, and — as the last card — the destructive Reset row
//  (ST12, X27): no icon tile, system destructive red label. The 3-button
//  reset alert and the iCloud handlers moved from `SettingsView` unchanged.
//

import SwiftUI
import UserNotifications

struct SettingsPrivacyView: View {
    @Environment(\.profileManager) var profileManager
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.authenticationManager) var authManager
    @Environment(\.rebuildCloudContainer) var rebuildCloudContainer

    @State var showingResetAlert = false

    // iCloud sync (moved from SettingsView)
    @State var icloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "icloudSyncEnabled")
    @State var showingRestartAlert = false

    // iCloud restore / sync now
    enum CloudActivity: Equatable { case restoring, syncing }
    @State var cloudActivity: CloudActivity?
    @State var showRestoreCompleteAlert = false
    @State var showRestoreNotFoundAlert = false
    @State var showSyncCompleteAlert = false
    @State var showSyncFailedAlert = false
    @State var showProfileNamePrompt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                LockGroup
                CloudGroup
                DataGroup
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProfileNamePrompt) {
            ProfileNamePromptView(isPresented: $showProfileNamePrompt)
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("OK") { }
        } message: {
            Text("This change will take effect the next time you open xT.")
        }
        .alert("Data Restored", isPresented: $showRestoreCompleteAlert) {
            Button("OK", role: .cancel) {
                // Same device-key caveat as the onboarding restore: if the
                // restored profile name is unreadable, collect a new one.
                if profileManager.profileName.isEmpty {
                    showProfileNamePrompt = true
                }
            }
        } message: {
            Text("Your data was restored from iCloud.")
        }
        .alert("No iCloud Data Found", isPresented: $showRestoreNotFoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No existing data was found in iCloud.")
        }
        .alert("Sync Complete", isPresented: $showSyncCompleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("xT saved your changes. iCloud will finish syncing automatically.")
        }
        .alert("Sync Unavailable", isPresented: $showSyncFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("iCloud sync isn't available right now. Try again in a moment.")
        }
        .alert("Reset App Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("This Device Only") { resetAppData(includingCloud: false) }
            Button("This Device and iCloud", role: .destructive) { resetAppData(includingCloud: true) }
        } message: {
            Text("\"This Device Only\" keeps your iCloud data — turning iCloud Sync back on later restores it. \"This Device and iCloud\" deletes your data everywhere.\n\nThis will close xT.")
        }
    }

    // MARK: - App lock

    private var LockGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Security", emphasis: .accent)
            SettingsGroup {
                NavigationLink {
                    AppLockSettingsView()
                } label: {
                    SettingsRow(icon: "lock.fill",
                                title: "App lock",
                                subtitle: privacyLockSubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - iCloud

    private var CloudGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "iCloud", emphasis: .accent)
            SettingsGroup {
                SettingsRow(icon: "icloud",
                            title: "iCloud Sync",
                            subtitle: icloudSyncEnabled
                                ? "Data syncs across your devices"
                                : "Data stays on this device only") {
                    SettingsToggle(isOn: $icloudSyncEnabled)
                }
                .onChange(of: icloudSyncEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "icloudSyncEnabled")
                    showingRestartAlert = true
                }

                if icloudSyncEnabled {
                    SettingsGroupDivider()

                    Button {
                        Task { await restoreFromiCloud() }
                    } label: {
                        SettingsRow(icon: "icloud.and.arrow.down",
                                    title: "Restore from iCloud",
                                    subtitle: "Download your data from iCloud") {
                            if cloudActivity == .restoring {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(cloudActivity != nil)

                    SettingsGroupDivider()

                    Button {
                        Task { await syncNow() }
                    } label: {
                        SettingsRow(icon: "arrow.triangle.2.circlepath.icloud",
                                    title: "Sync Now",
                                    subtitle: "Upload changes and refresh from iCloud") {
                            if cloudActivity == .syncing {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(cloudActivity != nil)
                }
            }
        }
    }

    // MARK: - Data

    private var DataGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Data", emphasis: .accent)
            SettingsGroup {
                NavigationLink {
                    DataExportView()
                } label: {
                    SettingsRow(icon: "square.and.arrow.up",
                                title: "Export data",
                                subtitle: "CSV or JSON — dose history, journal, blood tests") {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }

            // Reset (ST12, X27): its own card, no icon tile, destructive red
            // label. This is a control, not data display.
            Button(role: .destructive, action: { showingResetAlert = true }) {
                Text("Reset app data")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.card)
            }
            .buttonStyle(.plain)
            .paperCard(padding: 0, radius: Theme.Radius.lg)
        }
    }

    // MARK: - Subtitles

    private var privacyLockSubtitle: LocalizedStringResource {
        // ST4: show the real state — "lock off" reads "Off", not "Face ID · timeout".
        guard authManager.requireAuthentication else { return "Off" }
        let biometric = authManager.biometricType().description
        let timeout = authManager.timeoutLabel
        return "\(biometric) · \(timeout) timeout"
    }

    // MARK: - iCloud handlers (moved from SettingsView+CloudSync.swift)

    func restoreFromiCloud() async {
        cloudActivity = .restoring
        let restored = await CloudSyncService.restoreFromiCloud()
        cloudActivity = nil
        if restored {
            showRestoreCompleteAlert = true
        } else {
            showRestoreNotFoundAlert = true
        }
        // No onboardingComplete here: the managers are ObservableObjects, so
        // Settings rows and the rest of the app refresh live on success.
    }

    func syncNow() async {
        cloudActivity = .syncing
        let requested = await CloudSyncService.syncNow()
        cloudActivity = nil
        if requested {
            showSyncCompleteAlert = true
        } else {
            showSyncFailedAlert = true
        }
    }

    // MARK: - Reset (moved from SettingsView.swift)

    func resetAppData(includingCloud: Bool) {
        let defaults = UserDefaults.standard

        if !includingCloud {
            // Local-only reset: switch to a store with no CloudKit backing
            // BEFORE deleting rows, so no tombstones are exported and the
            // iCloud copy survives. The store file itself is replaced at the
            // next launch (pendingLocalStoreWipeKey) so no history of the
            // deletion survives to a later re-enable of sync either.
            defaults.set(false, forKey: "icloudSyncEnabled")
            rebuildCloudContainer(.cloudKit(false))
        }

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

        if !includingCloud {
            // Post-wipe flags for the local-only path: stay local-only, and
            // replace the store file at the next launch (safe — no container
            // is alive in xTApp.init).
            defaults.set(false, forKey: "icloudSyncEnabled")
            defaults.set(true, forKey: CloudSyncService.pendingLocalStoreWipeKey)
        }

        // 8. Close the app — every reset path wants a clean relaunch (fresh
        //    store file, onboarding from the top). Synchronize first so the
        //    flags written above survive the abrupt exit.
        defaults.synchronize()
        exit(0)
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            SettingsPrivacyView()
                .environment(\.profileManager, ProfileManager.shared)
                .environment(\.medicationManager, MedicationManager.shared)
                .environment(\.authenticationManager, AuthenticationManager.shared)
        }
    }
}
#endif
