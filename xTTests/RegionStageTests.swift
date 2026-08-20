//
//  RegionStageTests.swift
//  xTTests
//
//  The stage system from `docs/App design/TIME_STAGE_SYSTEM.md`.
//
//  Markers and month bands were authored as two independent lists describing
//  one timeline, with nothing checking that they agreed. They did not: the
//  chest marker put Tanner stage 4 at month 18 while the band covering months
//  14–17 said stage 4 arrives there, and the marker put stage 5 at month 48
//  while the only band naming stage 5 covered months 84–95.
//
//  A stage is the marker that carries an obligation. Where a landmark belongs
//  to a named clinical scale, these tests bind it to the sentence the reader
//  actually sees in the month it arrives, and — the other direction, which is
//  the one that catches invented copy — refuse to let any region's prose name
//  a stage the model does not hold.
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

private func markers(_ t: TrackedRegion) -> [RegionMarker] {
    TimeRegionMarkers.markers(track: t.track, key: t.region.key)
}

private func stages(_ t: TrackedRegion) -> [RegionMarker] {
    TimeRegionMarkers.stages(track: t.track, key: t.region.key)
}

/// Every authored string that belongs to one region — overview, every band,
/// every insight entry. This is the text a stage reference could hide in.
private func copy(_ t: TrackedRegion) -> [String] {
    var out = [t.region.overview]
    out += t.region.monthFocus.map { $0.1 }
    if let bank = TimeRegionInsights.bank(track: t.track, key: t.region.key) {
        out += (bank.mechanism + bank.fact).map(\.text)
    }
    out += markers(t).map(\.note)
    return out
}

// MARK: - Bands are addressable

/// `band(at:)` is the whole mechanism: a marker knows its month, and this is
/// how it finds the sentence the reader is looking at when that month lands.
@Test("Every marker's month resolves to a band")
func everyMarkerResolvesToABand() {
    for t in tracked {
        for marker in markers(t) {
            #expect(t.region.band(at: marker.month) != nil,
                    "\(t.region.key): marker '\(marker.name)' at month \(marker.month) falls outside every band")
        }
    }
}

@Test("band(at:) and focusText(at:) agree everywhere")
func bandAndFocusTextAgree() {
    for t in tracked {
        for month in 0...240 {
            #expect(t.region.band(at: month)?.text == t.region.focusText(at: month),
                    "\(t.region.key) month \(month): band and focusText disagree")
        }
    }
}

// MARK: - Stage sequences

@Test("A staged marker's name is the scale's own phrase")
func stageNamesComeFromTheScale() {
    for t in tracked {
        for marker in stages(t) {
            guard let stage = marker.stage else { continue }
            #expect(marker.name == stage.scale.phrase(ordinal: stage.ordinal),
                    "\(t.region.key): '\(marker.name)' is not how \(stage.scale.rawValue) writes step \(stage.ordinal)")
        }
    }
}

@Test("Stage sequences ascend without gaps and stay inside the scale")
func stageSequencesAreCompleteAndAscending() {
    for t in tracked {
        let staged = stages(t)
        guard !staged.isEmpty else { continue }

        // One scale per region. A region straddling two scales would need the
        // grouping this deliberately does not do.
        let scales = Set(staged.compactMap { $0.stage?.scale })
        #expect(scales.count == 1, "\(t.region.key): markers mix \(scales.count) scales")
        guard let scale = scales.first else { continue }

        let ordinals = staged.compactMap { $0.stage?.ordinal }
        #expect(ordinals == Array(scale.ordinals),
                "\(t.region.key): \(scale.rawValue) sequence is \(ordinals), expected \(Array(scale.ordinals))")

        // Ordinal order and month order have to be the same order, or "stage 4"
        // means nothing relative to "stage 3".
        #expect(staged.map(\.month) == staged.map(\.month).sorted(),
                "\(t.region.key): stages are not in ascending month order")
    }
}

// MARK: - The binding, both directions

/// Forward: a stage's arrival month must land in a band that names it. This is
/// what makes the NOW slot the reader's current-stage readout without the card
/// having to claim anything about them personally — the band copy is already
/// hedged, and now it is also correct.
@Test("Every stage arrival is named by the band that contains it")
func everyStageArrivalIsNamedByItsBand() {
    for t in tracked {
        for marker in stages(t) {
            guard let stage = marker.stage else { continue }
            guard let band = t.region.band(at: marker.month) else {
                Issue.record("\(t.region.key): stage \(stage.ordinal) at month \(marker.month) has no band")
                continue
            }
            let phrase = stage.scale.phrase(ordinal: stage.ordinal)
            #expect(band.text.localizedCaseInsensitiveContains(phrase),
                    "\(t.region.key): band \(band.range.lowerBound)-\(band.range.upperBound) contains month \(marker.month), where \(phrase) arrives, but does not name it — \"\(band.text)\"")
        }
    }
}

/// Reverse: no region's copy may name a step the model does not hold. This is
/// the direction that catches prose inventing a stage, which is how the chest
/// ended up describing a stage 5 arrival two years after the marker placed it.
@Test("No copy names a stage the region does not model")
func noCopyNamesAStageThatIsNotModelled() {
    let pattern = try! NSRegularExpression(pattern: "Tanner (?:stage )?([0-9])", options: [.caseInsensitive])

    for t in tracked {
        let modelled = Set(stages(t).compactMap { $0.stage?.ordinal })

        for text in copy(t) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let digits = Range(match.range(at: 1), in: text),
                      let ordinal = Int(text[digits]) else { continue }
                #expect(modelled.contains(ordinal),
                        "\(t.region.key) names Tanner stage \(ordinal), which the region does not model \(modelled.sorted()) — \"\(text)\"")
            }
        }
    }
}

// MARK: - Present tense

@Test("currentStage never names a stage that has not arrived")
func currentStageIsPresentTense() {
    for t in tracked {
        let staged = stages(t)
        guard let first = staged.first, let last = staged.last else { continue }

        for month in 0...240 {
            let current = TimeRegionMarkers.currentStage(track: t.track, key: t.region.key, month: month)
            if month < first.month {
                #expect(current == nil,
                        "\(t.region.key) month \(month): a stage is claimed before the first one arrives")
            } else {
                #expect((current?.month ?? Int.max) <= month,
                        "\(t.region.key) month \(month): currentStage points forward")
            }
        }

        #expect(TimeRegionMarkers.currentStage(track: t.track, key: t.region.key, month: 1200)?.name == last.name,
                "\(t.region.key): the last stage stops being current at long tenure")
    }
}

/// A staged region's NEXT and its current stage must never be the same step,
/// and NEXT must always be the one after.
@Test("current and next stages never collide")
func currentAndNextDoNotCollide() {
    for t in tracked where !stages(t).isEmpty {
        for month in 0...240 {
            let current = TimeRegionMarkers.currentStage(track: t.track, key: t.region.key, month: month)
            let next = TimeRegionMarkers.next(
                track: t.track,
                key: t.region.key,
                month: month,
                phase: t.region.phase(at: month)
            )
            guard let current, let next else { continue }
            #expect(current.month < next.month,
                    "\(t.region.key) month \(month): '\(current.name)' and '\(next.name)' are out of order")
        }
    }
}
