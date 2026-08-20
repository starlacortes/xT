import Foundation

// MARK: - Region markers
//
// The fourth card slot. See `docs/App design/TIME_CARD_PERSONALIZATION.md` §7.
//
// A marker is a named landmark on a region's own clock — "Tanner stage 4",
// "First fat-cell cycle" — with the month it typically arrives. Typical, not
// promised: the month is where the literature puts the median, and the copy
// says so every time.
//
// NEXT is the one slot allowed to look forward, and it is deliberately narrow.
// It names a concrete landmark, never a position on a progress curve — the
// "peak ahead" and "peak passed" labels this system removed were the latter.
// It is suppressed once a region has matured, and suppressed when the nearest
// landmark is more than two years out, because a card with nothing ahead of it
// should say nothing about what is ahead of it.

struct RegionMarker {
    /// Typical arrival month. Median of the literature, not a promise.
    let month: Int
    /// The landmark's name. Rendered as the slot's eyebrow.
    let name: String
    /// One sentence. Never repeats `name` — the eyebrow already said it.
    let note: String
    /// Set when this landmark is a step on a named clinical scale rather than a
    /// one-off label. A staged marker is bound to the NOW copy: see `StageScale`.
    var stage: StageRef?

    init(month: Int, name: String, note: String, stage: StageRef? = nil) {
        self.month = month
        self.name = name
        self.note = note
        self.stage = stage
    }
}

// MARK: - Stages

/// A named clinical scale whose steps a region passes through in order.
///
/// A marker is a landmark; a stage is a landmark that belongs to a sequence,
/// which is a stronger claim and earns a stronger guarantee. Stage 4 means
/// something relative to stage 3, the sequence has to be complete, and the
/// month band that contains a stage's arrival has to say so in words.
///
/// Tanner staging is the only scale modelled today. It is the one the breast
/// literature actually uses, it is already named in the chest region's prose,
/// and before this it was named there with nothing behind it — the copy placed
/// stage 4 at months 14–17 while the marker placed it at month 18, and named
/// stage 5 at months 84–95 while the marker placed it at month 48. Neither
/// could see the other. `RegionStageTests` is what stops that recurring.
enum StageScale: String {
    case tanner

    /// How a step on this scale is written, everywhere it is written. The
    /// marker's name, the band copy the test looks for, and the phrase a
    /// reader sees are all this one string.
    func phrase(ordinal: Int) -> String {
        switch self {
        case .tanner:
            return String(localized: "Tanner stage \(ordinal)",
                          comment: "A step on the Tanner scale of breast development")
        }
    }

    /// The steps this scale defines, in order. Stage 1 is the untreated
    /// baseline, so a region's sequence starts at 2.
    var ordinals: ClosedRange<Int> {
        switch self {
        case .tanner: return 2...5
        }
    }
}

/// Where a marker sits on a named scale.
struct StageRef: Equatable {
    let scale: StageScale
    let ordinal: Int
}

extension RegionMarker {
    /// A landmark that is a step on a named scale. The name comes from the
    /// scale rather than the call site, so the eyebrow, the band copy and the
    /// test all read the same spelling of the same stage.
    static func stage(_ scale: StageScale, _ ordinal: Int, month: Int, note: String) -> RegionMarker {
        RegionMarker(
            month: month,
            name: scale.phrase(ordinal: ordinal),
            note: note,
            stage: StageRef(scale: scale, ordinal: ordinal)
        )
    }
}

enum TimeRegionMarkers {

    /// How far ahead a landmark can be and still earn the slot, in months.
    static let horizon = 24

    static func markers(track: JourneyContext.HormoneTrack, key: String) -> [RegionMarker] {
        switch track {
        case .estrogen:     return estrogen[key] ?? []
        case .testosterone: return testosterone[key] ?? []
        }
    }

    /// The landmark the NEXT slot should show, or nil when it should not render.
    ///
    /// Arrays are authored in ascending month order; `markersAreSorted` holds
    /// that to it, so the first match past `month` is the nearest one.
    static func next(
        track: JourneyContext.HormoneTrack,
        key: String,
        month: Int,
        phase: RegionPhase
    ) -> RegionMarker? {
        guard phase != .matured else { return nil }
        guard let marker = markers(track: track, key: key).first(where: { $0.month > month }) else {
            return nil
        }
        guard marker.month - month <= horizon else { return nil }
        return marker
    }

    /// This region's staged landmarks, in order. Empty for a region with no
    /// named scale, which is every region but the estrogen chest today.
    static func stages(track: JourneyContext.HormoneTrack, key: String) -> [RegionMarker] {
        markers(track: track, key: key).filter { $0.stage != nil }
    }

