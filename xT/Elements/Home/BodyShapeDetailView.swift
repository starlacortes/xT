import SwiftUI

// MARK: - Math Helpers

private func lerpD(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * min(max(t, 0), 1)
}

private func easeD(_ t: Double) -> Double {
    t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}

private func progressD(_ months: Double, start: Double, end: Double) -> Double {
    easeD(min(max((months - start) / (end - start), 0), 1))
}

// MARK: - Animatable Body Silhouette Shape

struct DynamicBodySilhouette: Shape {
    var elapsedMonths: Double

    var animatableData: Double {
        get { elapsedMonths }
        set { elapsedMonths = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Virtual space is 100×120 (matching HTML prototype)
        let vW: CGFloat = 100, vH: CGFloat = 120
        let scale = min(rect.width / vW, rect.height / vH)
        let ox = (rect.width - vW * scale) / 2
        let oy = (rect.height - vH * scale) / 2

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(x) * scale, y: oy + CGFloat(y) * scale)
        }

        let m = elapsedMonths
        let cx = 50.0
        let waistW = lerpD(20, 14, progressD(m, start: 3, end: 20))
        let hipW   = lerpD(24, 34, progressD(m, start: 3, end: 22))
        let bustW  = lerpD(22, 28, progressD(m, start: 2, end: 24))

        var path = Path()
        // Neck/shoulder start — left side
        path.move(to: pt(cx - 8, 10))
        // Left shoulder to bust
        path.addCurve(
            to: pt(cx - bustW, 45),
            control1: pt(cx - 25, 25),
            control2: pt(cx - bustW, 40)
        )
        // Bust to waist
        path.addCurve(
            to: pt(cx - waistW, 70),
            control1: pt(cx - bustW + 2, 55),
            control2: pt(cx - waistW, 65)
        )
        // Waist to hip (left)
        path.addCurve(
            to: pt(cx - 20, 115),
            control1: pt(cx - hipW, 85),
            control2: pt(cx - hipW, 100)
        )
        // Bottom — left to right
        path.addLine(to: pt(cx + 20, 115))
        // Hip to waist (right)
        path.addCurve(
            to: pt(cx + waistW, 70),
            control1: pt(cx + hipW, 100),
            control2: pt(cx + hipW, 85)
        )
        // Waist to bust (right)
        path.addCurve(
            to: pt(cx + bustW, 45),
            control1: pt(cx + waistW, 65),
            control2: pt(cx + bustW - 2, 55)
        )
        // Bust to shoulder (right)
        path.addCurve(
            to: pt(cx + 8, 10),
            control1: pt(cx + bustW, 40),
            control2: pt(cx + 25, 25)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Mini Body Silhouette (shown in TimeBodySystemRow)

struct MiniBodySilhouette: View {
    let months: Int

    var body: some View {
        ZStack {
            DynamicBodySilhouette(elapsedMonths: Double(months))
                .fill(Theme.Colors.Time.body.base.opacity(0.12))

            DynamicBodySilhouette(elapsedMonths: Double(months))
                .stroke(Theme.Colors.Time.body.base.opacity(0.75), lineWidth: 1.2)

            // Subtle center axis
            DividerLine()
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
        }
        .shadow(color: Theme.Colors.Time.body.base.opacity(0.25), radius: 8)
        .frame(width: 68, height: 86)
        .animation(Theme.Motion.smooth, value: months)
        .drawingGroup()
    }

    private struct DividerLine: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY + 4))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 4))
            return p
        }
    }
}

// MARK: - Fat Pad Overlay Data

private struct FatPad: Identifiable {
    let id: String
    let regionKey: String
    let cx: Double      // fractional 0–1 in view space
    let cy: Double
    let rx: Double
    let ry: Double
    let startMonth: Double
    let peakMonth: Double
    let completeMonth: Double

    func opacity(at months: Int) -> Double {
        progressD(Double(months), start: startMonth, end: peakMonth) * 0.55
    }
}

private let fatPads: [FatPad] = [
    // Hips — left
    FatPad(id: "hip-l", regionKey: "hips",   cx: 0.28, cy: 0.70, rx: 0.14, ry: 0.12, startMonth: 3, peakMonth: 18, completeMonth: 36),
    // Hips — right
    FatPad(id: "hip-r", regionKey: "hips",   cx: 0.72, cy: 0.70, rx: 0.14, ry: 0.12, startMonth: 3, peakMonth: 18, completeMonth: 36),
    // Thighs — left
    FatPad(id: "thi-l", regionKey: "thighs", cx: 0.33, cy: 0.88, rx: 0.10, ry: 0.08, startMonth: 4, peakMonth: 20, completeMonth: 36),
    // Thighs — right
    FatPad(id: "thi-r", regionKey: "thighs", cx: 0.67, cy: 0.88, rx: 0.10, ry: 0.08, startMonth: 4, peakMonth: 20, completeMonth: 36),
    // Glutes — left
    FatPad(id: "glu-l", regionKey: "glutes", cx: 0.30, cy: 0.78, rx: 0.10, ry: 0.09, startMonth: 3, peakMonth: 24, completeMonth: 48),
    // Glutes — right
    FatPad(id: "glu-r", regionKey: "glutes", cx: 0.70, cy: 0.78, rx: 0.10, ry: 0.09, startMonth: 3, peakMonth: 24, completeMonth: 48),
    // Chest — left
    FatPad(id: "bre-l", regionKey: "chest",  cx: 0.36, cy: 0.38, rx: 0.10, ry: 0.08, startMonth: 1, peakMonth: 36, completeMonth: 60),
    // Chest — right
    FatPad(id: "bre-r", regionKey: "chest",  cx: 0.64, cy: 0.38, rx: 0.10, ry: 0.08, startMonth: 1, peakMonth: 36, completeMonth: 60),
]

