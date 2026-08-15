//
//  BodyArchitectureDetailView.swift
//  xT
//
//  Consolidated detail view for all physical body systems.
//  Pushed from the Time tab's "Body Architecture" primary choice row.
//  Aggregates: Body Shape, Skin, Cycle (E) / Skin & Hair, Voice, Cycle (T),
//  plus physical changes and regimen timeline.
//

import SwiftUI

struct BodyArchitectureDetailView: View {
    let engine: TimeContentEngine

    @State private var selectedRegion: String? = nil
    @State private var field: ConstellationField = .empty
    @State private var showDetails = false

    private var months: Int { engine.activeMonthsOnHRT }
    private var tier: TenureTier { engine.tenureTier }
    private var isEstrogen: Bool { engine.medication == "Estrogen" }
    private var bodyRegions: [BodyRegion] { isEstrogen ? TimeBodyRegions.bodyRegions : TimeBodyRegions.bodyRegionsT }

    /// Screen-fractional anchor points for each region's floating label. Shared
    /// across medications — both region sets reuse the same keys (`chest`,
    /// `abdomen`, `hips`, `glutes`, `thighs`), only the authored text differs.
    private let regionAnchors: [String: CGPoint] = [
        "chest":   CGPoint(x: 0.62, y: 0.34),
        "abdomen": CGPoint(x: 0.66, y: 0.46),
        "hips":    CGPoint(x: 0.68, y: 0.56),
        "glutes":  CGPoint(x: 0.32, y: 0.58),
        "thighs":  CGPoint(x: 0.60, y: 0.72),
    ]

    private var physicalSystems: [TimeBodySystem] {
        engine.bodySystems.filter { $0.systemKey != .moodAndMind }
    }

    private var physicalChanges: [TimeChange] {
        let moodLabels = ["Mood swings", "Emotional range", "Emotional sensitivity", "Emotional stability"]
        return engine.unlockedChanges.filter { change in
            !moodLabels.contains(where: { change.label.lowercased().contains($0.lowercased()) })
        }
    }

    var body: some View {
        ZStack {
            constellationBackground

            ConstellationView(
                field: field,
                tint: Theme.Colors.Time.body.base,
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
        .navigationTitle("Body Architecture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if field.nodes.isEmpty {
                field = ConstellationCloud.body(months: months, medication: engine.medication)
            }
        }
        .sheet(isPresented: $showDetails) { detailsSheet }
    }

    // MARK: - Immersive Background

    private var constellationBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.Time.body.surface, Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.Colors.Time.body.base.opacity(0.16), .clear],
                center: .center, startRadius: 8, endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Floating Region Labels

