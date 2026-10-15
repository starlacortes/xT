//
//  IsoclineChart.swift
//  IsoclineChart
//
//  The Isocline Home chart, on the Home Screen: the hormone curve, the level
//  readout and the next dose, drawn on paper with the same rose→lavender
//  sweep as the app's Home instrument (H1–H7).
//
//  Data arrives as a `WidgetChartSnapshot` the app writes into the shared
//  App Group (see `xT/Shared/WidgetSnapshotWriter.swift` on the app side).
//  Every string arrives already formatted and every color already resolved
//  to RGB for both appearances, so this target imports none of the app's
//  domain or theme code — it only lays out and draws.
//
//  Type sizes use the system faces (the bundled Plex faces are app-target
//  resources); the mono readout and small-caps labels echo their roles.
//

import WidgetKit
import SwiftUI

// MARK: - Snapshot (mirror of xT/Shared/WidgetSnapshotWriter.swift — keep in sync)

/// The chart, readout and palette the widget renders — one Codable value.
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

// MARK: - Snapshot store

/// Reads the snapshot the app publishes into the shared App Group.
private enum SnapshotStore {
    static let appGroupID = "group.com.starlacortes.isocline"
    static let storageKey = "isocline.chart-snapshot"

    static func read() -> WidgetChartSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetChartSnapshot.self, from: data)
    }

    /// Synthetic data for the placeholder and the gallery preview. Never drawn
    /// from a real person's regimen (the same rule as the app's own previews).
    static var sample: WidgetChartSnapshot {
        let now = Date()
        let calendar = Calendar.current
        // One q7d cycle, sampled a quarter-day apart — a Bateman rise into a
        // slow tail, so the curve reads at a glance.
        let points: [WidgetChartSnapshot.Point] = (0...40).map { i in
            let day = Double(i) * 0.25
            let rise = 1 - exp(-day / 0.55)
            let tail = exp(-day / 4.2)
            let value = 60 + 320 * rise * tail
            let date = now.addingTimeInterval((day - 6) * 86_400)
            return WidgetChartSnapshot.Point(t: date, v: value)
        }
        return WidgetChartSnapshot(
            generatedAt: now,
            points: points,
            labs: [
                WidgetChartSnapshot.LabPoint(t: calendar.date(byAdding: .day, value: -5, to: now)!, v: 342),
                WidgetChartSnapshot.LabPoint(t: calendar.date(byAdding: .day, value: 2, to: now)!, v: 288)
            ],
            eyebrow: "ESTRADIOL · DAY 3",
            levelText: "268",
            unitText: "pg/mL",
            provenanceText: "Calibrated",
            statusText: "mid-cycle",
            rangeBand: WidgetChartSnapshot.RangeBand(low: 100, high: 600),
            nextDoseDate: calendar.date(byAdding: .day, value: 4, to: now),
            palette: canonicalPalette
        )
    }

    /// The canonical Isocline palette (docs/design/tokens), for the moments no
    /// snapshot exists yet: paper, ink, and the rose→lavender brand ramp.
    private static var canonicalPalette: WidgetChartSnapshot.Palette {
        func dual(_ lightHex: String, _ darkHex: String) -> WidgetChartSnapshot.DualColor {
            WidgetChartSnapshot.DualColor(light: rgb(lightHex), dark: rgb(darkHex))
        }
        return WidgetChartSnapshot.Palette(
            appBackground: dual("#F8F3E8", "#1C0C10"),
            textPrimary:   dual("#050303", "#F1E8EA"),
            textSecondary: dual("#050303", "#F1E8EA"),
            textTertiary:  dual("#050303", "#F1E8EA"),
            accent:        dual("#D4537E", "#E8709A"),
            levelLow:      dual("#99345A", "#C2557E"),
            levelHigh:     dual("#8875D4", "#B0A4EA"),
            levelTint:     dual("#C2557E", "#DC94B2"),
            gridLine:      dual("#050303", "#F1E8EA")
        )
    }

    /// "#RRGGBB" → RGB triple in 0–1 space.
    private static func rgb(_ hex: String) -> [Double] {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        return [Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255]
    }
}

// MARK: - Palette

/// The snapshot's theme colors, picked for the current appearance.
private struct ChartPalette {
    let appBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let levelLow: Color
    let levelHigh: Color
    let levelTint: Color
    let gridLine: Color

