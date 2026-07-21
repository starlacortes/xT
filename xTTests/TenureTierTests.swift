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

@Test("Negative months fall to default (t7Veteran) — valid input expected in practice")
func negativeMonths() {
    #expect(TenureTier(months: -1) == TenureTier.t7Veteran)
}

@Test("Tiers are ordered from beginning to veteran")
func tierOrdering() {
    let tiers = TenureTier.allCases
    for i in 1..<tiers.count {
        #expect(tiers[i - 1] < tiers[i], "Tier at index \(i - 1) should be < tier at \(i)")
    }
}

@Test("All 7 tiers have distinct emoji")
func distinctEmoji() {
    let emojis = Set(TenureTier.allCases.map { $0.statusEmoji })
    #expect(emojis.count == 7)
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
        doseIntensityDisclaimer: nil,
        bloodTestSchedulingText: "Schedule your next blood test around month 9.",
        suggestedBloodTestMonth: 9,
        calibrationContext: nil
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

@Test("T7 anniversary milestone has celebratory badge")
func t7AnniversaryBadge() {
    let e = engine(months: 130)
    let anniversary = e.upcomingMilestones.first(where: { $0.title.contains("Anniversary") })
    #expect(anniversary != nil)
    #expect(anniversary?.badge == "Celebrate")
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
        relativeDoseIntensity: 1.0, doseIntensityDisclaimer: nil,
        bloodTestSchedulingText: "test", suggestedBloodTestMonth: 12,
        calibrationContext: nil
    )
    let milestones = e.upcomingMilestones
    let dexa = milestones.first(where: { $0.title.contains("Bone density") })
    #expect(dexa != nil)
    #expect(dexa?.badge?.contains("Done") == true)
}