    private var regionLabels: some View {
        GeometryReader { geo in
            ForEach(bodyRegions) { region in
                if let anchor = regionAnchors[region.key] {
                    ConstellationRegionTag(
                        label: region.label,
                        color: Theme.Colors.Time.body.base,
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
            heroSection
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
        let stats = isEstrogen ? TimeBodyRegions.bodyStats(months: months) : TimeBodyRegions.bodyStatsT(months: months)
        return HStack(spacing: 10) {
            ForEach(stats.indices, id: \.self) { i in
                VStack(spacing: 2) {
                    Text(stats[i].value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.Time.body.base)
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
                        } else {
                            bloodTestNudge
                                .padding(.horizontal, 22)
                                .padding(.top, 16)
                        }

                        BodySystemStatsRow(
                            stats: isEstrogen ? TimeBodyRegions.bodyStats(months: months) : TimeBodyRegions.bodyStatsT(months: months),
                            accentColor: Theme.Colors.Time.body.base
                        )
                        .padding(.horizontal, 22)
                        .padding(.top, 16)

                        KeyInsightBanner(
                            text: isEstrogen ? TimeBodyRegions.bodyInsight(months: months) : TimeBodyRegions.bodyInsightT(months: months),
                            accentColor: Theme.Colors.Time.body.base
                        )
                        .padding(.horizontal, 22)
                        .padding(.top, 14)

                        // Body region cards
                        VStack(alignment: .leading, spacing: 0) {
                            Text("BODY REGIONS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 22)
                                .padding(.top, 28)
                                .padding(.bottom, 10)

                            ForEach(bodyRegions) { region in
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
                        }

                        // Physical changes capsule pills
                        if !physicalChanges.isEmpty {
                            changesSection
                                .padding(.horizontal, 22)
                                .padding(.top, 24)
                        } else {
                            changesPlaceholder
                                .padding(.horizontal, 22)
                                .padding(.top, 24)
                        }

                        // Other body system sections (Skin, Cycle, etc.)
                        otherBodySystemsSections

                        // Regimen timeline
                        if !engine.regimenSegments.isEmpty && engine.regimenSegments.count > 1 {
                            regimenTimelineSection
                                .padding(.horizontal, 22)
                                .padding(.top, 24)
                        }

                        // How dose intensity feeds the timelines above
                        if let note = engine.doseIntensityNote {
                            doseIntensityNote(note)
                                .padding(.horizontal, 22)
                                .padding(.top, 16)
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

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TIME · BODY SYSTEMS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text("Body Architecture")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.Colors.Time.body.base)

            HStack(spacing: 6) {
                Text(tier.timeBandLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary.opacity(0.4))
                Text(months == 1 ? "1 month" : "\(months) months")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hormone Level Card

    private func hormoneLevelCard(insight: TimeHormoneInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HORMONE LEVELS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.Time.body.base)
                    .tracking(0.5)
                Spacer()
                Text(insight.rangeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(insight.rangePalette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(insight.rangePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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

    private var bloodTestNudge: some View {
        HStack(spacing: 12) {
            Image(systemName: "flask")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Colors.Time.body.base.opacity(0.6))
            VStack(alignment: .leading, spacing: 3) {
                Text("HORMONE LEVELS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(engine.bloodTestSchedulingText ?? "A blood test will show your hormone levels here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.Time.body.base.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var changesPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHYSICAL CHANGES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 10) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.Time.body.base.opacity(0.5))
                Text(changesPlaceholderText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground).opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var changesPlaceholderText: String {
        switch tier {
        case .t1Beginning:
            return "First body changes typically begin appearing in months 3–6."
        case .t2Emerging:
            return "Early changes are beginning to emerge — visible changes develop over the coming months."
        default:
            return "Body changes develop gradually over time."
        }
    }

    // MARK: - Body Silhouette

    private var bodySilhouetteSection: some View {
        ZStack {
            // Animated silhouette
            ArchitectureBodyCanvas(months: months, isEstrogen: isEstrogen)
                .allowsHitTesting(false)

            // Callout dots
            GeometryReader { geo in
                ForEach(TimeBodyRegions.bodyRegionCallouts, id: \.key) { callout in
                    let isSelected = selectedRegion == callout.key
                    Button {
                        withAnimation(Theme.Motion.snappy) {
                            selectedRegion = selectedRegion == callout.key ? nil : callout.key
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.Time.body.base.opacity(isSelected ? 0.25 : 0.12))
                                .frame(width: isSelected ? 22 : 16, height: isSelected ? 22 : 16)
                            Circle()
                                .fill(Theme.Colors.Time.body.base)
                                .frame(width: isSelected ? 10 : 7, height: isSelected ? 10 : 7)
                        }
                        .shadow(color: Theme.Colors.Time.body.base.opacity(0.5), radius: isSelected ? 6 : 3)
                        .animation(Theme.Motion.snappy, value: isSelected)
                    }
                    .position(
                        x: geo.size.width * callout.xFrac,
                        y: geo.size.height * callout.yFrac
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Changes Section

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHYSICAL CHANGES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(physicalChanges) { change in
                        HStack(spacing: 5) {
                            Image(systemName: change.unlocked ? "checkmark" : "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(change.label)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(
                            change.unlocked ? Theme.Colors.Time.cycle.base : Color.secondary
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            change.unlocked
                                ? Theme.Colors.Time.cycle.surface
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    // MARK: - Other Body Systems (Skin, Cycle / Skin & Hair, Voice)

    private var otherBodySystemsSections: some View {
        ForEach(physicalSystems) { system in
            if system.systemKey != .bodyShape {
                systemDetailSection(for: system)
                    .padding(.top, 24)
            }
        }
    }

    @ViewBuilder
    private func systemDetailSection(for system: TimeBodySystem) -> some View {
        let detail = engine.bodySystemDetail(for: system.systemKey)

        VStack(alignment: .leading, spacing: 0) {
            // Section title
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(system.palette.surface)
                        .frame(width: 34, height: 34)
                    Image(systemName: detail.heroIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(system.palette.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(system.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(system.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(system.focusText)
                        .font(.system(size: 11))
                        .foregroundStyle(system.palette.accent.opacity(0.85))
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                Spacer()

                Text(system.progressLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(system.palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(system.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 22)

            // Science text (collapsible)
            CollapsibleTextBlock(
                title: "What's happening",
                content: detail.scienceText,
                palette: system.palette
            )
            .padding(.horizontal, 22)
            .padding(.top, 14)

            // Timeline text (collapsible)
            CollapsibleTextBlock(
                title: "Typical timeline",
                content: detail.timelineText,
                palette: system.palette
            )
            .padding(.horizontal, 22)
            .padding(.top, 10)

            // What to expect (collapsible)
            CollapsibleTextBlock(
                title: "What to expect",
                content: detail.whatToExpect,
                palette: system.palette
            )
            .padding(.horizontal, 22)
            .padding(.top, 10)

            // Maintenance note (T5+)
            if let note = detail.maintenanceNote, tier >= .t5Settled {
                CollapsibleTextBlock(
                    title: "Long-term maintenance",
                    content: note,
                    palette: system.palette
                )
                .padding(.horizontal, 22)
                .padding(.top, 10)
            }

            // Deepening note (T4)
            if let note = detail.deepeningNote, tier == .t4Deepening {
                CollapsibleTextBlock(
                    title: "Where you are now",
                    content: note,
                    palette: system.palette
                )
                .padding(.horizontal, 22)
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Regimen Timeline

    private var regimenTimelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REGIMEN TIMELINE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text(regimenTimelineText)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.card)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    private var regimenTimelineText: String {
        let df = AppDateFormatters.monthDay
        return engine.regimenSegments.map { segment in
            let start = df.string(from: segment.startDate)
            let end = segment.endDate.map { df.string(from: $0) } ?? "Present"
            let concInfo = segment.concentrationMgPerMl.map { " @ \(AppNumberFormatters.concentration.string($0)) mg/mL" } ?? ""
            return "\(start) – \(end): \(segment.ester) \(AppNumberFormatters.dose.string(segment.doseAmount)) mg\(concInfo)"
        }.joined(separator: "\n")
    }

    // MARK: - Dose Intensity Note

    private func doseIntensityNote(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary.opacity(0.6))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .lineSpacing(2)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Collapsible Text Block

private struct CollapsibleTextBlock: View {
    let title: String
    let content: String
    let palette: TimeContentPalette

    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    private let collapsedHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(content)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .lineLimit(isExpanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.25), value: isExpanded)

            if !isExpanded && content.count > 200 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded = true
                    }
                } label: {
                    Text("Read more")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Body Silhouette Canvas

private struct ArchitectureBodyCanvas: View {
    let months: Int
    let isEstrogen: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.04))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.96))
                }
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                if isEstrogen {
                    DynamicBodySilhouette(elapsedMonths: Double(months))
                        .fill(Theme.Colors.Time.body.base.opacity(0.08))

                    DynamicBodySilhouette(elapsedMonths: Double(months))
                        .stroke(Theme.Colors.Time.body.base.opacity(0.6), lineWidth: 1.2)
                        .shadow(color: Theme.Colors.Time.body.base.opacity(0.25), radius: 8)
                } else {
                    DynamicBodySilhouetteT(elapsedMonths: Double(months))
                        .fill(Theme.Colors.Time.body.base.opacity(0.08))

                    DynamicBodySilhouetteT(elapsedMonths: Double(months))
                        .stroke(Theme.Colors.Time.body.base.opacity(0.6), lineWidth: 1.2)
                        .shadow(color: Theme.Colors.Time.body.base.opacity(0.25), radius: 8)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        BodyArchitectureDetailView(engine: TimeContentEngine(
            medication: "Estrogen",
            method: "Injectable",
            months: 6,
            currentLevel: 150,
            dayOfCycle: 3,
            activeMonthsOnHRT: 6,
            ageAtStart: 28,
            screeningLog: nil,
            showDoseIntensity: false,
            adherenceRate: 0.85,
            cyclePosition: .midCycle,
            regimenSegments: [],
            onTimeStreak: 4,
            relativeDoseIntensity: 1.0,
            doseIntensityNote: nil,
            bloodTestSchedulingText: "Schedule your next blood test around month 12.",
            suggestedBloodTestMonth: 12
        ))
    }
}
#endif