    init(_ snapshot: WidgetChartSnapshot, scheme: ColorScheme) {
        func pick(_ dual: WidgetChartSnapshot.DualColor) -> Color {
            let rgb = scheme == .dark ? dual.dark : dual.light
            guard rgb.count == 3 else { return .gray }
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        let palette = snapshot.palette
        self.appBackground = pick(palette.appBackground)
        self.textPrimary = pick(palette.textPrimary)
        self.textSecondary = pick(palette.textSecondary)
        self.textTertiary = pick(palette.textTertiary)
        self.accent = pick(palette.accent)
        self.levelLow = pick(palette.levelLow)
        self.levelHigh = pick(palette.levelHigh)
        self.levelTint = pick(palette.levelTint)
        self.gridLine = pick(palette.gridLine)
    }
}

// MARK: - Curve geometry

/// The curve math the app's `CurveLayout` performs, reduced to what the
/// widget draws: the same inflated bounds, the same band mapping, and the
/// same horizontal-midpoint cubic smoothing.
private enum CurveGeometry {

    /// The inflated value range (85% of min, 110% of max) all graphs use.
    static func valueBounds(_ values: [Double]) -> (min: Double, range: Double) {
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let minV = rawMin * 0.85
        let maxV = rawMax * 1.1
        return (minV, maxV - minV)
    }

    /// Value → y within the band [plotTop, plotBottom].
    static func y(value: Double, min: Double, range: Double,
                  plotTop: CGFloat, plotBottom: CGFloat) -> CGFloat {
        let band = max(plotBottom - plotTop, 1)
        guard range > 0 else { return plotTop + band / 2 }
        return plotBottom - CGFloat((value - min) / range) * band
    }

