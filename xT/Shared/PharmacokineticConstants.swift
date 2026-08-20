//
//  PharmacokineticConstants.swift
//  xT
//
//  Extracted from MedicationManager.swift — Step 4 of refactor-proposal-v2.
//  Contains the medication ester enums and their pharmacokinetic properties.
//

import Foundation

// MARK: - Shared PK Formulas

/// Exact Bateman time to peak, in days: `t_max = ln(ka/ke) / (ka − ke)`.
/// Shared by `MedicationEster.timeToPeakDays` and `TestosteroneEster.timeToPeakDays`,
/// which previously carried two copies of the formula. With
/// `eliminationHalfLifeHours == 0` (transdermal) `ke` is infinite and the result
/// is NaN — that is intentional; see `timeToPeakDays` on each enum.
private func batemanTmaxDays(halfLifeDays: Double, eliminationHalfLifeHours: Double) -> Double {
    let ka = log(2) / halfLifeDays
    let ke = log(2) / (eliminationHalfLifeHours / 24.0)
    guard abs(ka - ke) > 0.0001 else { return 1.0 / ka }
    return log(ka / ke) / (ka - ke)
}

/// Combined effective dose factor = ester weight factor × bioavailability.
/// Converts administered mg of ester → systemic mg of active hormone. Shared by
/// both ester enums; the deprecated `potencyFactor` aliases were removed.
private func combinedDoseFactor(esterWeightFactor: Double, bioavailability: Double) -> Double {
    esterWeightFactor * bioavailability
}

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
    /// **`.oral` restated 2026‑07‑31: 0.5 → 0.2773 d. This was not a recalibration —
    /// it was a no-op that made the constant honest.** `estimatedLevels()` never read
    /// this value for oral doses; it hardcoded `oralKa = 2.5` and `oralKe = 1.386`
    /// inline, and `scalingConstant` 1250 was fit against *those* rates. Once the
    /// engine began resolving oral rates from this enum (so testosterone can have its
    /// own — see `TestosteroneEster.oral`), the stored value had to reproduce what the
    /// engine actually used: ln2/2.5 = 0.2773 d. The old 0.5 d was the *elimination*
    /// half-life, which lives in `eliminationHalfLifeHours` where the engine looks for it.
    ///
    /// **`.oral` refit 2026‑08‑01: 0.2773 → 0.0791 d — a real recalibration, closing
    /// concern #7.** ka = 2.5 /day put Tmax at 12.7 h against a published oral
    /// estradiol Tmax of 4–8 h. Worse, 12.7 h exceeds the 12 h interval of a BID
    /// schedule, so each dose was still rising when the next arrived and the modeled
    /// curve flattened to a peak/trough of ~1.1× across the day. Tmax is now pinned to
    /// **6.0 h**, the midpoint of the published window — no physical principle picks a
    /// point inside 4–8 h, and the sources are secondary, so the midpoint is a stated
    /// choice rather than a fit. Solving ln(ka/ke)/(ka−ke) = 0.25 d on the ka > ke
    /// branch (the formula is symmetric under ka↔ke, so the root must be bracketed)
    /// gives ka = 8.762 /day → ln2/8.762 = 0.0791 d. Modeled BID peak/trough becomes
    /// ~1.37×. `scalingConstant` is deliberately NOT rescaled — see the note there.
    var halfLifeDays: Double {
        switch self {
        case .valerate: return 2.60
        case .cypionate: return 6.47
        case .oral: return 0.0791      // ka = ln2/0.0791 = 8.762 /day → Tmax 6.0 h (concern #7)
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
    /// Unchanged by the 2026‑08‑01 Tmax refit: that moved ka only. Note that at
    /// runtime this ke is scaled by `spiroClearanceFactor` when the user has
    /// spironolactone clearance enabled (see `pkParams` in
    /// `MedicationManager+Pharmacokinetics.swift`), so any Tmax assertion must be
    /// made against the enum or with that setting off.
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

    /// Exact Bateman time to peak, in days: `t_max = ln(ka/ke) / (ka − ke)`.
    ///
    /// This is the single source of truth for time-to-peak.
    /// `MedicationManager.expectedTimeToPeak(for:)` delegates here, and any UI that
    /// wants to show a peak day must read this rather than re-deriving one — the
    /// onboarding ester picker previously carried its own `halfLife × 1.44`
    /// approximation, which ignored `ke` entirely and ran 2–44× long.
    ///
    /// Note this reads the enum's own rates, so it is unaffected by the
    /// spironolactone `ke` scaling the engine applies to the estrogen branch (see
    /// the `eliminationHalfLifeHours` note above) — which is exactly what an
    /// ester-level label wants.
    var timeToPeakDays: Double {
        batemanTmaxDays(halfLifeDays: halfLifeDays,
                        eliminationHalfLifeHours: eliminationHalfLifeHours)
    }

    /// Whether `timeToPeakDays` rests on a primary- or label-anchored fit, and may
    /// therefore be shown to the user as fact.
    ///
    /// All three usable estrogen routes qualify: EV and EC were re-anchored
    /// 2026‑07‑29 against transfemscience Table 10, and oral was refit 2026‑08‑01
    /// to pin Tmax at 6.0 h inside the published 4–8 h window (OPEN_CONCERNS.md §7).
    /// `.transdermal` is false only because it has no meaningful Tmax — it is
    /// modeled as hourly micro-doses with ke = 0, so the Bateman does not apply.
    /// It never reaches the picker, which lists `injectableCases`.
    var isTmaxCalibrated: Bool {
        switch self {
        case .valerate, .cypionate, .oral: return true
        case .transdermal: return false
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
        combinedDoseFactor(esterWeightFactor: esterWeightFactor,
                           bioavailability: bioavailability)
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
    ///
    /// **`.oral` held at 1250 through the 2026‑08‑01 Tmax refit (concern #7) — a
    /// deliberate choice of anchor, and it supersedes the `Oral 2 mg → peak ~60 pg/mL`
    /// line above.** S and ka are coupled through the peak but not through the average:
    /// integrating the Bateman term gives AUC per dose = amount·S/ke exactly, with no ka
    /// in it, so Cavg is invariant to ka while Cmax is not. A single (S, ka) pair cannot
    /// therefore hold both the published Tmax and the published Cmax. Anchoring on Cavg
    /// keeps 2 mg daily at 90 pg/mL — unchanged by the refit, and the quantity clinicians
    /// titrate on — at the cost of single-dose Cmax rising 60 → 88 pg/mL for 2 mg. The
    /// alternative (rescaling S to 848.5 to hold Cmax at 60) would have dropped Cavg to
    /// 61 pg/mL, moving every average and trough number in the app to buy back a
    /// single-dose peak. Same reasoning as the injectable re‑anchor above. The 60 pg/mL
    /// figure is a *single-dose* Cmax: S = 1250 reproduces it to five figures for one
    /// 2 mg dose, which is how the anchor was identified.
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
    /// **Consequence, flagged deliberately:** TC (3.84 d) is shorter than TE (6.6 d)
    /// even though the two are clinically near-interchangeable. That is not an
    /// artifact: Bi's 3.84 d is *exogenous-only* (endogenous secretion modeled
    /// separately, as xT does with `baseLevel`), while Ichihara's 6.6 d is a
    /// total-testosterone terminal half-life measured in a population with roughly
    /// half Bi's clearance. The two numbers answer different questions in different
    /// cohorts; see the magnitude note on `scalingConstant`.
    ///
    /// **TE recalibrated 2026‑08‑02** from 7.0 → 6.6 d, the terminal half-life
    /// reported by Ichihara et al. 2020 (doi 10.1089/andro.2020.0002) — n=10
    /// transgender men, single 250 mg IM, the population this app actually serves,
    /// and the primary IM source OPEN_CONCERNS.md §3 was blocked on. The old 7.0 was
    /// an uncited round number that happened to land within 6% of it.
    ///
    /// TU's 20.0 d is retained: Zhang et al. 1998 measured 18.3 ± 2.3 d (500 mg) and
    /// 23.7 ± 2.7 d (1000 mg), and 20.0 sits inside both. The dose dependence there is
    /// itself a hint that TU's terminal phase is absorption-limited; see the
    /// peak/trough note on `eliminationHalfLifeHours`.
    var halfLifeDays: Double {
        switch self {
        case .cypionate: return 3.839
        case .enanthate: return 6.6     // Ichihara 2020, terminal t½ 6.6 ± 1.9 d
        case .propionate: return 1.0
        case .undecanoate: return 20.0  // Zhang 1998, 18.3 d (500 mg) / 23.7 d (1000 mg)
        case .oral: return 0.09          // Jatenzo, fit to Tmax 3 h + Cavg
        case .transdermal: return 0.5784 // AndroGel washout: 5% remaining at 60 h
        }
    }

    /// Terminal half-life (days) is the effective clinical half-life.
    /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).

    // MARK: Calibration status by ester (updated 2026‑08‑02)
    //
    // TC was refit on 2026‑07‑31 once the primary source became available
    // (Bi et al. 2018, doi 10.1002/psp4.12287 — the paper OPEN_CONCERNS.md §3 was
    // blocked on). Oral and transdermal testosterone were added at the same time to
    // close a live 1000×-overprediction defect (see `scalingConstant` below).
    //
    // TE and TU were refit on 2026‑08‑02 (docs/TESTOSTERONE_ESTER_RESEARCH_MEMO.md).
    // Both now carry a real absorption rate instead of the placeholder 2 h `ke`:
    //
    //  * TE — Ichihara et al. 2020, the IM study in transgender men that the former
    //    item 1 of this note said was missing. It supersedes the *subcutaneous*
    //    steady-state figure that was rejected here for not transferring to IM: this
    //    one is IM, primary, open access, and in the right population.
    //  * TU — Aveed's FDA clinical pharmacology Tmax (median 7 d, range 4–42) over
    //    Zhang 1998's terminal half-life. The former item 3 claimed TU "needs a
    //    structurally different model." That was wrong, and the memo's §2 is the
    //    refutation: every population PK analysis of injectable TU found (Pastuszak
    //    2021; the 2022 J Clin Pharmacol 8-week-interval study) fits it with a
    //    one-compartment first-order-absorption model — the same two-rate-constant
    //    Bateman used here. What remains open for TU is a source conflict about the
    //    terminal half-life, not the number of compartments; see the peak/trough
    //    note on `eliminationHalfLifeHours`.
    //
    // TP remains UNCALIBRATED and keeps the fixed 2 h `ke`, so it still peaks at
    // ~0.55 d against a published window of 1–2 d. Deliberately left: the best source
    // is a textbook chapter (Behre 2004) showing a *simulated* twice-weekly curve, not
    // fitted rate constants or raw single-dose concentration-time data, and the only
    // other figure surfaced is a 1974 three-man series confounded by a mixed TP+TE
    // injection. A fabricated-precision fit would be worse than the honest flag.
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
    /// **This slot holds two different pharmacological quantities. Read before editing.**
    ///
    ///   * **TC (13.64 h)** is Bi et al.'s *absorption* rate Ka = 1.22 /day
    ///     (t½ = ln2/1.22 = 0.568 d = 13.64 h) — depot release from the oil vehicle.
    ///   * **TE (8.4767 h)** is Ichihara 2020's *absorption* rate — the mean of the
    ///     four per-subject ka values the paper could estimate (2.82, 3.16, 0.49,
    ///     1.38 /day → 1.9625 /day, t½ = 8.4767 h). Same quantity as TC's.
    ///   * **TU (44.3883 h)** is a *fitted* depot-release rate, not a reported one:
    ///     0.37477 /day, the value that puts Tmax at Aveed's median 7 d given the
    ///     20 d terminal half-life. See the peak/trough note below.
    ///   * **TP (2.0 h)** is the *physiological clearance* of free testosterone — a
    ///     placeholder, not a depot rate. It forces Tmax to ~0.55 d (see the
    ///     calibration-status note above).
    ///
    /// So the gap between 13.64 and TP's 2.0 is not a claim that TC releases 6.8×
    /// slower than TP. They are answers to different questions, and TP's is a stand-in.
    /// Do **not** "correct" TP's 2.0 toward its siblings to close the gap. When TP is
    /// eventually calibrated, both rates should come from one primary source the way
    /// TC's do from Bi — and `scalingConstant` must be recomputed alongside, since
    /// S is pinned to `ke` by the clearance identity (see `scalingConstant`).
    ///
    /// **TC recalibrated 2026‑07‑31** from 2.0 → 13.64 h.
    /// **TE and TU recalibrated 2026‑08‑02** from 2.0 → 8.4767 h and 44.3883 h.
    /// Effect on Tmax: TE 0.54 → 1.58 d (observed 1.7 ± 0.9 d), TU 0.66 → 7.00 d
    /// (Aveed median 7 d). `scalingConstant` moved with them, as required above.
    ///
    /// **TU's remaining gap is a source conflict, not a missing compartment.**
    /// Wang et al. 2010 report a steady-state peak/trough of 1.8× (789.8 / 435.6
    /// ng/dL at week 12). The model gives 8.1× at 1000 mg q70d — better than the 11×
    /// it gave before this refit, but not close. That is arithmetic, not a modeling
    /// choice: over a 70-day interval a terminal half-life of 20 d is 3.5 half-lives
    /// of decay, so peak/trough cannot fall below ~11× on decay alone (absorption
    /// sustaining the trough is what brings it to 8.1×). Both targets *are* jointly
    /// reachable in this two-rate Bateman — a 73.8 d terminal half-life paired with a
    /// 27.5 h release rate hits Tmax 7 d **and** peak/trough 1.80× — which is
    /// precisely why the old "TU needs a 3-parameter model" claim was wrong. But
    /// 73.8 d is **3.7× what Zhang measured**, in either dose arm. The blocker is that Zhang's
    /// measured terminal half-life and Wang's observed flatness cannot both be true.
    /// Resolving it needs Wang's primary sampling schedule — specifically whether that
    /// week-12 peak/trough pair spans one full inter-dose interval — not a rewrite.
    ///
    /// Note this puts Bi's Ka in *this* slot and Bi's disposition rate CL/V = 0.1806 /day
    /// in `halfLifeDays` — i.e. the app stores them swapped relative to Bi's own labels.
    /// That is xT's modeling choice, not Bi's: Bi identifies Ka as absorption and
    /// CL/V as elimination, and with Ka > CL/V the model is not flip-flop, so no
    /// ambiguity is being invoked here. The swap is harmless because the Bateman is
    /// symmetric in Tmax under it and the amplitude difference is absorbed into
    /// `scalingConstant`, leaving the observable curve unchanged.
    ///
    /// **Consequence for future work:** because the labels are swapped, a drug
    /// interaction that alters testosterone *clearance* must scale the slow rate —
    /// `halfLifeDays` — and NOT this property, which for TC is an absorption rate.
    /// This is the mirror image of how `spiroClearanceFactor` is applied on the
    /// estrogen branch (`MedicationManager+Pharmacokinetics.swift`, `pkParams`),
    /// where the unswapped `ke` genuinely is elimination.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .cypionate: return 13.64
        case .enanthate: return 8.4767   // Ichihara 2020, mean ka 1.9625 /day
        case .propionate: return 2.0     // placeholder — TP is still uncalibrated
        case .undecanoate: return 44.3883 // fit to Aveed Tmax 7.0 d at t½ 20 d
        case .oral: return 2.003     // Jatenzo, fit jointly with halfLifeDays to Tmax 3 h
        case .transdermal: return 0  // single-exponential route; ke is unused
        }
    }

    /// Exact Bateman time to peak, in days: `t_max = ln(ka/ke) / (ka − ke)`.
    ///
    /// Single source of truth for time-to-peak;
    /// `MedicationManager.expectedTimeToPeak(for:)` delegates here. Correct for the
    /// shipped constants in every case — but see `isTmaxCalibrated` before showing
    /// the result to a user, because "correct for the constants" and "correct about
    /// the drug" still diverge for TP.
    ///
    /// **Returns NaN for `.transdermal`**, whose `eliminationHalfLifeHours` is 0 —
    /// that route is modeled as hourly micro-doses with no elimination phase, so
    /// `ke` is infinite and t_max is genuinely undefined rather than merely unknown.
    /// NaN is the honest answer; `isTmaxCalibrated` is false there for the same
    /// reason. Callers that format this into a string must gate on `isFinite`, since
    /// `Int(Double.nan)` traps in Swift.
    var timeToPeakDays: Double {
        batemanTmaxDays(halfLifeDays: halfLifeDays,
                        eliminationHalfLifeHours: eliminationHalfLifeHours)
    }

    /// Whether `timeToPeakDays` rests on a primary- or label-anchored fit, and may
    /// therefore be shown to the user as fact.
    ///
    /// **False for TP alone as of 2026‑08‑02.** It still carries the placeholder 2 h
    /// `ke` above, which puts its computed Tmax at 0.55 d against a published window
    /// of 1–2 d (OPEN_CONCERNS.md §3). Its *magnitude* was fixed by the 2026‑07‑31
    /// clearance identity and its terminal decay is governed by `halfLifeDays`, so
    /// only the first ~24 h of the curve is wrong — but that is precisely where Tmax
    /// lives, so the number must not be presented as a fact about the drug.
    ///
    /// True for TC (Bi et al. 2018, Tmax 1.84 d), TE (Ichihara et al. 2020, modeled
    /// 1.58 d against an observed 1.7 ± 0.9 d), TU (Aveed clinical pharmacology,
    /// modeled 7.00 d against a reported median of 7 d) and oral (Jatenzo label,
    /// Tmax 3 h).
    ///
    /// Note this flag is specifically about *time to peak*. TU's steady-state
    /// peak/trough ratio is still wrong by ~4× and that gap is documented on
    /// `eliminationHalfLifeHours`, but a peak *day* of 7 is now a sourced fact and is
    /// safe to show. If a future UI wants to state TU's peak *height*, it needs its
    /// own flag rather than this one.
    ///
    /// `.transdermal` is false because it has no meaningful Tmax — hourly micro-doses
    /// with ke = 0, so the Bateman does not apply.
    ///
    /// Callers must degrade gracefully rather than hide the ester: see
    /// `OnboardingView.esterList`, which shows half-life and a "calibration pending"
    /// note instead of a peak day.
    var isTmaxCalibrated: Bool {
        switch self {
        case .cypionate, .enanthate, .undecanoate, .oral: return true
        case .propionate: return false
        case .transdermal: return false
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
        combinedDoseFactor(esterWeightFactor: esterWeightFactor,
                           bioavailability: bioavailability)
    }

    /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
    /// expected peak levels for a reference dose. Calibrated from published PK data:
    ///   - TC 100 mg → peak T ~600–900 ng/dL   [well anchored]
    ///   - TE 100 mg → peak T ~600–900 ng/dL   [well anchored]
    ///   - TP 50 mg  → peak T ~800–1200 ng/dL  [LOW CONFIDENCE — internally
    ///     consistent estimate; published TG pharmacokinetic data is sparse]
    ///   - TU 1000 mg → peak T ~400–700 ng/dL  [LOW CONFIDENCE — single-source]
    ///
    /// TU is **not** the flat profile this comment originally claimed, and the reason
    /// given for that (2026‑07‑28: "the 2-param model structurally cannot represent
    /// that flatness; a genuine fit needs a 3-parameter or population-PK model") was
    /// **withdrawn 2026‑08‑02** — it is disproven both by the published pharmacometrics
    /// (Pastuszak 2021 fits IM TU with a one-compartment first-order-absorption model)
    /// and by direct construction (a 73.8 d / 27.5 h pair reproduces Tmax 7 d and
    /// peak/trough 1.80× simultaneously in this very model). The residual 8.1× is a
    /// conflict between two sources' half-lives. See `eliminationHalfLifeHours`.
    ///
    /// The TU target range above (400–700 ng/dL) also sits well below the ~1100 ng/dL
    /// Cmax reported for a single 1000 mg injection (Wang et al. 2010). The range may
    /// be describing an intended steady-state trough rather than a single-dose peak.
    /// Flagged for product/clinical confirmation; deliberately NOT changed here.
    /// (For reference, after the 2026‑08‑02 refit a single 1000 mg dose peaks at
    /// 944 ng/dL exogenous at day 7, down from 1176 at day 0.66.)
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
    /// So S is fixed by `ke` and clearance alone. At the time all three of TE, TP and
    /// TU carried the same 2 h `ke`, so all three took the same S = 1e5 × 8.3178 /
    /// 1817.4 = 457.67. TC satisfies this identity already (implied 67.11 vs the
    /// encoded 67.13), which is the check that the identity and the analytic TC fit
    /// agree.
    ///
    /// **TE → 107.98 and TU → 20.62 on 2026‑08‑02, forced by the `ke` refit.** Not a
    /// new decision — the same identity, re-evaluated at the new rates:
    ///
    ///     TE: 1e5 × 1.9625  / 1817.4 = 107.98
    ///     TU: 1e5 × 0.37477 / 1817.4 =  20.62
    ///
    /// TP keeps 457.67 because it keeps the 2 h `ke`. The three no longer share one S,
    /// and that is correct rather than a regression: they shared it only because they
    /// shared a placeholder. Steady-state Cavg is unchanged for all three by
    /// construction (S/ke is invariant), so this moves shape without moving magnitude:
    ///
    ///     TE 100 mg q7d    Cmax 750 → 703,  Cmin 397 → 405, Cavg 566 (unchanged)
    ///     TU 1000 mg q70d  Cmax 1290 → 1045, Cmin 117 → 129, Cavg 496 (unchanged)
    ///
    /// **Known magnitude discrepancy for TE, documented not fitted.** A single 250 mg
    /// dose gives 881 ng/dL exogenous here against Ichihara's observed Cmax of
    /// 2940 ± 1710 ng/dL. The gap is cohort, not error: Ichihara's own CLtot/F
    /// (14.3 L/day/kg ≈ 930 L/day at 65 kg) is about half the CL_T = 1817.4 L/day this
    /// app inherits from Bi, and their Vd/F (118.7 L/kg ≈ 7700 L) about half Bi's
    /// 14400 L. Adopting Ichihara's clearance for TE would put TE and TC 2× apart on
    /// the *same molecule*, breaking the conservation-of-mass identity that is the only
    /// thing keeping the esters mutually consistent. Magnitude therefore stays anchored
    /// to Bi; only shape was taken from Ichihara. Note their Cmax SD (±1710 on a mean
    /// of 2940, CV 0.58 on Vd/F) is wide enough that the two are not sharply in
    /// conflict at the individual level — this is what the per-user blood-test
    /// calibration factor α exists to absorb.
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
    /// TU's Cavg improves but its Cmax overshoots, because correcting the magnitude
    /// cannot correct the shape. (The 2026‑08‑02 refit narrowed this: peak/trough 11×
    /// → 8.1× against an observed 1.8×. The remainder is the half-life source conflict
    /// on `eliminationHalfLifeHours`, not the compartment count.)
    ///
    /// The single-dose peak targets listed at the top of this comment are therefore now
    /// *derived*, not enforced — the same trade the EV/EC re-anchoring made on
    /// 2026‑07‑29, and for the same reason: single-dose and steady-state targets are not
    /// simultaneously reachable in a 2-parameter model, and steady state is what users
    /// actually live at. As of 2026‑08‑02 only TP's `ka` remains uncalibrated, so only
    /// TP's *shape* (Tmax 0.55 d against a published 1–2 d) is still wrong.
    /// See OPEN_CONCERNS.md §3.
    ///
    /// See `.pk_analysis/fit_testosterone.py` for the full reproducible derivation and
    /// `.pk_analysis/verify_constants.py` for the identity check.
    var scalingConstant: Double {
        switch self {
        case .cypionate: return 67.13
        case .enanthate: return 107.98   // 1e5 × 1.9625 / 1817.4
        case .propionate: return 457.67  // still the placeholder-ke value
        case .undecanoate: return 20.62  // 1e5 × 0.37477 / 1817.4
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
    static let fullSuppressionWeeks = 104.0

    /// Exponential decay rate applied to the endogenous baseline as suppression
    /// progresses. Larger values suppress faster.
    static let suppressionTaperRate = 2.5

    /// Fraction of administered testosterone modeled as aromatizing to estradiol.
    static let aromatizationFraction = 0.002

    // MARK: Safety thresholds

    /// Estradiol (pg/mL) above which a level is flagged as high / very high.
    static let estradiolHighThreshold = 1000.0
    static let estradiolVeryHighThreshold = 1500.0

    /// Testosterone (ng/dL) above which a level is flagged as supraphysiologic.
    /// Kept separate from the estradiol thresholds — the two hormones use
    /// different units and different clinical cutoffs.
    static let testosteroneSupraphysiologicThreshold = 1500.0

    /// Estradiol (pg/mL) below which a level is flagged as low / very low.
    static let estradiolLowThreshold = 80.0
    static let estradiolVeryLowThreshold = 50.0

    // MARK: Drug interactions

    /// Multiplier applied to the estradiol elimination rate (ke) when the user
    /// takes spironolactone and has opted in. Spiro induces CYP3A4, modestly
    /// accelerating E2 clearance — typical estimates run 10–20% faster.
    static let spiroClearanceFactor = 1.15

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
    /// intensity for estrogen valerate and testosterone cypionate.
    ///
    /// These are *population* references — what the published curves are normalized
    /// against — not the dose defaulted into the logging UI (`defaultDoseAmount`).
    static let referenceEstrogenDoseMg = 2.0
    static let referenceTestosteroneDoseMg = 50.0
    static let referenceEstrogenConcentrationMgPerMl = 40.0

    /// The vial strength most commonly stocked for testosterone cypionate (mg/mL),
    /// used as the last-resort concentration default.
    static let referenceTestosteroneConcentrationMgPerMl = 200.0

    /// Dose (mg) pre-filled in the logging UI when no prior dose exists to copy.
    /// Deliberately *not* the population reference above: 40 mg is a common weekly
    /// starting prescription, and what a new user is most likely to actually log.
    static let defaultTestosteroneDoseMg = 40.0

    // MARK: Chart window

    /// Terms of the chart's window rule. See `PKChartWindow` for the derivation and for
    /// why the resulting EV window (3.15 d) reproduces the one that shipped before it.
    ///
    ///     W    = clamp(1.5 · t_max, lower: min(2 d, 2 · interval), upper: 1.5 · interval)
    ///     step = max(min(W/40, t_max/8), 15 min)

    /// Window length as a multiple of the ester's time-to-peak.
    static let chartWindowTmaxMultiplier = 1.5

    /// Ceiling on the window, as a multiple of the dosing interval. Binds for the daily
    /// routes (oral, cream), where it fixes the window at 1.5 d.
    static let chartWindowUpperIntervalMultiplier = 1.5

    /// Floor on the window, in days — itself capped at twice the dosing interval so a
    /// short-interval ester is never given a window wider than two of its own cycles.
    static let chartWindowLowerCapDays = 2.0

    /// Window length used when the ester's t_max cannot be trusted — uncalibrated
    /// (`isTmaxCalibrated == false`) or non-finite (the transdermal routes, which have
    /// no meaningful t_max). Sized to the daily/short-interval case it mostly serves.
    static let chartWindowFallbackRawDays = 2.0

    /// Target point count for the drawn curve: `step = W / 40`. Keeps every ester at a
    /// comparable density so curves read alike across very different timescales.
    static let chartWindowStepDivisor = 40.0

    /// The anti-aliasing guarantee: never sample coarser than `t_max / 8`. This is the
    /// term that stops the oral curve — dosed at exactly the old 1-day step — from
    /// collapsing into a flat line.
    static let chartWindowTmaxStepDivisor = 8.0

    /// Resolution floor for the drawn curve.
    static let chartWindowMinStepDays = 15.0 / (24.0 * 60.0)

    /// The scrub/dot grid is this many times finer than the drawn curve.
    static let chartWindowDenseStepDivisor = 4.0

    /// Resolution floor for the scrub/dot grid.
    static let chartWindowMinDenseStepDays = 5.0 / (24.0 * 60.0)

    /// Smallest dosing interval the window rule will divide by, so a future ester with a
    /// zero or negative interval degrades to a usable window instead of a zero-width one.
    static let chartWindowMinIntervalDays = 0.5
}
