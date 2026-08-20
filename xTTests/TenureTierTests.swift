//
//  TenureTierTests.swift
//  xTTests
//
//  Unit tests for TenureTier(months:) boundary correctness and
//  TimeContentEngine smoke tests at representative tenures.
//

import Testing
import Foundation
@testable import xT

// MARK: - TenureTier Boundary Tests

@Test("T1: month 0 maps to t1Beginning")
func t1Month0() {
    #expect(TenureTier(months: 0) == TenureTier.t1Beginning)
}

@Test("T1: month 2 maps to t1Beginning (upper bound)")
func t1Month2() {
    #expect(TenureTier(months: 2) == TenureTier.t1Beginning)
}

@Test("T2: month 3 maps to t2Emerging (lower bound)")
func t2Month3() {
    #expect(TenureTier(months: 3) == TenureTier.t2Emerging)
}

@Test("T2: month 5 maps to t2Emerging (upper bound)")
func t2Month5() {
    #expect(TenureTier(months: 5) == TenureTier.t2Emerging)
}

@Test("T3: month 6 maps to t3InMotion (lower bound)")
func t3Month6() {
    #expect(TenureTier(months: 6) == TenureTier.t3InMotion)
}

@Test("T3: month 11 maps to t3InMotion (upper bound)")
func t3Month11() {
    #expect(TenureTier(months: 11) == TenureTier.t3InMotion)
}

@Test("T4: month 12 maps to t4Deepening (lower bound)")
func t4Month12() {
    #expect(TenureTier(months: 12) == TenureTier.t4Deepening)
}

@Test("T4: month 23 maps to t4Deepening (upper bound)")
func t4Month23() {
    #expect(TenureTier(months: 23) == TenureTier.t4Deepening)
}

@Test("T5: month 24 maps to t5Settled (lower bound)")
func t5Month24() {
    #expect(TenureTier(months: 24) == TenureTier.t5Settled)
}

@Test("T5: month 59 maps to t5Settled (upper bound)")
func t5Month59() {
    #expect(TenureTier(months: 59) == TenureTier.t5Settled)
}

@Test("T6: month 60 maps to t6Rooted (lower bound)")
func t6Month60() {
    #expect(TenureTier(months: 60) == TenureTier.t6Rooted)
}

@Test("T6: month 119 maps to t6Rooted (upper bound)")
func t6Month119() {
    #expect(TenureTier(months: 119) == TenureTier.t6Rooted)
}

@Test("T7: month 120 maps to t7Veteran (lower bound)")
func t7Month120() {
    #expect(TenureTier(months: 120) == TenureTier.t7Veteran)
}

@Test("T7: month 240 maps to t7Veteran")
func t7Month240() {
    #expect(TenureTier(months: 240) == TenureTier.t7Veteran)
}

@Test("Negative months clamp to t1Beginning")
func negativeMonths() {
    #expect(TenureTier(months: -1) == TenureTier.t1Beginning)
    #expect(TenureTier(months: -100) == TenureTier.t1Beginning)
}

@Test("Tiers are ordered from beginning to veteran")
func tierOrdering() {
    let tiers = TenureTier.allCases
    for i in 1..<tiers.count {
        #expect(tiers[i - 1] < tiers[i], "Tier at index \(i - 1) should be < tier at \(i)")
    }
}

@Test("All 7 tiers have distinct time band labels")
func distinctTimeBandLabels() {
    // Tiers used to be distinguished by an emoji as well as a label. The emoji
    // was decorative and carried an implied verdict on the stage, so the label
    // is now the only identifier — which means it has to be unique.
    let labels = Set(TenureTier.allCases.map { $0.timeBandLabel })
    #expect(labels.count == 7)
}

@Test("Time band labels are non-empty for all tiers")
func timeBandLabelsNonEmpty() {
    for tier in TenureTier.allCases {
        #expect(!tier.timeBandLabel.isEmpty)
    }
}

// MARK: - TimeContentEngine Smoke Tests