    /// Index → x. The curve is index-proportional (the app samples the window
    /// at a uniform step), so this matches the app's mapping exactly.
    static func x(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    /// Date → fraction of the window's time span (for lab rings and the now
    /// point, which the app also positions by time).
    static func timeFraction(_ date: Date, in points: [WidgetChartSnapshot.Point]) -> CGFloat? {
        guard let first = points.first?.t, let last = points.last?.t, last > first else { return nil }
        return CGFloat(date.timeIntervalSince(first) / last.timeIntervalSince(first))
    }

    /// The smoothed stroke path (cubic, horizontal midpoints — CurveLayout's join).
    static func curvePath(points: [WidgetChartSnapshot.Point],
                          min: Double, range: Double,
                          width: CGFloat, plotTop: CGFloat, plotBottom: CGFloat) -> Path {
        Path { path in
            guard !points.isEmpty else { return }
            func y(_ i: Int) -> CGFloat {
                CurveGeometry.y(value: points[i].v, min: min, range: range,
                                plotTop: plotTop, plotBottom: plotBottom)
            }
            for i in points.indices {
                let xi = x(index: i, count: points.count, width: width)
                if i == 0 {
                    path.move(to: CGPoint(x: xi, y: y(0)))
                } else {
                    let prevX = x(index: i - 1, count: points.count, width: width)
                    path.addCurve(
                        to: CGPoint(x: xi, y: y(i)),
                        control1: CGPoint(x: prevX + (xi - prevX) * 0.5, y: y(i - 1)),
                        control2: CGPoint(x: prevX + (xi - prevX) * 0.5, y: y(i))
                    )
                }
            }
        }
    }

    /// The fill path: the curve closed down to `fillBottom`.
    static func fillPath(points: [WidgetChartSnapshot.Point],
                         min: Double, range: Double,
                         width: CGFloat, plotTop: CGFloat, plotBottom: CGFloat,
                         fillBottom: CGFloat) -> Path {
        var base = curvePath(points: points, min: min, range: range,
                             width: width, plotTop: plotTop, plotBottom: plotBottom)
        base.addLine(to: CGPoint(x: width, y: fillBottom))
        base.addLine(to: CGPoint(x: 0, y: fillBottom))
        base.closeSubpath()
        return base
    }

    /// The "now" point: bracketed by time between two samples, interpolated
    /// along the segment (index-proportional x, like the app's dense mapping).
    static func nowDot(at date: Date, in points: [WidgetChartSnapshot.Point],
                       width: CGFloat, minV: Double, range: Double,
                       plotTop: CGFloat, plotBottom: CGFloat) -> CGPoint? {
        guard points.count > 1,
              let first = points.first?.t, let last = points.last?.t, last > first else { return nil }
        let target = Swift.min(Swift.max(date, first), last)

        // Find the bracketing pair by time.
        var i0 = 0
        for i in points.indices.dropLast() where points[i].t <= target {
            i0 = i
        }
        let i1 = Swift.min(i0 + 1, points.count - 1)
        let segment = points[i1].t.timeIntervalSince(points[i0].t)
        let fraction = segment > 0
            ? target.timeIntervalSince(points[i0].t) / segment
            : 0

        let x0 = x(index: i0, count: points.count, width: width)
        let x1 = x(index: i1, count: points.count, width: width)
        let value = points[i0].v + (points[i1].v - points[i0].v) * fraction
        return CGPoint(
            x: x0 + (x1 - x0) * CGFloat(fraction),
            y: CurveGeometry.y(value: value, min: minV, range: range, plotTop: plotTop, plotBottom: plotBottom)
        )
    }
}

// MARK: - Timeline

struct ChartEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetChartSnapshot?
}

struct ChartProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChartEntry {
        ChartEntry(date: .now, snapshot: SnapshotStore.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChartEntry) -> Void) {
        completion(ChartEntry(date: .now, snapshot: SnapshotStore.read() ?? SnapshotStore.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChartEntry>) -> Void) {
        let snapshot = SnapshotStore.read()
        var entries: [ChartEntry] = []

        // Hourly entries so the now point keeps drifting between app-driven
        // reloads; the snapshot itself only changes when the app re-publishes.
        let now = Date()
        for hourOffset in 0..<5 {
            let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now) ?? now
            entries.append(ChartEntry(date: date, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget views

struct IsoclineChartEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    var entry: ChartEntry

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.points.count > 1 {
            ChartView(entry: entry, snapshot: snapshot,
                      palette: ChartPalette(snapshot, scheme: colorScheme))
        } else {
            EmptyChartView(palette: ChartPalette(SnapshotStore.sample, scheme: colorScheme))
        }
    }
}

/// The instrument: readout on paper, curve below, next dose last (H2's order).
private struct ChartView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ChartEntry
    let snapshot: WidgetChartSnapshot
    let palette: ChartPalette

    private var metaLine: String? {
        switch (snapshot.provenanceText, snapshot.statusText) {
        case let (p?, s?): return "\(p) · \(s)"
        case let (p?, nil):  return p
        case let (nil, s?): return s
        case (nil, nil):     return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow = snapshot.eyebrow {
                Text(eyebrow)
                    .font(.caption2.weight(.medium))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }

            levelRow

            if let metaLine {
                Text(metaLine)
                    .font(.caption2.weight(.medium))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(palette.textSecondary.opacity(0.65))
                    .lineLimit(1)
            }

            CurveCanvas(snapshot: snapshot, palette: palette, date: entry.date)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if family != .systemSmall, let next = snapshot.nextDoseDate {
                nextDoseRow(next)
            }
        }
        .padding(16)
        .widgetFrame(palette: palette)
    }

    /// The number with its unit — mono, like the app's IBM Plex readout (H2).
    private var levelRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(snapshot.levelText ?? "—")
                .font(.system(size: family == .systemSmall ? 30 : 34,
                              weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let unit = snapshot.unitText {
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.textSecondary.opacity(0.8))
            }
        }
    }

    /// "NEXT DOSE · in 3 days" — the offset updates live in the widget.
    private func nextDoseRow(_ next: Date) -> some View {
        HStack(spacing: 4) {
            Text("Next dose")
                .font(.caption2.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(palette.textTertiary.opacity(0.75))
            Text(next, style: .offset)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.textSecondary.opacity(0.85))
        }
        .lineLimit(1)
    }
}

/// The curve canvas: fill, stroke, range band, lab rings and the now point —
/// the same stack order as the Home graph (H4–H7).
private struct CurveCanvas: View {
    let snapshot: WidgetChartSnapshot
    let palette: ChartPalette
    let date: Date

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = snapshot.points.map(\.v)
            let (minV, range) = CurveGeometry.valueBounds(values)
            let plotBottom = h - 4

