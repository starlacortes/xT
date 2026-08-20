//
//  RegionCopyRulesTests.swift
//  xTTests
//
//  The two voice rules from `docs/App design/TIME_CARD_PERSONALIZATION.md` §9
//  that Phase E exists to clear, held over the whole region corpus — every
//  band, every overview, every insight entry, every marker.
//
//  These two are separated from the style lint in `RegionStyleTests` because
//  they are not stylistic. Terminus framing tells a long-tenure reader the
//  interesting part is behind them, which is both discouraging and imprecise:
//  maintained tissue is not tissue that stopped. Naming a comparison group
//  makes the reader the exception to it. Both are load-bearing, so both are
//  tested.
//

import Testing
import Foundation
@testable import xT

/// The corpus is built once, in `RegionStyleTests`, so the two lint files
/// cannot disagree about what "every string the card can render" means.
private let corpus = CardCopy.all

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
    for item in corpus {
        let lowered = item.text.lowercased()
        for phrase in terminusPhrases {
            #expect(!lowered.contains(phrase),
                    "\(item.source): terminus framing '\(phrase)' in \"\(item.text)\"")
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
    for item in corpus {
        let lowered = item.text.lowercased()
        for phrase in comparisonPhrases {
            #expect(!lowered.contains(phrase),
                    "\(item.source): comparison group '\(phrase)' in \"\(item.text)\"")
        }
    }
}

// MARK: - Corpus shape

@Test("No card copy is blank")
func noEmptyStrings() {
    // `RegionStyleTests.styleLintCoversEverything` pins the corpus size; this
    // pins that every entry in it actually carries text.
    for item in corpus {
        #expect(!item.text.isEmpty, "\(item.source) is empty")
    }
}