    /// The most recent stage the median reader has reached, or nil before the
    /// first one arrives.
    ///
    /// Present tense by construction: it names a step that has typically
    /// happened, never one that is coming. `next(...)` is the forward-looking
    /// half and stays the only forward-looking half.
    static func currentStage(
        track: JourneyContext.HormoneTrack,
        key: String,
        month: Int
    ) -> RegionMarker? {
        stages(track: track, key: key).last { $0.month <= month }
    }

    // MARK: Marker data

    static let estrogen: [String: [RegionMarker]] = [
        "pfc": [
            RegionMarker(month: 6, name: "Working memory", note: "Gains typically become measurable around month 6."),
            RegionMarker(month: 12, name: "Cognitive flexibility", note: "Usually consolidates around month 12."),
            RegionMarker(month: 18, name: "Adapted dopaminergic tone", note: "Typically reached around month 18."),
            RegionMarker(month: 36, name: "Maintained circuits", note: "Prefrontal circuits typically settle here around month 36."),
        ],
        "hippocampus": [
            RegionMarker(month: 6, name: "Measurable volume gain", note: "Hippocampal volume increase typically shows around month 6."),
            RegionMarker(month: 12, name: "Verbal memory", note: "Benchmarks are usually at their most improved around month 12."),
            RegionMarker(month: 24, name: "Maximum spine density", note: "CA1 density typically reaches its highest around month 24."),
            RegionMarker(month: 48, name: "Maintained volume", note: "Volume typically settles at its held level around month 48."),
        ],
        "amygdala": [
            RegionMarker(month: 3, name: "Widened emotional range", note: "Typically reported by around month 3."),
            RegionMarker(month: 6, name: "Clearest shift", note: "The change in emotional experience is usually clearest around month 6."),
            RegionMarker(month: 12, name: "Recalibrated reactivity", note: "Amygdala reactivity typically reaches its new baseline around month 12."),
            RegionMarker(month: 24, name: "Held baseline", note: "The emotional baseline is typically steady from around month 24."),
        ],
        "synaptic": [
            RegionMarker(month: 6, name: "Broad remodelling", note: "Both limbic and cortical circuits are typically remodelling by month 6."),
            RegionMarker(month: 18, name: "Remodelled density", note: "Synaptic density typically reaches its new level around month 18."),
            RegionMarker(month: 36, name: "Mature architecture", note: "The remodelled architecture is typically mature around month 36."),
            RegionMarker(month: 60, name: "Sustained plasticity", note: "Enhanced plasticity is typically a steady state from around month 60."),
        ],
        "hips": [
            RegionMarker(month: 6, name: "Iliac deposition", note: "Deposition at the iliac crest typically becomes measurable around month 6."),
            RegionMarker(month: 12, name: "Ratio shift", note: "The hip-to-waist ratio usually moves most noticeably around month 12."),
            RegionMarker(month: 24, name: "First fat-cell cycle", note: "Most of the first adipocyte turnover cycle is typically done by month 24."),
            RegionMarker(month: 36, name: "Established distribution", note: "Gynoid distribution is typically established around month 36."),
        ],
        "thighs": [
            RegionMarker(month: 9, name: "Inner-thigh pads", note: "Typically become visible around month 9."),
            RegionMarker(month: 16, name: "Defined contour", note: "The curve from hip to knee is usually well defined around month 16."),
            RegionMarker(month: 20, name: "Slowing deposition", note: "Thigh deposition typically begins slowing around month 20."),
            RegionMarker(month: 36, name: "Established distribution", note: "Thigh distribution is typically established around month 36."),
        ],
        "abdomen": [
            RegionMarker(month: 6, name: "Measurable visceral loss", note: "Visceral fat reduction typically shows on a tape measure around month 6."),
            RegionMarker(month: 10, name: "Fastest change", note: "Abdominal composition usually moves fastest around month 10."),
            RegionMarker(month: 12, name: "Visceral floor", note: "Visceral fat typically reaches its lowest level around month 12."),
            RegionMarker(month: 24, name: "Established pattern", note: "The estrogen-dominant abdominal pattern is typically established around month 24."),
        ],
        "glutes": [
            RegionMarker(month: 9, name: "Profile shift", note: "The posterior profile typically starts shifting around month 9."),
            RegionMarker(month: 18, name: "Pelvic tilt", note: "Ligament-driven changes in pelvic tilt usually settle around month 18."),
            RegionMarker(month: 24, name: "Fastest expansion", note: "Gluteal deposition typically runs fastest around month 24."),
            RegionMarker(month: 48, name: "Mature distribution", note: "Gluteal distribution typically reaches maturity around month 48."),
        ],
        // The only staged region. Months are the medians the chest bands are
        // written against, and `RegionStageTests` holds the two together.
        "chest": [
            .stage(.tanner, 2, month: 3,  note: "Typically establishes around month 3."),
            .stage(.tanner, 3, month: 9,  note: "Typically arrives around month 9."),
            .stage(.tanner, 4, month: 14, note: "Typically arrives around month 14."),
            .stage(.tanner, 5, month: 48, note: "Where it is reached, typically arrives around month 48."),
        ],
    ]

