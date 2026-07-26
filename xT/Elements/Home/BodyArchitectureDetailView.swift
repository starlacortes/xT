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

    private var months: Int { engine.activeMonthsOnHRT }
    private var tier: TenureTier { engine.tenureTier }

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
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero
                    heroSection
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    // Body silhouette canvas + callout dots
                    bodySilhouetteSection
                        .frame(height: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Theme.Colors.Time.body.base.opacity(0.04))
                        )

                    Text("Tap a region to explore")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Stats row
                    BodySystemStatsRow(
                        stats: TimeBodyRegions.bodyStats(months: months),
                        accentColor: Theme.Colors.Time.body.base
                    )
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    KeyInsightBanner(
                        text: TimeBodyRegions.bodyInsight(months: months),
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

                        ForEach(TimeBodyRegions.bodyRegions) { region in
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
                    }

                    // Other body system sections (Skin, Cycle, etc.)
                    otherBodySystemsSections

                    // Regimen timeline
                    if !engine.regimenSegments.isEmpty && engine.regimenSegments.count > 1 {
                        regimenTimelineSection
                            .padding(.horizontal, 22)
                            .padding(.top, 24)
                    }

                    // Dose intensity disclaimer
                    if let disclaimer = engine.doseIntensityDisclaimer {
                        doseIntensityNote(disclaimer)
                            .padding(.horizontal, 22)
                            .padding(.top, 16)
                    }

                    Color.clear.frame(height: 40)
                }
            }
        }
        .navigationTitle("Body Architecture")
        .navigationBarTitleDisplayMode(.inline)
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
                Text(tier.statusEmoji + " " + tier.timeBandLabel)
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

    // MARK: - Body Silhouette

    private var bodySilhouetteSection: some View {
        ZStack {
            // Animated silhouette
            ArchitectureBodyCanvas(months: months)
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
                title: "Your timeline",
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
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return engine.regimenSegments.map { segment in
            let start = df.string(from: segment.startDate)
            let end = segment.endDate.map { df.string(from: $0) } ?? "Present"
            let concInfo = segment.concentrationMgPerMl.map { " @ \(String(format: "%.0f", $0)) mg/mL" } ?? ""
            return "\(start) – \(end): \(segment.ester) \(String(format: "%.1f", segment.doseAmount)) mg\(concInfo)"
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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.04))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.96))
                }
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                DynamicBodySilhouette(elapsedMonths: Double(months))
                    .fill(Theme.Colors.Time.body.base.opacity(0.08))

                DynamicBodySilhouette(elapsedMonths: Double(months))
                    .stroke(Theme.Colors.Time.body.base.opacity(0.6), lineWidth: 1.2)
                    .shadow(color: Theme.Colors.Time.body.base.opacity(0.25), radius: 8)
            }
        }
    }
}

// MARK: - Preview

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
            doseIntensityDisclaimer: nil,
            bloodTestSchedulingText: "Schedule your next blood test around month 12.",
            suggestedBloodTestMonth: 12,
            calibrationContext: nil
        ))
    }
}
