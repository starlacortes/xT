//
//  WidgetSnapshotWriter.swift
//  xT
//
//  Publishes the Home chart to the Isocline widget extension (U20's revisit).
//
//  The app and the widget are separate processes with separate sandboxes, so the
//  curve is handed over as one small JSON snapshot written into a shared App
//  Group. Everything the widget draws is resolved *here*, on the app side: the
//  readout arrives already formatted, and the theme palette arrives resolved to
//  concrete RGB values for both appearances — the extension imports none of the
//  app's code. After a write, `WidgetCenter` reloads the widget's timeline so a
//  freshly logged dose shows up on the Home Screen without the app running.
//
//  `WidgetChartSnapshot` is duplicated in `IsoclineChart/IsoclineChart.swift`
//  (the widget target's copy) — the two definitions must stay in sync.
//

import Foundation
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Snapshot

/// The chart, readout and palette the widget renders — one Codable value.
///
/// Strings arrive fully formatted (numbers, units, provenance words) so the
/// widget does no domain logic; it only lays out and draws. Dates encode with
/// the JSON coder's default reference-date strategy, which both sides use.
struct WidgetChartSnapshot: Codable {
    /// A modeled curve point. `t` is the sample date, `v` the level.
    struct Point: Codable { let t: Date; let v: Double }
    /// A measured lab draw plotted as a ring (`v` is the raw measurement).
    struct LabPoint: Codable { let t: Date; let v: Double }
    /// The user-set reference band, low to high.
    struct RangeBand: Codable { let low: Double; let high: Double }

    /// One theme color resolved for both appearances: RGB triples in 0–1 space.
    struct DualColor: Codable { let light: [Double]; let dark: [Double] }

    /// The palette fields the widget reads, resolved from the live theme.
    struct Palette: Codable {
        let appBackground: DualColor
        let textPrimary: DualColor
        let textSecondary: DualColor
        let textTertiary: DualColor
        let accent: DualColor
        let levelLow: DualColor
        let levelHigh: DualColor
        let levelTint: DualColor
        let gridLine: DualColor
    }

    let generatedAt: Date
    let points: [Point]
    let labs: [LabPoint]
    let eyebrow: String?
    let levelText: String?
    let unitText: String?
    let provenanceText: String?
    let statusText: String?
    let rangeBand: RangeBand?
    let nextDoseDate: Date?
    let palette: Palette
}

// MARK: - Writer

/// Builds and publishes the chart snapshot for the widget extension.
@MainActor
enum WidgetSnapshotWriter {

    /// The App Group the app and the widget extension share. A new group —
    /// named for the current branding, not the bundle id — so a future rename
    /// of the app target never orphans the widget's data.
    static let appGroupID = "group.com.starlacortes.isocline"

    /// The snapshot's key inside the group's shared defaults.
    static let storageKey = "isocline.chart-snapshot"

    /// The widget's `kind`, matching the extension's registration.
    static let widgetKind = "IsoclineChart"

    /// Writes the current chart to the App Group and reloads the widget.
    ///
    /// Called from `MedicationManager.refreshState()` — the single funnel every
    /// data change flows through — and when the theme hue commits, so the
    /// widget's palette tracks the app's. Silently does nothing when the App
    /// Group is unavailable (e.g. hosted unit tests, or the entitlement removed).
    ///
    /// Takes the manager as a parameter rather than reading
    /// `MedicationManager.shared`: `refreshState()` also runs from the
    /// manager's own `init`, inside the singleton's `dispatch_once`, where
    /// touching `.shared` again deadlocks the app at launch.
    static func publish(from manager: MedicationManager) {
        let points = manager.recentLevels
        let level = manager.currentHormoneLevel

        // Lab rings: the measured draws inside the curve's own window.
        let labs: [WidgetChartSnapshot.LabPoint] = {
            guard let first = points.first?.date, let last = points.last?.date, last > first else { return [] }
            return manager.labPoints(in: first...last)
                .map { WidgetChartSnapshot.LabPoint(t: $0.date, v: $0.measured) }
        }()

        // The readout's status line — cycle position, then the user-range
        // relation if one is set (the same join HomeReadout performs, §7).
        let statusText: String? = level.flatMap { level in
            let phase = level.phase.phaseDescription
            let relation = level.statusPillText
            switch (phase, relation) {
            case let (p?, r?): return "\(p) · \(r)"
            case let (p?, nil): return p
            case let (nil, r?): return r
            case (nil, nil):    return nil
            }
        }

        let snapshot = WidgetChartSnapshot(
            generatedAt: .now,
            points: points.map { WidgetChartSnapshot.Point(t: $0.date, v: $0.value) },
            labs: labs,
            eyebrow: MedicationDisplayFormatter.readoutEyebrow(manager),
            levelText: level.map { AppNumberFormatters.hormoneLevel.string($0.value) },
            unitText: level.map { $0.unit.symbol },
            provenanceText: MedicationDisplayFormatter.provenanceLine(manager.levelProvenance),
            statusText: statusText,
            rangeBand: manager.rangeBand.map { WidgetChartSnapshot.RangeBand(low: $0.low, high: $0.high) },
            nextDoseDate: manager.nextDoseDate,
            palette: resolvedPalette(from: manager)
        )

        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    // MARK: - Palette

    /// The live palette, resolved to plain RGB values for both appearances.
    ///
    /// The theme colors are adaptive and seed-hue derived; resolving them here
    /// means the widget never ports the color math — it just picks light or dark.
    private static func resolvedPalette(from manager: MedicationManager) -> WidgetChartSnapshot.Palette {
        let palette = ThemeManager.shared.palette
        return WidgetChartSnapshot.Palette(
            appBackground: dual(palette.appBackground),
            textPrimary: dual(palette.textPrimary),
            textSecondary: dual(palette.textSecondary),
            textTertiary: dual(palette.textTertiary),
            accent: dual(palette.accent),
            levelLow: dual(palette.levelLow),
            levelHigh: dual(palette.levelHigh),
            levelTint: dual(levelTint(from: manager)),
            gridLine: dual(palette.graph.gridLine)
        )
    }

    /// The curve's tint at the current level: the rose→lavender lerp against
    /// the medication's therapeutic ceiling, exactly as FlatGraphView derives it.
    /// The manager arrives as a parameter for the same init-reentrancy reason
    /// as `publish(from:)`.
    private static func levelTint(from manager: MedicationManager) -> Color {
        guard let level = manager.currentHormoneLevel?.value,
              let medication = manager.selectedMedication else {
            return ThemeManager.shared.palette.accent
        }
        let ceiling: Double = medication == "Testosterone" ? 1200 : 600
        let t = min(max(level / ceiling, 0), 1)
        return Color.lerp(ThemeManager.shared.palette.levelLow,
                          ThemeManager.shared.palette.levelHigh, t)
    }

    private static func dual(_ color: Color) -> WidgetChartSnapshot.DualColor {
        WidgetChartSnapshot.DualColor(light: rgb(color, dark: false),
                                     dark: rgb(color, dark: true))
    }

    /// Resolves an adaptive color to plain RGB components for one appearance.
    private static func rgb(_ color: Color, dark: Bool) -> [Double] {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
}
