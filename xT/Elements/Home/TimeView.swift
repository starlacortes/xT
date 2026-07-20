//
//  TimeView.swift
//  xT
//
//  Flat Time layout — mirrors the home screen design language.
//  Hero header floats on the system background; sections separated
//  by hairline dividers instead of stacked colored cards.
//
//  Updated: tenure-aware personalization, tappable body system rows
//  that push to deep-dive detail pages, collapsible changes section
//  for mature users, and long-term health milestones at 24+ months.
//

import SwiftUI

struct TimeView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var adherencePercent: CGFloat = 0
    @State private var changesExpanded: Bool = false
    @State private var hasAnimatedAdherence = false
    @State private var cachedEngine: TimeContentEngine?
    @State private var lastDoseCount: Int = 0

    // Lightweight view-model: rebuilds only when observed dependencies change.
    // Reads from MedicationManager (which is @Observable-compatible via custom
    // EnvironmentKey) and caches the derived engine to avoid PK math on every body.
    private var engine: TimeContentEngine {
        if let cached = cachedEngine, cached.months == medicationManager.monthsOnHRT,
           cached.adherenceRate == medicationManager.adherenceRate,
           cached.currentLevel == medicationManager.currentHormoneLevel?.value,
           cached.cyclePosition == medicationManager.currentCyclePosition {
            return cached
        }
        let cycleDay: Int = {
            guard let last = medicationManager.lastDoseDate,
                  let methodStr = medicationManager.selectedAdministrationMethod,
                  let adm = MedicationManager.AdministrationMethod(rawValue: methodStr) else { return 1 }
            let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return (elapsed % adm.frequencyDays) + 1
        }()
        let newEngine = TimeContentEngine(
            medication: medicationManager.selectedMedication ?? "Estrogen",
            method: medicationManager.selectedAdministrationMethod ?? "Injectable",
            months: medicationManager.monthsOnHRT,
            currentLevel: medicationManager.currentHormoneLevel?.value,
            dayOfCycle: cycleDay,
            activeMonthsOnHRT: medicationManager.activeMonthsOnHRT,
            ageAtStart: medicationManager.ageAtHRTStart,
            screeningLog: medicationManager.screeningLog,
            showDoseIntensity: medicationManager.showDoseIntensityInsights,
            adherenceRate: medicationManager.adherenceRate,
            cyclePosition: medicationManager.currentCyclePosition,
            regimenSegments: medicationManager.regimenTransitionHistory,
            onTimeStreak: medicationManager.onTimeStreak,
            relativeDoseIntensity: medicationManager.relativeDoseIntensity,
            doseIntensityDisclaimer: medicationManager.doseIntensityDisclaimer,
            bloodTestSchedulingText: medicationManager.bloodTestSchedulingText,
            suggestedBloodTestMonth: medicationManager.suggestedBloodTestMonth,
            calibrationContext: nil
        )
        cachedEngine = newEngine
        return newEngine
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header (now includes adherence ring + cycle compass inline)
                    TimeHeroHeader(engine: engine, adherencePercent: $adherencePercent)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .entrance(delay: 0)
                        .onAppear {
                            guard !hasAnimatedAdherence else { return }
                            hasAnimatedAdherence = true
                            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                                adherencePercent = engine.adherenceRate ?? 0
                            }
                        }

                    if let insight = engine.hormoneInsight {
                        timeDivider()
                        TimeHormoneRow(insight: insight, medication: engine.medication, cyclePosition: engine.cyclePosition)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .entrance(delay: 0.08)
                    }

                    // Regimen Timeline Card (#3)
                    if !engine.regimenSegments.isEmpty && engine.regimenSegments.count > 1 {
                        timeDivider()
                        TimeRegimenTimelineRow(
                            segments: engine.regimenSegments,
                            tenureTier: engine.tenureTier,
                            months: engine.months
                        )
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .entrance(delay: 0.10)
                    }

                    // Changes section — ordered differently by tenure
                    // Early/established: changes BEFORE body systems
                    // Mature: changes AFTER body systems (collapsed)
                    if !engine.changesDefaultCollapsed {
                        timeDivider()
                        TimeChangesRow(
                            changes: engine.unlockedChanges,
                            sectionLabel: engine.changesSectionLabel,
                            summaryBadge: engine.changesSummaryBadge,
                            intensityDisclaimer: engine.doseIntensityDisclaimer
                        )
                        .padding(.vertical, 18)
                        .entrance(delay: 0.12)
                    }

                    // Body systems — tappable rows → detail pages
                    timeDivider()
                    TimeBodySection(engine: engine)
                        .entrance(delay: engine.changesDefaultCollapsed ? 0.12 : 0.16)

                    // Collapsed changes for mature users — after body systems
                    if engine.changesDefaultCollapsed {
                        timeDivider()
                        CollapsibleChangesRow(
                            changes: engine.unlockedChanges,
                            sectionLabel: engine.changesSectionLabel,
                            summaryBadge: engine.changesSummaryBadge,
                            intensityDisclaimer: engine.doseIntensityDisclaimer,
                            isExpanded: $changesExpanded
                        )
                        .padding(.vertical, 18)
                        .entrance(delay: 0.16)
                    }

                    // Milestones — tenure-aware label
                    timeDivider()
                    TimeMilestonesSection(
                        milestones: engine.upcomingMilestones,
                        sectionLabel: engine.milestonesSectionLabel
                    )
                        .entrance(delay: engine.changesDefaultCollapsed ? 0.20 : 0.20)
                        .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground).ignoresSafeArea())
            .onAppear {
                lastDoseCount = medicationManager.doseRecordedCount
                medicationManager.refreshState()
            }
        }
        .onChange(of: medicationManager.doseRecordedCount) { newCount in
            guard newCount > lastDoseCount else { return }
            lastDoseCount = newCount
            cachedEngine = nil  // force engine recompute
            medicationManager.refreshState()
            // Re-animate adherence ring
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                adherencePercent = engine.adherenceRate ?? 0
            }
        }
    }

    private func timeDivider() -> some View {
        Divider().opacity(0.5)
    }
}

