import SwiftUI

// MARK: - Shared Sub-Views

struct BodySystemStatsRow: View {
    let stats: [(value: String, label: String, sub: String)]
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ForEach(stats.indices, id: \.self) { i in
                VStack(spacing: 3) {
                    Text(stats[i].value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text(stats[i].label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(stats[i].sub)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(accentColor.opacity(0.12), lineWidth: 0.5)
                )
            }
        }
    }
}

struct KeyInsightBanner: View {
    let text: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("KEY INSIGHT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)
                .tracking(0.5)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(accentColor.opacity(0.18), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
}

struct RegionDetailCard: View {
    let region: BodyRegion
    let months: Int
    let isSelected: Bool
    let palette: TimeContentPalette
    let onTap: () -> Void

    @State private var isExpanded = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surface)
                            .frame(width: 34, height: 34)
                        Image(systemName: region.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.accent)
                    }

                    Text(region.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(region.progressStatus(at: months))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(region.phaseText(at: months))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)

                if !isExpanded {
                    Text("Read more")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isSelected ? palette.accent.opacity(0.5) : palette.border.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            onTap()
        }
    }
}

// MARK: - Mini Mind Diagram (shown in TimeBodySystemRow)

struct MiniMindDiagram: View {
    let months: Int

    private var density: Double {
        min(1.0, Double(max(months, 0)) / 36.0)
    }

    private let nodes: [CGPoint] = [
        CGPoint(x: 35, y: 35), CGPoint(x: 65, y: 35),
        CGPoint(x: 30, y: 65), CGPoint(x: 70, y: 65),
        CGPoint(x: 50, y: 50), CGPoint(x: 20, y: 50), CGPoint(x: 80, y: 50),
    ]

    private let edges: [(Int, Int)] = [
        (0, 4), (1, 4), (4, 2), (4, 3), (0, 5), (1, 6), (5, 2), (6, 3),
    ]

    var body: some View {
        SwiftUI.TimelineView(AnimationTimelineSchedule()) { timeline in
            Canvas { context, size in
                let mindColor = Theme.Colors.Time.mind.base
                let d = self.density
                let vW: CGFloat = 100, vH: CGFloat = 100
                let scale = min(size.width / vW, size.height / vH)
                let ox = (size.width - vW * scale) / 2
                let oy = (size.height - vH * scale) / 2
                context.translateBy(x: ox, y: oy)
                context.scaleBy(x: scale, y: scale)

                // Brain outline
                var outline = Path()
                outline.move(to: CGPoint(x: 50, y: 20))
                outline.addQuadCurve(to: CGPoint(x: 18, y: 35), control: CGPoint(x: 30, y: 18))
                outline.addQuadCurve(to: CGPoint(x: 10, y: 55), control: CGPoint(x: 8, y: 42))
                outline.addQuadCurve(to: CGPoint(x: 15, y: 72), control: CGPoint(x: 9, y: 63))
                outline.addQuadCurve(to: CGPoint(x: 28, y: 90), control: CGPoint(x: 15, y: 84))
                outline.addQuadCurve(to: CGPoint(x: 50, y: 95), control: CGPoint(x: 36, y: 98))
                outline.addQuadCurve(to: CGPoint(x: 72, y: 90), control: CGPoint(x: 64, y: 98))
                outline.addQuadCurve(to: CGPoint(x: 85, y: 72), control: CGPoint(x: 85, y: 84))
                outline.addQuadCurve(to: CGPoint(x: 90, y: 55), control: CGPoint(x: 91, y: 63))
                outline.addQuadCurve(to: CGPoint(x: 82, y: 35), control: CGPoint(x: 92, y: 42))
                outline.addQuadCurve(to: CGPoint(x: 50, y: 20), control: CGPoint(x: 70, y: 18))
                context.stroke(outline, with: .color(.white.opacity(0.15)), lineWidth: 1.5)

                // Center division line
                var centerLine = Path()
                centerLine.move(to: CGPoint(x: 50, y: 22))
                centerLine.addLine(to: CGPoint(x: 50, y: 93))
                context.stroke(centerLine, with: .color(.white.opacity(0.08)), lineWidth: 0.8)

                // Neural tracts — opacity and width scale with density
                for (fromIdx, toIdx) in edges {
                    let a = nodes[fromIdx], b = nodes[toIdx]
                    var line = Path()
                    line.move(to: a)
                    line.addLine(to: b)
                    let op = 0.1 + 0.65 * d
                    let sw = 0.4 + 1.6 * d
                    context.stroke(line, with: .color(mindColor.opacity(op)), lineWidth: sw)
                }

                // Pulsing synaptic nodes
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulseCount = Int(2 + 5 * d)
                for i in 0..<min(pulseCount, nodes.count) {
                    let node = nodes[i]
                    let phase = Double(i) * 0.9
                    let pulse = 0.25 + 0.55 * (0.5 + 0.5 * sin(t * 1.4 + phase))
                    let r = CGFloat(1.2 + 1.4 * d)
                    var dot = Path()
                    dot.addEllipse(in: CGRect(x: node.x - r, y: node.y - r, width: r * 2, height: r * 2))
                    context.fill(dot, with: .color(.white.opacity(pulse)))
                }
            }
        }
        .frame(width: 86, height: 86)
        .drawingGroup()
    }
}