            ZStack(alignment: .topLeading) {
                rangeBand(minV: minV, range: range, w: w, plotBottom: plotBottom)

                CurveGeometry.fillPath(points: snapshot.points, min: minV, range: range,
                                       width: w, plotTop: 0, plotBottom: plotBottom,
                                       fillBottom: h)
                    .fill(LinearGradient(
                        stops: [.init(color: palette.levelTint.opacity(0.3), location: 0),
                                .init(color: palette.levelTint.opacity(0.0), location: 1)],
                        startPoint: .top, endPoint: .bottom))

                CurveGeometry.curvePath(points: snapshot.points, min: minV, range: range,
                                        width: w, plotTop: 0, plotBottom: plotBottom)
                    .stroke(LinearGradient(colors: [palette.levelLow, palette.levelHigh],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                labRings(minV: minV, range: range, w: w, plotBottom: plotBottom)

                nowPoint(minV: minV, range: range, w: w, plotBottom: plotBottom)
            }
        }
    }

    /// The user's reference band — only ever against a range the user set (U18).
    @ViewBuilder
    private func rangeBand(minV: Double, range: Double, w: CGFloat, plotBottom: CGFloat) -> some View {
        if let band = snapshot.rangeBand {
            let yHigh = CurveGeometry.y(value: band.high, min: minV, range: range,
                                        plotTop: 0, plotBottom: plotBottom)
            let yLow = CurveGeometry.y(value: band.low, min: minV, range: range,
                                       plotTop: 0, plotBottom: plotBottom)
            let top = min(yHigh, yLow)
            let height = max(abs(yLow - yHigh), 1)
            Rectangle()
                .fill(palette.accent.opacity(0.05))
                .frame(width: w, height: height)
                .position(x: w / 2, y: top + height / 2)
        }
    }

    /// Measured labs, plotted at the raw value — never snapped to the curve
    /// (the gap between ring and curve is the information, H6).
    @ViewBuilder
    private func labRings(minV: Double, range: Double, w: CGFloat, plotBottom: CGFloat) -> some View {
        ForEach(snapshot.labs.indices, id: \.self) { i in
            if let fraction = CurveGeometry.timeFraction(snapshot.labs[i].t, in: snapshot.points) {
                let x = min(max(fraction * w, 8), w - 8)
                let y = CurveGeometry.y(value: snapshot.labs[i].v, min: minV, range: range,
                                        plotTop: 0, plotBottom: plotBottom)
                Circle()
                    .fill(palette.appBackground)
                    .overlay(Circle().strokeBorder(palette.textPrimary, lineWidth: 1.3))
                    .frame(width: 9, height: 9)
                    .position(x: x, y: y)
            }
        }
    }

    /// The concentric now point — a perfect dot inside its halo (H7).
    @ViewBuilder
    private func nowPoint(minV: Double, range: Double, w: CGFloat, plotBottom: CGFloat) -> some View {
        if let dot = CurveGeometry.nowDot(at: date, in: snapshot.points,
                                          width: w, minV: minV, range: range,
                                          plotTop: 0, plotBottom: plotBottom) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.15))
                    .frame(width: 26, height: 26)
                Circle()
                    .fill(palette.levelTint)
                    .frame(width: 10, height: 10)
            }
            .position(dot)
        }
    }
}

/// What the widget shows before the first dose: the wordmark and one line.
private struct EmptyChartView: View {
    let palette: ChartPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()
            Text("Isocline")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
            Text("Open Isocline to log your first dose.")
                .font(.caption)
                .foregroundStyle(palette.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .widgetFrame(palette: palette)
    }
}

// MARK: - Widget registration

struct IsoclineChart: Widget {
    let kind: String = "IsoclineChart"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChartProvider()) { entry in
            IsoclineChartEntryView(entry: entry)
        }
        .configurationDisplayName("Isocline")
        .description("Your hormone curve, level and next dose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Background (iOS 17 containerBackground, padded fallback before)

private extension View {
    @ViewBuilder
    func widgetFrame(palette: ChartPalette) -> some View {
        if #available(iOS 17.0, *) {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .containerBackground(for: .widget) { palette.appBackground }
        } else {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(palette.appBackground)
        }
    }
}

#Preview(as: .systemSmall) {
    IsoclineChart()
} timeline: {
    ChartEntry(date: .now, snapshot: SnapshotStore.sample)
    ChartEntry(date: .now.addingTimeInterval(3600), snapshot: SnapshotStore.sample)
}

#Preview(as: .systemMedium) {
    IsoclineChart()
} timeline: {
    ChartEntry(date: .now, snapshot: SnapshotStore.sample)
}
