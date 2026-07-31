//
//  PharmacokineticConstants.swift
//  xT
//
//  Extracted from MedicationManager.swift — Step 4 of refactor-proposal-v2.
//  Contains the medication ester enums and their pharmacokinetic properties.
//

import Foundation

// MARK: - Estrogen Esters

enum MedicationEster: String, CaseIterable {
    case valerate = "Valerate (EV)"
    case cypionate = "Cypionate (EC)"
    case oral = "Oral"
    case transdermal = "Transdermal"

    /// Apparent terminal half-life (days) — sets the Bateman `ka` (ka = ln2 / halfLifeDays).
    /// Under flip-flop kinetics for depot esters this is the absorption-limited terminal
    /// slope, and it is what governs the entire inter-dose peak→trough decay.
    ///
    /// Recalibrated 2026‑07‑29: EV 2.0 → 2.60 d and EC 8.5 → 6.47 d, fit so the modeled
    /// steady-state trough reproduces transfemscience.org Table 10 (5 mg weekly). The
    /// previous values undershot the published trough by 45% (EV) and 31% (EC).
    /// Oral/transdermal are elimination-dominated and were left as-is (already validated).
    /// See `.pk_analysis/fit_constants.py`.
    var halfLifeDays: Double {
        switch self {
        case .valerate: return 2.60
        case .cypionate: return 6.47
        case .oral: return 0.5
        case .transdermal: return 1.5
        }
    }

    /// Apparent absorption half-life (hours) — sets the Bateman `ke` (ke = ln2 / (h/24)).
    ///
    /// NOTE: despite the name, this is an *empirical curve-fit constant*, not the
    /// physiological clearance of free estradiol. Under flip-flop kinetics the fast
    /// exponential is unidentifiable from clinical data: with the previous fixed 3 h,
    /// exp(-ke·t) decayed within ~2 h and contributed nothing to the observable curve
    /// except to force Tmax to ~0.5 d for every ester. It is now fit per-ester so that
    /// Tmax = ln(ka/ke)/(ka−ke) lands on the published time-to-peak.
    ///
    /// Recalibrated 2026‑07‑29: EV 3 h → 21.5 h (Tmax 0.53 → 2.10 d, lit 2.1 d),
    /// EC 3 h → 38.6 h (Tmax 0.77 → 4.30 d, lit 3.1–4.3 d).
    /// See `.pk_analysis/fit_constants.py`.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .valerate: return 21.5
        case .cypionate: return 38.6
        case .oral: return 3.0
        case .transdermal: return 3.0
        }
    }

    /// Ester Weight Factor (EWF) — mg of active estradiol per mg of ester.
    /// Calculated from molecular weights: E2 base = 272.4 g/mol.
    /// EV = 356.5 g/mol → EWF = 272.4/356.5 ≈ 0.764
    /// EC = 396.6 g/mol → EWF = 272.4/396.6 ≈ 0.687
    var esterWeightFactor: Double {
        switch self {
        case .valerate: return 0.764
        case .cypionate: return 0.687
        case .oral: return 1.0      // oral is already base E2 (no ester cleavage needed)
        case .transdermal: return 1.0 // transdermal is base E2
        }
    }

    /// Route-specific bioavailability (fraction of administered dose reaching systemic circulation).
    /// Injectable depot: near-complete absorption from oil depot → F ≈ 1.0
    /// Oral: extensive first-pass metabolism → F ≈ 0.05
    /// Transdermal: skin barrier limits absorption → F ≈ 0.10–0.20
    var bioavailability: Double {
        switch self {
        case .valerate: return 1.0
        case .cypionate: return 1.0
        case .oral: return 0.05
        case .transdermal: return 0.15
        }
    }

    /// Combined effective dose factor = EWF × bioavailability.
    /// Converts administered mg of ester → systemic mg of active estradiol.
    var effectiveDoseFactor: Double {
        return esterWeightFactor * bioavailability
    }

    /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
    /// expected peak levels for a reference dose. Calibrated from published PK data
    /// (Düsterberg et al., Tiong et al.) so that a 2 mg dose yields the clinically
    /// observed peak E2 concentration. Recalibrated 2026‑06‑30.
    ///   - EV 2 mg → peak E2 ~250 pg/mL  (S = 3150)
    ///   - EC 2 mg → peak E2 ~180 pg/mL  (S = 2700)
    ///   - Oral 2 mg → peak E2 ~60 pg/mL (S = 1250)
    ///   - TD 1 mg → steady E2 ~50 pg/mL (S = 155)
    ///
    /// Re‑recalibrated 2026‑07‑28 (QA pass): `.oral` and `.transdermal` were
    /// previously 12000 / 8000. Those values were never actually validated end
    /// to end — a separate bug in `estimatedLevels()` routed all non‑injectable
    /// dose contributions through a code path that ignored `scalingConstant`
    /// entirely, so oral/transdermal predictions were silently flat at
    /// baseline regardless of dose. Now that the routing bug is fixed
    /// (MedicationManager+Pharmacokinetics.swift), the old constants would
    /// overshoot the documented targets by ~9.6× (oral) and ~52× (transdermal).
    /// These values were re‑derived numerically so the documented targets above
    /// are actually reproduced by the corrected code path. See
    /// `.pk_analysis/run_scenarios.py` for the derivation.
    ///
    /// **Re‑anchored 2026‑07‑29 (injectables only).** The single‑dose targets listed
    /// above are not reachable simultaneously with the published steady‑state curve:
    /// EV 2 mg → 250 pg/mL is 2.1× and EC 2 mg → 180 pg/mL is 3.1× the corresponding
    /// transfemscience.org Table 9 figures. Holding them put steady state ~+110% (EV)
    /// and ~+206% (EC) above Table 10. EV and EC are therefore now anchored to the
    /// published *steady‑state* peak (5 mg weekly: EV 384, EC 339 pg/mL), which the
    /// model reproduces to within 0.0% on both Cmax and Cmin. Single‑dose Cmax is now
    /// a derived value: EV 2 mg → ~119 pg/mL, EC 2 mg → ~59 pg/mL.
    ///
    /// Note this also corrects a latent inconsistency: at S = 2700 the shipped EC
    /// constant produced 51 pg/mL for a 2 mg dose, not the 180 pg/mL its own comment
    /// claimed (−71.5%). Every other ester matched its stated target to within 0.1%.
    ///
    /// Oral and transdermal are unchanged — they are elimination‑dominated, already
    /// validated end to end, and have no flip‑flop identifiability problem.
    /// See `.pk_analysis/fit_constants.py`.
    var scalingConstant: Double {
        switch self {
        case .valerate: return 396.4
        case .cypionate: return 273.0
        case .oral: return 1250.0
        case .transdermal: return 155.0
        }
    }

    /// DEPRECATED — kept for backward compatibility during migration.
    /// Use effectiveDoseFactor instead.
    var potencyFactor: Double {
        return effectiveDoseFactor
    }
}

