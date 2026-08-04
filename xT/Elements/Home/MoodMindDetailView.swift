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


// MARK: - Mood & Mind Detail View

struct MoodMindDetailView: View {
    let engine: TimeContentEngine

    @State private var selectedRegion: String? = nil
    @State private var field: ConstellationField = .empty
    @State private var showDetails = false

    private var months: Int { engine.activeMonthsOnHRT }
    private var isEstrogen: Bool { engine.medication == "Estrogen" }
    private var regions: [BodyRegion] { isEstrogen ? TimeBodyRegions.mindRegions : TimeBodyRegions.mindRegionsT }

    /// Screen-fractional anchor points for each region's floating label. Shared
    /// across medications — both region sets reuse the same keys (`pfc`,
    /// `hippocampus`, `amygdala`, `synaptic`), only the authored text differs.
    private let regionAnchors: [String: CGPoint] = [
        "pfc":         CGPoint(x: 0.28, y: 0.24),
        "hippocampus": CGPoint(x: 0.70, y: 0.72),
        "amygdala":    CGPoint(x: 0.80, y: 0.46),
        "synaptic":    CGPoint(x: 0.22, y: 0.58),
    ]

    var body: some View {
        ZStack {
            constellationBackground

            ConstellationView(
                field: field,
                tint: Theme.Colors.Time.mind.base,
                secondaryTint: Theme.Colors.Time.cycle.base,
                selectedRegion: selectedRegion,
                regionActivity: { ConstellationCloud.activity(regionKey: $0, months: months, medication: engine.medication) }
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if value.translation.height < -55 { showDetails = true }
                    }
            )

            regionLabels

            adornmentOverlay
        }
        .navigationTitle("Mood & Mind")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if field.nodes.isEmpty {
                field = ConstellationCloud.brain(months: months)
            }
        }
        .sheet(isPresented: $showDetails) { detailsSheet }
    }

    // MARK: - Immersive Background

    private var constellationBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.Time.mind.surface, Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.Colors.Time.mind.base.opacity(0.18), .clear],
                center: .center, startRadius: 8, endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Floating Region Labels

    private var regionLabels: some View {
        GeometryReader { geo in
            ForEach(regions) { region in
                if let anchor = regionAnchors[region.key] {
                    ConstellationRegionTag(
                        label: region.label,
                        color: region.key == "hippocampus"
                            ? Theme.Colors.Time.cycle.base
                            : Theme.Colors.Time.mind.base,
                        isSelected: selectedRegion == region.key
                    )
                    .position(x: geo.size.width * anchor.x,
                              y: geo.size.height * anchor.y)
                    .onTapGesture { selectRegion(region.key) }
                }
            }
        }
    }

    // MARK: - Adornments (hero + stats + hint)

    private var adornmentOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TIME · BODY SYSTEMS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("Mood & Mind")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.Colors.Time.mind.base)
                HStack(spacing: 6) {
                    Text(engine.tenureTier.timeBandLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary.opacity(0.4))
                    Text(months == 1 ? "1 month" : "\(months) months")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)

            Spacer()

            floatingStats
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

            detailsHint
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var floatingStats: some View {
        let stats = isEstrogen ? TimeBodyRegions.mindStats(months: months) : TimeBodyRegions.mindStatsT(months: months)
        return HStack(spacing: 10) {
            ForEach(stats.indices, id: \.self) { i in
                VStack(spacing: 2) {
                    Text(stats[i].value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.Time.mind.base)
                    Text(stats[i].label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var detailsHint: some View {
        Button { showDetails = true } label: {
            VStack(spacing: 3) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                Text("Details")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func selectRegion(_ key: String) {
        withAnimation(Theme.Motion.snappy) { selectedRegion = key }
        showDetails = true
    }

    // MARK: - Details Sheet

    private var detailsSheet: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let insight = engine.hormoneInsight {
                            hormoneLevelCard(insight: insight)
                                .padding(.horizontal, 22)
                                .padding(.top, 16)
                        }

                        BodySystemStatsRow(
                            stats: isEstrogen ? TimeBodyRegions.mindStats(months: months) : TimeBodyRegions.mindStatsT(months: months),
                            accentColor: Theme.Colors.Time.mind.base
                        )
                        .padding(.horizontal, 22)
                        .padding(.top, 16)

                        KeyInsightBanner(
                            text: isEstrogen ? TimeBodyRegions.mindInsight(months: months) : TimeBodyRegions.mindInsightT(months: months),
                            accentColor: Theme.Colors.Time.mind.base
                        )
                        .padding(.horizontal, 22)
                        .padding(.top, 14)

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

                        EducationalFooter()
                            .padding(.top, 8)

                        Color.clear.frame(height: 40)
                    }
                }
                .onAppear {
                    if let sel = selectedRegion {
                        withAnimation { proxy.scrollTo(sel, anchor: .center) }
                    }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
        .presentationDragIndicator(.visible)
    }

    private func hormoneLevelCard(insight: TimeHormoneInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HORMONE LEVELS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(0.5)
                Spacer()
                Text(insight.rangeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(insight.rangePalette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(insight.rangePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                if let pos = cyclePositionBadge {
                    Text(pos)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                AnimatedCounter(value: insight.level)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(insight.unit)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(insight.bodyDescription)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(insight.rangePalette.border.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var cyclePositionBadge: String? {
        switch engine.cyclePosition {
        case .nearPeak: return "Peak"
        case .midCycle: return "Mid"
        case .trough:   return "Trough"
        case .unknown:  return nil
        }
    }
}
