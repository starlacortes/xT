//
//  HormoneLevelPresentation.swift
//  xT
//
//  The single place where a `HormoneLevel` becomes words and colour.
//
//  `MedicationManager` returns classification as values (`LevelStatus`,
//  `SafetyFlag`, `RangeSource`, …) and contains no user-facing English. Everything
//  the user reads about a level is built here, which keeps semantics separate from
//  presentation and gives localization one file to cover instead of six views.
//
//  Two rules govern the copy:
//
//  1. **State, don't advise.** These strings report what was measured or modelled.
//     They do not recommend an action, evaluate the user, or imply a goal.
//  2. **Compare only against bounds the user set.** When
//     `boundsSource == .modelDerived` the range came from the population model, not
//     from the user — so the copy reports the estimate and stops. No "below target",
//     no red or green, because there is no target.
//

import SwiftUI

// MARK: - Units

extension HormoneUnit {
    /// Unit symbol. Localized because a few locales transliterate the symbols,
    /// though most keep them as-is.
    var symbol: String {
        switch self {
        case .picogramsPerMilliliter:
            return String(localized: "pg/mL",
                          comment: "Unit symbol: picograms per millilitre, used for estradiol levels")
        case .nanogramsPerDeciliter:
            return String(localized: "ng/dL",
                          comment: "Unit symbol: nanograms per decilitre, used for testosterone levels")
        }
    }
}

// MARK: - Cycle phase

extension MedicationManager.CyclePosition {
    /// Where in the dose cycle the estimate falls. `nil` when unknown — the copy
    /// then omits the clause rather than saying "unknown".
    var phaseDescription: String? {
        switch self {
        case .nearPeak:
            return String(localized: "near peak",
                          comment: "Position in the dose cycle, used mid-sentence: 'Estimated 142 pg/mL near peak'")
        case .trough:
            return String(localized: "at trough",
                          comment: "Position in the dose cycle, used mid-sentence: 'Estimated 142 pg/mL at trough'")
        case .midCycle:
            return String(localized: "mid-cycle",
                          comment: "Position in the dose cycle, used mid-sentence: 'Estimated 142 pg/mL mid-cycle'")
        case .unknown:
            return nil
        }
    }
}

// MARK: - Level copy

extension HormoneLevel {

    /// The estimate itself — "142 pg/mL".
    var valueDescription: String {
        String(localized: "\(AppNumberFormatters.hormoneLevel.string(value)) \(unit.symbol)",
               comment: "A hormone level and its unit, e.g. '142 pg/mL'")
    }

    /// The comparison bounds — "100–200 pg/mL".
    var boundsDescription: String {
        let lower = AppNumberFormatters.hormoneLevel.string(bounds.min)
        let upper = AppNumberFormatters.hormoneLevel.string(bounds.max)
        return String(localized: "\(lower)–\(upper) \(unit.symbol)",
                      comment: "A range of hormone levels with its unit, e.g. '100–200 pg/mL'")
    }

    /// Whether the app has standing to make a comparative statement at all.
    /// False when the bounds came from the population model rather than the user.
    var hasUserBounds: Bool { boundsSource == .userSet }

    /// Where the estimate sits relative to the user's own bounds, collapsed to the
    /// three distinctions that are actually visible in the numbers. `nil` when the
    /// user has set no bounds.
    ///
    /// The finer gradations `LevelStatus` carries (critically low vs. very low) are
    /// deliberately not surfaced: the exact figure and range are both shown, so a
    /// severity adjective would only add a judgement on top of visible facts.
    enum BoundsRelation { case below, within, above }

    var boundsRelation: BoundsRelation? {
        guard hasUserBounds else { return nil }
        switch status {
        case .criticallyLow, .veryLow, .slightlyBelow: return .below
        case .inRange:                                 return .within
        case .slightlyAbove, .high:                    return .above
        }
    }

    /// Short label for the pill beside the level readout.
    /// `nil` when there is nothing factual to assert — no pill is drawn.
    var statusPillText: String? {
        if let safety { return safety.pillText }
        switch boundsRelation {
        case .below:
            return String(localized: "Below set trough",
                          comment: "Pill label: the estimate is under the trough range the user configured")
        case .within:
            return String(localized: "Within set trough",
                          comment: "Pill label: the estimate is inside the trough range the user configured")
        case .above:
            return String(localized: "Above set trough",
                          comment: "Pill label: the estimate is over the trough range the user configured")
        case nil:
            return nil
        }
    }

