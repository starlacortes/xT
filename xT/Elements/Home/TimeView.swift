//
//  TimeView.swift
//  xT
//
//  The Time screen is a single interactive whole-body 3-D diagram. The body
//  rests centred in theme-coloured skin with a slow idle rotation; tapping a
//  region fires the shared ripple, zooms the camera in while shifting the body
//  off the left edge, dissolves the skin into a constellation starfield, and
//  reveals that region's timeline/phase content. The head surfaces the "Mind"
//  content, dropping the model to the bottom of the screen.
//
//  A compact header (months on HRT + regimen + adherence) stays pinned at top.
//  Honors Reduce Motion (idle rotation and camera moves degrade to jump cuts;
//  the starfield freezes).
//

import SwiftUI

struct TimeView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.themeManager) private var themeManager

    // Tier milestone celebration.
    @AppStorage("lastSeenTierRawValue") private var lastSeenTierRawValue: String = ""
    @State private var showingTierCelebration = false
    @State private var celebrationTier: TenureTier? = nil

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
                checkForTierTransition()
            }
        }
        .onChange(of: medicationManager.doseRecordedCount) { _, _ in
            medicationManager.refreshState()
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
            Text(verbatim: AppNumberFormatters.months.string(engine.months))
                .font(.system(size: 42, weight: .bold))
                .tracking(-1.5)
                // The Time screen's backdrop is near-black in both appearances,
                // so the header uses explicit light text rather than adaptive.
                .foregroundStyle(Color.white)

            Text("Months")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))

            Spacer(minLength: 12)

            // Regimen + live adherence, on the same baseline.
            HStack(spacing: 6) {
                Text("\(esterLabel) · \(engine.medication)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)

                if let rate = engine.adherenceRate {
                    Circle()
                        .fill(adherenceColor)
                        .frame(width: 7, height: 7)
                    Text(verbatim: "\(AppNumberFormatters.percent.string(rate * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
