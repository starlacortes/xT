//
//  DeveloperSettingsView.swift
//  xT
//
//  Developer tools page — accessed via Settings → Privacy & Data → Developer
//  (DEBUG only). Tier 4d (ST6): the private clones of the row kit are gone;
//  this screen now uses the shared `SettingsGroup` / `SettingsRow` /
//  `SettingsToggle` vocabulary like every other sub-screen.
//
//  Multi-persona support (2026-08-04): replaces the single Jan toggle with a
//  persona picker. Select a persona, enable the Sample Profile toggle, and
//  the app quits + relaunches with that persona's data active.
//

#if DEBUG
import SwiftUI

struct DeveloperSettingsView: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingDeveloperModeAlert = false
    @State private var showingSampleProfileAlert = false
    @State private var showingSampleProfileDisableAlert = false

    var body: some View {
        let dev = DeveloperSettings.shared

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(text: "Developer tools", emphasis: .accent)
                SettingsGroup {
                    HStack(spacing: Theme.Spacing.card) {
                        SettingsIconTile(icon: "wrench.and.screwdriver")
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Developer mode")
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(verbatim: dev.developerModeEnabled ? "On" : "Off")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        SettingsToggle(isOn: Binding(
                            get: { dev.developerModeEnabled },
                            set: { newValue in
                                if newValue { showingDeveloperModeAlert = true }
                                else { onDeveloperModeDisabled() }
                            }
                        ))
                    }
                    .padding(.horizontal, Theme.Spacing.card)
                    .padding(.vertical, Theme.Spacing.md)
                    .contentShape(Rectangle())

                    SettingsGroupDivider()

                    personaPickerRow(dev: dev)
                        .disabled(!dev.developerModeEnabled)
                        .opacity(dev.developerModeEnabled ? 1 : 0.4)

                    SettingsGroupDivider()

                    HStack(spacing: Theme.Spacing.card) {
                        SettingsIconTile(icon: "person.crop.circle.badge")
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Sample profile")
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(verbatim: dev.sampleProfileEnabled
                                 ? "\(dev.activePersonaName) active"
                                 : "Load \(dev.activePersonaName)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        SettingsToggle(isOn: Binding(
                            get: { dev.sampleProfileEnabled },
                            set: { newValue in
                                if newValue { showingSampleProfileAlert = true }
                                else { showingSampleProfileDisableAlert = true }
                            }
                        ))
                    }
                    .padding(.horizontal, Theme.Spacing.card)
                    .padding(.vertical, Theme.Spacing.md)
                    .contentShape(Rectangle())
                    .disabled(!dev.developerModeEnabled)
                    .opacity(dev.developerModeEnabled ? 1 : 0.4)

                    if dev.sampleProfileEnabled {
                        SettingsGroupDivider()

                        HStack(spacing: Theme.Spacing.tiny) {
                            Image(systemName: "info.circle.fill")
                                .font(Theme.Fonts.footnote)
                                .foregroundStyle(Theme.Colors.accent)
                            Text(verbatim: "Active persona: \(dev.activePersonaName)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.card)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enable developer mode?", isPresented: $showingDeveloperModeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") { DeveloperSettings.shared.developerModeEnabled = true }
        } message: {
            Text("Developer mode unlocks test-only tools. Leave this off for normal use.")
        }
        .alert("Switch to sample profile?", isPresented: $showingSampleProfileAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Quit & Switch") { onSampleProfileEnabled() }
        } message: {
            Text("Your data is preserved and will be restored when you turn this off. The app will quit.\n\nActive persona: \(dev.activePersonaName)")
        }
        .alert("Restore your profile?", isPresented: $showingSampleProfileDisableAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Quit & Restore") { onSampleProfileDisabled() }
        } message: {
            Text("The sample data will be removed and your original data restored. The app will quit.")
        }
    }

    // MARK: - Persona Picker

    private func personaPickerRow(dev: DeveloperSettings) -> some View {
        HStack(spacing: Theme.Spacing.card) {
            SettingsIconTile(icon: "person.3.fill")
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Persona")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(verbatim: dev.activePersonaName)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { dev.activePersonaIndex },
                set: { dev.activePersonaIndex = $0 }
            )) {
                ForEach(0..<DeveloperSettings.personaNames.count, id: \.self) { i in
                    Text(verbatim: DeveloperSettings.personaNames[i]).tag(i)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.card)
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func onDeveloperModeDisabled() {
        if DeveloperSettings.shared.sampleProfileEnabled {
            onSampleProfileDisabled()
        }
        DeveloperSettings.shared.developerModeEnabled = false
    }

    private func onSampleProfileEnabled() {
        guard ProfileSnapshot.snapshotIfNeeded() else {
            print("[DeveloperSettingsView] snapshot failed — aborting sample profile switch")
            return
        }
        DeveloperSettings.shared.sampleProfileEnabled = true
        SpoofProfile.forceApply()
        try? JournalManager.shared.modelContext?.save()
        MedicationManager.shared.saveContext()
        UserDefaults.standard.synchronize()
        exit(0)
    }

    private func onSampleProfileDisabled() {
        ProfileSnapshot.restore()
        DeveloperSettings.shared.sampleProfileEnabled = false
        UserDefaults.standard.synchronize()
        exit(0)
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
