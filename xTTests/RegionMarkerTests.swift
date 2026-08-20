//
//  RegionMarkerTests.swift
//  xTTests
//
//  Phase E of the region-card personalization system:
//  see `docs/App design/TIME_CARD_PERSONALIZATION.md` §7.
//
//  Markers are the only forward-looking content on the card. These hold them to
//  the two rules that keep NEXT from becoming the "peak ahead" label this
//  system removed: it names a concrete landmark, and it disappears when there
//  is nothing concrete within reach.
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

private func markers(_ t: TrackedRegion) -> [RegionMarker] {
    TimeRegionMarkers.markers(track: t.track, key: t.region.key)
}

// MARK: - Marker data

@Test("Every region has markers, in ascending month order, with unique names")
func markersAreSorted() {
    for t in tracked {
        let list = markers(t)
        #expect(list.count >= 4, "\(t.region.key) has only \(list.count) markers")
        #expect(list.map(\.month) == list.map(\.month).sorted(),
                "\(t.region.key): markers are not in ascending month order")
        #expect(Set(list.map(\.name)).count == list.count,
                "\(t.region.key): two markers share a name")
        for marker in list {
            #expect(!marker.name.isEmpty && !marker.note.isEmpty,
                    "\(t.region.key) marker at month \(marker.month) is missing copy")
            #expect(marker.note.split(separator: " " as Character).count <= 20,
                    "\(t.region.key) marker '\(marker.name)': note is over the 20-word cap")
        }
    }
}

@Test("Markers sit on the region's own clock, not on the calendar")
func markersTrackTheRegionClock() {
    for t in tracked {
        let list = markers(t)
        #expect((list.first?.month ?? 0) >= t.region.startMonth,
                "\(t.region.key): a marker falls before the region's clock starts")
        #expect((list.last?.month ?? 0) <= max(t.region.completeMonth, 60),
                "\(t.region.key): the last marker sits past where the region matures")
    }
}

@Test("No marker names a peak, ahead or passed")
func markersAreNotAboutThePeak() {
    for t in tracked {
        for marker in markers(t) {
            #expect(!marker.name.localizedCaseInsensitiveContains("peak"),
                    "\(t.region.key) marker '\(marker.name)' names a peak")
            #expect(!marker.note.localizedCaseInsensitiveContains("peak"),
                    "\(t.region.key) marker '\(marker.name)' note names a peak")
        }
    }
}

// MARK: - NEXT slot

@Test("NEXT never points backward and never reaches past the horizon")
func nextStaysInsideTheHorizon() {
    for t in tracked {
        for month in 0...240 {
            guard let next = slots(t, month: month).next else { continue }
            #expect(next.month > month,
                    "\(t.region.key) month \(month): NEXT points at month \(next.month)")
            #expect(next.month - month <= TimeRegionMarkers.horizon,
                    "\(t.region.key) month \(month): NEXT is \(next.month - month) months out")
        }
    }
}

@Test("NEXT is the nearest landmark ahead, never a later one")
func nextIsTheNearestLandmark() {
    for t in tracked {
        let list = markers(t)
        for month in 0...240 {
            guard let next = slots(t, month: month).next else { continue }
            let nearest = list.first { $0.month > month }
            #expect(next.month == nearest?.month,
                    "\(t.region.key) month \(month): NEXT skipped a nearer landmark")
        }
    }
}

@Test("A matured region says nothing about what is ahead of it")
func maturedRegionsSuppressNext() {
    for t in tracked {
        for month in 0...240 where t.region.phase(at: month) == .matured {
            #expect(slots(t, month: month).next == nil,
                    "\(t.region.key) month \(month): NEXT renders on a matured region")
        }
    }
}

@Test("NEXT actually renders somewhere in every region's developing span")
func nextIsReachable() {
    for t in tracked {
        let rendered = (0...240).contains { slots(t, month: $0).next != nil }
        #expect(rendered, "\(t.region.key): NEXT never renders at any month")
    }
}
