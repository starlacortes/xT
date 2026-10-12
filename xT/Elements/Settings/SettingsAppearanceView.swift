//
//  SettingsAppearanceView.swift
//  xT
//
//  Settings → Appearance (ST1/ST8). Renamed from `ThemeSettingsView` so the
//  row title and the screen title finally match. The hue specimen (S11) and
//  the band/stops live in the shared `ThemePickerView`; this screen owns the
//  readout row, the app-icon picker (I4) and the reset. Resetting a hue
//  isn't destructive, so the reset is plain accent text, not error red.
//

import SwiftUI

struct SettingsAppearanceView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.appIconManager) private var appIconManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                ThemePickerView()

                readoutRow

                if AppIconManager.isAvailable {
                    iconSection
                }

                Button {
                    themeManager.resetToDefault()
                } label: {
                    Text("Reset to default")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - App icon (I4)

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(text: "App icon", emphasis: .accent)
            iconGrid
            if showsMatchRow {
                matchRow
            }
        }
    }

    /// The nine shipped icons — the primary, one per remaining quick stop,
    /// then Discreet. The preview images are the shipped artwork; iOS offers
    /// no way to read a compiled app icon back from the catalog.
    private var iconGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Theme.Spacing.md),
                count: 4
            ),
            spacing: Theme.Spacing.lg
        ) {
            ForEach(AppIconChoice.allCases) { choice in
                Button {
                    appIconManager.apply(choice)
                } label: {
                    iconTile(choice)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(accessibilityLabel(for: choice))
                .accessibilityAddTraits(appIconManager.current == choice ? .isSelected : [])
            }
        }
    }

    private func iconTile(_ choice: AppIconChoice) -> some View {
        let isSelected = appIconManager.current == choice
        return VStack(spacing: Theme.Spacing.xs) {
            Image(choice.previewAssetName)
                .resizable()
                .frame(width: Self.tileSize, height: Self.tileSize)
                .overlay(
                    // The preview carries its own rounded corners (as the
                    // icon reads in-app); the ring follows the same ratio,
                    // 230.4 / 1024, so it hugs the artwork.
                    RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.Colors.accent : Theme.Colors.border,
                            lineWidth: isSelected ? 2 : Theme.Line.hairline
                        )
                )
            tileLabel(choice)
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private func tileLabel(_ choice: AppIconChoice) -> some View {
        // Degree labels are verbatim ("48°"); the word labels localize.
        if let hueLabel = choice.hueLabel {
            Text(verbatim: hueLabel)
        } else if choice == .primary {
            Text("Default")
        } else {
            Text("Discreet")
        }
    }

    /// The quiet nudge (I4): the app never switches the icon silently — iOS
    /// alerts on every change anyway — so a hue icon that no longer matches
    /// the dial gets this row instead. Discreet is deliberate; it never
    /// gets the row.
    private var showsMatchRow: Bool {
        appIconManager.current != .discreet
            && appIconManager.current != AppIconChoice.nearest(toHue: themeManager.seedHue)
    }

    private var matchRow: some View {
        Button {
            appIconManager.apply(AppIconChoice.nearest(toHue: themeManager.seedHue))
        } label: {
            Text("Update icon to match your hue")
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.accent)
        }
        .buttonStyle(.plain)
    }

    private func accessibilityLabel(for choice: AppIconChoice) -> LocalizedStringResource {
        switch choice {
        case .primary:
            "Default icon"
        case .discreet:
            "Discreet icon"
        default:
            "\(Int((choice.stopHue ?? 0).rounded())) degrees icon"
        }
    }

    /// Icon tiles preview at 64 pt — small enough for a four-column grid on
    /// the narrowest device, large enough to read the mark.
    private static let tileSize: CGFloat = 64
    /// 64 × (230.4 / 1024) — the preview's own corner ratio.
    private static let tileRadius: CGFloat = 14.4

    // MARK: - Readout row (ST8)

    /// Mono `HUE 2.5° · ACCENT #D4537E` plus the stop name as plain accent text.
    private var readoutRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(verbatim: "HUE \(String(format: "%.1f", themeManager.seedHue))° · ACCENT \(hexAccent)")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()
            Text(nearestStopName)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hexAccent: String {
        // The live accent from the palette, as hex. `Color` → components →
        // hex; the palette holds UIColor-bridgeable values.
        let ui = UIColor(Theme.Colors.accent)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    /// The nearest quick stop, named by its hue; "Custom rose" between stops.
    private var nearestStopName: String {
        let hue = themeManager.seedHue
        let nearest = Theme.Seed.stops.min { a, b in
            circularDistance(hue, a) < circularDistance(hue, b)
        } ?? Theme.Seed.stops[0]
        let degrees = circularDistance(hue, nearest)
        if degrees <= 2.5 {
            return String(localized: "Default rose",
                          comment: "Name of the default brand hue in the Appearance readout")
        }
        if degrees > 22.5 {
            return String(localized: "Custom hue",
                          comment: "Name shown when the chosen hue sits between quick stops")
        }
        return String(localized: "Near \(Int(nearest.rounded()))°",
                      comment: "The quick-stop hue closest to the current selection")
    }

    private func circularDistance(_ a: Double, _ b: Double) -> Double {
        let delta = abs(a - b)
        return min(delta, 360 - delta)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsAppearanceView()
            .environment(\.themeManager, ThemeManager.shared)
    }
}
#endif