// MARK: - Hero Header (now with adherence ring #2 + cycle compass #6)

struct TimeHeroHeader: View {
    let engine: TimeContentEngine
    @Binding var adherencePercent: CGFloat

    private var cleanTitle: String {
        engine.timelineTitle
            .replacingOccurrences(of: " ✦", with: "")
            .replacingOccurrences(of: "✦", with: "")
    }

    /// Color for the cycle compass ring based on level range (#6).
    private var cycleCompassColor: Color {
        guard let level = engine.currentLevel else { return Color.secondary.opacity(0.3) }
        if engine.medication == "Estrogen" {
            if level >= 100 && level <= 400 { return .green }
            if level >= 50 && level < 100 { return .yellow }
            if level > 400 && level <= 500 { return .yellow }
            return .red.opacity(0.6)
        } else {
            if level >= 300 && level <= 1000 { return .green }
            if level >= 100 && level < 300 { return .yellow }
            return .red.opacity(0.6)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Title block
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.timelineSubtitle)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Color.secondary)

                Text(cleanTitle)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: Theme.Gradients.brandColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 6) {
                    Text(engine.medication)
                    Text("·")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text(engine.method)
                }
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Color.secondary)

                // Anniversary marker for 10+ year veterans (plan §6.3)
                if engine.tenureTier >= .t7Veteran {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                        Text("A decade and counting")
                            .font(Theme.Fonts.caption2)
                    }
                    .foregroundStyle(Theme.Colors.Time.cycle.base)
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Right: Adherence ring + cycle compass stack
            VStack(spacing: 10) {
                // Adherence Ring (#2)
                if let rate = engine.adherenceRate {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 5)
                            .frame(width: 56, height: 56)
                        Circle()
                            .trim(from: 0, to: adherencePercent)
                            .stroke(
                                rate >= 0.8 ? Color.green : rate >= 0.5 ? Color.yellow : Color.red.opacity(0.7),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0), value: adherencePercent)
                        Text(adherenceLabelText(rate: rate, tier: engine.tenureTier, streak: engine.onTimeStreak))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primary)
                    }
                    Text(adherenceSubtitleLabel(tier: engine.tenureTier))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                }

                // Cycle Compass (#6) — dot color reflects optimal range
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(cycleCompassColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(cycleCompassColor)
                            .frame(width: 12, height: 12)
                    }
                    Text(cyclePositionLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cyclePositionLabel: String {
        switch engine.cyclePosition {
        case .nearPeak: return "Near Peak"
        case .midCycle: return "Mid-Cycle"
        case .trough:   return "Trough"
        case .unknown:  return ""
        }
    }

    /// Tier-aware text inside the adherence ring (plan §6.2).
    /// T1–T4: raw percent. T5+: streak count when available.
    private func adherenceLabelText(rate: Double, tier: TenureTier, streak: Int) -> String {
        if tier >= .t5Settled && streak > 0 {
            return "\(streak)mo"
        }
        return "\(Int(rate * 100))%"
    }

    /// Tier-aware label under the adherence ring.
    private func adherenceSubtitleLabel(tier: TenureTier) -> String {
        if tier >= .t7Veteran {
            return "Consistent"
        } else if tier >= .t5Settled {
            return "Streak"
        } else {
            return "Adherence"
        }
    }
}

