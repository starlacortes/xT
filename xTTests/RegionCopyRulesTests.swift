//
//  RegionCopyRulesTests.swift
//  xTTests
//
//  The two voice rules from `docs/App design/TIME_CARD_PERSONALIZATION.md` §9
//  that Phase E exists to clear, held over the whole region corpus — every
//  band, every phase text, every overview, every insight entry, every marker.
//
//  These two are here rather than in Phase F's full style lint because they are
//  not stylistic. Terminus framing tells a long-tenure reader the interesting
//  part is behind them, which is both discouraging and imprecise: maintained
//  tissue is not tissue that stopped. Naming a comparison group makes the
//  reader the exception to it. Both are load-bearing, so both are tested.
//

import Testing
import Foundation
@testable import xT

/// Every authored string the region card can render.
private let corpus: [(String, String)] = {
    var out: [(String, String)] = []

    let regions: [(String, BodyRegion, JourneyContext.HormoneTrack)] =
        TimeBodyRegions.mindRegions.map { ("E mind", $0, .estrogen) }
        + TimeBodyRegions.bodyRegions.map { ("E body", $0, .estrogen) }
        + TimeBodyRegions.mindRegionsT.map { ("T mind", $0, .testosterone) }
        + TimeBodyRegions.bodyRegionsT.map { ("T body", $0, .testosterone) }

    for (label, region, track) in regions {
        let source = "\(label) \(region.key)"
        out.append(("\(source).earlyText", region.earlyText))
        out.append(("\(source).midText", region.midText))
        out.append(("\(source).lateText", region.lateText))
        out.append(("\(source).overview", region.overview))
        for (range, text) in region.monthFocus {
            out.append(("\(source).band \(range.lowerBound)-\(range.upperBound)", text))
        }
        if let bank = TimeRegionInsights.bank(track: track, key: region.key) {
            for entry in bank.mechanism { out.append(("\(source).mechanism", entry.text)) }
            for entry in bank.fact { out.append(("\(source).fact", entry.text)) }
        }
        for marker in TimeRegionMarkers.markers(track: track, key: region.key) {
            out.append(("\(source).marker \(marker.name)", marker.note))
        }
    }
    return out
}()

// MARK: - No terminus framing

/// Editorial verdicts that leave the reader with nothing. Note what is *not*
/// here: "plateaus" is allowed. "Breast development typically plateaus around
/// year five" is a true and useful thing to tell someone. What goes is the
/// verdict layered on top of it.
private let terminusPhrases = [
    "no further", "nothing more", "nothing left", "no longer changes",
    "is complete", "are complete", "fully complete", "finished",
    "has stopped", "have stopped", "plateaued", "requires no",
    "not expected", "no additional",
]

@Test("No card copy frames the long tail as something that ended")
func noTerminusFraming() {
    for (source, text) in corpus {
        let lowered = text.lowercased()
        for phrase in terminusPhrases {
            #expect(!lowered.contains(phrase),
                    "\(source): terminus framing '\(phrase)' in \"\(text)\"")
        }
    }
}

// MARK: - No comparison groups

/// Facts drawn from the wider literature are written as tissue state — "in any
/// estrogen-maintained skeleton" — never as a population comparison. Naming a
/// group positions the reader relative to it, in either direction.
private let comparisonPhrases = [
    "cisgender", "cis women", "cis men",
    "unlike women", "unlike men",
    "compared to women", "compared to men",
    "biological women", "biological men",
    "the same as in women", "the same as in men",
]

@Test("No card copy positions the reader against another group")
func noComparisonGroups() {
    for (source, text) in corpus {
        let lowered = text.lowercased()
        for phrase in comparisonPhrases {
            #expect(!lowered.contains(phrase),
                    "\(source): comparison group '\(phrase)' in \"\(text)\"")
        }
    }
}

// MARK: - Corpus shape

@Test("The corpus this lint runs over is actually the whole corpus")
func lintCoversEverything() {
    // A silent drop in what the lint reads would make it pass for the wrong
    // reason, so the count is pinned rather than trusted.
    #expect(corpus.count > 700, "corpus is only \(corpus.count) strings")
    for (source, text) in corpus {
        #expect(!text.isEmpty, "\(source) is empty")
    }
}