// MARK: - Testosterone Esters

enum TestosteroneEster: String, CaseIterable {
    case cypionate = "Cypionate (TC)"
    case enanthate = "Enanthate (TE)"
    case propionate = "Propionate (TP)"
    case undecanoate = "Undecanoate (TU)"

    var halfLifeDays: Double {
        switch self {
        case .cypionate: return 8.0
        case .enanthate: return 7.0
        case .propionate: return 1.0
        case .undecanoate: return 20.0
        }
    }

    /// Terminal half-life (days) is the effective clinical half-life.
    /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).

    // MARK: Deliberately NOT recalibrated (2026‑07‑29)
    //
    // The estrogen esters were refit on this date so Tmax and steady-state trough
    // match published curves (see MedicationEster above). The same treatment was
    // scoped for testosterone and then **deliberately not applied**, because the
    // evidence base did not support it. Recording why, so this isn't re-litigated:
    //
    //  1. TC has no usable published weekly-IM steady-state Cmax/Cmin pair. What
    //     exists is a single-dose study (200 mg IM, n=11 hypogonadal men, Cmax
    //     1112±297 ng/dL) and the Endocrine Society trough target of 400–700 ng/dL
    //     measured one week post-dose. Neither pins `ka`.
    //
    //  2. **The Tmax target currently encoded in `.pk_analysis/run_scenarios.py`
    //     for TC (1.0–2.0 d, cited as "24-48h") looks wrong.** That figure appears
    //     to describe when levels rise into the supraphysiologic range, not when
    //     they peak — the measured Cmax in the study above falls on **day 4–5**.
    //     Fitting `ke` to the encoded window would bake in a ~3-day error. Resolve
    //     this before any TC refit.
    //
    //  3. TE does have a usable steady-state profile (100 mg/week, week 6:
    //     Cmax 1427, Cmin 584, Cavg 895.5 ng/dL, Tmax 33.9 h → Cmin/Cmax ≈ 0.409)
    //     — but it is **subcutaneous**, and SC absorbs more slowly and flatter than
    //     the IM route modeled here, so its `ka` does not transfer unjustified.
    //
    //  4. Both sources are paywalled (Wiley / ScienceDirect). The figures above come
    //     from secondary summaries, not primary tables. That is below the bar for
    //     constants in a health app — verify against the papers before using them.
    //
    // Net effect: TC/TE/TP/TU keep the 2 h `ke` below, and therefore still
    // underestimate Tmax (~0.55 d modeled vs 1.5–7 d published). This is a known,
    // accepted gap — not an oversight.

    /// Elimination half-life of free testosterone (hours) — used for Bateman ke parameter.
    /// Free T is cleared rapidly (~2 hrs); depot absorption dominates the terminal slope.
    ///
    /// NOTE: as with estradiol, this is an *apparent* constant, and pinning it to a
    /// physiological 2 h forces Tmax to ~0.55 d for every T ester regardless of ester.
    /// See the "Deliberately NOT recalibrated" note above for why it is unchanged.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .cypionate: return 2.0
        case .enanthate: return 2.0
        case .propionate: return 2.0
        case .undecanoate: return 2.0
        }
    }

    /// Ester Weight Factor (EWF) — mg of active testosterone per mg of ester.
    /// Calculated from molecular weights: T base = 288.4 g/mol.
    /// TC = 412.6 g/mol → EWF = 288.4/412.6 ≈ 0.699
    /// TE = 400.6 g/mol → EWF = 288.4/400.6 ≈ 0.720
    /// TP = 344.5 g/mol → EWF = 288.4/344.5 ≈ 0.837
    /// TU = 456.7 g/mol → EWF = 288.4/456.7 ≈ 0.631
    var esterWeightFactor: Double {
        switch self {
        case .cypionate: return 0.699
        case .enanthate: return 0.720
        case .propionate: return 0.837
        case .undecanoate: return 0.631
        }
    }

    /// Route-specific bioavailability for injectable testosterone esters.
    /// Depot injection → near-complete systemic absorption, F ≈ 1.0
    var bioavailability: Double {
        return 1.0  // all T esters here are injectable
    }

    /// Combined effective dose factor = EWF × bioavailability.
    var effectiveDoseFactor: Double {
        return esterWeightFactor * bioavailability
    }

    /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
    /// expected peak levels for a reference dose. Calibrated from published PK data:
    ///   - TC 100 mg → peak T ~600–900 ng/dL   [well anchored]
    ///   - TE 100 mg → peak T ~600–900 ng/dL   [well anchored]
    ///   - TP 50 mg  → peak T ~800–1200 ng/dL  [LOW CONFIDENCE — internally
    ///     consistent estimate; published TG pharmacokinetic data is sparse]
    ///   - TU 1000 mg → peak T ~400–700 ng/dL  [LOW CONFIDENCE — single-source]
    ///
    /// TU is **not** the flat profile this comment previously claimed. A two-parameter
    /// Bateman over a 70-day interval produces a peak/trough ratio of ~11×, where the
    /// real drug is ~2–3×. The 2-param model structurally cannot represent that
    /// flatness; a genuine fit needs a 3-parameter or population-PK model. Logged as a
    /// future enhancement — deliberately not attempted here.
    ///
    /// The TU target range above (400–700 ng/dL) also sits well below the ~1100 ng/dL
    /// Cmax reported for a single 1000 mg injection (Wang et al. 2010). The range may
    /// be describing an intended steady-state trough rather than a single-dose peak.
    /// Flagged for product/clinical confirmation; deliberately NOT changed here.
    /// Used in the Bateman biexponential to convert mg → concentration.
    ///
    /// Recalibrated 2026‑07‑28 (QA pass): the previous values (11 / 11 / 18 / 5)
    /// were miscalibrated by ~20–98×. Under flip‑flop kinetics the Bateman
    /// "shape factor" ka/(ka−ke)·(e^(−ke·t) − e^(−ka·t)) evaluated at t_max is
    /// small (~0.01 for these esters) — the estrogen esters' constants correctly
    /// account for this, but these testosterone constants did not, so a 100 mg
    /// TC dose previously produced a peak of ~8 ng/dL instead of ~750 ng/dL
    /// (>99% below both the target above and this file's own unit tests in
    /// xTTests/PharmacokineticTests.swift, which assert 400–1200 ng/dL for a
    /// 100 mg TC dose). Values re‑derived numerically to reproduce the targets
    /// above; see `.pk_analysis/run_scenarios.py` for the derivation.
    var scalingConstant: Double {
        switch self {
        case .cypionate: return 1081.0
        case .enanthate: return 923.0
        case .propionate: return 359.0
        case .undecanoate: return 214.0
        }
    }

    /// DEPRECATED — kept for backward compatibility during migration.
    /// Use effectiveDoseFactor instead.
    var potencyFactor: Double {
        return effectiveDoseFactor
    }
}
// MARK: - Model Constants