/// Helper: builds a minimal engine for testing.
private func engine(
    medication: String = "Estrogen",
    months: Int,
    activeMonthsOnHRT: Int? = nil,
    method: String = "Injectable",
    currentLevel: Double? = 185,
    ageAtStart: Int? = nil
) -> TimeContentEngine {
    TimeContentEngine(
        medication: medication,
        method: method,
        months: months,
        currentLevel: currentLevel,
        dayOfCycle: 3,
        activeMonthsOnHRT: activeMonthsOnHRT ?? months,
        ageAtStart: ageAtStart,
        screeningLog: nil,
        showDoseIntensity: false,
        adherenceRate: 0.92,
        cyclePosition: MedicationManager.CyclePosition.midCycle,
        regimenSegments: [],
        onTimeStreak: 4,
        relativeDoseIntensity: 1.0,
        doseIntensityNote: nil,
        bloodTestSchedulingText: "Schedule your next blood test around month 9.",
        suggestedBloodTestMonth: 9,
        cycleLengthDays: 7
    )
}

// --- Tier assignment at representative tenures ---

@Test("Engine at 0 months -> T1 Beginning")
func engineMonth0() {
    let e = engine(months: 0)
    #expect(e.tenureTier == TenureTier.t1Beginning)
    #expect(e.timelineTitle.contains("Month 0"))
    #expect(e.timelineSubtitle.contains("Month 0"))
}

@Test("Engine at 5 months -> T2 Emerging")
func engineMonth5() {
    let e = engine(months: 5)
    #expect(e.tenureTier == TenureTier.t2Emerging)
    #expect(e.timelineTitle.contains("Month 3"))
}

@Test("Engine at 9 months -> T3 InMotion")
func engineMonth9() {
    let e = engine(months: 9)
    #expect(e.tenureTier == TenureTier.t3InMotion)
    #expect(e.timelineTitle.contains("Month 6"))
}

@Test("Engine at 18 months -> T4 Deepening")
func engineMonth18() {
    let e = engine(months: 18)
    #expect(e.tenureTier == TenureTier.t4Deepening)
    #expect(e.timelineTitle.contains("Year 1"))
}

@Test("Engine at 42 months -> T5 Settled")
func engineMonth42() {
    let e = engine(months: 42)
    #expect(e.tenureTier == TenureTier.t5Settled)
    #expect(e.timelineTitle.contains("Year 2"))
    #expect(e.milestonesSectionLabel == "LONG-TERM HEALTH")
}

@Test("Engine at 70 months -> T6 Rooted")
func engineMonth70() {
    let e = engine(months: 70)
    #expect(e.tenureTier == TenureTier.t6Rooted)
    #expect(e.timelineTitle.contains("Year 5"))
}

@Test("Engine at 130 months -> T7 Veteran")
func engineMonth130() {
    let e = engine(months: 130)
    #expect(e.tenureTier == TenureTier.t7Veteran)
    #expect(e.timelineTitle.contains("10+ years"))
}

// --- Gap-aware tiering ---

@Test("activeMonthsOnHRT drives tiering, not calendar months")
func gapAwareTiering() {
    let e = engine(months: 50, activeMonthsOnHRT: 18)
    #expect(e.tenureTier == TenureTier.t4Deepening)
}

// --- Subtitle formatting ---

@Test("Subtitle contains medication, method, and month count")
func subtitleFormatting() {
    let e = engine(months: 18)
    let sub = e.timelineSubtitle
    #expect(sub.contains("Estrogen"))
    #expect(sub.contains("Injectable"))
    #expect(sub.contains("Month 18"))
}

// --- Changes section ---

@Test("T1-T4 changes section expands; T5+ collapses by default")
func changesCollapse() {
    #expect(engine(months: 3).changesDefaultCollapsed == false)
    #expect(engine(months: 8).changesDefaultCollapsed == false)
    #expect(engine(months: 18).changesDefaultCollapsed == false)
    #expect(engine(months: 24).changesDefaultCollapsed == true)
    #expect(engine(months: 70).changesDefaultCollapsed == true)
    #expect(engine(months: 130).changesDefaultCollapsed == true)
}

