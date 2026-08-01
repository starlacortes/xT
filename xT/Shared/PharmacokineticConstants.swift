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

    /// The chemical esters a user can pick when the route is Injectable. `.oral` and
    /// `.transdermal` are route pseudo-esters resolved from the dose's administration
    /// method (see `MedicationManager.effectiveEsterName`), never chosen as an ester.
    static var injectableCases: [MedicationEster] {
        [.valerate, .cypionate]
    }

    /// Apparent terminal half-life (days) — sets the Bateman `ka` (ka = ln2 / halfLifeDays).
    /// Under flip-flop kinetics for depot esters this is the absorption-limited terminal
    /// slope, and it is what governs the entire inter-dose peak→trough decay.
    ///
    /// Recalibrated 2026‑07‑29: EV 2.0 → 2.60 d and EC 8.5 → 6.47 d, fit so the modeled
    /// steady-state trough reproduces transfemscience.org Table 10 (5 mg weekly). The
    /// previous values undershot the published trough by 45% (EV) and 31% (EC).
    /// Oral/transdermal are elimination-dominated and were left as-is (already validated).
    /// See `.pk_analysis/fit_constants.py`.
    ///
    /// **`.oral` restated 2026‑07‑31: 0.5 → 0.2773 d. This is not a recalibration —
    /// it is a no-op that makes the constant honest.** `estimatedLevels()` never read
    /// this value for oral doses; it hardcoded `oralKa = 2.5` and `oralKe = 1.386`
    /// inline, and `scalingConstant` 1250 was fit against *those* rates. Now that the
    /// engine resolves oral rates from this enum (so testosterone can have its own —
    /// see `TestosteroneEster.oral`), the stored value has to reproduce what the
    /// engine actually used: ln2/2.5 = 0.2773 d. Every oral E2 prediction is
    /// bit-identical before and after. The old 0.5 d was the *elimination* half-life,
    /// which lives in `eliminationHalfLifeHours` (12.0 h) where the engine looks for it.
    var halfLifeDays: Double {
        switch self {
        case .valerate: return 2.60
        case .cypionate: return 6.47
        case .oral: return 0.2773      // ka = ln2/0.2773 = 2.5 /day (was inline in the engine)
        case .transdermal: return 1.5  // ka = ln2/1.5 — already matched the engine's inline value
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
    /// **`.oral` restated 2026‑07‑31: 3.0 → 12.0 h — again a no-op, not a refit.**
    /// See the note on `halfLifeDays`. ln2/(12.0035/24) = 1.386 /day, exactly the
    /// `oralKe` the engine previously hardcoded. The old 3.0 h was never read.
    ///
    /// `.transdermal` is unused: the transdermal route is modeled as 24 hourly
    /// micro-doses with ke = 0 (single-exponential), so no `ke` is derived from it.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .valerate: return 21.5
        case .cypionate: return 38.6
        case .oral: return 12.0035     // ke = 1.386 /day (was inline in the engine)
        case .transdermal: return 3.0  // unused — transdermal micro-doses set ke = 0
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

    /// Typical dosing interval in days, used only to project a forward trajectory when
    /// the user has logged a single dose and set no custom frequency. See
    /// `TestosteroneEster.typicalIntervalDays` for why this is per-ester and not
    /// per-route.
    var typicalIntervalDays: Int {
        switch self {
        case .valerate, .cypionate: return 7
        case .oral, .transdermal: return 1
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
    case oral = "Oral"
    case transdermal = "Transdermal"

    /// The two non-injectable cases are route pseudo-esters, mirroring
    /// `MedicationEster.oral` / `.transdermal`. They are resolved from the dose's
    /// administration method (see `MedicationManager.effectiveEster`), never chosen
    /// as an injectable ester — `injectableCases` is what the UI should offer.
    static var injectableCases: [TestosteroneEster] {
        [.cypionate, .enanthate, .propionate, .undecanoate]
    }

    /// Apparent terminal half-life (days) — sets the Bateman `ka` (ka = ln2 / halfLifeDays).
    /// This is the SLOW constant and governs the whole inter-dose decay.
    ///
    /// **TC recalibrated 2026‑07‑31** from 8.0 → 3.839 d. Derived from the primary
    /// population-PK source (Bi et al. 2018, Table 2): CL/F 2.6 kL/day ÷ V/F 14.4 kL
    /// = 0.1806 /day → t½ 3.839 d. The paper's own median post hoc estimate is 4.05 d
    /// (5.2% agreement).
    ///
    /// Note this is deliberately NOT the ~7–8 d figure commonly quoted for TC. Bi
    /// addresses that discrepancy directly: noncompartmental analysis yields 6.9 d,
    /// and their own model yields 6.87 d *when endogenous testosterone secretion is
    /// assumed to be zero*, but 4.05 d once endogenous production is properly
    /// accounted for. xT models endogenous production separately as `baseLevel`, so
    /// the value that belongs here is the exogenous-only figure. See
    /// `.pk_analysis/fit_testosterone.py`.
    ///
    /// **Consequence, flagged deliberately:** TC (3.84 d) is now shorter than TE
    /// (7.0 d), inverting the previous ordering, even though the two are clinically
    /// near-interchangeable. This is an artifact of TC being the only ester with a
    /// primary-source refit — not a claim that TC clears twice as fast as TE. TE/TP/TU
    /// remain uncalibrated; see the note below and OPEN_CONCERNS.md §3.
    var halfLifeDays: Double {
        switch self {
        case .cypionate: return 3.839
        case .enanthate: return 7.0
        case .propionate: return 1.0
        case .undecanoate: return 20.0
        case .oral: return 0.09          // Jatenzo, fit to Tmax 3 h + Cavg
        case .transdermal: return 0.5784 // AndroGel washout: 5% remaining at 60 h
        }
    }

    /// Terminal half-life (days) is the effective clinical half-life.
    /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).

    // MARK: Calibration status by ester (updated 2026‑07‑31)
    //
    // TC was refit on 2026‑07‑31 once the primary source became available
    // (Bi et al. 2018, doi 10.1002/psp4.12287 — the paper OPEN_CONCERNS.md §3 was
    // blocked on). Oral and transdermal testosterone were added at the same time to
    // close a live 1000×-overprediction defect (see `scalingConstant` below).
    //
    // TE / TP / TU remain UNCALIBRATED and keep the fixed 2 h `ke`, so they still
    // peak at ~0.55 d against published windows of 1.5–7 d. Why they were left:
    //
    //  1. TE's usable steady-state profile (100 mg/week, week 6: Cmax 1427,
    //     Cmin 584, Cavg 895.5 ng/dL, Tmax 33.9 h) is **subcutaneous**, and SC
    //     absorbs more slowly and flatter than the IM route modeled here, so its
    //     `ka` does not transfer without justification.
    //  2. That figure also comes from a secondary summary, not the primary table.
    //  3. TP has sparse published PK data; TU needs a structurally different model
    //     (see §4 note on `scalingConstant`), not merely different constants.
    //
    // RESOLVED 2026‑07‑31 — the former item 2 of this note claimed the encoded TC
    // Tmax window (1.0–2.0 d) "looks wrong" because a secondary source put Cmax at
    // day 4–5. Bi et al. Table 2 gives Ka = 1.22 /day against a disposition rate of
    // 0.1806 /day, i.e. Tmax = ln(ka/ke)/(ka−ke) = 1.84 d — inside the encoded
    // window. Propagating the published 95% CI on Ka (0.785–2.67) gives a Tmax band
    // of 1.08–2.43 d, which never reaches day 4–5. The encoded window stands; the
    // day 4–5 claim does not. Note Bi's own limitation statement (1–2 absorption-
    // phase samples per subject, Ka RSE 44.9%) explains why that estimate is
    // imprecise, so TC Tmax should be read as 1.84 d ± ~0.7 d.

    /// The FAST Bateman constant — `ke = ln2 / (eliminationHalfLifeHours / 24)`.
    ///
    /// For TE/TP/TU this remains the physiological ~2 h clearance of free
    /// testosterone, which forces Tmax to ~0.55 d regardless of ester (see the
    /// calibration-status note above).
    ///
    /// **TC recalibrated 2026‑07‑31** from 2.0 → 13.64 h, from Bi et al.'s
    /// Ka = 1.22 /day (t½ = ln2/1.22 = 0.568 d = 13.64 h). Under flip-flop kinetics
    /// the assignment of "absorption" vs "elimination" to the two exponentials is
    /// ambiguous — Bi says so explicitly — but the Bateman is symmetric in Tmax
    /// under that swap and the amplitude difference is absorbed into `scalingConstant`,
    /// so the observable curve is unaffected by which label we attach.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .cypionate: return 13.64
        case .enanthate: return 2.0
        case .propionate: return 2.0
        case .undecanoate: return 2.0
        case .oral: return 2.003     // Jatenzo, fit jointly with halfLifeDays to Tmax 3 h
        case .transdermal: return 0  // single-exponential route; ke is unused
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
        case .oral: return 0.631        // oral TU is the undecanoate ester
        case .transdermal: return 1.0   // gel delivers unesterified testosterone
        }
    }

    /// Route-specific bioavailability (fraction of the administered dose reaching
    /// systemic circulation).
    ///
    /// Transdermal F = 0.10 is stated outright by the AndroGel 1% label §12.3:
    /// "Approximately 10% of the testosterone dose applied on the skin surface
    /// from AndroGel is absorbed into systemic circulation."
    ///
    /// Oral F is set to 1.0 because absolute oral-TU bioavailability is not
    /// established in the source. F and `scalingConstant` are confounded — only
    /// their product is identified by the published data — so folding F into S
    /// avoids inventing a number. Predictions are unaffected by the split.
    var bioavailability: Double {
        switch self {
        case .cypionate, .enanthate, .propionate, .undecanoate:
            return 1.0   // depot IM: near-complete absorption from the oil depot
        case .oral:
            return 1.0   // see note above — folded into scalingConstant
        case .transdermal:
            return 0.10  // AndroGel 1% label §12.3
        }
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
    /// **TC re-derived 2026‑07‑31, analytically rather than by curve-fit.** Matching
    /// the app's expression to the true one-compartment model gives a closed form:
    ///
    ///     S = 1e5 · Ka / (V_L · EDF · ke)
    ///       = 1e5 · 1.22 / (14400 · 0.699 · 0.180556) = 67.13
    ///
    /// (1e5 converts mg/L → ng/dL; EDF appears because the app multiplies the dose
    /// by it while Bi's V/F already absorbs ester conversion.) This reproduces Bi's
    /// population model exactly. Independent check not used in the fit: a single
    /// 100 mg dose gives Cmax 498 ng/dL at 1.84 d, against 556 ng/dL implied by the
    /// 200 mg IM single-dose literature figure scaled linearly — 10.4% agreement.
    /// At weekly 100 mg the model gives 736 peak / 321 trough ng/dL exogenous;
    /// adding Bi's own basal-secretion floor (b_base 6.24 mg/day ÷ CL = 240 ng/dL,
    /// which xT models separately as `baseLevel`) gives 976 / 561 against the
    /// ~1100–1200 peak visible in Bi Figure 2's 100 mg intensive panel.
    ///
    /// **Oral and transdermal added 2026‑07‑31 — these close a live defect.**
    /// Before this, `estimatedLevels` looked up the route scaling constant behind a
    /// `medication == "Estrogen"` guard, so a testosterone dose on the Oral or Cream
    /// route fell through to the hardcoded literals 12000.0 / 8000.0. Those are the
    /// pre-2026‑07‑28 estrogen values that this file already documents as ~9.6× and
    /// ~52× too large *for estrogen*. Applied to testosterone they produced roughly
    /// **1100× overprediction**: a 50 mg/day testosterone gel dose returned about
    /// 610,000 ng/dL against a clinical expectation near 550, and 200 mg oral TU
    /// returned about 727,000 ng/dL. Both routes are reachable from the UI.
    ///
    ///   - Transdermal S = 132.98, anchored to AndroGel 1% label Table 5,
    ///     50 mg/day → Cavg 555 ng/dL (Day 180 steady state, n=44).
    ///   - Oral S = 13.57, anchored to Jatenzo 237 mg BID → Cavg 489 ng/dL.
    ///
    /// Two limitations are documented rather than fitted around, both structural:
    ///   * The transdermal model (24 hourly micro-doses, no absorption phase) tops
    ///     out at Cmax/Cmin ≈ 1.05 against an observed 2.24 — it under-predicts
    ///     intraday ripple. Reproducing 2.24 would need a ~1 h half-life, which
    ///     contradicts the label's own 48–72 h washout by an order of magnitude.
    ///   * Transdermal dose-response in the source is markedly sublinear
    ///     (50→555, 75→601, 100→713 ng/dL), and the 1.62% label shows the same
    ///     inversion (81 mg Cavg 537 < 60.75 mg Cavg 643). That is a titration
    ///     artifact — higher-dose arms are enriched for poor absorbers — not
    ///     saturable PK. S is anchored to the 50 mg group, the standard starting
    ///     dose and least selection-confounded arm; predictions at 75/100 mg
    ///     therefore run high by ~39% / ~56%.
    ///   * Oral TU: with Tmax pinned to the reported 2–4 h, the model's achievable
    ///     Cmax/Cavg tops out at 1.61 against a reported 2.06, so peak fluctuation
    ///     is under-predicted (789 vs 1008 ng/dL). The reported ratio is itself
    ///     inflated by mean-of-maxima bias (Cmax SD ±581 on a mean of 1008).
    ///
    /// **TE / TP / TU corrected 2026‑07‑31 to 457.67, by conservation of mass.**
    ///
    /// This is not a curve fit and it needed no new source — it follows from the TC
    /// refit plus one identity. Integrating the app's own expression over a dosing
    /// interval and applying superposition gives a steady-state average of
    ///
    ///     Cavg = Dose · EDF · S / (τ · ke)
    ///
    /// because ∫₀^∞ (ka/(ka−ke))(e^(−ke·t) − e^(−ka·t)) dt = 1/ke exactly. The true
    /// value is Cavg = (mg of testosterone per day) / CL, and CL is a property of
    /// *testosterone*, not of the ester attached to it. Equating the two, EWF cancels:
    ///
    ///     S = 1e5 · ke / (CL_T · F),   CL_T = 1817.4 L/day = Bi's CL/F 2600 × EWF_TC
    ///
    /// So S is fixed by `ke` and clearance alone. Since TE, TP and TU all still carry
    /// the same 2 h `ke`, they all take the same S = 1e5 × 8.3178 / 1817.4 = 457.67.
    /// TC satisfies this identity already (implied 67.11 vs the encoded 67.13), which
    /// is the check that the identity and the analytic TC fit agree.
    ///
    /// What was wrong: the previous values were mutually inconsistent, spanning 0.47×
    /// to 2.02× of the implied value, so the app told users on different esters
    /// different things about the same clearance. Steady-state effect at typical doses
    /// (exogenous only; the app adds `baseLevel` on top):
    ///
    ///     TE 100 mg q7d   Cavg 1141 → 566 ng/dL,  Cmax 1513 → 750
    ///     TP  50 mg q2d   Cavg  903 → 1151,       Cmax 1367 → 1743
    ///     TU 1000 mg q70d Cavg  232 → 496,        Cmax  603 → 1290
    ///
    /// TE is the clearest gain: it was contradicting its primary-sourced sibling TC by
    /// 2× despite the two being clinically near-interchangeable, and the corrected
    /// 100 mg/week profile (peak ≈ 750, trough ≈ 397 exogenous) matches published TE.
    ///
    /// TU's Cavg improves but its Cmax now overshoots, because correcting the magnitude
    /// cannot correct the shape: the 2-parameter Bateman gives TU a peak/trough of ~11×
    /// where the real drug is ~2–3×. That is the structural limitation recorded above
    /// and in OPEN_CONCERNS.md §4, and it is unchanged by this correction.
    ///
    /// The single-dose peak targets listed at the top of this comment are therefore now
    /// *derived*, not enforced — the same trade the EV/EC re-anchoring made on
    /// 2026‑07‑29, and for the same reason: single-dose and steady-state targets are not
    /// simultaneously reachable in a 2-parameter model, and steady state is what users
    /// actually live at. TE/TP/TU `ka` values remain uncalibrated, so their *shape*
    /// (Tmax ≈ 0.3–0.7 d against published windows of 1.5–7 d) is still wrong.
    /// See OPEN_CONCERNS.md §3.
    ///
    /// See `.pk_analysis/fit_testosterone.py` for the full reproducible derivation and
    /// `.pk_analysis/verify_constants.py` for the identity check.
    var scalingConstant: Double {
        switch self {
        case .cypionate: return 67.13
        case .enanthate: return 457.67
        case .propionate: return 457.67
        case .undecanoate: return 457.67
        case .oral: return 13.57
        case .transdermal: return 132.98
        }
    }

    /// Typical dosing interval in days, used only to project a forward trajectory when
    /// the user has logged a single dose and set no custom frequency.
    ///
    /// Added 2026‑07‑31. That projection previously took its interval from the
    /// *administration method*, which returns 7 days for everything injectable. For TC
    /// and TE that is right. For TU — dosed every 10–14 weeks — it meant a user with one
    /// logged 1000 mg dose saw a projection built from weekly 1000 mg injections,
    /// reaching ~2850 ng/dL where a single dose reaches ~1190. TP, dosed every other
    /// day, was under-projected for the mirror-image reason. Neither is a modeling
    /// error; both are the chart answering a question the user did not ask.
    ///
    /// A user-set `customFrequencyDays` still wins over this. These are conventional
    /// starting intervals, not recommendations.
    var typicalIntervalDays: Int {
        switch self {
        case .cypionate, .enanthate: return 7
        case .propionate: return 2       // typically every other day
        case .undecanoate: return 70     // 10 weeks; label intervals run 10–14
        case .oral, .transdermal: return 1
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
