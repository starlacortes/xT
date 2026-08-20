//
//  DeveloperSettingsView.swift
//  xT
//
//  Developer tools page — accessed via Settings → About → Developer.
//  Only compiled and reachable in DEBUG builds.
//
//  Multi-persona support (2026-08-04): replaces the single Jan toggle with a
//  persona picker. Select a persona, enable the Sample Profile toggle, and
//  the app quits + relaunches with that persona's data active.
//

#if DEBUG
import SwiftUI

struct DeveloperSettingsView: View {
    @State private var showingDeveloperModeAlert = false
    @State private var showingSampleProfileAlert = false
    @State private var showingSampleProfileDisableAlert = false

    var body: some View {
        let dev = DeveloperSettings.shared

        ScrollView {
            VStack(spacing: 32) {
                devSection(label: "Developer Tools") {
                    devToggleRow(
                        icon: "wrench.and.screwdriver",
                        bg: Color(.systemGray6),
                        color: .secondary,
                        title: "Developer mode",
                        subtitle: dev.developerModeEnabled ? "On" : "Off",
                        isOn: Binding(
                            get: { dev.developerModeEnabled },
                            set: { newValue in
                                if newValue { showingDeveloperModeAlert = true }
                                else { onDeveloperModeDisabled() }
                            }
                        )
                    )

                    devDivider()

                    // Persona picker — only active when developer mode is on
                    personaPickerRow(dev: dev)
                        .disabled(!dev.developerModeEnabled)
                        .opacity(dev.developerModeEnabled ? 1 : 0.4)

                    devDivider()

                    devToggleRow(
                        icon: "person.crop.circle.badge",
                        bg: Theme.Colors.Time.cycle.surface,
                        color: Theme.Colors.Time.cycle.base,
                        title: "Sample profile",
                        subtitle: dev.sampleProfileEnabled
                            ? "\(dev.activePersonaName) active"
                            : "Load \(dev.activePersonaName)",
                        isOn: Binding(
                            get: { dev.sampleProfileEnabled },
                            set: { newValue in
                                if newValue { showingSampleProfileAlert = true }
                                else { showingSampleProfileDisableAlert = true }
                            }
                        )
                    )
                    .disabled(!dev.developerModeEnabled)
                    .opacity(dev.developerModeEnabled ? 1 : 0.4)

                    if dev.sampleProfileEnabled {
                        devDivider()

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.accent)
                            Text("Active persona: \(dev.activePersonaName)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Colors.appBackground)
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
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Persona")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                Text(dev.activePersonaName)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { dev.activePersonaIndex },
                set: { dev.activePersonaIndex = $0 }
            )) {
                ForEach(0..<DeveloperSettings.personaNames.count, id: \.self) { i in
                    Text(DeveloperSettings.personaNames[i]).tag(i)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
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

    // MARK: - Layout Helpers

    private func devSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func devToggleRow(
        icon: String,
        bg: Color,
        color: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            devIconView(icon: icon, bg: bg, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func devIconView(icon: String, bg: Color, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bg)
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
        }
    }

    private func devDivider() -> some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 22 + 32 + 14)
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
#endif
