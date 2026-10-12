//
//  TimeView.swift
//  xT
//
//  The Time screen is a single interactive whole-body 3-D diagram. The body
//  rests centred in theme-coloured skin with a slow idle rotation; tapping a
//  region fires the shared ripple, zooms the camera in and reframes the model
//  around the region's `framing` — lifted into the upper screen with the card
//  as a bottom strip for `.stage` regions, nudged left beside a narrow card
//  for `.profile` (thighs) — dissolves the skin into a constellation
//  starfield, and reveals that region's timeline/phase content.
//
//  A compact header (months on HRT + regimen + adherence) stays pinned at top.
//  Honors Reduce Motion (idle rotation and camera moves degrade to jump cuts;
//  the starfield freezes).
//

import SwiftUI

struct TimeView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.themeManager) private var themeManager

    /// The content model for this screen, derived fresh from the manager's state.
    private var engine: TimeContentEngine {
        // Effective interval (custom frequency when set, else method default) —
        // was `adm.frequencyDays`, which ignored custom schedules and could
        // render "Day 9 of 7".
        let frequency = medicationManager.effectiveFrequencyDays
        let cycleDay: Int = {
            guard let last = medicationManager.lastDoseDate else { return 1 }
            let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return (elapsed % frequency) + 1
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
            suggestedBloodTestMonth: medicationManager.suggestedBloodTestMonth,
            cycleLengthDays: frequency
        )
    }

    var body: some View {
        // One engine construction per body evaluation (header, tier onChange,
        // celebration check all read from it).
        let engine = self.engine

        NavigationStack {
            ZStack {
                NightSkyBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TimeHeroHeader(engine: engine)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                        .entrance(delay: 0)

                    TimeBodyExplorerView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                medicationManager.refreshState()
            }
        }
        // The Time tab is the one intentionally always-night surface: the
        // backdrop is near-black in both appearances, so everything inside
        // resolves dark — material, `.primary`/`.secondary` text — instead of
        // only the sheet and the region card, which forced it individually
        // before (T2). The tab bar is system-styled and adapts on its own.
        .environment(\.colorScheme, .dark)
        .onChange(of: medicationManager.doseRecordedCount) { _, _ in
            medicationManager.refreshState()
        }
    }
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

    /// The quiet tier milestone (T4): factual, in the mono eyebrow voice —
    /// "MONTH 12 · NEW CHAPTER UNLOCKED" — shown only on the first month of a
    /// new tier. Replaces the full-screen `TierCelebrationOverlay`; the first
    /// tier (month 0) is the start, not an unlock, so it never shows.
    private var milestoneLine: String? {
        let month = engine.activeMonthsOnHRT
        let tierStart: Int
        switch TenureTier(months: month) {
        case .t1Beginning: return nil
        case .t2Emerging:  tierStart = 3
        case .t3InMotion:  tierStart = 6
        case .t4Deepening:  tierStart = 12
        case .t5Settled:   tierStart = 24
        case .t6Rooted:    tierStart = 60
        case .t7Veteran:   tierStart = 120
        }
        guard month == tierStart else { return nil }
        return "MONTH \(month) · NEW CHAPTER UNLOCKED"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // `activeMonthsOnHRT`, not `months`. The region card computes every
                // phase, band and insight from the gap-aware count, and this header
                // sits directly above it — two different numbers for "how long have
                // I been doing this" on one screen is a bug, not a nuance.
                Text(verbatim: AppNumberFormatters.months.string(engine.activeMonthsOnHRT))
                    .font(Theme.Fonts.hero)
                    .tracking(-1.5)
                    // The Time screen's backdrop is near-black in both appearances,
                    // so the header uses explicit light text rather than adaptive.
                    .foregroundStyle(Color.white)

                Text("Months")
                    .font(Theme.Fonts.serifTitle)
                    .foregroundStyle(Color.white.opacity(0.65))

                Spacer(minLength: 12)

                // Regimen + live adherence, on the same baseline.
                HStack(spacing: 6) {
                    Text("\(esterLabel) · \(engine.medication)")
                        .font(Theme.Fonts.detail)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)

                    if let rate = engine.adherenceRate {
                        Circle()
                            .fill(adherenceColor)
                            .frame(width: 7, height: 7)
                        Text(verbatim: "\(AppNumberFormatters.percent.string(rate * 100))%")
                            .font(Theme.Fonts.detail.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
            }

            if let milestone = milestoneLine {
                Text(verbatim: milestone)
                    .font(Theme.Fonts.eyebrow)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