// MARK: - Brain Wireframe (Detail View Canvas)

private struct BrainCallout {
    let key: String
    let dotX: CGFloat   // virtual 100×100 coords
    let dotY: CGFloat
    let lineToX: CGFloat
    let lineToY: CGFloat
}

private let brainCallouts: [BrainCallout] = [
    BrainCallout(key: "pfc",         dotX: 12, dotY: 28, lineToX: 36, lineToY: 36),
    BrainCallout(key: "hippocampus", dotX: 12, dotY: 72, lineToX: 34, lineToY: 67),
    BrainCallout(key: "amygdala",    dotX: 18, dotY: 53, lineToX: 36, lineToY: 57),
    BrainCallout(key: "synaptic",    dotX: 84, dotY: 38, lineToX: 58, lineToY: 50),
]

private let brainNodes: [CGPoint] = [
    CGPoint(x: 35, y: 35), CGPoint(x: 65, y: 35),
    CGPoint(x: 30, y: 65), CGPoint(x: 70, y: 65),
    CGPoint(x: 50, y: 50), CGPoint(x: 20, y: 50), CGPoint(x: 80, y: 50),
]

private let brainEdges: [(Int, Int)] = [
    (0, 4), (1, 4), (4, 2), (4, 3), (0, 5), (1, 6), (5, 2), (6, 3),
]

struct BrainWireframeView: View {
    let months: Int
    let selectedRegion: String?
    let onCalloutTapped: (String) -> Void

    private let vW: CGFloat = 100
    private let vH: CGFloat = 100
    private let mindColor = Theme.Colors.Time.mind.base
    private let mindSurface = Theme.Colors.Time.mind.surface

    private var density: Double { min(1.0, Double(max(months, 0)) / 36.0) }
    private var pfcOpacity: Double { min(1.0, Double(max(months - 1, 0)) / 18.0) }
    private var hippStroke: Double { min(1.0, Double(max(months - 1, 0)) / 24.0) }
    private var amygOpacity: Double { min(1.0, Double(max(months - 1, 0)) / 12.0) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = min(size.width / vW, size.height / vH)
            let ox = (size.width - vW * scale) / 2
            let oy = (size.height - vH * scale) / 2

            ZStack {
                // Static anatomy layer
                Canvas { context, _ in
                    context.translateBy(x: ox, y: oy)
                    context.scaleBy(x: scale, y: scale)
                    drawBrainAnatomy(into: &context, density: density, pfcOpacity: pfcOpacity, hippStroke: hippStroke, amygOpacity: amygOpacity)
                }

                // Animated neural network layer
                SwiftUI.TimelineView(AnimationTimelineSchedule()) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, _ in
                        context.translateBy(x: ox, y: oy)
                        context.scaleBy(x: scale, y: scale)
                        drawNeuralNetwork(into: &context, density: density, time: t)
                    }
                }

