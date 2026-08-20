//
//  RegionStyleTests.swift
//  xTTests
//
//  The house style from `docs/App design/TIME_CARD_PERSONALIZATION.md` §9,
//  enforced over every string the region card can render.
//
//  A style guide that lives only in a document is a style guide that drifts.
//  These rules are mechanical on purpose — length, punctuation, hedge count,
//  tense — so they can be checked rather than remembered. The rules that need
//  judgement stay in §9 as prose and in review.
//
//  Caps are per slot because the slots do different jobs: NOW carries the
//  month, INSIGHT carries one idea, NEXT names one landmark, ABOUT introduces
//  a region the reader has not started seeing change in yet.
//

import Testing
import Foundation
@testable import xT

// MARK: - The corpus

/// One authored string, tagged with the slot it renders in.
struct CardString {
    /// Which slot of `RegionCardSlots` this text can land in.
    enum Slot {
        case now, about, insight, next

        /// (sentences, words per slot, words per sentence) — §9.
        var caps: (sentences: Int, words: Int, sentenceWords: Int) {
            switch self {
            case .now:     return (2, 34, 24)
            case .about:   return (2, 40, 24)
            case .insight: return (2, 30, 24)
            case .next:    return (1, 20, 20)
            }
        }
    }

    let source: String
    let slot: Slot
    let text: String
}

/// Every authored string the region card can render, in one place so the two
/// lint files cannot drift apart on what "the corpus" means.
enum CardCopy {
    static let all: [CardString] = {
        var out: [CardString] = []

        let regions: [(String, BodyRegion, JourneyContext.HormoneTrack)] =
            TimeBodyRegions.mindRegions.map { ("E mind", $0, .estrogen) }
            + TimeBodyRegions.bodyRegions.map { ("E body", $0, .estrogen) }
            + TimeBodyRegions.mindRegionsT.map { ("T mind", $0, .testosterone) }
            + TimeBodyRegions.bodyRegionsT.map { ("T body", $0, .testosterone) }

        for (label, region, track) in regions {
            let source = "\(label) \(region.key)"
            out.append(CardString(source: "\(source).overview", slot: .about, text: region.overview))
            for (range, text) in region.monthFocus {
                out.append(CardString(source: "\(source).band \(range.lowerBound)-\(range.upperBound)",
                                      slot: .now, text: text))
            }
            if let bank = TimeRegionInsights.bank(track: track, key: region.key) {
                for entry in bank.mechanism {
                    out.append(CardString(source: "\(source).mechanism", slot: .insight, text: entry.text))
                }
                for entry in bank.fact {
                    out.append(CardString(source: "\(source).fact", slot: .insight, text: entry.text))
                }
            }
            for marker in TimeRegionMarkers.markers(track: track, key: region.key) {
                out.append(CardString(source: "\(source).marker \(marker.name)",
                                      slot: .next, text: marker.note))
            }
        }
        return out
    }()
}

// MARK: - Text measurement

/// Split on terminal punctuation. The corpus has no abbreviations and no
/// decimals — a test asserts that below — so this is exact rather than
/// approximate, which is why it is a character scan and not a regex.
private func sentences(of text: String) -> [String] {
    var out: [String] = []
    var current = ""
    for character in text {
        current.append(character)
        if character == "." || character == "!" || character == "?" {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { out.append(trimmed) }
            current = ""
        }
    }
    let tail = current.trimmingCharacters(in: .whitespaces)
    if !tail.isEmpty { out.append(tail) }
    return out
}

/// Words as a reader counts them: whitespace-separated, so "hip-to-waist" is
/// one word. Used for the length caps.
private func wordCount(of text: String) -> Int {
    text.split(separator: " " as Character).count
}

/// Words as a matcher needs them: lowercased and stripped of punctuation, so
/// "often," and "often" are the same token. Used for the vocabulary rules,
/// where substring matching would find "often" inside "soften", and by
/// `RegionInsightBankTests` for its near-duplicate check.
func tokens(of text: String) -> [String] {
    text.lowercased()
        .split { !($0.isLetter || $0.isNumber || $0 == "'") }
        .map(String.init)
}

// MARK: - Length

@Test("Every slot stays inside its sentence and word caps")
func lengthCaps() {
    for item in CardCopy.all {
        let caps = item.slot.caps
        let parts = sentences(of: item.text)
        #expect(parts.count <= caps.sentences,
                "\(item.source): \(parts.count) sentences, cap \(caps.sentences) — \"\(item.text)\"")
        let total = wordCount(of: item.text)
        #expect(total <= caps.words,
                "\(item.source): \(total) words, cap \(caps.words) — \"\(item.text)\"")
        for part in parts {
            let count = wordCount(of: part)
            #expect(count <= caps.sentenceWords,
                    "\(item.source): sentence of \(count) words, cap \(caps.sentenceWords) — \"\(part)\"")
        }
    }
}

// MARK: - Punctuation

