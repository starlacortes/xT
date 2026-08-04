//
//  TimeView.swift
//  xT
//
//  iOS 27 redesign — the Time screen is now two large, tappable constellations:
//  "Mind" (brain point-cloud) and "Body" (silhouette point-cloud), promoted from
//  the detail screens to the top level. A peeking "Up Next" drawer sits at the
//  bottom showing only an up-chevron; pulling it up slides it in while the Mind
//  and Body sections lift, shrink, and blur away on a staggered cascade.
//
//  Mirrors Figma `xt-time-screen-ios27`. Honors Reduce Motion (the cascade
//  degrades to a cross-fade; the constellations freeze via ConstellationView).
//

import SwiftUI

struct TimeView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Constellation fields — generated once, regenerated only when months change.
    @State private var brainField: ConstellationField = .empty
    @State private var bodyField: ConstellationField = .empty

    // "Up Next" drawer state.
    @State private var isUpNextOpen = false
    @State private var dragTranslation: CGFloat = 0

    // Tier milestone celebration.
    @AppStorage("lastSeenTierRawValue") private var lastSeenTierRawValue: String = ""
    @State private var showingTierCelebration = false
    @State private var celebrationTier: TenureTier? = nil

    private let peekHeight: CGFloat = 54

    /// The content model for this screen, derived from the manager's published state.
    ///
    /// This used to memoize into an `@State` property, assigning to it from inside a
    /// computed property that `body` reads — a write to view state during the view update
    /// pass, which SwiftUI flags as "Modifying state during view update" and which can
    /// invalidate the view it is being read from. The cache also bought nothing:
    /// `TimeContentEngine` is a struct of stored `let`s, so building one only copies its
    /// fields, and the expensive parts (`bodySystems`, `upcomingMilestones`,
    /// `unlockedChanges`) are computed properties that re-ran on every access whether or
    /// not the instance was reused.
    private var engine: TimeContentEngine {
        let cycleDay: Int = {
            guard let last = medicationManager.lastDoseDate,
                  let methodStr = medicationManager.selectedAdministrationMethod,
                  let adm = MedicationManager.AdministrationMethod(rawValue: methodStr) else { return 1 }
            let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return (elapsed % adm.frequencyDays) + 1
        }()
        return TimeContentEngine(
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
            doseIntensityNote: medicationManager.doseIntensityNote,
            bloodTestSchedulingText: medicationManager.bloodTestSchedulingText,
            suggestedBloodTestMonth: medicationManager.suggestedBloodTestMonth
        )
    }

    private var cloudMonths: Int { engine.activeMonthsOnHRT }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let drawerHeight = geo.size.height * 0.9
                let travel = max(drawerHeight - peekHeight, 1)
                let progress = drawerProgress(travel: travel)

                // Staggered cascade — Mind leads (blurs early, small lift);
                // Body holds sharp a touch longer, then travels much further.
                let mindP = smoothstep(clampUnit(progress / 0.75))
                let bodyP = smoothstep(clampUnit((progress - 0.12) / 0.75))

                ZStack(alignment: .bottom) {
                    Color(.systemBackground).ignoresSafeArea()

                    mainContent(mindP: mindP, bodyP: bodyP)
                        .padding(.bottom, peekHeight)
                        .allowsHitTesting(progress < 0.5)

                    TimeUpNextDrawer(
                        milestones: engine.upcomingMilestones,
                        sectionLabel: engine.milestonesSectionLabel,
                        isOpen: isUpNextOpen,
                        onToggle: toggleUpNext
                    )
                    .frame(height: drawerHeight)
                    .offset(y: travel * CGFloat(1 - progress))
                    .gesture(drawerDrag(travel: travel))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationDestination(for: BodySystemKey.self) { key in
                switch key {
                case .moodAndMind:
                    MoodMindDetailView(engine: engine)
                case .bodyShape:
                    BodyArchitectureDetailView(engine: engine)
                default:
                    if let system = engine.bodySystems.first(where: { $0.systemKey == key }) {
                        TimeBodyDetailView(system: system, engine: engine)
                    }
                }
            }
            .onAppear {
                medicationManager.refreshState()
                regenerateFieldsIfNeeded()
                checkForTierTransition()
            }
        }
        // `engine` is derived fresh from the manager, so a recorded dose only needs the
        // manager's own state refreshed — there is no view-side cache left to invalidate.
        .onChange(of: medicationManager.doseRecordedCount) { _, _ in
            medicationManager.refreshState()
        }
        .onChange(of: cloudMonths) { _, _ in
            brainField = ConstellationCloud.brain(months: cloudMonths)
            bodyField = ConstellationCloud.body(months: cloudMonths, medication: engine.medication)
        }
        .onChange(of: engine.tenureTier) { old, new in
            if new > old {
                withAnimation(Theme.Motion.entrance) {
                    celebrationTier = new
                    showingTierCelebration = true
                }
                lastSeenTierRawValue = new.rawValue
            }
        }
        .overlay {
            if showingTierCelebration, let tier = celebrationTier {
                TierCelebrationOverlay(tier: tier) {
                    withAnimation(Theme.Motion.snappy) {
                        showingTierCelebration = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Main content (Header + Mind + Body)

    @ViewBuilder
    private func mainContent(mindP: Double, bodyP: Double) -> some View {
        let secondarySystems = engine.bodySystems.filter {
            $0.systemKey != .moodAndMind && $0.systemKey != .bodyShape
        }
        VStack(spacing: 0) {
            TimeHeroHeader(engine: engine)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 6)
                .entrance(delay: 0)

            NavigationLink(value: BodySystemKey.moodAndMind) {
                TimeConstellationSection(
                    title: "Mind",
                    field: brainField,
                    tint: Theme.Colors.Time.mind.base,
                    secondaryTint: Theme.Colors.Time.cycle.base,
                    months: cloudMonths,
                    medication: engine.medication
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Mind stays present as a heavily-blurred frost behind the drawer.
            .modifier(CascadeDismiss(progress: mindP, maxBlur: 22, maxLift: 50,
                                     minScale: 0.5, minOpacity: 0.4, reduceMotion: reduceMotion))
            .entrance(delay: 0.08)

            NavigationLink(value: BodySystemKey.bodyShape) {
                TimeConstellationSection(
                    title: "Body",
                    field: bodyField,
                    tint: Theme.Colors.Time.body.base,
                    secondaryTint: nil,
                    months: cloudMonths,
                    medication: engine.medication
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Body recedes further, dropping to a lower resting opacity.
            .modifier(CascadeDismiss(progress: bodyP, maxBlur: 16, maxLift: 180,
                                     minScale: 0.55, minOpacity: 0.15, reduceMotion: reduceMotion))
            .entrance(delay: 0.16)

            if !secondarySystems.isEmpty {
                TimeSystemsStrip(systems: secondarySystems)
                    .modifier(CascadeDismiss(progress: bodyP, maxBlur: 16, maxLift: 180,
                                             minScale: 0.55, minOpacity: 0.15, reduceMotion: reduceMotion))
                    .entrance(delay: 0.22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Up Next interaction

    /// Effective drawer progress: 0 = peeking, 1 = fully open. Combines the
    /// settled open/closed state with the live drag offset.
    private func drawerProgress(travel: CGFloat) -> Double {
        let base: Double = isUpNextOpen ? 1 : 0
        return clampUnit(base + Double(-dragTranslation / travel))
    }

    private func toggleUpNext() {
        withAnimation(Theme.Motion.entrance) {
            isUpNextOpen.toggle()
            dragTranslation = 0
        }
    }

    private func drawerDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let projected = value.translation.height + value.predictedEndTranslation.height * 0.2
                let target = (isUpNextOpen ? 1.0 : 0.0) + Double(-projected / travel)
                withAnimation(Theme.Motion.entrance) {
                    isUpNextOpen = target > 0.5
                    dragTranslation = 0
                }
            }
    }

    private func regenerateFieldsIfNeeded() {
        if brainField.nodes.isEmpty { brainField = ConstellationCloud.brain(months: cloudMonths) }
        if bodyField.nodes.isEmpty { bodyField = ConstellationCloud.body(months: cloudMonths, medication: engine.medication) }
    }

    private func checkForTierTransition() {
        let current = engine.tenureTier
        defer { lastSeenTierRawValue = current.rawValue }
        guard !lastSeenTierRawValue.isEmpty,
              let stored = TenureTier(rawValue: lastSeenTierRawValue),
              current > stored else { return }
        withAnimation(Theme.Motion.entrance) {
            celebrationTier = current
            showingTierCelebration = true
        }
    }
}

// MARK: - Cascade dismiss modifier

/// Lifts, shrinks, blurs, and fades a section as the Up Next drawer rises.
/// `progress` is already remapped per-section for the staggered cascade.
private struct CascadeDismiss: ViewModifier {
    let progress: Double        // 0…1
    let maxBlur: CGFloat
    let maxLift: CGFloat
    let minScale: CGFloat
    let minOpacity: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            // No parallax/blur — a plain cross-fade instead.
            content.opacity(1 - progress * (1 - minOpacity))
        } else {
            content
                .blur(radius: maxBlur * CGFloat(progress))
                .scaleEffect(1 - (1 - minScale) * CGFloat(progress), anchor: .top)
                .offset(y: -maxLift * CGFloat(progress))
                .opacity(1 - (1 - minOpacity) * progress)
        }
    }
}

private func clampUnit(_ x: Double) -> Double { min(max(x, 0), 1) }

/// Smootherstep easing for a softer cascade ramp.
private func smoothstep(_ x: Double) -> Double {
    let t = clampUnit(x)
    return t * t * (3 - 2 * t)
}

// MARK: - Hero Header (compact one-liner)

struct TimeHeroHeader: View {
    let engine: TimeContentEngine

    private var esterLabel: String {
        engine.method.contains("Injectable") ? "Injectable" : engine.method
    }

    private var adherenceColor: Color {
        guard let rate = engine.adherenceRate else { return .secondary }
        return rate >= 0.8 ? .green : rate >= 0.5 ? .yellow : .red.opacity(0.7)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: AppNumberFormatters.percent.string(engine.months))
                .font(.system(size: 42, weight: .bold))
                .tracking(-1.5)
                .foregroundStyle(Color.primary)

            Text("Months")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.secondary)

            Spacer(minLength: 12)

            // Regimen + live adherence, on the same baseline.
            HStack(spacing: 6) {
                Text("\(esterLabel) · \(engine.medication)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)

                if let rate = engine.adherenceRate {
                    Circle()
                        .fill(adherenceColor)
                        .frame(width: 7, height: 7)
                    Text(verbatim: "\(AppNumberFormatters.percent.string(rate * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Constellation Section (large, tappable "Mind" / "Body")

struct TimeConstellationSection: View {
    let title: String
    let field: ConstellationField
    let tint: Color
    var secondaryTint: Color? = nil
    let months: Int
    let medication: String

    var body: some View {
        ConstellationView(
            field: field,
            tint: tint,
            secondaryTint: secondaryTint,
            regionActivity: { ConstellationCloud.activity(regionKey: $0, months: months, medication: medication) }
        )
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .tracking(-1)
                .foregroundStyle(tint)
                .padding(.leading, 22)
                .padding(.top, 2)
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .padding(.trailing, 18)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Up Next Drawer

struct TimeUpNextDrawer: View {
    let milestones: [TimeMilestone]
    let sectionLabel: String
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Grabber / header — the only part visible when peeking.
            Button(action: onToggle) {
                VStack(spacing: 5) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text(isOpen ? sectionLabel : "Up Next")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Color.secondary)
                        .tracking(0.5)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        TimeMilestoneRow(milestone: milestone)
                            .entrance(index: index)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Clear panel — the blurred Mind/Body behind supplies the frosted backdrop.
        .contentShape(Rectangle())
    }
}

// MARK: - Milestone Row (reused inside the Up Next drawer)

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
        .contentShape(Rectangle())
    }

    private func sfSymbol(for name: String) -> String {
        switch name {
        case "clock":     return "clock"
        case "test-pipe": return "flask"
        default:          return "star"
        }
    }
}

// MARK: - Secondary Systems Strip

struct TimeSystemsStrip: View {
    let systems: [TimeBodySystem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(systems) { system in
                    NavigationLink(value: system.systemKey) {
                        TimeSystemChip(system: system)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
        .frame(height: 64)
    }
}

struct TimeSystemChip: View {
    let system: TimeBodySystem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: system.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(system.palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(system.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(system.progressLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(system.palette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(system.palette.accent.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Tier Celebration Overlay

struct TierCelebrationOverlay: View {
    let tier: TenureTier
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(tierColor)

                VStack(spacing: 6) {
                    Text("MILESTONE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Text(tier.timeBandLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }

                Button("Continue") { onDismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tierColor)
                    .padding(.top, 4)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(tierColor.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, 44)
            .shadow(color: tierColor.opacity(0.15), radius: 30)
        }
    }

    private var tierColor: Color {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion: return .blue
        case .t4Deepening: return .green
        case .t5Settled:   return .purple
        case .t6Rooted:    return .indigo
        case .t7Veteran:   return .orange
        }
    }

    private var subtitle: String {
        switch tier {
        case .t1Beginning: return "Your body is beginning to adapt to HRT."
        case .t2Emerging:  return "First changes are starting to emerge."
        case .t3InMotion:  return "This is the most active phase of change."
        case .t4Deepening: return "Changes continue to deepen and settle."
        case .t5Settled:   return "Changes are largely settled. You've reached a new baseline."
        case .t6Rooted:    return "Five years on HRT — an established part of your health."
        case .t7Veteran:   return "Ten years. A milestone worth acknowledging."
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        TimeView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
