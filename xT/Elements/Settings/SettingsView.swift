//
//  SettingsView.swift
//  xT
//
//  The Settings root on Isocline paper (ST1–ST3, ST5, ST10). An ink serif
//  title, a flush profile header (ST2), four gateway cards with live mono
//  subtitles (ST5) and a flush mono footer (ST10). The old 2×2 quick-card
//  grid and the five inline sections are gone — every row now lives in one
//  of the four gateway sub-screens.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.profileManager) var profileManager
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.notificationManager) var notificationManager
    @Environment(\.authenticationManager) var authManager
    @Environment(\.themeManager) var themeManager
    @Environment(\.appIconManager) var appIconManager

    @State var showingProfileEditor = false

    private let hPad: CGFloat = Theme.Spacing.Gutter.screen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(Theme.Fonts.hero)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, hPad)
                        .padding(.top, 48)
                        .padding(.bottom, Theme.Spacing.sm)

                    profileHeader
                        .padding(.horizontal, hPad)
                        .padding(.bottom, Theme.Spacing.xl)

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SettingsGatewayCard(icon: "pills.fill",
                                            title: "Medication & Dose",
                                            subtitle: medicationGatewaySubtitle) {
                            SettingsMedicationView()
                        }
                        SettingsGatewayCard(icon: "flask",
                                            title: "Labs & Records",
                                            subtitle: labsGatewaySubtitle) {
                            SettingsLabsView()
                        }
                        SettingsGatewayCard(icon: "paintbrush.fill",
                                            title: "Appearance",
                                            subtitle: appearanceGatewaySubtitle) {
                            SettingsAppearanceView()
                        }
                        SettingsGatewayCard(icon: "lock.fill",
                                            title: "Privacy & Data",
                                            subtitle: privacyGatewaySubtitle) {
                            SettingsPrivacyView()
                        }
                    }
                    .padding(.horizontal, hPad)

                    footer
                        .padding(.horizontal, hPad)
                        .padding(.top, Theme.Spacing.section)

                    Spacer(minLength: 48)
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .background(Theme.Colors.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView()
            }
        }
    }

    // MARK: - Profile header (ST2)

    private var profileHeader: some View {
        HStack(spacing: Theme.Spacing.lg) {
            AvatarView(image: profileManager.profilePhoto, size: AvatarView.Size.header)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: displayName)
                    .font(Theme.Fonts.serifTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(verbatim: tenureLine)
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monoLabel()
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                showingProfileEditor = true
            } label: {
                Text("Edit")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var displayName: String {
        profileManager.profileDisplayName.isEmpty
            ? profileManager.profileName
            : profileManager.profileDisplayName
    }

    /// `DAY 412 · 13 MONTHS` — built from `tenureLabel` plus the day count.
    /// `nil` tenure renders the day count alone; no HRT start yet renders nothing.
    private var tenureLine: String {
        guard let start = medicationManager.hrtStartDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        let dayPart = String(localized: "Day \(days)",
                             comment: "Days on HRT, Settings profile mono line")
        if let tenure = medicationManager.tenureLabel {
            let label = String(localized: tenure)
            return "\(dayPart) · \(label)"
        }
        return dayPart
    }

    // MARK: - Gateway subtitles (ST5)

    private var medicationGatewaySubtitle: LocalizedStringResource? {
        guard medicationManager.isFullyConfigured else {
            return LocalizedStringResource(
                "Not configured",
                comment: "Medication gateway subtitle when nothing is set up"
            )
        }
        guard let name = MedicationDisplayFormatter.medicationName(medicationManager) else {
            return nil
        }
        let interval = medicationManager.effectiveDueIntervalDays
        let defaults = medicationManager.resolvedDoseDefaults(
            medication: medicationManager.selectedMedication,
            method: medicationManager.selectedAdministrationMethod
        )
        let amount = AppNumberFormatters.dose.string(defaults.amountMg)
        return LocalizedStringResource(
            "\(name) · \(amount) mg Q\(interval)D",
            comment: "Medication gateway subtitle: regimen name, dose amount, interval in days"
        )
    }

    private var labsGatewaySubtitle: LocalizedStringResource? {
        // ST5: count labs for the selected hormone, plus the last draw age.
        let selected = medicationManager.selectedMedication ?? "Estrogen"
        let tests = medicationManager.bloodTestHistory.filter { $0.hormoneType == selected }
        guard !tests.isEmpty else {
            let anyLabs = !medicationManager.bloodTestHistory.isEmpty
            return LocalizedStringResource(
                anyLabs ? "No labs for your medication yet" : "No labs yet",
                comment: "Labs gateway subtitle before a lab for the current medication exists"
            )
        }
        let count = tests.count
        guard let last = tests.map(\.drawDate).max() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        let age = String(localized: "^[\(days) day](inflect: true) ago",
                         comment: "Age of the most recent lab draw")
        return LocalizedStringResource(
            "\(count) labs · last \(age)",
            comment: "Labs gateway subtitle: count plus the age of the newest lab"
        )
    }

    private var appearanceGatewaySubtitle: LocalizedStringResource? {
        // ST5: the hue plus the active icon — "Hue 2° · Default icon".
        LocalizedStringResource(
            "Hue \(Int(themeManager.seedHue.rounded()))° · \(appearanceIconName)",
            comment: "Appearance gateway subtitle: the chosen hue in degrees, plus the active app icon"
        )
    }

    /// The active icon as the subtitle names it: word labels for the primary
    /// and Discreet, the rounded hue for the rest.
    private var appearanceIconName: String {
        switch appIconManager.current {
        case .primary:
            String(localized: "Default icon",
                   comment: "The primary app icon, as the Appearance subtitle names it")
        case .discreet:
            String(localized: "Discreet icon",
                   comment: "The Discreet app icon, as the Appearance subtitle names it")
        default:
            String(
                localized: "\(appIconManager.current.hueLabel ?? "") icon",
                comment: "A hue-matched app icon, as the Appearance subtitle names it"
            )
        }
    }

    private var privacyGatewaySubtitle: LocalizedStringResource? {
        let lock: String
        if authManager.requireAuthentication {
            lock = authManager.biometricType().description
        } else {
            lock = String(localized: "Lock off",
                          comment: "Privacy gateway subtitle when the app lock is disabled")
        }
        let cloud: String
        if UserDefaults.standard.bool(forKey: "icloudSyncEnabled") {
            cloud = String(localized: "iCloud on",
                            comment: "Privacy gateway subtitle when iCloud sync is enabled")
        } else {
            cloud = String(localized: "iCloud off",
                           comment: "Privacy gateway subtitle when iCloud sync is disabled")
        }
        return LocalizedStringResource(
            "\(lock) · \(cloud)",
            comment: "Privacy gateway subtitle: lock state plus iCloud sync state"
        )
    }

    // MARK: - Footer (ST10)

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(verbatim: AppVersion.footerLine)
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textTertiary)
                .monoLabel()

            HStack(spacing: Theme.Spacing.xs) {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Text("Acknowledgements")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monoLabel()
                }
                .buttonStyle(.plain)

#if DEBUG
                // The Developer tools row, restored from the pre-Isocline
                // About section — the Tier 4d gateway rebuild dropped its only
                // navigation link, leaving DeveloperSettingsView unreachable
                // from the running app. DEBUG builds only; release keeps the
                // footer factual (ST10).
                NavigationLink {
                    DeveloperSettingsView()
                } label: {
                    Text("Developer")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monoLabel()
                }
                .buttonStyle(.plain)
#endif

                Text(verbatim: "SHAPED PROTOCOL.")
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .monoLabel()
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    SpoofPreview {
        SettingsView()
            .environment(\.profileManager, ProfileManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.notificationManager, NotificationManager.shared)
    }
}
#endif