// MARK: - Hormone Row (now with cycle position context #11)

struct TimeHormoneRow: View {
    let insight: TimeHormoneInsight
    let medication: String
    let cyclePosition: MedicationManager.CyclePosition

    private var positionBadge: String? {
        switch cyclePosition {
        case .nearPeak: return "Peak"
        case .midCycle: return "Mid"
        case .trough:   return "Trough"
        case .unknown:  return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HORMONE LEVELS")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(0.8)
                Spacer()
                HStack(spacing: 6) {
                    Text(insight.rangeLabel)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(insight.rangePalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(insight.rangePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    if let pos = positionBadge {
                        Text(pos)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                AnimatedCounter(value: insight.level)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                Text(insight.unit)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Color.secondary)
            }

            Text(insight.bodyDescription)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Changes Row (tenure-aware label + summary badge)

struct TimeChangesRow: View {
    let changes: [TimeChange]
    let sectionLabel: String
    let summaryBadge: String?
    let intensityDisclaimer: String?

    private var unlockedCount: Int { changes.filter(\.unlocked).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sectionLabel)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
                if let badge = summaryBadge {
                    Text(badge)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(changes) { change in
                        HStack(spacing: 5) {
                            Image(systemName: change.unlocked ? "checkmark" : "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(change.label)
                                .font(Theme.Fonts.caption2)
                                .fontWeight(.medium)
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
                .padding(.horizontal, 22)
                .padding(.vertical, 1)
            }

            // Dose intensity disclaimer (#13)
            if let disclaimer = intensityDisclaimer {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                    Text(disclaimer)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Collapsible Changes Row (mature users)

struct CollapsibleChangesRow: View {
    let changes: [TimeChange]
    let sectionLabel: String
    let summaryBadge: String?
    let intensityDisclaimer: String?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(sectionLabel)
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Color.secondary)
                        .tracking(0.5)
                    Spacer()
                    if let badge = summaryBadge {
                        Text(badge)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(changes) { change in
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(change.label)
                                        .font(Theme.Fonts.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(Theme.Colors.Time.cycle.base)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Theme.Colors.Time.cycle.surface)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 1)
                    }

                    if let disclaimer = intensityDisclaimer {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary.opacity(0.6))
                            Text(disclaimer)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Body Systems Section (Tappable Rows)

struct TimeBodySection: View {
    let engine: TimeContentEngine

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YOUR BODY")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            ForEach(engine.bodySystems) { system in
                NavigationLink(value: system.systemKey) {
                    TimeBodySystemRow(system: system, tenureTier: engine.tenureTier)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.pressable)
                if system.id != engine.bodySystems.last?.id {
                    Divider()
                        .opacity(0.5)
                        .padding(.horizontal, 22)
                }
            }
        }
        // Value-based navigation destination — maps BodySystemKey to detail view
        .navigationDestination(for: BodySystemKey.self) { key in
            if let system = engine.bodySystems.first(where: { $0.systemKey == key }) {
                TimeBodyDetailView(system: system, engine: engine)
            }
        }
    }
}

struct TimeBodySystemRow: View {
    let system: TimeBodySystem
    let tenureTier: TenureTier

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(system.palette.surface)
                    .frame(width: 38, height: 38)
                Image(systemName: sfSymbol(for: system.icon))
                    .font(.system(size: 16))
                    .foregroundStyle(system.palette.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(system.title)
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    // Status dot for ALL tiers (spec §3.4: progress bar removed entirely)
                    Circle()
                        .fill(system.palette.progress)
                        .frame(width: 6, height: 6)
                    Text(system.progressLabel)
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(system.subtitle)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
        .contentShape(Rectangle())
    }

    private func sfSymbol(for name: String) -> String {
        switch name {
        case "brain":              return "brain.head.profile"
        case "sparkles":           return "sparkles"
        case "body-scan":          return "figure.stand"
        case "heart-rate-monitor": return "waveform.path.ecg"
        case "microphone":         return "mic"
        case "test-pipe":          return "flask"
        case "clock":              return "clock"
        default:                   return "circle"
        }
    }
}

// MARK: - Milestones Section (tenure-aware label)

struct TimeMilestonesSection: View {
    let milestones: [TimeMilestone]
    let sectionLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(sectionLabel)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            VStack(spacing: 10) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    TimeMilestoneRow(milestone: milestone)
                        .entrance(index: index)
                }
            }
            .padding(.horizontal, 22)
        }
    }
}

struct TimeMilestoneRow: View {
    let milestone: TimeMilestone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 36, height: 36)
                Image(systemName: sfSymbol(for: milestone.icon))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(milestone.title)
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let badge = milestone.badge {
                        Text(badge)
                            .font(Theme.Fonts.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Text(milestone.description)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.card)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func sfSymbol(for name: String) -> String {
        switch name {
        case "clock":     return "clock"
        case "test-pipe": return "flask"
        default:          return "star"
        }
    }
}

// MARK: - Regimen Timeline Card (#3)

/// Static date formatter to avoid allocation on every render.
private let regimenDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "MMM d"
    return df
}()

struct TimeRegimenTimelineRow: View {
    let segments: [MedicationManager.RegimenSegment]
    let tenureTier: TenureTier
    let months: Int

    @State private var isExpanded = false

    /// T5+ get a compact summary; T1–T4 get the full list (plan §6.1).
    private var isCompacted: Bool { tenureTier >= .t5Settled }

    private var compactSummary: String {
        let segmentCount = segments.count
        let years = max(1, months / 12)
        return "\(segmentCount) regimen change\(segmentCount == 1 ? "" : "s") over \(years) year\(years == 1 ? "" : "s")"
    }

    private var fullText: String {
        return segments.map { segment in
            let start = regimenDateFormatter.string(from: segment.startDate)
            let end = segment.endDate.map { regimenDateFormatter.string(from: $0) } ?? "Present"
            let concInfo = segment.concentrationMgPerMl.map { " @ \(String(format: "%.0f", $0)) mg/mL" } ?? ""
            var line = "\(start) – \(end): \(segment.ester) \(String(format: "%.1f", segment.doseAmount)) mg\(concInfo)"
            if let prev = segment.previousConcentrationMgPerMl, let curr = segment.concentrationMgPerMl {
                line += "\n  Concentration changed: \(String(format: "%.0f", prev)) → \(String(format: "%.0f", curr)) mg/mL"
            }
            return line
        }.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REGIMEN TIMELINE")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
                if isCompacted {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Less" : "Details")
                                .font(Theme.Fonts.caption2)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                    }
                } else {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
            }

            if isCompacted && !isExpanded {
                Text(compactSummary)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color.primary.opacity(0.8))
            } else {
                Text(fullText)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
}

// MARK: - Preview

#Preview {
    TimeView()
        .environment(\.medicationManager, MedicationManager.shared)
}