/// Named constants for the pharmacokinetic and scheduling model.
///
/// These values were previously written as bare literals inside
/// `MedicationManager+Pharmacokinetics.swift`, `+Dosing.swift` and `+Schedule.swift`,
/// in several cases duplicated across files with values that had drifted apart.
/// Collecting them here makes the model's assumptions reviewable in one place and
/// gives the unit tests a symbol to assert against instead of a magic number.
enum PKConstants {

    // MARK: Endogenous suppression

    /// Weeks of continuous HRT after which endogenous production is treated as fully
    /// suppressed and the dynamic baseline stops decaying.
    static let fullSuppressionWeeks = 104

    /// Exponential decay rate applied to the endogenous baseline as suppression
    /// progresses. Larger values suppress faster.
    static let suppressionTaperRate = 2.5

    /// Fraction of administered testosterone modeled as aromatizing to estradiol.
    static let aromatizationFraction = 0.002

    // MARK: Safety thresholds

    /// Estradiol (pg/mL) above which a level is flagged as high / very high.
    static let estradiolHighThreshold = 1000.0
    static let estradiolVeryHighThreshold = 1500.0

    /// Estradiol (pg/mL) below which a level is flagged as low / very low.
    static let estradiolLowThreshold = 80.0
    static let estradiolVeryLowThreshold = 50.0