@Test("T6 produces single-item 'All established' change list")
func t6ChangesSingleItem() {
    let e = engine(months: 70)
    #expect(e.unlockedChanges.count == 1)
    #expect(e.unlockedChanges[0].label.contains("fully established"))
}

@Test("T7 produces retrospective summary change list")
func t7ChangesRetrospective() {
    let e = engine(months: 130)
    #expect(e.unlockedChanges.count == 1)
    #expect(e.unlockedChanges[0].label.contains("changes over"))
}

// --- Milestones ---

@Test("T1-T4 milestones section label is 'COMING UP'")
func earlyMilestonesLabel() {
    #expect(engine(months: 8).milestonesSectionLabel == "COMING UP")
    #expect(engine(months: 18).milestonesSectionLabel == "COMING UP")
}

@Test("T5-T7 milestones section label is 'LONG-TERM HEALTH'")
func matureMilestonesLabel() {
    #expect(engine(months: 42).milestonesSectionLabel == "LONG-TERM HEALTH")
    #expect(engine(months: 130).milestonesSectionLabel == "LONG-TERM HEALTH")
}

@Test("T5 milestones include DEXA and breast screening")
func t5MilestoneTypes() {
    let e = engine(months: 42)
    let titles = e.upcomingMilestones.map(\.title)
    #expect(titles.contains(where: { $0.contains("Bone density") }))
    #expect(titles.contains(where: { $0.contains("Breast health") }))
}

@Test("T6 milestones include 5-year reassessment")
func t6MilestoneTypes() {
    let e = engine(months: 70)
    let titles = e.upcomingMilestones.map(\.title)
    #expect(titles.contains(where: { $0.contains("5-year") }))
}

@Test("T7 milestones include 10-year review and anniversary")
func t7MilestoneTypes() {
    let e = engine(months: 130)
    let titles = e.upcomingMilestones.map(\.title)
    #expect(titles.contains(where: { $0.contains("10-year") }))
    #expect(titles.contains(where: { $0.contains("Anniversary") }))
}

@Test("T7 anniversary milestone badge names the milestone")
func t7AnniversaryBadge() {
    let e = engine(months: 130)
    let anniversary = e.upcomingMilestones.first(where: { $0.title.contains("Anniversary") })
    #expect(anniversary != nil)
    // The badge names the milestone rather than instructing the user to feel
    // something about it — see EducationalFooter / the tone pass.
    #expect(anniversary?.badge == "10 years")
}

// --- Body system detail — does not crash ---

@Test("Body system detail does not crash at any tier (Estrogen)")
func bodyDetailNoCrashEstrogen() {
    for months in [0, 5, 9, 18, 42, 70, 130] {
        let e = engine(medication: "Estrogen", months: months)
        for key: BodySystemKey in [.moodAndMind, .skinAndGlow, .bodyShape, .yourCycle] {
            let detail = e.bodySystemDetail(for: key)
            #expect(!detail.title.isEmpty)
            #expect(!detail.scienceText.isEmpty)
            #expect(!detail.timelineText.isEmpty)
            #expect(!detail.whatToExpect.isEmpty)
        }
    }
}

@Test("Body system detail does not crash at any tier (Testosterone)")
func bodyDetailNoCrashTestosterone() {
    for months in [0, 5, 9, 18, 42, 70, 130] {
        let e = engine(medication: "Testosterone", months: months)
        for key: BodySystemKey in [.voice, .skinAndHair, .muscleStrength, .yourCycle] {
            let detail = e.bodySystemDetail(for: key)
            #expect(!detail.title.isEmpty)
            #expect(!detail.scienceText.isEmpty)
            #expect(!detail.timelineText.isEmpty)
            #expect(!detail.whatToExpect.isEmpty)
        }
    }
}