// MARK: - Body Silhouette Detail View

private struct BodyCallout {
    let key: String
    let xFrac: Double   // fractional in view space
    let yFrac: Double
}

private let bodyCallouts: [BodyCallout] = [
    BodyCallout(key: "hips",   xFrac: 0.12, yFrac: 0.68),
    BodyCallout(key: "thighs", xFrac: 0.88, yFrac: 0.85),
    BodyCallout(key: "waist",  xFrac: 0.14, yFrac: 0.50),
    BodyCallout(key: "glutes", xFrac: 0.86, yFrac: 0.75),
    BodyCallout(key: "chest",  xFrac: 0.14, yFrac: 0.34),
]

struct BodySilhouetteView: View {
    let months: Int
    let selectedRegion: String?
    let onCalloutTapped: (String) -> Void

    private let bodyColor = Theme.Colors.Time.body.base

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Fat pad glows — soft, blurred ellipses behind the outline
                ForEach(fatPads) { pad in
                    let op = pad.opacity(at: months)
                    if op > 0 {
                        let isRegionSelected = selectedRegion == pad.regionKey
                        Ellipse()
                            .fill(bodyColor.opacity(op * (isRegionSelected ? 2.0 : 1.0)))
                            .frame(width: pad.rx * 2 * w, height: pad.ry * 2 * h)
                            .blur(radius: 8)
                            .position(x: pad.cx * w, y: pad.cy * h)
                            .animation(Theme.Motion.smooth, value: months)
                    }
                }

                // Body outline — animates with months
                DynamicBodySilhouette(elapsedMonths: Double(months))
                    .fill(bodyColor.opacity(0.07))
                    .frame(width: w, height: h)
                    .animation(Theme.Motion.smooth, value: months)

                DynamicBodySilhouette(elapsedMonths: Double(months))
                    .stroke(bodyColor.opacity(0.65), lineWidth: 1.8)
                    .frame(width: w, height: h)
                    .shadow(color: bodyColor.opacity(0.2), radius: 4)
                    .animation(Theme.Motion.smooth, value: months)

                // Callout dots
                ForEach(bodyCallouts, id: \.key) { callout in
                    let isSelected = selectedRegion == callout.key
                    Button { onCalloutTapped(callout.key) } label: {
                        ZStack {
                            Circle()
                                .fill(bodyColor.opacity(isSelected ? 0.25 : 0.12))
                                .frame(width: isSelected ? 22 : 16, height: isSelected ? 22 : 16)
                            Circle()
                                .fill(bodyColor)
                                .frame(width: isSelected ? 10 : 7, height: isSelected ? 10 : 7)
                        }
                        .shadow(color: bodyColor.opacity(0.5), radius: isSelected ? 6 : 3)
                        .animation(Theme.Motion.snappy, value: isSelected)
                    }
                    .position(x: callout.xFrac * w, y: callout.yFrac * h)
                }
            }
        }
    }
}

// MARK: - Body Shape Detail View

struct BodyShapeDetailView: View {
    let system: TimeBodySystem
    let engine: TimeContentEngine

    @State private var selectedRegion: String? = nil

    private var months: Int { engine.activeMonthsOnHRT }
    private var regions: [BodyRegion] { TimeBodyRegions.bodyRegions }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIME · BODY SYSTEMS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        Text("Body Architecture")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.Colors.Time.body.base)

                        HStack(spacing: 6) {
                            Text(engine.tenureTier.statusEmoji + " " + engine.tenureTier.timeBandLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.secondary.opacity(0.4))
                            Text(months == 1 ? "1 month" : "\(months) months")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // Body silhouette canvas
                    BodySilhouetteView(months: months, selectedRegion: selectedRegion) { key in
                        withAnimation(Theme.Motion.snappy) {
                            selectedRegion = selectedRegion == key ? nil : key
                        }
                        withAnimation { proxy.scrollTo(key, anchor: .center) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Theme.Colors.Time.body.base.opacity(0.03))
                    )

                    Text("Tap a region to explore")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Stats
                    BodySystemStatsRow(
                        stats: TimeBodyRegions.bodyStats(months: months),
                        accentColor: Theme.Colors.Time.body.base
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    // Key insight
                    KeyInsightBanner(
                        text: TimeBodyRegions.bodyInsight(months: months),
                        accentColor: Theme.Colors.Time.body.base
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                    // Region cards
                    Text("BODY REGIONS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 28)
                        .padding(.bottom, 10)

                    ForEach(regions) { region in
                        RegionDetailCard(
                            region: region,
                            months: months,
                            isSelected: selectedRegion == region.key,
                            palette: .amber,
                            onTap: {
                                withAnimation(Theme.Motion.snappy) {
                                    selectedRegion = selectedRegion == region.key ? nil : region.key
                                }
                            }
                        )
                        .id(region.key)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 8)
                    }

                    Color.clear.frame(height: 40)
                }
            }
        }
        .navigationTitle("Body Architecture")
        .navigationBarTitleDisplayMode(.inline)
    }
}
