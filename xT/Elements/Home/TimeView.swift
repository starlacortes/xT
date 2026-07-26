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
    @State private var hasAnimatedAdherence = false
    @State private var cachedEngine: TimeContentEngine?
    @State private var lastDoseCount: Int = 0

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
                    TimeHeroHeader(
                        engine: engine,
                        doseCount: medicationManager.doseRecordedCount,
                        adherencePercent: adherencePercent
                    )
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

                    timeDivider()

                    TimePrimaryChoicesSection(engine: engine)
                        .entrance(delay: 0.08)

                    timeDivider()

                    // Milestones
                    TimeMilestonesSection(
                        milestones: engine.upcomingMilestones,
                        sectionLabel: engine.milestonesSectionLabel
                    )
                        .entrance(delay: 0.16)
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
            cachedEngine = nil
            medicationManager.refreshState()
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                adherencePercent = engine.adherenceRate ?? 0
            }
        }
    }

    private func timeDivider() -> some View {
        Divider().opacity(0.5)
    }
}

// MARK: - Hero Header (redesigned — tier label + large month + regimen subtitle)

struct TimeHeroHeader: View {
    let engine: TimeContentEngine
    let doseCount: Int
    let adherencePercent: CGFloat

    private var medicationSubtitle: String {
        let ester = engine.method.contains("Injectable") ? "Injectable" : engine.method
        return "\(engine.medication) · \(ester)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tier label row — with adherence indicator when available (3+ doses)
            HStack(spacing: 8) {
                Text(engine.tenureTier.statusEmoji + " " + engine.tenureTier.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accentSecondary)
                    .tracking(0.5)
                    .textCase(.uppercase)

                if let rate = engine.adherenceRate, doseCount >= 3 {
                    adherencePill(rate: rate)
                }

                Spacer()
            }

            // Large month number + unit
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(engine.months)")
                    .font(.system(size: 42, weight: .bold))
                    .tracking(-1.5)
                    .foregroundStyle(Color.primary)

                Text("Months")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }

            // Medication · method
            Text(medicationSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)

            // Anniversary marker for veterans
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func adherencePill(rate: Double) -> some View {
        let color: Color = rate >= 0.8 ? .green : rate >= 0.5 ? .yellow : .red.opacity(0.7)
        let label: String = {
            if engine.tenureTier >= .t5Settled && engine.onTimeStreak > 0 {
                return "\(engine.onTimeStreak)mo streak"
            }
            return "\(Int(rate * 100))% adherence"
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Primary Choices Section (Two-Choice Schema)

struct TimePrimaryChoicesSection: View {
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

            // Mood & Mind
            NavigationLink(value: BodySystemKey.moodAndMind) {
                TimePrimaryChoiceRow(
                    title: "Mood & Mind",
                    subtitle: mindSubtitle,
                    progressLabel: mindProgressLabel,
                    palette: .purple,
                    diagram: { isPressed in
                        ZStack {
                            BreathingGlowView(
                                color: Theme.Colors.Time.mind.base,
                                isPressed: isPressed,
                                duration: 3.0
                            )
                            .frame(width: 72, height: 72)

                            MiniMindDiagram(months: engine.activeMonthsOnHRT)
                                .frame(width: 90, height: 100)
                        }
                        .frame(width: 100, height: 110)
                    }
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
            .buttonStyle(.pressable)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 22)

            // Body Architecture
            NavigationLink(value: BodySystemKey.bodyShape) {
                TimePrimaryChoiceRow(
                    title: "Body Architecture",
                    subtitle: bodyArchitectureSubtitle,
                    progressLabel: bodyArchitectureProgressLabel,
                    palette: .amber,
                    diagram: { isPressed in
                        ZStack {
                            BreathingGlowView(
                                color: Theme.Colors.Time.body.base,
                                isPressed: isPressed,
                                duration: 3.5
                            )
                            .frame(width: 72, height: 72)

                            MiniBodySilhouette(months: engine.activeMonthsOnHRT)
                                .frame(width: 68, height: 86)

                            BodySilhouetteShimmer(months: engine.activeMonthsOnHRT,
                                                  isPressed: isPressed)
                                .frame(width: 68, height: 86)
                        }
                        .frame(width: 100, height: 110)
                    }
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
            .buttonStyle(.pressable)
        }
        .navigationDestination(for: BodySystemKey.self) { key in
            switch key {
            case .moodAndMind:
                if let system = engine.bodySystems.first(where: { $0.systemKey == .moodAndMind }) {
                    MoodMindDetailView(system: system, engine: engine)
                }
            case .bodyShape:
                BodyArchitectureDetailView(engine: engine)
            default:
                if let system = engine.bodySystems.first(where: { $0.systemKey == key }) {
                    TimeBodyDetailView(system: system, engine: engine)
                }
            }
        }
    }

    private var mindSubtitle: String {
        engine.bodySystems.first(where: { $0.systemKey == .moodAndMind })?.subtitle ?? "How hormones shape your emotions"
    }

    private var mindProgressLabel: String {
        engine.bodySystems.first(where: { $0.systemKey == .moodAndMind })?.progressLabel ?? ""
    }

    private var bodyArchitectureSubtitle: String {
        "Body, skin, cycle & changes"
    }

    private var bodyArchitectureProgressLabel: String {
        engine.bodySystems.first(where: { $0.systemKey == .bodyShape })?.progressLabel ?? ""
    }
}

// MARK: - Primary Choice Row

struct TimePrimaryChoiceRow<Diagram: View>: View {
    let title: String
    let subtitle: String
    let progressLabel: String
    let palette: TimeContentPalette
    @ViewBuilder let diagram: (Bool) -> Diagram

    @State private var isPressing = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            diagram(isPressing)
                .scaleEffect(isPressing ? 1.06 : 1.0)
                .animation(.easeOut(duration: 0.18), value: isPressing)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(.primary)
                    Spacer()
                    Circle()
                        .fill(palette.progress)
                        .frame(width: 6, height: 6)
                    Text(progressLabel)
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(isPressing ? 0.65 : 0.35))
                .offset(x: isPressing ? 4 : 0)
                .animation(.easeOut(duration: 0.18), value: isPressing)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressing = pressing
            }
        }, perform: {})
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

// MARK: - Breathing Glow

private struct BreathingGlowView: View {
    let color: Color
    let isPressed: Bool
    let duration: Double

    @State private var breathe = false

    var body: some View {
        Circle()
            .fill(color.opacity(breathe ? 0.22 : 0.09))
            .scaleEffect(breathe ? 1.18 : 0.82)
            .blur(radius: 24)
            .scaleEffect(isPressed ? 1.25 : 1.0)
            .opacity(isPressed ? 1.35 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}

// MARK: - Body Silhouette Shimmer

private struct BodySilhouetteShimmer: View {
    let months: Int
    let isPressed: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t * 2.2
            let opacity = 0.06 + 0.10 * abs(sin(phase))
            let boosted = isPressed ? opacity * 2.2 : opacity

            DynamicBodySilhouette(elapsedMonths: Double(months))
                .stroke(
                    Theme.Colors.Time.body.base.opacity(boosted),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
                .blur(radius: 1.8)
        }
        .drawingGroup()
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }
}

// MARK: - Preview

#Preview {
    SpoofPreview {
        TimeView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
