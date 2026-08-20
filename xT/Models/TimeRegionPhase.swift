import Foundation

// MARK: - Journey Context
//
// The single object every piece of region-card copy is selected against.
// See `docs/App design/TIME_CARD_PERSONALIZATION.md` §3.
//
// Before this existed the card read `months` from one place, `tenureTier` from
// another, and a 17-field `TimeContentEngine` was constructed with fourteen
// placeholder values just to reach one lookup table. Everything the card needs
// is here, and nothing it doesn't.

struct JourneyContext {
    enum HormoneTrack {
        case estrogen
        case testosterone
    }

    let track: HormoneTrack
    /// Gap-aware months on HRT. The only month count the card reads.
    let month: Int
    let tier: TenureTier
    let method: String?
    let ageAtStart: Int?
    let adherence: Double?
    let hasLabs: Bool

    init(
        track: HormoneTrack,
        month: Int,
        method: String? = nil,
        ageAtStart: Int? = nil,
        adherence: Double? = nil,
        hasLabs: Bool = false
    ) {
        self.track = track
        self.month = month
        self.tier = TenureTier(months: month)
        self.method = method
        self.ageAtStart = ageAtStart
        self.adherence = adherence
        self.hasLabs = hasLabs
    }

    var isTestosterone: Bool { track == .testosterone }
}

// MARK: - Region Phase

/// Where a region sits on its own clock — not the user's tenure.
///
/// Replaces the old four-string `phaseLabel(at:)` ladder, whose middle two
/// states ("Active · peak ahead", "Maturing · peak passed") described the card's
/// relationship to a peak rather than what the tissue is doing now.
enum RegionPhase {
    /// `month < startMonth`
    case pending
    /// `month < peakMonth`
    case developing
    /// `month < completeMonth`
    case refining
    /// `month >= completeMonth`
    case matured
}

/// Which set of words a region's phases are named with.
///
/// Tissue remodels; neural circuits adapt. The mind regions' own copy has
/// always used the second register — "the amygdala is recalibrating", "fully
/// adapted to the estrogen-dominant neurochemical environment" — so the phase
/// label needs to match it rather than announce that a brain has "Settled".
///
/// Set once per region array, not derived at the call site.
enum PhaseVocabulary {
    case tissue
    case neural
}

// MARK: - Change Rate

/// How fast the region is moving right now. Decides which bank the INSIGHT slot
/// draws from: mechanism copy while there is something to narrate, fact copy
/// when there isn't. See spec §5.
enum ChangeRate {
    case fast
    case moderate
    case slow
    case steady

    /// True when the card should reach for a fact rather than a mechanism —
    /// the month-10-to-month-11 case the whole system exists to answer.
    var prefersFact: Bool {
        switch self {
        case .fast, .moderate: return false
        case .slow, .steady:   return true
        }
    }
}

// MARK: - BodyRegion phase resolution

extension BodyRegion {

    func phase(at month: Int) -> RegionPhase {
        if month < startMonth    { return .pending }
        if month < peakMonth     { return .developing }
        if month < completeMonth { return .refining }
        return .matured
    }

    func changeRate(at month: Int) -> ChangeRate {
        switch phase(at: month) {
        case .pending:
            return .slow
        case .matured:
            return .steady
        case .developing, .refining:
            // Within ±25% of the peak month the region is moving fast enough
            // that a mechanism reads as news rather than as filler.
            let window = max(1, peakMonth / 4)
            if abs(month - peakMonth) <= window { return .fast }
            return phase(at: month) == .developing ? .moderate : .slow
        }
    }

    /// Present-tense phase label. Never points at a peak — ahead or passed.
    func phaseLabel(at month: Int) -> String {
        switch (phase(at: month), vocabulary) {
        case (.pending, _):
            return String(localized: "Begins month \(startMonth)",
                          comment: "Phase label before a region's changes start")
        case (.developing, .tissue):
            return String(localized: "Developing",
                          comment: "Phase label while tissue is actively changing")
        case (.developing, .neural):
            return String(localized: "Adapting",
                          comment: "Phase label while a brain region is actively adapting")
        case (.refining, .tissue):
            return String(localized: "Refining",
                          comment: "Phase label while tissue change is slowing but ongoing")
        case (.refining, .neural):
            return String(localized: "Tuning",
                          comment: "Phase label while a brain region's adaptation is slowing but ongoing")
        case (.matured, .tissue):
            return String(localized: "Settled",
                          comment: "Phase label once tissue change is maintained rather than driven")
        case (.matured, .neural):
            return String(localized: "Adapted",
                          comment: "Phase label once a brain region's adaptation is maintained")
        }
    }
}