// --- Screening log integration ---

@Test("lastScreening returns nil when screeningLog is nil")
func lastScreeningNil() {
    let e = engine(months: 42)
    #expect(e.lastScreening(.dexaScan) == nil)
}

@Test("screening badge shows 'Done' when record exists")
func screeningBadgeDone() {
    let now = Date()
    let e = TimeContentEngine(
        medication: "Estrogen", method: "Injectable",
        months: 42, currentLevel: 200, dayOfCycle: 3,
        activeMonthsOnHRT: 42, ageAtStart: 30,
        screeningLog: [ScreeningType.dexaScan: now], showDoseIntensity: false,
        adherenceRate: 0.9,
        cyclePosition: MedicationManager.CyclePosition.midCycle,
        regimenSegments: [], onTimeStreak: 10,
        relativeDoseIntensity: 1.0, doseIntensityNote: nil,
        bloodTestSchedulingText: "test", suggestedBloodTestMonth: 12,
        cycleLengthDays: 7
    )
    let milestones = e.upcomingMilestones
    let dexa = milestones.first(where: { $0.title.contains("Bone density") })
    #expect(dexa != nil)
    #expect(dexa?.badge?.contains("Done") == true)
}

// MARK: - Gap-aware consistency regression

@Test("Gap-aware: hormoneInsight uses tenureTier, not calendar months")
func gapAwareHormoneInsight() {
    // Calendar months=50 (T5 → established baseline) but only 10 active months (T3 → no baseline).
    // Before fix, estrogenInsight re-derived TenureTier(months: 50) → hasEstablishedBaseline = true.
    // After fix, it uses tenureTier (T3) → hasEstablishedBaseline = false.
    let e = engine(medication: "Estrogen", months: 50, activeMonthsOnHRT: 10, currentLevel: 150)
    #expect(e.tenureTier == TenureTier.t3InMotion)
    let insight = e.hormoneInsight
    // T3 → newer-user copy mentions "therapeutic range" context, not "established therapy".
    #expect(insight?.bodyDescription.contains("established estrogen therapy") == false)
    #expect(insight?.bodyDescription.contains("hormone therapy aims for") == true)
}

@Test("Gap-aware: muscle progressLabel uses active months, not calendar months")
func gapAwareMuscleLabel() {
    // Calendar 7 months (>= 6 → "Growing") but only 3 active months (< 6 → "Building").
    let e = engine(medication: "Testosterone", months: 7, activeMonthsOnHRT: 3)
    let muscle = e.bodySystems.first(where: { $0.systemKey == .muscleStrength })
    #expect(muscle?.progressLabel == "Building")
}

@Test("Gap-aware: T7 retrospective names active months, not calendar months")
func gapAwareT7Retrospective() {
    // Calendar 130 months (T7) but 130 active months too; just verify the label uses active count.
    let e = engine(months: 200, activeMonthsOnHRT: 130)
    #expect(e.tenureTier == TenureTier.t7Veteran)
    let changes = e.unlockedChanges
    #expect(changes.count == 1)
    #expect(changes[0].label.contains("130 months"))
    #expect(!changes[0].label.contains("200 months"))
}

// MARK: - Phase 2: Region overview coverage

@Test("All E mind regions have non-empty overviews")
func eMindRegionOverviews() {
    for region in TimeBodyRegions.mindRegions {
        #expect(!region.overview.isEmpty, "E mind region '\(region.key)' has empty overview")
    }
}

@Test("All E body regions have non-empty overviews")
func eBodyRegionOverviews() {
    for region in TimeBodyRegions.bodyRegions {
        #expect(!region.overview.isEmpty, "E body region '\(region.key)' has empty overview")
    }
}

@Test("All T mind regions have non-empty overviews")
func tMindRegionOverviews() {
    for region in TimeBodyRegions.mindRegionsT {
        #expect(!region.overview.isEmpty, "T mind region '\(region.key)' has empty overview")
    }
}