    // MARK: Oral & transdermal kinetics

    /// First-order absorption rate constant for oral administration (per day).
    static let oralAbsorptionRate = 2.5

    /// Elimination rate constant for oral administration (per day), equivalent to a
    /// ~12-hour half-life (`log(2) / 0.5`).
    static let oralEliminationRate = 1.386

    /// Absorption half-life for transdermal administration, in days. Matches
    /// `MedicationEster.transdermal.halfLifeDays`.
    static let transdermalAbsorptionHalfLifeDays = 1.5

    /// Number of micro-doses a single transdermal application is expanded into when
    /// integrating the model, one per hour of the application day.
    static let transdermalMicroDoseCount = 24

    // MARK: Scheduling windows

    /// Rolling window, in days, over which the adherence rate is computed.
    static let adherenceWindowDays = 30

    /// Default grace period, in hours, before a dose counts as missed.
    static let missedDoseGraceHours = 12.0

    /// Grace window for on-time streak accounting: tighter for daily regimens.
    static let onTimeGraceHoursDaily = 12.0
    static let onTimeGraceHoursPeriodic = 24.0

    /// A blood test older than this many days is no longer considered representative
    /// when suggesting the next draw.
    static let bloodTestRelevanceDays = 75

    /// How far ahead scheduled doses are projected, in days.
    static let scheduleLookaheadDays = 90

    // MARK: Volume & syringe sizing

    /// Injection volumes below this (mL) cannot be measured reliably on a standard syringe.
    static let minMeasurableVolumeMl = 0.1

    /// Injection volume (mL) above which a single intramuscular site is discouraged.
    static let highVolumeWarningMl = 2.5

    /// Injection volume (mL) treated as unsafe for a single site.
    static let maxVolumePerSiteMl = 4.5

    /// Barrel sizes (mL) offered when recommending a syringe, smallest first.
    static let syringeSizesMl: [Double] = [0.3, 1.0, 3.0]

    // MARK: Reference dosing

    /// Reference dose (mg) and concentration (mg/mL) used to normalize relative dose
    /// intensity for estrogen valerate.
    static let referenceEstrogenDoseMg = 2.0
    static let referenceEstrogenConcentrationMgPerMl = 40.0
}