    /// Tint for the pill and the level readout.
    ///
    /// Error red is reserved for documented clinical thresholds. Sitting outside a
    /// self-chosen range is not an error, so it takes the neutral accent — and with
    /// no user-set range there is nothing to colour at all.
    var statusTint: Color {
        if safety != nil { return Theme.Colors.error }
        return Theme.Colors.accent
    }

    /// One-line factual summary — the estimate, when in the cycle it falls, and
    /// (only if the user set bounds) how it compares to them.
    var summaryText: String {
        let phase = self.phase.phaseDescription

        guard let relation = boundsRelation else {
            // No user-set bounds: report the estimate and stop.
            if let phase {
                return String(localized: "Estimated \(valueDescription) \(phase).",
                              comment: "Level readout with cycle position, e.g. 'Estimated 142 pg/mL at trough.'")
            }
            return String(localized: "Estimated \(valueDescription).",
                          comment: "Level readout with no cycle position, e.g. 'Estimated 142 pg/mL.'")
        }

        let comparison: String
        switch relation {
        case .below:
            comparison = String(localized: "below your set trough range of \(boundsDescription)",
                                comment: "Sentence fragment comparing the estimate to the user's configured range")
        case .within:
            comparison = String(localized: "within your set trough range of \(boundsDescription)",
                                comment: "Sentence fragment comparing the estimate to the user's configured range")
        case .above:
            comparison = String(localized: "above your set trough range of \(boundsDescription)",
                                comment: "Sentence fragment comparing the estimate to the user's configured range")
        }

        if let phase {
            return String(localized: "Estimated \(valueDescription) \(phase) — \(comparison).",
                          comment: "Full level readout: estimate, cycle position, comparison to the user's range")
        }
        return String(localized: "Estimated \(valueDescription) — \(comparison).",
                      comment: "Full level readout: estimate and comparison to the user's range")
    }

    /// A documented clinical association for levels past a known threshold.
    ///
    /// States the association only. It does not instruct the user to do anything —
    /// what to do with the information is theirs and their provider's to decide.
    var safetyNote: String? { safety?.note }

    /// How the calibrated estimate compares to the uncalibrated population model.
    /// Shown only where blood-test calibration is being discussed; `nil` when there
    /// is no meaningful comparison to draw.
    var deviationNote: String? {
        switch deviation {
        case .below:
            return String(localized: "Measured lower than the population model predicts for this regimen.",
                          comment: "Comparison of the user's calibrated level to the uncalibrated model")
        case .above:
            return String(localized: "Measured higher than the population model predicts for this regimen.",
                          comment: "Comparison of the user's calibrated level to the uncalibrated model")
        case .onTrack, .incomparable:
            return nil
        }
    }
}

// MARK: - Safety flags

extension SafetyFlag {

    var pillText: String {
        switch self {
        case .estrogenCeiling:
            return String(localized: "Above 1,000 pg/mL",
                          comment: "Pill label naming the estradiol threshold the estimate has passed")
        case .testosteroneSupraphysiologic:
            return String(localized: "Above 1,500 ng/dL",
                          comment: "Pill label naming the testosterone threshold the estimate has passed")
        case .subTherapeuticTrough:
            return String(localized: "Below 50 pg/mL at trough",
                          comment: "Pill label naming the low estradiol trough threshold")
        case .spironolactoneClearance:
            return String(localized: "Below 80 pg/mL at trough",
                          comment: "Pill label naming the low estradiol trough threshold while spironolactone is in use")
        }
    }

    /// The clinical fact behind the flag. Describes an association; issues no instruction.
    var note: String {
        switch self {
        case .estrogenCeiling:
            return String(localized: "Estradiol above 1,000 pg/mL is associated with increased thromboembolic risk.",
                          comment: "Clinical association for very high estradiol. States a fact, not an instruction.")
        case .testosteroneSupraphysiologic:
            return String(localized: "Testosterone above 1,500 ng/dL is associated with increased risk of polycythemia.",
                          comment: "Clinical association for very high testosterone. States a fact, not an instruction.")
        case .subTherapeuticTrough:
            return String(localized: "Estradiol below 50 pg/mL at trough is under the range typically associated with therapeutic effect.",
                          comment: "Clinical association for a low estradiol trough. States a fact, not an instruction.")
        case .spironolactoneClearance:
            return String(localized: "Spironolactone can increase estradiol clearance, which lowers trough levels.",
                          comment: "Pharmacological interaction note. States a fact, not an instruction.")
        }
    }
}
