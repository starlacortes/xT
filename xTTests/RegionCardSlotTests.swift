//
//  RegionCardSlotTests.swift
//  xTTests
//
//  Phase A of the region-card personalization system:
//  see `docs/App design/TIME_CARD_PERSONALIZATION.md`.
//
//  These cover the structural guarantees Phase A lands — present-tense phase
//  labels, the two phase vocabularies, and the slot contract. The month-to-month
//  variance invariant lives in `RegionInsightBankTests` alongside Phases B and C.
//

import Testing
import Foundation
@testable import xT

private let allRegions: [BodyRegion] =
    TimeBodyRegions.mindRegions + TimeBodyRegions.bodyRegions
    + TimeBodyRegions.mindRegionsT + TimeBodyRegions.bodyRegionsT

private let mindRegions: [BodyRegion] =
    TimeBodyRegions.mindRegions + TimeBodyRegions.mindRegionsT

private let bodyRegions: [BodyRegion] =
    TimeBodyRegions.bodyRegions + TimeBodyRegions.bodyRegionsT

private func context(month: Int, testosterone: Bool = false) -> JourneyContext {
    JourneyContext(track: testosterone ? .testosterone : .estrogen, month: month)
}

// MARK: - Phase resolution

@Test("Phase boundaries follow start/peak/complete exactly")
func phaseBoundaries() {
    for region in allRegions {
        if region.startMonth > 0 {
            #expect(region.phase(at: region.startMonth - 1) == .pending,
                    "\(region.key) should be pending below startMonth")
        }
        #expect(region.phase(at: region.startMonth) == .developing || region.startMonth >= region.peakMonth,
                "\(region.key) should be developing at startMonth")
        #expect(region.phase(at: region.peakMonth) == .refining,
                "\(region.key) should be refining at peakMonth")
        #expect(region.phase(at: region.completeMonth) == .matured,
                "\(region.key) should be matured at completeMonth")
        #expect(region.phase(at: 240) == .matured,
                "\(region.key) should be matured at month 240")
    }
}

// MARK: - Phase labels

@Test("No phase label points at a peak, ahead or passed")
func phaseLabelsAreNotAboutThePeak() {
    for region in allRegions {
        for month in 0...240 {
            let label = region.phaseLabel(at: month)
            #expect(!label.localizedCaseInsensitiveContains("peak"),
                    "\(region.key) month \(month): '\(label)' still references the peak")
            #expect(!label.isEmpty, "\(region.key) month \(month): empty phase label")
        }
    }
}

@Test("Phase labels change only when the phase changes")
func phaseLabelsTrackPhaseOnly() {
    for region in allRegions {
        for month in 1...240 {
            let sameLabel = region.phaseLabel(at: month) == region.phaseLabel(at: month - 1)
            let samePhase = region.phase(at: month) == region.phase(at: month - 1)
            #expect(sameLabel == samePhase,
                    "\(region.key): label and phase disagree across month \(month - 1)→\(month)")
        }
    }
}

@Test("Mind regions use the neural vocabulary, body regions the tissue one")
func vocabularyAssignment() {
    for region in mindRegions {
        #expect(region.vocabulary == .neural, "mind region '\(region.key)' is not .neural")
    }
    for region in bodyRegions {
        #expect(region.vocabulary == .tissue, "body region '\(region.key)' is not .tissue")
    }
}

@Test("No brain region is ever labelled 'Settled'")
func brainIsNeverSettled() {
    for region in mindRegions {
        for month in 0...240 {
            #expect(region.phaseLabel(at: month) != "Settled",
                    "\(region.key) reads 'Settled' at month \(month)")
        }
    }
}

// MARK: - Change rate

@Test("Change rate prefers a fact once a region has matured")
func maturedRegionsPreferFacts() {
    for region in allRegions {
        #expect(region.changeRate(at: region.completeMonth) == .steady,
                "\(region.key) is not steady at completeMonth")
        #expect(region.changeRate(at: 240).prefersFact,
                "\(region.key) does not prefer a fact at month 240")
    }
}

@Test("Change rate is fast in the window around the peak")
func peakWindowIsFast() {
    for region in allRegions {
        #expect(region.changeRate(at: region.peakMonth) == .fast,
                "\(region.key) is not fast at peakMonth")
    }
}

// MARK: - Slot contract

@Test("NOW is never empty for any region at any month")
func nowSlotAlwaysPopulated() {
    for region in allRegions {
        for month in 0...240 {
            let slots = RegionCardSlots(region: region, context: context(month: month), mindFallback: nil)
            #expect(!slots.now.isEmpty, "\(region.key) month \(month): empty NOW slot")
        }
    }
}

@Test("NOW and INSIGHT never render the same string")
func slotsNeverDuplicate() {
    for region in allRegions {
        for month in 0...240 {
            let slots = RegionCardSlots(region: region, context: context(month: month), mindFallback: nil)
            if let insight = slots.insight {
                #expect(insight != slots.now,
                        "\(region.key) month \(month): NOW and INSIGHT are identical")
            }
        }
    }
}

@Test("ABOUT shows only while a region's clock has not started")
func aboutSlotIsPendingOnly() {
    for region in allRegions {
        for month in 0...240 {
            let slots = RegionCardSlots(region: region, context: context(month: month), mindFallback: nil)
            let isPending = region.phase(at: month) == .pending
            #expect((slots.about != nil) == isPending,
                    "\(region.key) month \(month): ABOUT visibility does not match pending")
        }
    }
}

@Test("A region with no BodyRegion falls back to the mind insight")
func mindFallbackPopulatesNow() {
    let slots = RegionCardSlots(region: nil, context: context(month: 7), mindFallback: "fallback copy")
    #expect(slots.now == "fallback copy")
    #expect(slots.insight == nil)
    #expect(slots.about == nil)
}

// MARK: - JourneyContext

@Test("JourneyContext derives its tier from the month it was given")
func journeyContextTier() {
    #expect(context(month: 0).tier == .t1Beginning)
    #expect(context(month: 11).tier == .t3InMotion)
    #expect(context(month: 60).tier == .t6Rooted)
    #expect(context(month: 240).tier == .t7Veteran)
    #expect(context(month: 6, testosterone: true).isTestosterone)
    #expect(!context(month: 6).isTestosterone)
}