@Test("All T body regions have non-empty overviews")
func tBodyRegionOverviews() {
    for region in TimeBodyRegions.bodyRegionsT {
        #expect(!region.overview.isEmpty, "T body region '\(region.key)' has empty overview")
    }
}

// MARK: - Phase 5: Fact coverage (focusText ?? phaseText non-nil and non-empty)

@Test("E mind regions: focusText ?? phaseText non-empty at every month 0-240")
func eMindFactCoverage() {
    for region in TimeBodyRegions.mindRegions {
        for month in stride(from: 0, through: 240, by: 1) {
            let text = region.focusText(at: month) ?? region.phaseText(at: month)
            #expect(!text.isEmpty, "E mind '\(region.key)' empty at month \(month)")
        }
    }
}

@Test("E body regions: focusText ?? phaseText non-empty at every month 0-240")
func eBodyFactCoverage() {
    for region in TimeBodyRegions.bodyRegions {
        for month in stride(from: 0, through: 240, by: 1) {
            let text = region.focusText(at: month) ?? region.phaseText(at: month)
            #expect(!text.isEmpty, "E body '\(region.key)' empty at month \(month)")
        }
    }
}

@Test("T mind regions: focusText ?? phaseText non-empty at every month 0-240")
func tMindFactCoverage() {
    for region in TimeBodyRegions.mindRegionsT {
        for month in stride(from: 0, through: 240, by: 1) {
            let text = region.focusText(at: month) ?? region.phaseText(at: month)
            #expect(!text.isEmpty, "T mind '\(region.key)' empty at month \(month)")
        }
    }
}

@Test("T body regions: focusText ?? phaseText non-empty at every month 0-240")
func tBodyFactCoverage() {
    for region in TimeBodyRegions.bodyRegionsT {
        for month in stride(from: 0, through: 240, by: 1) {
            let text = region.focusText(at: month) ?? region.phaseText(at: month)
            #expect(!text.isEmpty, "T body '\(region.key)' empty at month \(month)")
        }
    }
}

@Test("focusText bands are distinct across months in the same region (E hips)")
func distinctFocusBandsEHips() {
    let hips = TimeBodyRegions.bodyRegions.first { $0.key == "hips" }!
    // Sample representative months from different bands and assert distinct text.
    let samples = [6, 15, 25, 42, 65, 84, 110, 150, 200]
    let texts = samples.map { hips.focusText(at: $0) ?? hips.phaseText(at: $0) }
    // No two adjacent samples should produce identical copy.
    for i in 1..<texts.count {
        #expect(texts[i] != texts[i - 1],
                "Months \(samples[i - 1]) and \(samples[i]) share identical focus text")
    }
}

// MARK: - Phase 3 & 4: Detail reachability

@Test("E mind (head) resolves bodySystemKey → moodAndMind")
func detailReachabilityEMind() {
    let e = engine(medication: "Estrogen", months: 18)
    let detail = e.bodySystemDetail(for: .moodAndMind)
    #expect(!detail.title.isEmpty)
    #expect(!detail.timelineText.isEmpty)
    #expect(!detail.whatToExpect.isEmpty)
}

@Test("E hips resolves bodySystemKey → bodyShape")
func detailReachabilityEHips() {
    let e = engine(medication: "Estrogen", months: 18)
    let detail = e.bodySystemDetail(for: .bodyShape)
    #expect(!detail.title.isEmpty)
    #expect(!detail.timelineText.isEmpty)
}

@Test("T chest resolves bodySystemKey → muscleStrength")
func detailReachabilityTChest() {
    let e = engine(medication: "Testosterone", months: 18)
    let detail = e.bodySystemDetail(for: .muscleStrength)
    #expect(!detail.title.isEmpty)
    #expect(!detail.timelineText.isEmpty)
}