@Test("At most one em-dash per slot, and no parenthetical asides")
func punctuation() {
    for item in CardCopy.all {
        let dashes = item.text.filter { $0 == "\u{2014}" }.count
        #expect(dashes <= 1, "\(item.source): \(dashes) em-dashes — \"\(item.text)\"")
        #expect(!item.text.contains("("), "\(item.source): parenthetical aside — \"\(item.text)\"")
        #expect(!item.text.contains(")"), "\(item.source): parenthetical aside — \"\(item.text)\"")
        #expect(!item.text.contains("!"), "\(item.source): exclamation mark — \"\(item.text)\"")
    }
}

// MARK: - Hedging

/// Words that soften a claim. §9 allows one per sentence: `typically` **or**
/// `may`, never both. Two hedges in one sentence read as evasion, not care.
private let hedgeWords: Set<String> = [
    "typically", "may", "might", "often", "usually",
    "generally", "commonly", "sometimes", "can",
]

/// Words that approximate a number. Same rule, separate list: "roughly ten
/// years, and about 8% annually" hedges the arithmetic twice.
private let approximators: Set<String> = [
    "roughly", "approximately", "about", "around",
]

@Test("No sentence hedges twice")
func oneHedgePerSentence() {
    for item in CardCopy.all {
        for sentence in sentences(of: item.text) {
            let words = tokens(of: sentence)
            var hedges = words.filter { hedgeWords.contains($0) }
            let lowered = sentence.lowercased()
            if lowered.contains("tends to") || lowered.contains("tend to") { hedges.append("tends to") }
            #expect(hedges.count <= 1,
                    "\(item.source): hedges \(hedges) in one sentence — \"\(sentence)\"")

            let approximate = words.filter { approximators.contains($0) }
            #expect(approximate.count <= 1,
                    "\(item.source): approximators \(approximate) in one sentence — \"\(sentence)\"")
        }
    }
}

// MARK: - Voice

/// Openings that put the reader before the tissue. §9 wants "Ductal tissue is
/// branching", not "You may notice your breasts changing" — and `many people
/// report` second rather than first, where it belongs to the claim it
/// qualifies rather than framing the whole card as hearsay.
private let readerFirstOpenings = [
    "you ", "your ", "expect ",
    "many people", "most people", "some people", "people ",
]

@Test("Every slot leads with the tissue, not the reader")
func leadWithTheTissue() {
    for item in CardCopy.all {
        let lowered = item.text.lowercased()
        for opening in readerFirstOpenings {
            #expect(!lowered.hasPrefix(opening),
                    "\(item.source): opens with '\(opening)' — \"\(item.text)\"")
        }
    }
}

@Test("Only NEXT speaks in the future tense")
func tense() {
    for item in CardCopy.all where item.slot != .next {
        #expect(!tokens(of: item.text).contains("will"),
                "\(item.source): future tense outside NEXT — \"\(item.text)\"")
    }
}

@Test("No copy announces itself as a fun fact")
func noFunFact() {
    for item in CardCopy.all {
        #expect(item.text.range(of: "fun fact", options: .caseInsensitive) == nil,
                "\(item.source): \"\(item.text)\"")
    }
}

// MARK: - Corpus shape

@Test("The sentence splitter's assumption holds: no abbreviations, no decimals")
func sentenceSplittingIsExact() {
    // `sentences(of:)` breaks on every period. That is only correct while the
    // corpus contains no "e.g.", no "Dr.", and no "1.5" — so assert it, rather
    // than discover it when a future string quietly splits in two.
    for item in CardCopy.all {
        for (index, character) in item.text.enumerated() where character == "." {
            let next = item.text.index(item.text.startIndex, offsetBy: index + 1)
            guard next < item.text.endIndex else { continue }
            #expect(item.text[next] == " ",
                    "\(item.source): period mid-token would mis-split — \"\(item.text)\"")
        }
        #expect(item.text.hasSuffix(".") || item.text.hasSuffix("?"),
                "\(item.source): no terminal punctuation — \"\(item.text)\"")
    }
}

@Test("The style lint runs over the whole corpus")
func styleLintCoversEverything() {
    // Pinned so a silent drop in what the lint reads cannot make it pass for
    // the wrong reason. 18 regions: 1 overview, 18-20 bands, 5 mechanism,
    // 10 fact and 4 markers each.
    #expect(CardCopy.all.count == 700, "corpus is \(CardCopy.all.count) strings")
    let slots = Dictionary(grouping: CardCopy.all, by: { $0.slot }).mapValues(\.count)
    #expect(slots[.about] == 18, "about: \(slots[.about] ?? 0)")
    #expect(slots[.now] == 340, "now: \(slots[.now] ?? 0)")
    #expect(slots[.insight] == 270, "insight: \(slots[.insight] ?? 0)")
    #expect(slots[.next] == 72, "next: \(slots[.next] ?? 0)")
}
