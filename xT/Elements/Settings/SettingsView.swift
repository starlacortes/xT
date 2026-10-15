//
//  SettingsView.swift
//  xT
//
//  The Settings root on Isocline paper (ST1–ST3, ST5, ST10). The screen
//  sketch's composition: an ISOCLINE brand eyebrow over an ink serif title,
//  the profile centered flush on the paper (avatar, serif name, mono tenure,
//  a quiet EDIT caption — the block itself stays non-interactive, X26), four
//  gateway cards with live mono subtitles (ST5), the Isocline Plus card, and
//  a flush mono footer (ST10).
//  The old 2×2 quick-card grid and the five inline sections are gone — every
//  row now lives in one of the four gateway sub-screens.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.profileManager) var profileManager
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.notificationManager) var notificationManager
    @Environment(\.authenticationManager) var authManager
    @Environment(\.themeManager) var themeManager
    @Environment(\.appIconManager) var appIconManager
    @Environment(\.entitlementManager) var entitlementManager

    @State var showingProfileEditor = false
    /// Tracked separately from the raw default so the Privacy gateway's "iCloud
    /// on/off" half stays live — `UserDefaults` reads aren't an Observation
    /// dependency, so this screen would otherwise show a stale subtitle after
    /// the user flips the toggle on `SettingsPrivacyView` and comes back.
    @AppStorage("icloudSyncEnabled") private var icloudSyncEnabled = false

    private let hPad: CGFloat = Theme.Spacing.Gutter.screen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Isocline")
                            .eyebrow()
                        Text("Settings")
                            .font(Theme.Fonts.hero)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, 48)
                    .padding(.bottom, Theme.Spacing.xl)

                    profileHeader
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Theme.Spacing.xxl)

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SettingsGatewayCard(icon: "plus",
                                            title: "Medication & Dose",
                                            subtitle: medicationGatewaySubtitle) {
                            SettingsMedicationView()
                        }
                        SettingsGatewayCard(icon: "diamond",
                                            title: "Labs & Records",
                                            subtitle: labsGatewaySubtitle) {
                            SettingsLabsView()
                        }
                        SettingsGatewayCard(icon: "circle.righthalf.filled",
                                            title: "Appearance & Curve",
                                            subtitle: appearanceGatewaySubtitle) {
                            SettingsAppearanceView()
                        }
                        SettingsGatewayCard(icon: "square",
                                            title: "Privacy & Data",
                                            subtitle: privacyGatewaySubtitle) {
                            SettingsPrivacyView()
                        }
                        SettingsGatewayCard(icon: "seal",
                                            title: "Isocline Plus",
                                            subtitle: plusGatewaySubtitle) {
                            SettingsPlusView()
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

    /// The screen-sketch profile: centered flush on the paper — avatar, serif
    /// name, mono tenure, and a quiet EDIT caption beneath (the block itself
    /// stays non-interactive; X26 stands).
    private var profileHeader: some View {
        VStack(spacing: 0) {
            AvatarView(image: profileManager.profilePhoto, size: AvatarView.Size.settingsHero)
                .padding(.bottom, Theme.Spacing.card)

            Text(verbatim: displayName)
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.bottom, Theme.Spacing.xxs)

            if !tenureLine.isEmpty {
                Text(verbatim: tenureLine)
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monoLabel()
                    .textCase(.uppercase)
                    .padding(.bottom, Theme.Spacing.xs)
            }

            Button {
                showingProfileEditor = true
            } label: {
                Text("Edit")
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.accent)
                    .monoLabel()
                    .textCase(.uppercase)
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
    ///
    /// The tenure resource carries a `^[…](inflect: true)` grammar directive,
    /// which only resolves through `AttributedString` — `String(localized:)`
    /// leaves the raw directive in the text.
    private var tenureLine: String {
        guard let start = medicationManager.hrtStartDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        let dayPart = String(localized: "Day \(days)",
                             comment: "Days on HRT, Settings profile mono line")
        guard let tenure = medicationManager.tenureLabel else { return dayPart }
        return "\(dayPart) · \(Self.resolvedInflection(AttributedString(localized: tenure)))"
    }

    /// Resolves an `^[…](inflect: true)` grammar directive — only `AttributedString`
    /// parses it; `String(localized:)` leaves the raw directive in the text.
    private static func resolvedInflection(_ attributed: AttributedString) -> String {
        String(attributed.characters)
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
        let age = Self.resolvedInflection(AttributedString(
            localized: "^[\(days) day](inflect: true) ago",
            comment: "Age of the most recent lab draw"
        ))
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
        if icloudSyncEnabled {
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

    private var plusGatewaySubtitle: LocalizedStringResource? {
        switch entitlementManager.access {
        case .active:
            guard let date = entitlementManager.expirationDate else {
                return LocalizedStringResource("Active", comment: "Plus gateway subtitle for a subscriber")
            }
            return LocalizedStringResource(
                "Renews \(date.formatted(date: .abbreviated, time: .omitted))",
                comment: "Plus gateway subtitle: the subscription's renewal date"
            )
        case .lapsed:
            return LocalizedStringResource("Ended", comment: "Plus gateway subtitle after a subscription lapses")
        case .free:
            return LocalizedStringResource("Not subscribed", comment: "Plus gateway subtitle before subscribing")
        }
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
