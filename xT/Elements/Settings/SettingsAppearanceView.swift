//
//  SettingsAppearanceView.swift
//  xT
//
//  Settings → Appearance (ST1/ST8). Renamed from `ThemeSettingsView` so the
//  row title and the screen title finally match. The hue specimen (S11) and
//  the band/stops live in the shared `ThemePickerView`; this screen owns the
//  readout row and the reset. Resetting a hue isn't destructive, so the reset
//  is plain accent text, not error red.
//

import SwiftUI

struct SettingsAppearanceView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                ThemePickerView()

                readoutRow

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
