//
//  RegionInsightBankTests.swift
//  xTTests
//
//  Phases B and C of the region-card personalization system:
//  see `docs/App design/TIME_CARD_PERSONALIZATION.md` §5–§6.
//
//  Phase B is the INSIGHT bank and its selector; Phase C re-cuts the NOW band
//  grid onto each region's own clock. Together they carry the invariant the
//  whole system exists for: the card at month m never matches the card at m+1.
//

import Testing
import Foundation
@testable import xT

private struct TrackedRegion {
    let region: BodyRegion
    let track: JourneyContext.HormoneTrack
}

private let tracked: [TrackedRegion] =
    TimeBodyRegions.mindRegions.map { TrackedRegion(region: $0, track: .estrogen) }
    + TimeBodyRegions.bodyRegions.map { TrackedRegion(region: $0, track: .estrogen) }
    + TimeBodyRegions.mindRegionsT.map { TrackedRegion(region: $0, track: .testosterone) }
    + TimeBodyRegions.bodyRegionsT.map { TrackedRegion(region: $0, track: .testosterone) }

private func slots(_ t: TrackedRegion, month: Int) -> RegionCardSlots {
    RegionCardSlots(
        region: t.region,
        context: JourneyContext(track: t.track, month: month),
        mindFallback: nil
    )
}

// MARK: - The invariant

@Test("The card at month m never matches the card at month m+1")
func consecutiveMonthsNeverMatch() {
    for t in tracked {
        for month in 0..<240 {
            let a = slots(t, month: month)
            let b = slots(t, month: month + 1)
            #expect(!(a.now == b.now && a.insight == b.insight),
                    "\(t.region.key): card is identical across month \(month)→\(month + 1)")
        }
    }
}

@Test("Every eligible insight pool holds at least four entries")
func everyPoolHasFourEntries() {
    for t in tracked {
        guard let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else {
            Issue.record("\(t.region.key) has no insight bank")
            continue
        }
        for month in 0...240 {
            let pool = bank.mechanism.filter { $0.months.contains(month) }
                + bank.fact.filter { $0.months.contains(month) }
            #expect(pool.count >= 4,
                    "\(t.region.key) month \(month): eligible pool is only \(pool.count)")
        }
    }
}

// MARK: - Selector

@Test("Selection is stable within a month and rotates between months")
func selectionIsStableWithinAMonth() {
    for t in tracked {
        for month in 0...240 {
            let first = slots(t, month: month).insight
            let second = slots(t, month: month).insight
            #expect(first == second,
                    "\(t.region.key) month \(month): reopening the card reshuffled INSIGHT")
        }
        for month in 0..<240 {
            #expect(slots(t, month: month).insight != slots(t, month: month + 1).insight,
                    "\(t.region.key): INSIGHT repeated across month \(month)→\(month + 1)")
        }
    }
}

@Test("The seed is FNV-1a over the region identifier, not a per-process hash")
func seedIsProcessIndependent() {
    // Hard-coded so a switch to `hashValue` — which Swift seeds randomly per
    // process — fails here rather than reshuffling every card on every launch.
    #expect(TimeRegionInsights.seed(track: .estrogen, key: "abdomen") == 1_202_453_888)
    #expect(TimeRegionInsights.seed(track: .testosterone, key: "chest") == 1_237_001_956)
    #expect(TimeRegionInsights.seed(track: .estrogen, key: "chest")
            != TimeRegionInsights.seed(track: .testosterone, key: "chest"))
}

@Test("An empty pool returns nil rather than trapping")
func emptyPoolSelectsNothing() {
    #expect(TimeRegionInsights.select(from: [], month: 7, seed: 1) == nil)
    #expect(TimeRegionInsights.select(from: [InsightEntry(0...5, "x")], month: 7, seed: 1) == nil)
    #expect(TimeRegionInsights.select(from: [InsightEntry(0...5, "x")], month: 3, seed: 1) == "x")
}

@Test("Rate steers the bank but falls through when the preferred one is empty")
func bankFallthrough() {
    let bank = RegionInsightBank(
        mechanism: [InsightEntry(0...240, "mechanism")],
        fact: [InsightEntry(0...240, "fact")]
    )
    let seed = 0
    #expect(TimeRegionInsights.select(from: bank.entries(.mechanism), month: 4, seed: seed) == "mechanism")
    #expect(TimeRegionInsights.select(from: bank.entries(.fact), month: 4, seed: seed) == "fact")

    // A matured region prefers a fact and every shipped bank now has one, so it
    // must be fact copy that lands — not a mechanism entry via the fall-through.
    for t in tracked {
        let matured = max(t.region.completeMonth, 60)
        #expect(t.region.changeRate(at: matured).prefersFact,
                "\(t.region.key) should prefer a fact at month \(matured)")
        guard let insight = slots(t, month: matured).insight else {
            Issue.record("\(t.region.key) month \(matured): INSIGHT fell through to nothing")
            continue
        }
        guard let regionBank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else { continue }
        #expect(regionBank.fact.contains { $0.text == insight },
                "\(t.region.key) month \(matured): drew mechanism copy where a fact was available")
    }
}