                // Callout dots — interactive SwiftUI views
                ForEach(brainCallouts, id: \.key) { callout in
                    let isSelected = selectedRegion == callout.key
                    let dotColor: Color = callout.key == "hippocampus"
                        ? Theme.Colors.Time.cycle.base
                        : mindColor

                    Button { onCalloutTapped(callout.key) } label: {
                        ZStack {
                            Circle()
                                .fill(dotColor.opacity(isSelected ? 0.25 : 0.12))
                                .frame(width: isSelected ? 22 : 16, height: isSelected ? 22 : 16)
                            Circle()
                                .fill(dotColor)
                                .frame(width: isSelected ? 10 : 7, height: isSelected ? 10 : 7)
                        }
                        .shadow(color: dotColor.opacity(0.5), radius: isSelected ? 6 : 3)
                        .animation(Theme.Motion.snappy, value: isSelected)
                    }
                    .position(
                        x: ox + callout.dotX * scale,
                        y: oy + callout.dotY * scale
                    )
                }
            }
        }
    }

    private func drawBrainAnatomy(into context: inout GraphicsContext, density: Double, pfcOpacity: Double, hippStroke: Double, amygOpacity: Double) {
        // Brain outline — full brain silhouette
        var outline = Path()
        outline.move(to: CGPoint(x: 50, y: 20))
        outline.addQuadCurve(to: CGPoint(x: 18, y: 35), control: CGPoint(x: 30, y: 18))
        outline.addQuadCurve(to: CGPoint(x: 10, y: 55), control: CGPoint(x: 8, y: 42))
        outline.addQuadCurve(to: CGPoint(x: 15, y: 72), control: CGPoint(x: 9, y: 63))
        outline.addQuadCurve(to: CGPoint(x: 28, y: 90), control: CGPoint(x: 15, y: 84))
        outline.addQuadCurve(to: CGPoint(x: 50, y: 95), control: CGPoint(x: 36, y: 98))
        outline.addQuadCurve(to: CGPoint(x: 72, y: 90), control: CGPoint(x: 64, y: 98))
        outline.addQuadCurve(to: CGPoint(x: 85, y: 72), control: CGPoint(x: 85, y: 84))
        outline.addQuadCurve(to: CGPoint(x: 90, y: 55), control: CGPoint(x: 91, y: 63))
        outline.addQuadCurve(to: CGPoint(x: 82, y: 35), control: CGPoint(x: 92, y: 42))
        outline.addQuadCurve(to: CGPoint(x: 50, y: 20), control: CGPoint(x: 70, y: 18))
        context.stroke(outline, with: .color(.primary.opacity(0.25)), lineWidth: 1.5)

        // Center line
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: 50, y: 22))
        centerLine.addLine(to: CGPoint(x: 50, y: 93))
        context.stroke(centerLine, with: .color(.secondary.opacity(0.15)), lineWidth: 0.8)

        // Callout lines
        for callout in brainCallouts {
            var cLine = Path()
            cLine.move(to: CGPoint(x: callout.dotX, y: callout.dotY))
            cLine.addLine(to: CGPoint(x: callout.lineToX, y: callout.lineToY))
            let lineColor: Color = callout.key == "hippocampus"
                ? Theme.Colors.Time.cycle.base
                : Theme.Colors.Time.mind.base
            context.stroke(cLine, with: .color(lineColor.opacity(0.3)), lineWidth: 0.8)
        }

        // PFC region — upper band, opacity grows with months
        if pfcOpacity > 0 {
            var pfcLeft = Path()
            pfcLeft.addEllipse(in: CGRect(x: 18, y: 28, width: 26, height: 18))
            context.fill(pfcLeft, with: .color(Theme.Colors.Time.mind.base.opacity(0.08 + 0.18 * pfcOpacity)))

            var pfcRight = Path()
            pfcRight.addEllipse(in: CGRect(x: 56, y: 28, width: 26, height: 18))
            context.fill(pfcRight, with: .color(Theme.Colors.Time.mind.base.opacity(0.08 + 0.18 * pfcOpacity)))
        }

        // Hippocampus crescents — lower inner region, stroke grows with months
        if hippStroke > 0 {
            var hippLeft = Path()
            hippLeft.move(to: CGPoint(x: 29, y: 65))
            hippLeft.addQuadCurve(to: CGPoint(x: 38, y: 65), control: CGPoint(x: 33, y: 59))
            hippLeft.addQuadCurve(to: CGPoint(x: 29, y: 65), control: CGPoint(x: 33, y: 72))
            context.stroke(hippLeft, with: .color(Theme.Colors.Time.cycle.base.opacity(0.3 + 0.55 * hippStroke)), lineWidth: 1.0 + 2.0 * hippStroke)

            var hippRight = Path()
            hippRight.move(to: CGPoint(x: 62, y: 65))
            hippRight.addQuadCurve(to: CGPoint(x: 71, y: 65), control: CGPoint(x: 67, y: 59))
            hippRight.addQuadCurve(to: CGPoint(x: 62, y: 65), control: CGPoint(x: 67, y: 72))
            context.stroke(hippRight, with: .color(Theme.Colors.Time.cycle.base.opacity(0.3 + 0.55 * hippStroke)), lineWidth: 1.0 + 2.0 * hippStroke)
        }

        // Amygdala — small circles mid-lateral
        if amygOpacity > 0 {
            var amygLeft = Path()
            amygLeft.addEllipse(in: CGRect(x: 24, y: 53, width: 9, height: 9))
            context.fill(amygLeft, with: .color(Theme.Colors.Time.mind.base.opacity(0.15 + 0.35 * amygOpacity)))

            var amygRight = Path()
            amygRight.addEllipse(in: CGRect(x: 67, y: 53, width: 9, height: 9))
            context.fill(amygRight, with: .color(Theme.Colors.Time.mind.base.opacity(0.15 + 0.35 * amygOpacity)))
        }
    }

    private func drawNeuralNetwork(into context: inout GraphicsContext, density: Double, time: Double) {
        // Tracts
        for (fromIdx, toIdx) in brainEdges {
            let a = brainNodes[fromIdx], b = brainNodes[toIdx]
            var line = Path()
            line.move(to: a)
            line.addLine(to: b)
            let op = 0.08 + 0.6 * density
            let sw = 0.4 + 1.8 * density
            context.stroke(line, with: .color(mindColor.opacity(op)), lineWidth: sw)
        }

        // Pulsing nodes
        let pulseCount = Int(2 + 5 * density)
        for i in 0..<min(pulseCount, brainNodes.count) {
            let node = brainNodes[i]
            let phase = Double(i) * 0.9
            let pulse = 0.2 + 0.6 * (0.5 + 0.5 * sin(time * 1.4 + phase))
            let r = CGFloat(1.5 + 2.0 * density)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: node.x - r, y: node.y - r, width: r * 2, height: r * 2))
            context.fill(dot, with: .color(mindColor.opacity(pulse)))

            // Outer glow ring
            if density > 0.3 {
                let gr = r + CGFloat(1.5 * density)
                var glow = Path()
                glow.addEllipse(in: CGRect(x: node.x - gr, y: node.y - gr, width: gr * 2, height: gr * 2))
                context.stroke(glow, with: .color(mindColor.opacity(0.12 * density)), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Mood & Mind Detail View

struct MoodMindDetailView: View {
    let system: TimeBodySystem
    let engine: TimeContentEngine

    @State private var selectedRegion: String? = nil

    private var months: Int { engine.activeMonthsOnHRT }
    private var regions: [BodyRegion] { TimeBodyRegions.mindRegions }

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

                        Text("Mood & Mind")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.Colors.Time.mind.base)

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

                    // Brain wireframe canvas
                    BrainWireframeView(months: months, selectedRegion: selectedRegion) { key in
                        withAnimation(Theme.Motion.snappy) {
                            selectedRegion = selectedRegion == key ? nil : key
                        }
                        withAnimation { proxy.scrollTo(key, anchor: .center) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Theme.Colors.Time.mind.base.opacity(0.04))
                    )

                    Text("Tap a region to explore")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Stats
                    BodySystemStatsRow(
                        stats: TimeBodyRegions.mindStats(months: months),
                        accentColor: Theme.Colors.Time.mind.base
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    // Key insight
                    KeyInsightBanner(
                        text: TimeBodyRegions.mindInsight(months: months),
                        accentColor: Theme.Colors.Time.mind.base
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                    // Region cards
                    Text("NEURAL REGIONS")
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
                            palette: .purple,
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
        .navigationTitle("Mood & Mind")
        .navigationBarTitleDisplayMode(.inline)
    }
}