@Test("Region overview and focusText text are both non-empty for head region at month 18")
func headRegionHeroAndOverview() {
    let mindRegions = TimeBodyRegions.mindRegions
    let pfc = mindRegions.first { $0.key == "pfc" }!
    let heroText = pfc.focusText(at: 18) ?? pfc.phaseText(at: 18)
    #expect(!heroText.isEmpty)
    #expect(!pfc.overview.isEmpty)
}

@Test("Gap-aware: insight tier and progressLabel agree with tenureTier (regression)")
func gapAwareConsistencyRegression() {
    // A user with calendar 50 months but only 10 active months should be T3, not T5.
    let e = engine(medication: "Estrogen", months: 50, activeMonthsOnHRT: 10)
    let tier = e.tenureTier
    #expect(tier == .t3InMotion)
    // Body systems' progressLabels are gap-aware — they should read early-stage copy.
    let mood = e.bodySystems.first { $0.systemKey == .moodAndMind }
    // T3 progress label should not contain mature/settled copy.
    #expect(mood?.progressLabel.contains("Settled") == false)
    #expect(mood?.progressLabel.contains("Maintained") == false)
}

// MARK: - activeMonthsOnHRT Gap Awareness

/// Tests the manager-side computation behind the engine's gap-aware tiering.
/// Regression: a long-term user whose dose log only spans recent months (installed
/// the app later) must not collapse to "months 0–3" tiering.
@Suite("activeMonthsOnHRT gap-aware tenure")
struct ActiveMonthsGapAwarenessTests {

    private func takenDose(on date: Date) -> DoseRecord {
        DoseRecord(
            doseDate: date,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 4.0,
            concentrationMgPerMl: 20.0
        )
    }

    @MainActor
    @Test("Fresh install with retroactive start trusts declared tenure")
    func freshInstallTrustsDeclaredStart() {
        let mgr = TestDefaults.manager()
        let calendar = Calendar.current
        let now = Date()
        mgr.hrtStartDate = calendar.date(byAdding: .month, value: -60, to: now)

        // Only the last three months have logged doses — the rest predate app use.
        mgr.doseHistory = [
            takenDose(on: calendar.date(byAdding: .month, value: -2, to: now)!),
            takenDose(on: calendar.date(byAdding: .month, value: -1, to: now)!),
            takenDose(on: now),
        ]

        let months = mgr.activeMonthsOnHRT
        #expect(months >= 60, "60-month user with 3 logged months must not collapse to \(months)")
        #expect(TenureTier(months: months) == .t6Rooted,
                "60-month fresh install should tier t6Rooted, got \(TenureTier(months: months))")
    }

    @MainActor
    @Test("Internal gap subtracts exactly the missing months")
    func internalGapSubtracts() {
        let mgr = TestDefaults.manager()
        let calendar = Calendar.current
        let now = Date()
        mgr.hrtStartDate = calendar.date(byAdding: .month, value: -60, to: now)!

        func dose(_ offset: Int) -> DoseRecord {
            takenDose(on: calendar.date(byAdding: .month, value: offset, to: now)!)
        }

        // Continuous log spanning offsets -60...0.
        mgr.doseHistory = (-60 ... 0).map(dose)
        let fullMonths = mgr.activeMonthsOnHRT

        // Same log minus a 6-month hole in the middle (-58...-53).
        mgr.doseHistory = (-60 ... 0).filter { !(-58 ... -53).contains($0) }.map(dose)
        let gapMonths = mgr.activeMonthsOnHRT

        #expect(fullMonths - gapMonths == 6,
                "a 6-month hole should subtract exactly 6 months (full \(fullMonths), gap \(gapMonths))")
    }

    @MainActor
    @Test("No logged doses falls back to calendar tenure")
    func noDosesFallsBack() {
        let mgr = TestDefaults.manager()
        mgr.hrtStartDate = Calendar.current.date(byAdding: .month, value: -60, to: Date())
        mgr.doseHistory = []

        #expect(mgr.activeMonthsOnHRT == mgr.monthsOnHRT)
        #expect(mgr.activeMonthsOnHRT >= 60)
    }
}