// MARK: - Fact bank (Phase D)

@Test("The long-tail fact pool is at least eight deep at every month past 60")
func longTailFactPoolIsDeep() {
    for t in tracked {
        guard let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else {
            Issue.record("\(t.region.key) has no insight bank")
            continue
        }
        for month in 60...240 {
            let pool = bank.fact.filter { $0.months.contains(month) }
            #expect(pool.count >= 8,
                    "\(t.region.key) month \(month): fact pool is only \(pool.count)")
        }
    }
}

@Test("A region past completeMonth draws a fact, not a mechanism")
func maturedRegionsDrawFromTheFactBank() {
    for t in tracked {
        guard let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else { continue }
        for month in stride(from: max(t.region.completeMonth, 60), through: 240, by: 7) {
            guard let insight = slots(t, month: month).insight else {
                Issue.record("\(t.region.key) month \(month): no INSIGHT")
                continue
            }
            #expect(bank.fact.contains { $0.text == insight },
                    "\(t.region.key) month \(month): INSIGHT is not fact copy")
        }
    }
}

@Test("No entry appears in both banks for the same region")
func banksDoNotOverlap() {
    for t in tracked {
        guard let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else { continue }
        let mechanism = Set(bank.mechanism.map(\.text))
        let fact = Set(bank.fact.map(\.text))
        #expect(mechanism.intersection(fact).isEmpty,
                "\(t.region.key): an entry is in both the mechanism and fact banks")
        #expect(mechanism.count == bank.mechanism.count, "\(t.region.key): duplicate mechanism entry")
        #expect(fact.count == bank.fact.count, "\(t.region.key): duplicate fact entry")
    }
}

// MARK: - Band grid (Phase C)

@Test("Bands cover every month from startMonth onward, with no gaps or overlaps")
func bandGridIsContiguousFromStart() {
    for t in tracked {
        var seen = Set<Int>()
        for (range, _) in t.region.monthFocus {
            for month in range {
                #expect(!seen.contains(month),
                        "\(t.region.key): month \(month) is covered by two bands")
                seen.insert(month)
            }
        }
        #expect(seen.intersection(Set(0...240)) == Set(t.region.startMonth...240),
                "\(t.region.key): band coverage does not equal [\(t.region.startMonth), 240]")
    }
}

@Test("Band width tracks the region's own clock, not the calendar")
func bandsAreDenseWhileTheRegionMoves() {
    for t in tracked {
        for (range, _) in t.region.monthFocus where range.lowerBound < t.region.peakMonth {
            #expect(range.count <= 6,
                    "\(t.region.key): band \(range) runs \(range.count) months before the peak")
        }
        // A region still developing must never be described by a band wider
        // than one that starts after it has matured.
        let developing = t.region.monthFocus
            .filter { $0.0.lowerBound < t.region.peakMonth }
            .map { $0.0.count }
        let matured = t.region.monthFocus
            .filter { $0.0.lowerBound >= t.region.completeMonth }
            .map { $0.0.count }
        if let widestDeveloping = developing.max(), let narrowestMatured = matured.min() {
            #expect(widestDeveloping <= narrowestMatured,
                    "\(t.region.key): developing bands are wider than matured ones")
        }
    }
}

@Test("Every band and every insight entry stays inside its word cap")
func copyStaysWithinCaps() {
    for t in tracked {
        for (range, text) in t.region.monthFocus {
            let words = text.split(separator: " " as Character).count
            #expect(words <= 34, "\(t.region.key) band \(range): NOW is \(words) words")
        }
        guard let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) else { continue }
        for entry in bank.mechanism + bank.fact {
            let words = entry.text.split(separator: " " as Character).count
            #expect(words <= 30, "\(t.region.key): INSIGHT entry is \(words) words")
        }
    }
}

// MARK: - Slot wiring

@Test("Every region resolves a NOW and an INSIGHT at every month")
func bothSlotsAlwaysResolve() {
    for t in tracked {
        for month in 0...240 {
            let s = slots(t, month: month)
            #expect(!s.now.isEmpty, "\(t.region.key) month \(month): empty NOW")
            #expect(s.insight?.isEmpty == false, "\(t.region.key) month \(month): empty INSIGHT")
        }
    }
}

@Test("The month-10 to month-11 case the system exists to answer")
func monthTenAndElevenDiffer() {
    guard let abdomen = TimeBodyRegions.bodyRegions.first(where: { $0.key == "abdomen" }) else {
        Issue.record("estrogen abdomen region missing")
        return
    }
    let t = TrackedRegion(region: abdomen, track: .estrogen)
    let ten = slots(t, month: 10)
    let eleven = slots(t, month: 11)

    #expect(ten.now == eleven.now, "months 10 and 11 should share a NOW band")
    #expect(ten.insight != eleven.insight, "months 10 and 11 must not share an INSIGHT")
    #expect(ten.about == nil && eleven.about == nil, "abdomen is past pending by month 10")
}