    static let testosterone: [String: [RegionMarker]] = [
        "pfc": [
            RegionMarker(month: 3, name: "Direct processing", note: "A shift toward it is typically reported by around month 3."),
            RegionMarker(month: 6, name: "Steadier week to week", note: "Day-to-day variability usually narrows around month 6."),
            RegionMarker(month: 12, name: "Adapted configuration", note: "Prefrontal circuits typically reach it around month 12."),
            RegionMarker(month: 24, name: "Held processing style", note: "Executive processing is typically steady from around month 24."),
        ],
        "hippocampus": [
            RegionMarker(month: 3, name: "Spatial gains", note: "Where they appear, typically show by around month 3."),
            RegionMarker(month: 6, name: "Consolidation", note: "Spatial-cognition gains usually consolidate around month 6."),
            RegionMarker(month: 12, name: "Adapted function", note: "Hippocampal function typically reaches its androgen-adapted state around month 12."),
            RegionMarker(month: 24, name: "Held benefit", note: "Spatial-cognition benefits are typically steady from around month 24."),
        ],
        "amygdala": [
            RegionMarker(month: 3, name: "More contained response", note: "Typically reported by around month 3."),
            RegionMarker(month: 6, name: "Stabilising shift", note: "The change in emotional reactivity usually stabilises around month 6."),
            RegionMarker(month: 9, name: "Recalibrated reactivity", note: "Typically reached around month 9."),
            RegionMarker(month: 18, name: "Held baseline", note: "The emotional baseline is typically steady from around month 18."),
        ],
        "synaptic": [
            RegionMarker(month: 4, name: "Fastest remodelling", note: "Spine formation typically runs fastest around month 4."),
            RegionMarker(month: 12, name: "Remodelled density", note: "Spine density typically reaches its new level around month 12."),
            RegionMarker(month: 24, name: "Settled architecture", note: "The androgen-adapted architecture typically settles around month 24."),
            RegionMarker(month: 36, name: "Sustained maintenance", note: "Synaptic architecture is typically a steady state from around month 36."),
        ],
        "chest": [
            RegionMarker(month: 6, name: "First chest hair", note: "Typically starts appearing around month 6."),
            RegionMarker(month: 11, name: "Fastest muscle gain", note: "Pectoral gain typically runs fastest around month 11, with training."),
            RegionMarker(month: 22, name: "Full hair pattern", note: "Chest hair is typically fully in around month 22."),
            RegionMarker(month: 30, name: "Training-led growth", note: "Pectoral size typically tracks training rather than tenure from around month 30."),
        ],
        "abdomen": [
            RegionMarker(month: 6, name: "Measurable accumulation", note: "Abdominal accumulation typically shows around month 6."),
            RegionMarker(month: 12, name: "Fastest redistribution", note: "Fat redistribution typically runs fastest around month 12."),
            RegionMarker(month: 18, name: "Android default", note: "New storage typically follows the androgenic pattern from around month 18."),
            RegionMarker(month: 36, name: "Established distribution", note: "Androgenic fat distribution is typically established around month 36."),
        ],
        "hips": [
            RegionMarker(month: 4, name: "Shifting ratio", note: "The hip-to-shoulder ratio typically starts moving around month 4."),
            RegionMarker(month: 11, name: "Fastest proportional change", note: "Typically runs fastest around month 11."),
            RegionMarker(month: 17, name: "Set silhouette", note: "The masculinised silhouette is typically largely set around month 17."),
            RegionMarker(month: 30, name: "Stable proportion", note: "Hip proportion is typically stable from around month 30."),
        ],
        "glutes": [
            RegionMarker(month: 9, name: "Rapid strength", note: "Squat and leg-press numbers typically climb fastest around month 9."),
            RegionMarker(month: 12, name: "Fastest hypertrophy", note: "Gluteal gain typically runs fastest around month 12, with training."),
            RegionMarker(month: 18, name: "Training ceiling", note: "Gluteal muscle typically reaches its training-stimulus ceiling around month 18."),
            RegionMarker(month: 36, name: "Training-led mass", note: "Gluteal mass typically tracks training rather than tenure from around month 36."),
        ],
        "thighs": [
            RegionMarker(month: 5, name: "Visible growth", note: "Thigh muscle growth typically becomes visible around month 5, with training."),
            RegionMarker(month: 10, name: "Fastest gain", note: "Thigh hypertrophy typically runs fastest around month 10."),
            RegionMarker(month: 14, name: "Satellite plateau", note: "Androgen-driven satellite cell activation typically plateaus around month 14."),
            RegionMarker(month: 28, name: "Training-led size", note: "Thigh size typically tracks training rather than tenure from around month 28."),
        ],
    ]
}
