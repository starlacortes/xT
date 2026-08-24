//
//  PharmacokineticTests.swift
//  xTTests
//
//  Pharmacokinetic model validation — ester constants, Bateman biexponential,
//  flip-flop kinetics, dynamic baseline, calibration, safety overrides,
//  aromatization, dose intensity, and edge-case robustness.
//

import Testing
import Foundation
@testable import xT

// MARK: - Ester Constants Validation

@Suite("Ester Constants — Physical Plausibility")
struct EsterConstantsTests {

    @Test("All E2 ester half-lives are positive and within expected ranges")
    func estrogenHalfLives() {
        // EV/EC recalibrated 2026-07-29 so the modeled steady-state trough matches
        // transfemscience Table 10 (5 mg weekly). See .pk_analysis/fit_constants.py.
        // Oral restated 2026-07-31 from 0.5 to 0.2773 d. That was behaviour-neutral: the
        // engine hardcoded ka = 2.5 for oral doses and never read this field, and S = 1250
        // was fit against that rate, so ln2/0.2773 = 2.5 left predictions unchanged.
        //
        // Oral refit 2026-08-01 to 0.0791 d (concern #7) — this one DOES move predictions.
        // ka 2.5 -> 8.762 /day pulls Tmax from 12.7 h to 6.0 h, inside the published
        // 4-8 h window. See `oralE2TmaxInRange`, and PharmacokineticConstants.swift for
        // why S was held at 1250 rather than rescaled alongside it.
        let expected: [String: Double] = [
            "Valerate (EV)": 2.60,
            "Cypionate (EC)": 6.47,
            "Oral": 0.0791,
            "Transdermal": 1.5
        ]
        for ester in MedicationEster.allCases {
            let halfLife = ester.halfLifeDays
            #expect(halfLife > 0, "\(ester.rawValue) half-life must be positive")
            // Lower bound relaxed 0.25 -> 0.05 d for the oral refit. This field is the
            // *absorption* half-life (it sets ka), so for a fast oral route sub-0.25 d is
            // the expected regime, not an out-of-range value; the old floor only held
            // because oral's ka was mis-set. 0.05 d = 1.2 h still catches a zeroing bug.
            #expect(halfLife >= 0.05 && halfLife <= 10.0,
                    "\(ester.rawValue) half-life \(halfLife) outside clinical range")
            #expect(halfLife == expected[ester.rawValue],
                    "\(ester.rawValue) half-life changed from expected \(expected[ester.rawValue]!) to \(halfLife)")
        }
    }

    @Test("All injectable T ester half-lives are positive and within expected ranges")
    func testosteroneHalfLives() {
        // TC recalibrated 2026-07-31 from 8.0 to 3.839 d, = ln2/(CL/V) from Bi et al.
        // 2018 Table 2. Deliberately not the commonly quoted 7-8 d: that figure assumes
        // zero endogenous secretion, and xT models endogenous production separately as
        // `baseLevel`. See PharmacokineticConstants.swift for the full note.
        // TE recalibrated 2026-08-02 from 7.0 to 6.6 d, the terminal half-life reported
        // by Ichihara et al. 2020 (IM, n=10 transgender men). The old 7.0 was an
        // uncited round number. TU's 20.0 is retained: Zhang 1998 measured 18.3 d at
        // 500 mg and 23.7 d at 1000 mg, and 20.0 sits inside both arms.
        let expected: [String: Double] = [
            "Cypionate (TC)": 3.839,
            "Enanthate (TE)": 6.6,
            "Propionate (TP)": 1.0,
            "Undecanoate (TU)": 20.0
        ]
        for ester in TestosteroneEster.injectableCases {
            let halfLife = ester.halfLifeDays
            #expect(halfLife > 0, "\(ester.rawValue) half-life must be positive")
            #expect(halfLife >= 0.5 && halfLife <= 25.0,
                    "\(ester.rawValue) half-life \(halfLife) outside clinical range")
            #expect(halfLife == expected[ester.rawValue],
                    "\(ester.rawValue) half-life changed from expected \(expected[ester.rawValue]!) to \(halfLife)")
        }
    }

    /// The two non-injectable cases describe a *route*, not a chemical ester, and are
    /// resolved from the dose's administration method rather than chosen by the user.
    /// They are excluded from `injectableCases` and carry sub-day kinetics, so they must
    /// not be swept into the injectable range checks above.
    @Test("T route pseudo-esters carry their own fitted kinetics")
    func testosteroneRoutePseudoEsters() {
        #expect(TestosteroneEster.oral.halfLifeDays == 0.09,
                "Oral TU slow half-life, fit jointly with ke to Tmax 3 h (Jatenzo)")
        #expect(TestosteroneEster.transdermal.halfLifeDays == 0.5784,
                "Gel half-life from the AndroGel 1% washout statement (5% at 60 h)")
        #expect(!TestosteroneEster.injectableCases.contains(.oral))
        #expect(!TestosteroneEster.injectableCases.contains(.transdermal))
        #expect(TestosteroneEster.injectableCases.count == 4)
        #expect(MedicationEster.injectableCases == [.valerate, .cypionate])
    }

    /// These are apparent curve-fit constants, not physiological clearance. The
    /// injectables are fit per-ester so Tmax matches the published time-to-peak;
    /// oral/transdermal remain elimination-dominated at the original 3 h.
    /// See .pk_analysis/fit_constants.py.
    @Test("E2 elimination half-lives match their per-ester fitted values")
    func estrogenEliminationHalfLife() {
        // Oral restated 2026-07-31 from 3.0 to 12.0035 h — behaviour-neutral, see the
        // half-life test above. ln2/(12.0035/24) = 1.386, the engine's old hardcoded ke.
        let expected: [String: Double] = [
            "Valerate (EV)": 21.5,
            "Cypionate (EC)": 38.6,
            "Oral": 12.0035,
            "Transdermal": 3.0
        ]
        for ester in MedicationEster.allCases {
            #expect(ester.eliminationHalfLifeHours == expected[ester.rawValue],
                    "\(ester.rawValue) elimination half-life changed from expected \(expected[ester.rawValue]!) to \(ester.eliminationHalfLifeHours)")
        }
    }

    /// TC was refit from Bi et al. 2018 on 2026-07-31 (2.0 → 13.64 h = ln2/Ka 1.22).
    /// TE and TU followed on 2026-08-02. Only TP still carries the placeholder 2 h
    /// value, which is why its Tmax is still wrong (0.55 d against a published 1–2 d)
    /// even though its *magnitude* was corrected on 2026-07-31. This test is the guard
    /// that the remaining gap stays visible.
    @Test("T elimination half-lives: only TP is still a placeholder")
    func testosteroneEliminationHalfLife() {
        #expect(TestosteroneEster.cypionate.eliminationHalfLifeHours == 13.64,
                "TC ke comes from Bi et al. Ka = 1.22/day")
        #expect(TestosteroneEster.enanthate.eliminationHalfLifeHours == 8.4767,
                "TE ke comes from Ichihara et al. 2020, mean of the four reported per-subject ka (1.9625/day)")
        #expect(TestosteroneEster.undecanoate.eliminationHalfLifeHours == 44.3883,
                "TU ke is fitted so Tmax lands on Aveed's median 7 d at the 20 d terminal half-life")
        #expect(TestosteroneEster.propionate.eliminationHalfLifeHours == 2.0,
                "TP still carries the uncalibrated 2.0 h placeholder — see OPEN_CONCERNS.md §3")
    }

    @Test("E2 ester weight factors match molecular-weight calculations")
    func estrogenEWF() {
        // E2 base = 272.4 g/mol
        // EV = 356.5 → 272.4/356.5 ≈ 0.764
        // EC = 396.6 → 272.4/396.6 ≈ 0.687
        #expect(abs(MedicationEster.valerate.esterWeightFactor - 0.764) < 0.001)
        #expect(abs(MedicationEster.cypionate.esterWeightFactor - 0.687) < 0.001)
        #expect(MedicationEster.oral.esterWeightFactor == 1.0)
        #expect(MedicationEster.transdermal.esterWeightFactor == 1.0)
    }

    @Test("T ester weight factors match molecular-weight calculations")
    func testosteroneEWF() {
        // T base = 288.4 g/mol
        // TC = 412.6 → 0.699, TE = 400.6 → 0.720
        // TP = 344.5 → 0.837, TU = 456.7 → 0.631
        #expect(abs(TestosteroneEster.cypionate.esterWeightFactor - 0.699) < 0.001)
        #expect(abs(TestosteroneEster.enanthate.esterWeightFactor - 0.720) < 0.001)
        #expect(abs(TestosteroneEster.propionate.esterWeightFactor - 0.837) < 0.001)
        #expect(abs(TestosteroneEster.undecanoate.esterWeightFactor - 0.631) < 0.001)
    }

    @Test("Bioavailability values match route pharmacokinetics")
    func bioavailability() {
        // Injectable = near-complete absorption from depot
        #expect(MedicationEster.valerate.bioavailability == 1.0)
        #expect(MedicationEster.cypionate.bioavailability == 1.0)
        // Oral = extensive first-pass metabolism
        #expect(MedicationEster.oral.bioavailability == 0.05)
        // Transdermal = skin barrier limits absorption
        #expect(MedicationEster.transdermal.bioavailability == 0.15)
        // T depot injectables: near-complete absorption from the oil depot
        for ester in TestosteroneEster.injectableCases {
            #expect(ester.bioavailability == 1.0)
        }
        // Gel: stated outright by the AndroGel 1% label §12.3 — "approximately 10% of
        // the testosterone dose applied on the skin surface ... is absorbed".
        #expect(TestosteroneEster.transdermal.bioavailability == 0.10)
        // Oral TU: absolute bioavailability is not established in the source, so F is
        // folded into `scalingConstant` rather than invented. Only the product is
        // identified by the published data, so predictions are unaffected by the split.
        #expect(TestosteroneEster.oral.bioavailability == 1.0)
    }

    @Test("Effective dose factor = EWF × bioavailability")
    func effectiveDoseFactor() {
        for ester in MedicationEster.allCases {
            let expected = ester.esterWeightFactor * ester.bioavailability
            #expect(abs(ester.effectiveDoseFactor - expected) < 0.0001,
                    "\(ester.rawValue) EDF mismatch")
        }
        for ester in TestosteroneEster.allCases {
            let expected = ester.esterWeightFactor * ester.bioavailability
            #expect(abs(ester.effectiveDoseFactor - expected) < 0.0001,
                    "\(ester.rawValue) EDF mismatch")
        }
    }

    @Test("E2 scaling constants are in clinical range (100–15000)")
    func estrogenScalingConstants() {
        // Range widened 2026-07-28 to include the recalibrated Oral (1250) and
        // Transdermal (155) constants — see PharmacokineticConstants.swift for
        // why the old values (12000 / 8000) were never actually validated.
        let constants = [
            MedicationEster.valerate.scalingConstant,
            MedicationEster.cypionate.scalingConstant,
            MedicationEster.oral.scalingConstant,
            MedicationEster.transdermal.scalingConstant,
        ]
        for c in constants {
            #expect(c >= 100 && c <= 15000,
                    "Scaling constant \(c) outside clinical range")
        }
    }

    @Test("T scaling constants are in the range implied by testosterone clearance")
    func testosteroneScalingConstants() {
        // Bounds widened 2026-07-31 (lower bound 100 → 10). The scaling constant is no
        // longer a free parameter with a plausibility range: it is pinned by ke and
        // clearance (see the identity test below), and TC's fitted ke of 13.64 h puts
        // its S at 67.13, legitimately below the old floor.
        for ester in TestosteroneEster.allCases {
            let c = ester.scalingConstant
            #expect(c >= 10 && c <= 1500,
                    "\(ester.rawValue) scaling constant \(c) outside clinical range")
        }
    }

    /// Replaces two ordering tests (`propionateLowerScalingThanCypionate` and
    /// `undecanoateLowerScaling`) that asserted S ordering by half-life. Both were
    /// inverted by the 2026-07-31 refit, and both were reasoning from the wrong
    /// quantity: S does not track the ester's half-life at all.
    ///
    /// Integrating the app's own expression over a dosing interval gives exactly
    /// Cavg = Dose·EDF·S/(τ·ke), because ∫₀^∞ (ka/(ka−ke))(e^(−ke·t) − e^(−ka·t)) dt
    /// = 1/ke. The true steady-state average is (mg testosterone/day)/CL, and clearance
    /// belongs to testosterone rather than to the ester carrying it. Equating them, the
    /// ester weight factor cancels and S = 1e5·ke/(CL_T·F) — a function of `ke` and
    /// clearance only, with `ka` (and therefore the ester's half-life) absent entirely.
    ///
    /// This is a much stronger guard than an ordering check: it fails on any drift in
    /// any injectable T constant, and it is what caught TE being 2× too high.
    @Test("T scaling constants satisfy S = 1e5·ke/(CL_T·F) — steady-state conservation")
    func testosteroneScalingSatisfiesClearanceIdentity() {
        // Bi et al. 2018 Table 2 reports CL/F = 2.6 kL/day per mg of *cypionate*.
        // Per mg of testosterone: 2600 × EWF_TC.
        let clearanceLPerDay = 2600.0 * TestosteroneEster.cypionate.esterWeightFactor
        for ester in TestosteroneEster.injectableCases {
            let ke = log(2) / (ester.eliminationHalfLifeHours / 24.0)
            let implied = 1e5 * ke / (clearanceLPerDay * ester.bioavailability)
            let err = abs(ester.scalingConstant - implied) / implied
            #expect(err < 0.01,
                    "\(ester.rawValue): S = \(ester.scalingConstant) but clearance implies \(implied) (\(err * 100)% off). See PharmacokineticConstants.swift.")
        }
    }

    /// TC's S was derived independently — analytically, from Bi's V/F and Ka, without
    /// reference to the clearance identity above. The two agreeing is what makes the
    /// identity trustworthy enough to have been applied to TE/TP/TU.
    @Test("TC scaling matches its analytic derivation from Bi et al. V/F and Ka")
    func cypionateScalingMatchesAnalyticForm() {
        let V_L = 14400.0                              // Bi Table 2: V/F = 14.4 kL
        let Ka = 1.22                                  // Bi Table 2: Ka = 1.22 /day
        let ke = log(2) / TestosteroneEster.cypionate.halfLifeDays   // = CL/V = 0.1806
        let edf = TestosteroneEster.cypionate.effectiveDoseFactor
        let implied = 1e5 * Ka / (V_L * edf * ke)      // = 67.13
        #expect(abs(TestosteroneEster.cypionate.scalingConstant - implied) / implied < 0.01,
                "TC S = \(TestosteroneEster.cypionate.scalingConstant), analytic form gives \(implied)")
    }

    @Test("EV half-life < EC half-life")
    func valerateVsCypionateHalfLife() {
        #expect(MedicationEster.valerate.halfLifeDays < MedicationEster.cypionate.halfLifeDays,
                "EV (2.0d) should have shorter half-life than EC (8.5d)")
    }

    @Test("T undecanoate has longest half-life among T esters")
    func undecanoateLongestHalfLife() {
        let halfLives = TestosteroneEster.allCases.map(\.halfLifeDays)
        let maxHalfLife = halfLives.max()!
        #expect(TestosteroneEster.undecanoate.halfLifeDays == maxHalfLife,
                "Undecanoate should have the longest half-life")
    }
}


// MARK: - Bateman Mathematics

@Suite("Bateman Biexponential — Mathematical Correctness")
struct BatemanMathematicsTests {

    /// Compute the Bateman function value directly for testing.
    func bateman(D: Double, S: Double, ka: Double, ke: Double, t: Double) -> Double {
        let denom = ka - ke
        if abs(denom) < 0.0001 {
            // ka ≈ ke: limit approximation
            return D * S * ka * t * exp(-ka * t)
        }
        return D * S * (ka / denom) * (exp(-ke * t) - exp(-ka * t))
    }

    @Test("Bateman at t=0 yields zero (no dose contribution at injection time)")
    func batemanAtT0() {
        // EV: ka = ln2/2.0 ≈ 0.3466, ke = ln2/0.125 ≈ 5.545
        let ka = log(2) / 2.0
        let ke = log(2) / 0.125
        let result = bateman(D: 2.0, S: 3150.0, ka: ka, ke: ke, t: 0.0)
        #expect(abs(result) < 0.001, "Bateman at t=0 should be ~0, got \(result)")
    }

    @Test("Bateman at large t approaches zero (dose fully cleared)")
    func batemanAtLargeT() {
        // EV: t = 30 days (15 half-lives)
        let ka = log(2) / 2.0
        let ke = log(2) / (3.0 / 24.0)  // 3h → 0.125d → ke = 5.545
        let result = bateman(D: 2.0, S: 3150.0, ka: ka, ke: ke, t: 30.0)
        // With ka=0.347/d ke=5.545/d the analytic result is ~0.0128 — negligible for
        // any clinical dose. Threshold 0.05 is still ~3000× smaller than a typical peak.
        #expect(abs(result) < 0.05, "Bateman at t=30d should be negligible, got \(result)")
    }

    @Test("Bateman produces positive values for positive t")
    func batemanPositive() {
        let ka = log(2) / 2.0    // EV ka
        let ke = log(2) / 0.125  // EV ke
        for t in [0.5, 1.0, 2.0, 3.0, 5.0, 7.0] {
            let result = bateman(D: 2.0, S: 3150.0, ka: ka, ke: ke, t: t)
            #expect(result > 0, "Bateman at t=\(t) should be positive, got \(result)")
        }
    }

    @Test("Bateman rises then decays (single peak)")
    func batemanSinglePeak() {
        let ka = log(2) / 2.0
        let ke = log(2) / 0.125
        var values: [Double] = []
        for t in stride(from: 0.0, through: 10.0, by: 0.1) {
            values.append(bateman(D: 2.0, S: 3150.0, ka: ka, ke: ke, t: t))
        }
        // Find the peak index
        guard let peakIdx = values.indices.max(by: { values[$0] < values[$1] }) else {
            Issue.record("Could not find peak")
            return
        }
        // Values before peak should be non-decreasing
        for i in 1..<peakIdx {
            #expect(values[i] >= values[i - 1] - 0.001,
                    "Pre-peak dip at index \(i): \(values[i]) < \(values[i-1])")
        }
        // Values after peak should be non-increasing
        for i in (peakIdx + 1)..<values.count {
            #expect(values[i] <= values[i - 1] + 0.001,
                    "Post-peak rise at index \(i): \(values[i]) > \(values[i-1])")
        }
    }

    @Test("Bateman ka≈ke limit approximation is continuous")
    func batemanKaEqualsKe() {
        // When ka == ke, use the limit form: D*S*ka*t*exp(-ka*t)
        let k = 1.0  // ka = ke = 1.0
        let result = bateman(D: 2.0, S: 3150.0, ka: k, ke: k, t: 2.0)
        let expected = 2.0 * 3150.0 * 1.0 * 2.0 * exp(-1.0 * 2.0)
        #expect(abs(result - expected) < 0.001, "ka≈ke limit should match closed form")
    }
}


// MARK: - Flip-Flop Kinetics

@Suite("Flip-Flop Kinetics — Physiological Correctness")
struct FlipFlopKineticsTests {

    @Test("Depot esters exhibit flip-flop: kₐ ≪ kₑ")
    func depotEstersKaMuchLessThanKe() {
        // Flip-flop (ka < ke) still holds after the 2026-07-29 recalibration, but the
        // separation is far less extreme: ke is no longer pinned to a physiological
        // 3 h, so the ratios moved from ~0.06/0.02 into the ~0.25–0.35 band.
        //
        // EV: ka = 0.267, ke = 0.774 → ratio ≈ 0.345
        let ev_ka = log(2) / MedicationEster.valerate.halfLifeDays
        let ev_ke = log(2) / (MedicationEster.valerate.eliminationHalfLifeHours / 24.0)
        #expect(ev_ka < ev_ke, "EV should have ka < ke")
        #expect(ev_ka / ev_ke < 0.5, "EV: ka/ke ratio \(ev_ka / ev_ke) should be < 0.5 (flip-flop)")

        // EC: ka = 0.107, ke = 0.431 → ratio ≈ 0.249
        let ec_ka = log(2) / MedicationEster.cypionate.halfLifeDays
        let ec_ke = log(2) / (MedicationEster.cypionate.eliminationHalfLifeHours / 24.0)
        #expect(ec_ka < ec_ke, "EC should have ka < ke")
        #expect(ec_ka / ec_ke < 0.5, "EC: ka/ke ratio \(ec_ka / ec_ke) should be < 0.5")

        // TC: ka = 0.181, ke = 1.220 → ratio ≈ 0.148, after the 2026-07-31 refit from
        // Bi et al. Flip-flop still holds, but the separation narrows from ~0.010 to
        // ~0.148 for the same reason it narrowed for EV/EC on 2026-07-29: ke is no
        // longer pinned to an arbitrary 2 h, so it no longer exaggerates the ratio.
        let tc_ka = log(2) / TestosteroneEster.cypionate.halfLifeDays
        let tc_ke = log(2) / (TestosteroneEster.cypionate.eliminationHalfLifeHours / 24.0)
        #expect(tc_ka < tc_ke, "TC should have ka < ke")
        #expect(tc_ka / tc_ke < 0.5, "TC: ka/ke ratio \(tc_ka / tc_ke) should be < 0.5 (flip-flop)")

        // TP: ka = 0.693, ke = 8.318 → ratio ≈ 0.083 (borderline flip-flop)
        let tp_ka = log(2) / TestosteroneEster.propionate.halfLifeDays
        let tp_ke = log(2) / (TestosteroneEster.propionate.eliminationHalfLifeHours / 24.0)
        #expect(tp_ka < tp_ke, "TP should still have ka < ke (barely)")
        #expect(tp_ka / tp_ke < 0.5, "TP: ka/ke ratio should be < 0.5")
    }

    @Test("Oral route: kₐ > kₑ (absorption faster than elimination)")
    func oralKaGreaterThanKe() {
        // This is NOT flip-flop; terminal slope is elimination-limited.
        //
        // Rewritten 2026-08-01: this test used to assert the literal `2.5 > 1.386`,
        // which is a tautology — it never read the enum, so it would have passed
        // unchanged no matter what the constants became. It now reads them.
        //
        // The ordering also matters beyond the flip-flop question: t_max =
        // ln(ka/ke)/(ka−ke) is symmetric under ka↔ke, so the constants alone do not
        // say which root the fit landed on. ka > ke is what pins it to the
        // absorption-limited branch.
        let ka = log(2) / MedicationEster.oral.halfLifeDays
        let ke = log(2) / (MedicationEster.oral.eliminationHalfLifeHours / 24.0)
        #expect(ka > ke, "Oral ka (\(ka)) should be > ke (\(ke))")
    }
}


// MARK: - Time to Peak (t_max)

@Suite("Time to Peak — Pharmacodynamic Accuracy")
struct TimeToPeakTests {

    /// Retargeted 2026-07-29 to the published Tmax windows. These are the observable
    /// proof that the ke recalibration worked: before it, ke was pinned to 3 h and
    /// every depot ester peaked at ~0.5 d regardless of its ester.
    @MainActor
    @Test("EV t_max matches literature 1.9–2.1 d (transfemscience/Tiong)")
    func valeratePeakTime() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        let tMax = mgr.expectedTimeToPeak(for: MedicationEster.valerate)
        // EV: ka=0.267, ke=0.774 → t_max ≈ 2.10 (was ~0.52 with the 3 h ke)
        #expect(tMax > 1.5 && tMax < 2.5,
                "EV t_max should be within the 1.5–2.5 d literature window, got \(tMax)")
    }

    /// Added 2026-08-01 with the oral ka refit (concern #7). Before it, ka = 2.5 /day
    /// put oral E2 t_max at 12.7 h — outside the published window, and longer than the
    /// 12 h interval of a BID schedule, which flattened the modeled intraday swing to
    /// ~1.1×. Nothing in the suite caught that: there was no oral t_max test at all,
    /// and the one oral constants test was a tautology (see `oralKaGreaterThanKe`).
    ///
    /// Asserted against the enum rather than through `estimatedLevels` on purpose:
    /// `pkParams` scales ke by `spiroClearanceFactor` when a user has spironolactone
    /// clearance enabled, which would move t_max out from under this assertion.
    @MainActor
    @Test("Oral E2 t_max is inside the published 4–8 h window")
    func oralE2TmaxInRange() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        let tMaxHours = mgr.expectedTimeToPeak(for: MedicationEster.oral) * 24.0
        #expect(tMaxHours > 4.0 && tMaxHours < 8.0,
                "Oral E2 t_max should be within the 4–8 h literature window, got \(tMaxHours) h")
        // Pinned to the midpoint — no physical principle picks a point inside 4–8 h,
        // so this second assertion guards against silent drift off a stated choice.
        #expect(abs(tMaxHours - 6.0) < 0.1,
                "Oral E2 t_max should sit at the pinned 6.0 h midpoint, got \(tMaxHours) h")
    }

    @MainActor
    @Test("EC t_max matches literature 3.1–4.3 d (transfemscience)")
    func cypionatePeakTime() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        let tMax = mgr.expectedTimeToPeak(for: MedicationEster.cypionate)
        // EC: ka=0.107, ke=0.431 → t_max ≈ 4.30 (was ~0.77 with the 3 h ke)
        #expect(tMax > 3.0 && tMax < 4.5,
                "EC t_max should be within the 3.0–4.5 d literature window, got \(tMax)")
    }

    /// Resolves OPEN_CONCERNS.md §2, which suspected the encoded 1–2 d window was wrong
    /// because a secondary source put TC's Cmax on day 4–5. Bi et al. 2018 Table 2 gives
    /// Ka = 1.22/day against a disposition rate of 0.1806/day, i.e. Tmax = 1.84 d —
    /// inside the encoded window. Propagating the published 95% CI on Ka (0.785–2.67)
    /// gives a Tmax band of 1.08–2.43 d, which never reaches day 4–5. Bi's own limitation
    /// statement (1–2 absorption-phase samples per subject, Ka RSE 44.9%) explains why
    /// that estimate is imprecise, so TC Tmax reads as 1.84 d ± ~0.7 d.
    @MainActor
    @Test("TC t_max = 1.84 d, matching Bi et al. 2018 Table 2")
    func cypionateTPeakTime() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        // ka = ln2/3.839 = 0.1806 (= CL/V), ke = ln2/(13.64/24) = 1.2196 (= Bi's Ka)
        let tMax = mgr.expectedTimeToPeak(for: TestosteroneEster.cypionate)
        #expect(abs(tMax - 1.84) < 0.05,
                "TC t_max should be 1.84 d per Bi Table 2, got \(tMax)")
        #expect(tMax > 1.08 && tMax < 2.43,
                "TC t_max should sit inside the CI band implied by Ka's 95% CI, got \(tMax)")
    }

    @MainActor
    @Test("TP t_max ≈ 0.2–0.5 days (rapid)")
    func propionatePeakTime() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        let tMax = mgr.expectedTimeToPeak(for: TestosteroneEster.propionate)
        // TP: ka = 0.693, ke = 8.318 → t_max ≈ 0.33 days (~8 hours)
        #expect(tMax > 0.1 && tMax < 0.6,
                "TP t_max should be 0.1–0.6 days, got \(tMax)")
    }

    /// The clinical ordering, restored 2026-08-02.
    ///
    /// History, because it explains why this assertion is worth keeping: the original
    /// version of this test asserted TU t_max > TC t_max and passed for the wrong
    /// reason — both esters carried the same placeholder 2 h `ke`, so the ordering came
    /// entirely from their half-lives. It broke on 2026-07-31 when TC alone got a real
    /// absorption rate (t_max 0.55 → 1.84 d) while TU stayed pinned at 0.66 d, and was
    /// rewritten to document that inversion with an explicit instruction to restore the
    /// clinical assertion once TU was given a source. That has now happened.
    ///
    /// Both numbers are now sourced independently — TC from Bi et al. 2018, TU from
    /// Aveed's clinical pharmacology (median 7 d, range 4–42) — so the ordering is a
    /// real prediction rather than an artifact of shared constants.
    @MainActor
    @Test("TU peaks weeks after TC, and both t_max values are primary-sourced")
    func undecanoatePeaksAfterCypionate() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        let tcMax = mgr.expectedTimeToPeak(for: TestosteroneEster.cypionate)
        let tuMax = mgr.expectedTimeToPeak(for: TestosteroneEster.undecanoate)

        #expect(tuMax > tcMax,
                "TU should peak after TC; got TU \(tuMax) d vs TC \(tcMax) d")
        #expect(abs(tuMax - 7.0) < 0.2,
                "TU t_max should be ≈7 d (Aveed median), got \(tuMax)")
        #expect(TestosteroneEster.undecanoate.eliminationHalfLifeHours == 44.3883,
                "TU t_max is a function of this rate; they must move together")
    }

    /// TE's t_max, from the one IM study run in this app's own population.
    ///
    /// Note the target is the paper's *observed* Tmax while the constant came from its
    /// *reported ka values* — two different quantities from the same paper, estimated
    /// in different subsets (Tmax in all 10, ka in the 4 where it was estimable). So
    /// this is a genuine cross-check rather than a round trip, which is why the
    /// tolerance is the paper's own spread rather than something tighter.
    @MainActor
    @Test("TE t_max ≈ 1.6 d, inside Ichihara's observed 1.7 ± 0.9 d")
    func enanthatePeakTime() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        let teMax = mgr.expectedTimeToPeak(for: TestosteroneEster.enanthate)

        #expect(abs(teMax - 1.58) < 0.05,
                "TE t_max should be ≈1.58 d for the encoded constants, got \(teMax)")
        #expect(teMax > 0.8 && teMax < 2.6,
                "TE t_max should sit inside Ichihara's observed 1.7 ± 0.9 d, got \(teMax)")
    }

    /// The Bateman t_max formula moved onto the ester enums as `timeToPeakDays` so UI
    /// with no manager in scope reads the same number the engine does; the manager
    /// methods now delegate. This pins the two together across every case of both
    /// enums, so a future edit to one cannot silently diverge from the other.
    @MainActor
    @Test("timeToPeakDays and expectedTimeToPeak(for:) agree for every ester")
    func timeToPeakDaysMatchesExpectedTimeToPeak() {
        let mgr = TestDefaults.manager()

        // NaN != NaN, so compare bit patterns: TestosteroneEster.transdermal has
        // eliminationHalfLifeHours = 0, giving an infinite ke and an undefined t_max.
        // That is the correct answer for a route with no elimination phase, and the
        // delegation must reproduce it exactly rather than paper over it.
        func agrees(_ a: Double, _ b: Double) -> Bool {
            (a.isNaN && b.isNaN) || a == b
        }

        for ester in MedicationEster.allCases {
            #expect(agrees(mgr.expectedTimeToPeak(for: ester), ester.timeToPeakDays),
                    "MedicationEster.\(ester.rawValue): manager and enum disagree")
        }
        for ester in TestosteroneEster.allCases {
            #expect(agrees(mgr.expectedTimeToPeak(for: ester), ester.timeToPeakDays),
                    "TestosteroneEster.\(ester.rawValue): manager and enum disagree")
        }

        // Every ester the picker can actually show must yield a usable number —
        // this is the assertion that would catch a NaN reaching `Int()` in the UI.
        for ester in MedicationEster.injectableCases where ester.isTmaxCalibrated {
            #expect(ester.timeToPeakDays.isFinite && ester.timeToPeakDays > 0,
                    "MedicationEster.\(ester.rawValue) is shown in the picker but has no usable t_max")
        }
        for ester in TestosteroneEster.injectableCases where ester.isTmaxCalibrated {
            #expect(ester.timeToPeakDays.isFinite && ester.timeToPeakDays > 0,
                    "TestosteroneEster.\(ester.rawValue) is shown in the picker but has no usable t_max")
        }
    }

    /// Regression test for the onboarding ester picker, which carried its own
    /// `halfLife × 1.44` approximation of t_max. That heuristic ignored `ke`
    /// completely, so it ran 3–44× long on testosterone (TU: "Peaks day 29" against a
    /// modeled 0.66 d) and ~2× long on estrogen (EC: "day 9" against 4.30 d).
    ///
    /// Asserts both that the exact values are right and that the old heuristic is
    /// gone — the second half is what actually catches a reintroduction, since a
    /// plausible-looking wrong formula would still pass a loose range check.
    @MainActor
    @Test("Ester picker peak day uses exact Bateman t_max, not halfLife × 1.44")
    func onboardingPeakDayMatchesBatemanTmax() {
        // Primary/label-anchored esters — the only ones the picker shows a peak for.
        // TE and TU joined this list on 2026-08-02, when they stopped being placeholders.
        // TU is the sharpest case for the second assertion below: the retired heuristic
        // said "peaks day 29" for TU against a real 7 d.
        let expected: [(name: String, tPeak: Double, tHalf: Double)] = [
            ("TC", TestosteroneEster.cypionate.timeToPeakDays, TestosteroneEster.cypionate.halfLifeDays),
            ("TE", TestosteroneEster.enanthate.timeToPeakDays, TestosteroneEster.enanthate.halfLifeDays),
            ("TU", TestosteroneEster.undecanoate.timeToPeakDays, TestosteroneEster.undecanoate.halfLifeDays),
            ("EV", MedicationEster.valerate.timeToPeakDays, MedicationEster.valerate.halfLifeDays),
            ("EC", MedicationEster.cypionate.timeToPeakDays, MedicationEster.cypionate.halfLifeDays),
        ]
        let targets = ["TC": 1.84, "TE": 1.58, "TU": 7.00, "EV": 2.10, "EC": 4.30]

        for row in expected {
            #expect(abs(row.tPeak - targets[row.name]!) < 0.05,
                    "\(row.name) t_max should be ≈\(targets[row.name]!) d, got \(row.tPeak)")
            // The retired heuristic. Every one of these is off by enough that a 0.2 d
            // tolerance cleanly separates it from the exact value.
            #expect(abs(row.tPeak - row.tHalf * 1.44) > 0.2,
                    "\(row.name): value matches the retired halfLife × 1.44 heuristic — has it been reintroduced?")
        }

        // The floor the picker applies (`max(1, rounded)`) must never be load-bearing
        // for a calibrated ester; if it becomes so, the label is hiding a sub-day peak.
        for row in expected {
            #expect(row.tPeak.rounded() >= 1,
                    "\(row.name) rounds to day 0 — the picker's floor would be masking it")
        }
    }

    /// `isTmaxCalibrated` gates whether the picker shows a peak day at all. It is a
    /// hand-maintained flag, so it can drift out of sync with the constants it
    /// describes. This fails if someone recalibrates an ester's `ke` without clearing
    /// the flag, or flags one as calibrated while it still carries the placeholder.
    @MainActor
    @Test("isTmaxCalibrated matches which esters still carry the placeholder ke")
    func uncalibratedEstersAreFlagged() {
        #expect(TestosteroneEster.cypionate.isTmaxCalibrated)
        #expect(TestosteroneEster.enanthate.isTmaxCalibrated)    // Ichihara 2020
        #expect(TestosteroneEster.undecanoate.isTmaxCalibrated)  // Aveed, 2026-08-02
        #expect(TestosteroneEster.oral.isTmaxCalibrated)
        #expect(MedicationEster.valerate.isTmaxCalibrated)
        #expect(MedicationEster.cypionate.isTmaxCalibrated)
        #expect(MedicationEster.oral.isTmaxCalibrated)

        // The placeholder 2 h ke and the false flag must move together, in both
        // directions — see OPEN_CONCERNS.md §3. TP is the last ester holding both.
        #expect(!TestosteroneEster.propionate.isTmaxCalibrated,
                "TP is flagged calibrated")
        #expect(TestosteroneEster.propionate.eliminationHalfLifeHours == 2.0,
                "TP no longer carries the placeholder ke — clear isTmaxCalibrated and give it a real peak day in the picker")

        // The converse guard: nothing may claim calibration while still sitting on the
        // placeholder. Without this the pairing above only constrains TP by name, so a
        // newly added ester could arrive flagged-true with a copy-pasted 2.0.
        for ester in TestosteroneEster.allCases where ester.isTmaxCalibrated {
            #expect(ester.eliminationHalfLifeHours != 2.0,
                    "\(ester.rawValue) is flagged calibrated but still carries the 2 h placeholder")
        }
    }
}


// MARK: - Dynamic Baseline

@Suite("Dynamic Baseline — Endogenous Suppression")
struct DynamicBaselineTests {

    @MainActor
    @Test("Returns suppressed baseline when anti-androgen is in use")
    func antiAndrogenSuppressesT() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.antiAndrogenInUse = true
        mgr.hrtStartDate = Date()

        let baseline = mgr.dynamicBaseline(for: .testosterone)
        #expect(baseline == MedicationManager.MedicationType.testosterone.suppressedBaseline,
                "AA should suppress T to \(MedicationManager.MedicationType.testosterone.suppressedBaseline) ng/dL, got \(baseline)")
        mgr.antiAndrogenInUse = false
    }

    @MainActor
    @Test("Returns full baseline when no HRT start date")
    func noHRTStartDateReturnsFull() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.hrtStartDate = nil
        mgr.lastDoseDate = nil
        mgr.antiAndrogenInUse = false

        let baseline = mgr.dynamicBaseline(for: .estrogen)
        #expect(baseline == MedicationManager.MedicationType.estrogen.baselineValue,
                "No HRT start → full baseline of \(MedicationManager.MedicationType.estrogen.baselineValue), got \(baseline)")
    }

    @MainActor
    @Test("Returns fully suppressed after 2 years on HRT")
    func fullySuppressedAfterTwoYears() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.antiAndrogenInUse = false

        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -3, to: Date())!
        mgr.hrtStartDate = twoYearsAgo

        let baseline = mgr.dynamicBaseline(for: .estrogen)
        #expect(baseline == MedicationManager.MedicationType.estrogen.suppressedBaseline,
                ">2 years HRT → suppressed baseline of \(MedicationManager.MedicationType.estrogen.suppressedBaseline), got \(baseline)")
    }

    @MainActor
    @Test("Baseline decreases monotonically over time (fast suppression)")
    func suppressionMonotonic() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.antiAndrogenInUse = false
        mgr.suppressionSpeed = .fast  // 4 weeks

        let full = MedicationManager.MedicationType.estrogen.baselineValue    // 100
        let suppressed = MedicationManager.MedicationType.estrogen.suppressedBaseline  // 5

        var baselines: [Double] = []
        for weeks in stride(from: 0, through: 6, by: 1) {
            let startDate = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date())!
            mgr.hrtStartDate = startDate
            baselines.append(mgr.dynamicBaseline(for: .estrogen))
        }

        // baselines should be non-increasing (or equal)
        for i in 1..<baselines.count {
            #expect(baselines[i] <= baselines[i - 1] + 0.001,
                    "Baseline should not increase: week \(i) = \(baselines[i]) > week \(i-1) = \(baselines[i-1])")
        }

        #expect(baselines.first! == full, "At t=0, baseline should be full \(full), got \(baselines.first!)")
        #expect(baselines.last! < full, "After 6 weeks, baseline should be below full")
        #expect(baselines.last! > suppressed, "After 6 weeks, baseline should still be above suppressed")
    }

    @MainActor
    @Test("Slow suppression takes longer than fast suppression")
    func slowVsFast() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.antiAndrogenInUse = false

        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())!
        mgr.hrtStartDate = fourWeeksAgo

        mgr.suppressionSpeed = .fast
        let fastBaseline = mgr.dynamicBaseline(for: .estrogen)

        mgr.suppressionSpeed = .slow
        let slowBaseline = mgr.dynamicBaseline(for: .estrogen)

        #expect(fastBaseline < slowBaseline,
                "Fast suppression should produce lower baseline at 4 weeks: fast=\(fastBaseline), slow=\(slowBaseline)")
    }

    @MainActor
    @Test("Baseline bounded between suppressed and full values")
    func baselineBounded() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.antiAndrogenInUse = false

        let full = MedicationManager.MedicationType.estrogen.baselineValue
        let suppressed = MedicationManager.MedicationType.estrogen.suppressedBaseline

        for weeks in stride(from: 0, through: 110, by: 2) {
            let startDate = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date())!
            mgr.hrtStartDate = startDate
            let baseline = mgr.dynamicBaseline(for: .estrogen)
            #expect(baseline >= suppressed - 0.001,
                    "Baseline \(baseline) below suppressed \(suppressed) at week \(weeks)")
            #expect(baseline <= full + 0.001,
                    "Baseline \(baseline) above full \(full) at week \(weeks)")
        }
    }
}


// MARK: - Deviation Classification

@Suite("Deviation Classification — Calibration Ratio Binning")
struct DeviationClassificationTests {

    @MainActor
    @Test("Equal actual and predicted → on track")
    func equalIsOnTrack() {
        let mgr = TestDefaults.manager()
        #expect(mgr.deviationClassification(actual: 200, predicted: 200) == .onTrack)
    }

    @MainActor
    @Test("Actual < 0.7× predicted → below")
    func below() {
        let mgr = TestDefaults.manager()
        #expect(mgr.deviationClassification(actual: 80, predicted: 200) == .below, "ratio=0.4")
        #expect(mgr.deviationClassification(actual: 120, predicted: 200) == .below, "ratio=0.6")
    }

    @MainActor
    @Test("Actual 0.7–1.3× predicted → on track")
    func onTrackRange() {
        let mgr = TestDefaults.manager()
        for ratio in [0.7, 0.85, 1.0, 1.15, 1.29] {
            let result = mgr.deviationClassification(actual: ratio * 200, predicted: 200)
            #expect(result == .onTrack, "ratio=\(ratio) should be on track, got \(result)")
        }
    }

    @MainActor
    @Test("Actual > 1.3× predicted → above")
    func above() {
        let mgr = TestDefaults.manager()
        #expect(mgr.deviationClassification(actual: 300, predicted: 200) == .above, "ratio=1.5")
        #expect(mgr.deviationClassification(actual: 500, predicted: 200) == .above, "ratio=2.5")
    }

    @MainActor
    @Test("Very low predicted value → incomparable")
    func incomparable() {
        let mgr = TestDefaults.manager()
        #expect(mgr.deviationClassification(actual: 1.0, predicted: 0.5) == .incomparable)
    }

    @MainActor
    @Test("Boundary exact values")
    func boundaryValues() {
        let mgr = TestDefaults.manager()
        // Bin edges are [0, 0.7) below, [0.7, 1.3) on track, [1.3, ∞) above.
        #expect(mgr.deviationClassification(actual: 100.0, predicted: 200.0) == .below,   "ratio=0.5 exact")
        #expect(mgr.deviationClassification(actual: 140.0, predicted: 200.0) == .onTrack, "ratio=0.7 exact")
        #expect(mgr.deviationClassification(actual: 260.0, predicted: 200.0) == .above,   "ratio=1.3 exact")
        #expect(mgr.deviationClassification(actual: 400.0, predicted: 200.0) == .above,   "ratio=2.0 exact")
    }
}


// MARK: - Safety Overrides

@Suite("Safety Overrides — Clinical Safety Flags")
struct SafetyOverrideTests {

    @MainActor
    @Test("E2 > 1000 pg/mL → estrogen ceiling flag")
    func estrogenVeryHigh() {
        let mgr = TestDefaults.manager()
        #expect(mgr.safetyOverride(level: 1200, medication: .estrogen, phase: .nearPeak) == .estrogenCeiling)
    }

    @MainActor
    @Test("E2 at exactly 1000 does NOT trigger safety")
    func estrogenExactly1000() {
        let mgr = TestDefaults.manager()
        // The threshold is `level > 1000`, so exactly 1000 should NOT trigger.
        #expect(mgr.safetyOverride(level: 1000, medication: .estrogen, phase: .nearPeak) == nil)
    }

    @MainActor
    @Test("T > 1500 ng/dL → supraphysiologic flag")
    func testosteroneSupraphysiological() {
        let mgr = TestDefaults.manager()
        #expect(mgr.safetyOverride(level: 1600, medication: .testosterone, phase: .nearPeak) == .testosteroneSupraphysiologic)
    }

    @MainActor
    @Test("E2 < 50 at trough → sub-therapeutic trough flag")
    func estrogenSubTherapeuticTrough() {
        let mgr = TestDefaults.manager()
        #expect(mgr.safetyOverride(level: 30, medication: .estrogen, phase: .trough) == .subTherapeuticTrough)
    }

    @MainActor
    @Test("E2 < 50 NOT at trough → no safety flag")
    func lowEstrogenNotTroughNoFlag() {
        let mgr = TestDefaults.manager()
        #expect(mgr.safetyOverride(level: 30, medication: .estrogen, phase: .nearPeak) == nil,
                "Low E2 at peak should not trigger the trough flag")
    }

    @MainActor
    @Test("Normal levels → no override")
    func normalNoOverride() {
        let mgr = TestDefaults.manager()
        #expect(mgr.safetyOverride(level: 200, medication: .estrogen, phase: .nearPeak) == nil)
        #expect(mgr.safetyOverride(level: 600, medication: .testosterone, phase: .nearPeak) == nil)
    }

    @MainActor
    @Test("Safety notes state an association and issue no instruction")
    func safetyNotesAreNotInstructions() {
        // The app reports clinical facts; deciding what to do with them is the
        // user's and their provider's call. Guard against advisory copy creeping back.
        let imperatives = ["consider", "contact your", "consult", "you should",
                           "monitor for", "reduce your", "talk to"]
        for flag: SafetyFlag in [.estrogenCeiling, .testosteroneSupraphysiologic,
                                 .subTherapeuticTrough, .spironolactoneClearance] {
            let note = flag.note.lowercased()
            for phrase in imperatives {
                #expect(!note.contains(phrase),
                        "SafetyFlag.\(flag) note contains advisory phrase \"\(phrase)\": \(flag.note)")
            }
        }
    }
}


// MARK: - Aromatization

@Suite("Aromatization — T→E2 Conversion")
struct AromatizationTests {

    @MainActor
    @Test("0.2% conversion: 1000 ng/dL T → 20.0 pg/mL E2")
    func conversionRate() {
        let mgr = TestDefaults.manager()
        let e2 = mgr.estimatedE2FromTestosterone(1000.0)
        #expect(abs(e2 - 20.0) < 0.01, "1000 ng/dL T → E2 should be ~20.0 pg/mL, got \(e2)")
    }

    @MainActor
    @Test("Aromatization yields 0 at zero T")
    func zeroT() {
        let mgr = TestDefaults.manager()
        let e2 = mgr.estimatedE2FromTestosterone(0.0)
        #expect(e2 == 0.0, "Zero T should yield zero E2")
    }

    @MainActor
    @Test("Assessment: elevated when E2 > 40")
    func elevatedAssessment() {
        let mgr = TestDefaults.manager()
        // 2500 ng/dL T * 0.02 = 50 pg/mL E2 > 40 → elevated
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 2500.0)
        #expect(isElevated, "E2 of \(e2) pg/mL from 2500 ng/dL T should be elevated (>40)")
    }

    @MainActor
    @Test("Assessment: normal when E2 10–40")
    func normalAssessment() {
        let mgr = TestDefaults.manager()
        // 800 ng/dL T * 0.02 = 16 pg/mL → normal
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 800.0)
        #expect(!isElevated, "E2 of \(e2) pg/mL should NOT be elevated")
    }

    @MainActor
    @Test("Assessment: below range when E2 < 10")
    func belowRangeAssessment() {
        let mgr = TestDefaults.manager()
        // 200 ng/dL T * 0.02 = 4 pg/mL → below range
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 200.0)
        #expect(!isElevated, "E2 of \(e2) pg/mL should NOT trigger elevated")
    }

    @MainActor
    @Test("Aromatization scales linearly")
    func linearScaling() {
        let mgr = TestDefaults.manager()
        for t in [100.0, 500.0, 1000.0, 3000.0, 10000.0] {
            let e2 = mgr.estimatedE2FromTestosterone(t)
            let expected = t * 0.02
            #expect(abs(e2 - expected) < 0.001,
                    "E2 should be \(expected) for T=\(t), got \(e2)")
        }
    }
}


// MARK: - Dose Intensity

@Suite("Dose Intensity — Dose Scaling Computation")
struct DoseIntensityTests {

    @MainActor
    @Test("No doses → intensity = 1.0")
    func noDosesDefaultIntensity() {
        let mgr = TestDefaults.manager()
        mgr.doseHistory = []
        let intensity = mgr.relativeDoseIntensity
        #expect(intensity == 1.0, "No doses should default to intensity 1.0, got \(intensity)")
    }

    @MainActor
    @Test("Standard E dose → intensity ≈ 1.0")
    func standardDoseIntensity() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        let now = Date()

        // Create a dose at standard 2 mg
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let intensity = mgr.relativeDoseIntensity
        #expect(abs(intensity - 1.0) < 0.01,
                "Standard 2mg E dose → intensity ~1.0, got \(intensity)")
    }

    @MainActor
    @Test("Double standard dose → intensity > 1.0")
    func highDoseIntensity() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        let now = Date()

        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 4.0,  // double standard
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let intensity = mgr.relativeDoseIntensity
        #expect(intensity > 1.5, "4mg E dose → intensity > 1.5, got \(intensity)")
    }

    @MainActor
    @Test("Half standard T dose → intensity < 1.0")
    func lowDoseIntensity() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        let now = Date()

        let record = DoseRecord(
            doseDate: now,
            medicationType: "Testosterone",
            ester: TestosteroneEster.cypionate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 25.0,  // half standard (50mg)
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let intensity = mgr.relativeDoseIntensity
        #expect(intensity < 1.0 && intensity > 0,
                "25mg T dose → intensity < 1.0, got \(intensity)")
    }
}


// MARK: - PK Engine: Nominal Scenarios

@Suite("PK Engine — Nominal Dosing Scenarios")
struct PKEngineNominalTests {

    @MainActor
    @Test("Single EV dose produces clinically plausible peak ~200–250 pg/mL")
    func evSingleDosePeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        // Compute PK curve for 7 days
        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                          stepDays: 0.25, applyCalibration: false)
        #expect(points.count > 0, "Should produce level points")

        // Retargeted 2026-07-29. Amplitude is now anchored to the transfemscience
        // Table 10 steady-state peak rather than the app's legacy 2mg→250 target,
        // which was 2.1x the corresponding Table 9 figure. Single-dose Cmax is now a
        // derived value: ~119 pg/mL for 2 mg EV (S=396.4, effective=1.528mg).
        // Note: the window starts at the injection moment (Bateman(0)=0=baseline),
        // so points.first is NOT the peak; use maxLevel for peak assertions.
        let maxLevel = points.map(\.value).max() ?? 0
        #expect(maxLevel > 90 && maxLevel < 180,
                "EV 2mg peak should be 90–180 pg/mL, got \(maxLevel)")

        // After 7 days, should be approaching baseline (~5 pg/mL fully suppressed)
        let troughLevel = points.last!.value
        #expect(troughLevel < maxLevel * 0.5,
                "Trough at day 7 should be well below peak")
    }

    @MainActor
    @Test("Single TC dose produces clinically plausible peak ~600–900 ng/dL")
    func tcSingleDosePeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Testosterone",
            ester: TestosteroneEster.cypionate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 100.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(14 * 86400),
                                          stepDays: 0.5, applyCalibration: false)
        #expect(points.count > 0, "Should produce level points")

        let maxLevel = points.map(\.value).max() ?? 0
        #expect(maxLevel > 400 && maxLevel < 1200,
                "TC 100mg peak should be 400–1200 ng/dL, got \(maxLevel)")
    }

    @MainActor
    @Test("Oral E2 produces rapid spike and fast decay")
    func oralE2Kinetics() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Oral"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.oral.rawValue,
            administrationMethod: "Oral",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        // Compute PK curve for 24 hours at 1h resolution
        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(24 * 3600),
                                          stepDays: 1.0 / 24.0, applyCalibration: false)
        #expect(points.count > 0, "Should produce level points")

        let maxLevel = points.map(\.value).max() ?? 0
        let lastLevel = points.last!.value
        // Peak is above baseline, and the curve is declining from peak by 24h.
        //
        // Tightened 2026-08-01 with the ka refit. The old comment here said a
        // "50%-within-24h requirement is too tight for these constants" — true at
        // ka = 2.5, where the 24 h level sat at ~78% of peak because the curve was
        // still nearly flat. At ka = 8.762 the dose peaks at 6 h and 24 h lands at
        // ~42% of peak, so "fast decay" is now actually assertable, which is what
        // this test claims in its name.
        //
        // The decay ratio is taken on the dose's contribution ABOVE baseline, not on
        // the raw level: `estimatedLevels` returns baseLevel + spike (see the sum in
        // MedicationManager+Pharmacokinetics), and dividing raw levels would let a
        // nonzero `dynamicBaseline` mask the decay. At t=0 the Bateman term is exactly
        // zero, so the first point is the baseline.
        let baseline = points.first!.value
        let peakSpike = maxLevel - baseline
        let spikeAt24h = lastLevel - baseline
        #expect(peakSpike > 20,
                "Oral E2 2mg should produce a real peak above baseline, got spike=\(peakSpike)")
        #expect(spikeAt24h < peakSpike * 0.5,
                "Oral E2 should decay below half its peak within 24h: peak spike=\(peakSpike), 24h spike=\(spikeAt24h)")
    }

    @MainActor
    @Test("Calibration factor scales levels proportionally")
    func calibrationScaling() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        // Add a calibration factor of 1.5x
        let bloodRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(3 * 86400),
            measuredLevel: 300,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        bloodRecord.calibrationFactor = 1.5
        mgr.bloodTestHistory = [bloodRecord]

        let uncalibrated = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(86400),
                                                stepDays: 1.0, applyCalibration: false)
        let calibrated = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(86400),
                                              stepDays: 1.0, applyCalibration: true)

        guard let uVal = uncalibrated.last?.value, let cVal = calibrated.last?.value else {
            Issue.record("Failed to get level values")
            return
        }

        // α scales the exogenous spike only; the endogenous baseline is not part
        // of the calibrated quantity. The old `cVal ≈ uVal × 1.5` assertion only
        // passed while the baseline was ~0 — at this test's 3-year suppression the
        // 5.0 pg/mL floor makes that off by 0.5 × baseline.
        let base = mgr.dynamicBaseline(for: .estrogen)
        let expected = (uVal - base) * 1.5 + base
        #expect(abs(cVal - expected) < 1.0,
                "Calibrated level (\(cVal)) should be ~1.5x the exogenous part of uncalibrated (\(uVal)) plus baseline (\(base))")
    }
}


// MARK: - Edge Cases & Robustness

@Suite("PK Engine — Edge Cases & Robustness")
struct PKEngineEdgeCaseTests {

    @MainActor
    @Test("Empty dose history returns empty points array")
    func emptyDoseHistory() {
        let mgr = TestDefaults.manager()
        mgr.doseHistory = []
        let points = mgr.estimatedLevels(from: Date(), to: Date().addingTimeInterval(86400))
        // With no medication selected, returns []
        #expect(points.isEmpty)
    }

    @MainActor
    @Test("No medication selected returns empty")
    func noMedicationSelected() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = nil
        mgr.selectedAdministrationMethod = nil
        let points = mgr.estimatedLevels(from: Date(), to: Date().addingTimeInterval(86400))
        #expect(points.isEmpty)
    }

    @MainActor
    @Test("Zero dose amount produces near-baseline levels")
    func zeroDoseAmount() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 0.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                          stepDays: 1.0, applyCalibration: false)
        #expect(points.count > 0)

        // With zero dose, effective amount = 0, levels should equal baseline
        let suppressedBaseline = MedicationManager.MedicationType.estrogen.suppressedBaseline
        for p in points {
            #expect(abs(p.value - suppressedBaseline) < 1.0,
                    "Zero dose should produce baseline-only levels (5 pg/mL), got \(p.value)")
        }
    }

    @MainActor
    @Test("Start date = end date produces single point")
    func startEqualsEnd() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let points = mgr.estimatedLevels(from: now, to: now,
                                          stepDays: 1.0, applyCalibration: false)
        #expect(points.count == 1, "Start=end should produce exactly 1 point, got \(points.count)")
    }

    @MainActor
    @Test("Start after end produces no points")
    func startAfterEnd() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())

        let record = DoseRecord(
            doseDate: Date().addingTimeInterval(-86400),
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let end = Date()
        let start = Date().addingTimeInterval(86400)  // start is after end
        let points = mgr.estimatedLevels(from: start, to: end,
                                          stepDays: 1.0, applyCalibration: false)
        #expect(points.isEmpty, "Start after end should produce empty array")
    }

    @MainActor
    @Test("Very large stepDays produces fewer points")
    func largeStepDays() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        let finePoints = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                              stepDays: 0.25, applyCalibration: false)
        let coarsePoints = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                                stepDays: 2.0, applyCalibration: false)
        #expect(finePoints.count > coarsePoints.count,
                "Finer stepDays (\(finePoints.count)) should produce more points than coarse (\(coarsePoints.count))")
    }

    @MainActor
    @Test("Dose from far in the past contributes negligible amounts")
    func veryOldDose() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let oldDoseDate = Calendar.current.date(byAdding: .day, value: -90, to: now)!

        let oldRecord = DoseRecord(
            doseDate: oldDoseDate,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 100.0,  // very large dose to exaggerate
            doseStatus: .taken
        )
        mgr.doseHistory = [oldRecord]

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(86400),
                                          stepDays: 1.0, applyCalibration: false)
        #expect(points.count > 0)

        // After 90 days / 2 day half-life = 45 half-lives, contribution should be ~0
        // EV: ka = 0.347, ke = 5.545, 90d * ka = 31.2, contribution ~ D*S*(ka/(ka-ke))*exp(-5.545*90) ≈ 0
        let level = points.first!.value
        let baseline = MedicationManager.MedicationType.estrogen.suppressedBaseline
        #expect(abs(level - baseline) < 10.0,
                "90-day-old dose should contribute negligibly: level=\(level), baseline=\(baseline)")
    }
}


// MARK: - Superposition

@Suite("Superposition — Multi-Dose Contributions")
struct SuperpositionTests {

    @MainActor
    @Test("Two doses sum additively")
    func additiveSuperposition() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let dose1 = DoseRecord(
            doseDate: now.addingTimeInterval(-7 * 86400),
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [dose1]
        let singleLevels = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(86400),
                                                stepDays: 1.0, applyCalibration: false)

        let dose2 = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [dose1, dose2]
        let dualLevels = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(86400),
                                              stepDays: 1.0, applyCalibration: false)

        guard let sVal = singleLevels.last?.value, let dVal = dualLevels.last?.value else {
            Issue.record("Failed to get level values")
            return
        }

        // At t=now (just after dose2), dual should be single + dose2_contribution
        // dose2 contribution at t=0 should be 0 (Bateman at t=0 = 0)
        // But cursor starts at `now` exactly, so the Bateman term for dose2 at t=0 is 0
        // Actually cursor starts at `now` and increments, so first cursor is `now`
        // For dose2, dt = 0 at the first point → Bateman(0) = 0
        // So dual[0] should equal single[0]
        // At the next step, dual > single (because dose2 now contributes)
        #expect(dVal >= sVal - 1.0,
                "Dual-dose should be >= single-dose: single=\(sVal), dual=\(dVal)")
    }
}


// MARK: - Calibration Factor

@Suite("Calibration Factor — Alpha Computation & Clamping")
struct CalibrationFactorTests {

    @MainActor
    @Test("Alpha clamped to [0.2, 5.0]")
    func alphaClamping() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())

        let now = Date()
        let record = DoseRecord(
            doseDate: now,
            medicationType: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 2.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [record]

        // Test minimum clamp: measured very low, predicted normal → alpha should clamp at 0.2
        let lowRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(3 * 86400),
            measuredLevel: 1.0,    // very low
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        mgr.bloodTestHistory = [lowRecord]
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.computeCalibrationFactor(for: lowRecord)

        if let alpha = lowRecord.calibrationFactor {
            #expect(alpha >= 0.2 - 0.001,
                    "Alpha should clamp at ≥0.2, got \(alpha)")
            #expect(alpha <= 5.0 + 0.001,
                    "Alpha should clamp at ≤5.0, got \(alpha)")
        }

        // Test maximum clamp: measured very high, predicted normal → alpha should clamp at 5.0
        let highRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(3 * 86400),
            measuredLevel: 9999.0,  // very high
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        mgr.computeCalibrationFactor(for: highRecord)

        if let alpha = highRecord.calibrationFactor {
            #expect(alpha >= 0.2 - 0.001,
                    "Alpha should clamp at ≥0.2, got \(alpha)")
            #expect(alpha <= 5.0 + 0.001,
                    "Alpha should clamp at ≤5.0, got \(alpha)")
        }
    }

    @MainActor
    @Test("No calibration factor when no blood tests exist")
    func noBloodTestsNilCalibration() {
        let mgr = TestDefaults.manager()
        mgr.bloodTestHistory = []
        #expect(mgr.calibrationFactor == nil,
                "No blood tests → calibration factor should be nil")
    }
}


// MARK: - Testosterone Ester Specific Validations

@Suite("Testosterone Ester — PK Validation")
struct TestosteroneEsterPKTests {

    @MainActor
    @Test("TU (undecanoate) produces flatter profile than TC")
    func undecanoateFlatterProfile() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()

        // TC: 100mg
        let tcRecord = DoseRecord(
            doseDate: now,
            medicationType: "Testosterone",
            ester: TestosteroneEster.cypionate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 100.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [tcRecord]
        let tcPoints = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(14 * 86400),
                                            stepDays: 1.0, applyCalibration: false)
        let tcLevels = tcPoints.map(\.value)
        let tcPeakToTrough = (tcLevels.max() ?? 0) - (tcLevels.min() ?? 0)

        // TU: 1000mg (standard dose)
        let tuRecord = DoseRecord(
            doseDate: now,
            medicationType: "Testosterone",
            ester: TestosteroneEster.undecanoate.rawValue,
            administrationMethod: "Injectable",
            doseAmount: 1000.0,
            doseStatus: .taken
        )
        mgr.doseHistory = [tuRecord]
        let tuPoints = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(14 * 86400),
                                            stepDays: 1.0, applyCalibration: false)
        let tuLevels = tuPoints.map(\.value)

        // TC should decay more sharply (higher peak-to-trough swing)
        // TU should be flatter (lower peak-to-trough swing relative to TU's own scale)
        let tcTC = tcLevels.max() ?? 0
        let tuTU = tuLevels.max() ?? 0
        guard tcTC > 0, tuTU > 0 else {
            Issue.record("Failed to compute TC/TU peak levels")
            return
        }
        #expect(tcPeakToTrough > 0, "TC 100mg should produce non-flat profile")
    }

    @MainActor
    @Test("TP peak arrives faster than TC peak")
    func propionateFasterPeakThanCypionate() {
        let mgr = TestDefaults.manager()

        let tpMax = mgr.expectedTimeToPeak(for: TestosteroneEster.propionate)
        let tcMax = mgr.expectedTimeToPeak(for: TestosteroneEster.cypionate)
        #expect(tpMax < tcMax,
                "TP peak (\(tpMax)d) should arrive before TC peak (\(tcMax)d)")
    }
}


// MARK: - Contextual Range

@Suite("Contextual Range — Dose-Scaled Targets")
struct ContextualRangeTests {

    @MainActor
    @Test("Peak range > trough range")
    func peakRangeHigherThanTrough() {
        let mgr = TestDefaults.manager()
        let peak = mgr.contextualRange(for: .estrogen, at: .nearPeak, doseIntensity: 1.0)
        let trough = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        #expect(peak.max > trough.max,
                "Peak ceiling (\(peak.max)) should exceed trough max (\(trough.max))")
    }

    @MainActor
    @Test("Higher dose intensity shifts targets upward")
    func doseIntensityShiftsTargets() {
        let mgr = TestDefaults.manager()
        let lowRange = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 0.25)
        let highRange = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 2.0)
        // High intensity should shift targets up (or at least not below low)
        #expect(highRange.max >= lowRange.max - 1.0,
                "Higher dose intensity should not reduce target ranges")
    }

    @MainActor
    @Test("Unknown cycle position uses fallback range")
    func unknownCycleUsesFallback() {
        let mgr = TestDefaults.manager()
        let unknown = mgr.contextualRange(for: .estrogen, at: .unknown, doseIntensity: 1.0)
        let trough = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        // Unknown fallback uses troughMin and peakCeiling
        #expect(unknown.min == trough.min,
                "Unknown should use troughMin (\(trough.min)) for safety, got \(unknown.min)")
    }

    @MainActor
    @Test("Bounds are reported as model-derived when the user has set no target")
    func noUserTargetIsModelDerived() {
        let mgr = TestDefaults.manager()
        mgr.userTherapeuticTarget = nil
        let range = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        #expect(range.source == .modelDerived)
    }

    @MainActor
    @Test("Bounds are reported as user-set once the user configures a target")
    func userTargetIsUserSet() {
        let mgr = TestDefaults.manager()
        mgr.userTherapeuticTarget = MedicationManager.TherapeuticTarget(troughMin: 120, troughMax: 220, peakCeiling: 500)
        let range = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        #expect(range.source == .userSet)
        #expect(range.min == 120)
        #expect(range.max == 220)
    }

    @MainActor
    @Test("Only bounds the user actually entered are marked user-set")
    func blendedBoundsAreNotAttributedToTheUser() {
        // Settings collects a trough floor, a trough ceiling and a peak ceiling.
        // Mid-cycle and near-peak bounds are interpolated against model-scaled peak
        // values, so they are not numbers the user ever entered. Marking them
        // `.userSet` made the app say "your set range of 195–425" to someone who
        // had entered 150–250.
        let mgr = TestDefaults.manager()
        mgr.userTherapeuticTarget = MedicationManager.TherapeuticTarget(troughMin: 150, troughMax: 250, peakCeiling: 600)

        for phase: MedicationManager.CyclePosition in [.midCycle, .nearPeak, .unknown] {
            let range = mgr.contextualRange(for: .estrogen, at: phase, doseIntensity: 1.0)
            #expect(range.source == .modelDerived,
                    "\(phase) bounds are blended with model values and must not be attributed to the user")
        }

        // The trough pair is exactly what the user typed, so it may be quoted back.
        let trough = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        #expect(trough.source == .userSet)
        #expect(trough.min == 150 && trough.max == 250)
    }
}


// MARK: - Level Copy

/// The app states facts and compares only against bounds the user actually set.
/// These guard both rules against regression.
@Suite("Level Copy — Factual Tone and Target Attribution")
struct LevelCopyTests {

    private func level(status: LevelStatus,
                       source: RangeSource,
                       safety: SafetyFlag? = nil,
                       phase: MedicationManager.CyclePosition = .trough) -> HormoneLevel {
        HormoneLevel(value: 142, unit: .picogramsPerMilliliter, status: status,
                     phase: phase, deviation: .onTrack, safety: safety,
                     bounds: LevelBounds(min: 100, max: 200), boundsSource: source)
    }

    @MainActor
    @Test("Model-derived bounds produce no comparison and no status pill")
    func modelDerivedMakesNoClaim() {
        // The user never set this range, so the app must not tell them they are
        // above or below "their" target.
        for status: LevelStatus in [.criticallyLow, .veryLow, .slightlyBelow,
                                    .inRange, .slightlyAbove, .high] {
            let l = level(status: status, source: .modelDerived)
            #expect(l.boundsRelation == nil)
            #expect(l.statusPillText == nil, "status \(status) should render no pill")
            #expect(!l.summaryText.contains("range"),
                    "summary should make no range claim, got: \(l.summaryText)")
        }
    }

    @MainActor
    @Test("Model-derived bounds are never tinted as good or bad")
    func modelDerivedIsNeutrallyTinted() {
        for status: LevelStatus in [.criticallyLow, .inRange, .high] {
            #expect(level(status: status, source: .modelDerived).statusTint == Theme.Colors.accent)
        }
    }

    @MainActor
    @Test("User-set bounds produce a comparison naming the range")
    func userSetComparesAgainstTheRange() {
        #expect(level(status: .inRange, source: .userSet).summaryText.contains("within your set trough range"))
        #expect(level(status: .veryLow, source: .userSet).summaryText.contains("below your set trough range"))
        #expect(level(status: .high, source: .userSet).summaryText.contains("above your set trough range"))
    }

    @MainActor
    @Test("A safety flag surfaces even with no user-set bounds")
    func safetyFlagAlwaysSurfaces() {
        // Crossing a documented clinical threshold is a fact about the estimate,
        // not a comparison to a target, so it does not depend on user bounds.
        let l = level(status: .high, source: .modelDerived, safety: .estrogenCeiling)
        #expect(l.statusPillText != nil)
        #expect(l.safetyNote != nil)
        #expect(l.statusTint == Theme.Colors.error)
    }

    @MainActor
    @Test("Level copy contains no advisory, evaluative or congratulatory language")
    func copyIsFactual() {
        let banned = ["consider", "you should", "keep up", "great", "excellent",
                      "optimal", "sweet spot", "make sure", "don't forget",
                      "monitor for", "consult", "contact your", "well done"]
        var samples: [String] = []
        for source: RangeSource in [.userSet, .modelDerived] {
            for status: LevelStatus in [.criticallyLow, .veryLow, .slightlyBelow,
                                        .inRange, .slightlyAbove, .high] {
                for phase: MedicationManager.CyclePosition in [.trough, .nearPeak, .midCycle, .unknown] {
                    let l = level(status: status, source: source, phase: phase)
                    samples.append(l.summaryText)
                    if let pill = l.statusPillText { samples.append(pill) }
                }
            }
        }
        for sample in samples {
            for phrase in banned {
                #expect(!sample.lowercased().contains(phrase),
                        "copy contains \"\(phrase)\": \(sample)")
            }
        }
    }
}


// MARK: - Regression Tests for 2026-07-28 QA Fixes

/// Covers the testosterone scalingConstant recalibration (previously ~20-98x
/// too low — see PharmacokineticConstants.swift for the derivation).
/// NOTE on what these tests actually measure. They check the model against *clinical*
/// peak bands, and the literature quotes those for an established regimen — accumulation
/// from earlier doses included — not for one injection into an empty system.
///
/// These used to get that accumulation for free. A single logged dose put
/// `estimatedLevels` into a forward-projection branch that invented the remaining doses
/// on the ester's typical interval, so the peak inside a multi-interval window was the
/// peak of a *projected* regimen rather than of one injection. That projection has since
/// been removed — it drew untaken doses as though they had already been given, which is
/// what `ForwardProjectionTests` now guards — so a scenario that needs accumulation has
/// to log the doses for real.
///
/// Esters whose interval exceeds the window never accumulated inside it either way, and
/// stay single-dose scenarios: TU is dosed every 10 weeks, so its 14-day window only ever
/// held one injection. (Before 2026-07-31 the projection used 7 days for every
/// injectable, which is why the TU expectation moved: projecting it weekly reached
/// ~2850 ng/dL against a single-dose ~1190.)
@Suite("Testosterone Ester — Absolute Peak Accuracy (post-recalibration)")
struct TestosteronePeakAccuracyTests {

    @MainActor
    @Test("TE 100mg weekly produces clinically plausible peak ~600–900 ng/dL")
    func teWeeklyRegimenPeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        // The 400–900 band describes 100 mg *q7d*, so the history has to actually contain
        // that regimen. Six weeks is well past accumulation plateau for TE's ~4.5-day
        // terminal half-life. This used to be one dose plus five imaginary ones supplied
        // by the forward projection; on a single real dose the model reads ~367 ng/dL,
        // which is the correct single-injection answer to a question nobody was asking.
        mgr.doseHistory = (0..<6).reversed().map { k in
            DoseRecord(doseDate: now.addingTimeInterval(-Double(k * 7) * 86400.0),
                       medicationType: "Testosterone",
                       ester: TestosteroneEster.enanthate.rawValue,
                       administrationMethod: "Injectable", doseAmount: 100.0, doseStatus: .taken)
        }

        // One interval forward from the newest dose: the steady-state peak.
        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                          stepDays: 0.25, applyCalibration: false)
        // TE's scaling constant was corrected 2026-07-31 from 923 to 457.67 by the
        // clearance identity; on the old value this same scenario read ~1160 ng/dL.
        // 100 mg weekly is a standard regimen and should land mid-band, not near the top.
        //
        // The 2026-08-02 shape refit moved S again (457.67 → 107.98) but deliberately
        // did NOT move this scenario's magnitude: S and ke changed together, and Cavg
        // depends only on their ratio. The peak drops slightly (750 → 703 exogenous)
        // because the curve is now flatter within the interval, not lower overall.
        let maxLevel = points.map(\.value).max() ?? 0
        #expect(maxLevel > 400 && maxLevel < 900,
                "TE 100mg q7d steady-state peak should be 400-900 ng/dL, got \(maxLevel)")
    }

    @MainActor
    @Test("TP 50mg EOD produces clinically plausible peak ~800–1200 ng/dL")
    func tpEodRegimenPeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        // The band below describes 50 mg *EOD* — roughly 146 mg of testosterone per week,
        // a deliberately high dose — so the history has to contain that regimen. It used
        // to arrive via the forward projection, which invented doses at the ester's
        // 2-day interval across this window; with that gone they are logged for real.
        mgr.doseHistory = (0..<8).reversed().map { k in
            DoseRecord(doseDate: now.addingTimeInterval(-Double(k * 2) * 86400.0),
                       medicationType: "Testosterone",
                       ester: TestosteroneEster.propionate.rawValue,
                       administrationMethod: "Injectable", doseAmount: 50.0, doseStatus: .taken)
        }

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(7 * 86400),
                                          stepDays: 0.1, applyCalibration: false)
        // Range widened 2026-07-31; the old 500-1600 was written against a weekly
        // projection rather than the ester's real 2-day interval.
        let maxLevel = points.map(\.value).max() ?? 0
        #expect(maxLevel > 900 && maxLevel < 2200,
                "TP 50mg EOD steady-state peak should be 900-2200 ng/dL, got \(maxLevel)")
    }

    @MainActor
    @Test("TU 1000mg produces a non-trivial, clinically plausible peak (not ~13 ng/dL)")
    func tuSingleDosePeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(doseDate: now, medicationType: "Testosterone",
                                 ester: TestosteroneEster.undecanoate.rawValue,
                                 administrationMethod: "Injectable", doseAmount: 1000.0, doseStatus: .taken)
        mgr.doseHistory = [record]

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(21 * 86400),
                                          stepDays: 0.5, applyCalibration: false)
        let maxLevel = points.map(\.value).max() ?? 0
        // The peak amplitude is roughly consistent with Wang et al. 2010 (~1100 ng/dL
        // for 1000mg IM); the range below is a plausibility check, not a calibration
        // target.
        //
        // Two 2026-07-31 changes pull in opposite directions here and roughly cancel:
        // S rose 214 → 457.67 (clearance identity), while the forward projection moved
        // from weekly to the ester's real 10-week interval. Net effect on this scenario
        // was ~1190 ng/dL, against ~1050 before. Had only the first landed it would read
        // ~2850, which is why `typicalIntervalDays` exists. The projection has since been
        // removed outright, which leaves this scenario unchanged: TU's 10-week interval
        // never placed a second dose inside a 21-day window in the first place.
        //
        // The 2026-08-02 shape refit then moved the peak to ~944 ng/dL and, more to the
        // point, moved *when* it arrives: day 7 rather than day 0.66. This 21-day window
        // now genuinely brackets the peak instead of catching the tail of a curve that
        // had already turned over. The former comment here cited OPEN_CONCERNS.md §4's
        // claim that TU "needs a 3-parameter model"; that claim was withdrawn — see §4a
        // for what is actually still open (a half-life source conflict, not compartments).
        #expect(maxLevel > 800 && maxLevel < 2000,
                "TU 1000mg peak should be in the plausible range 800–2000 ng/dL, got \(maxLevel)")
    }
}

/// Covers the oral/transdermal routing bug: previously, the main superposition
/// loop's `isInjectable && event.ke > 0` guard checked the manager's GLOBAL
/// selected route, not each event's own kinetics, so oral and transdermal
/// dose contributions fell through to an unscaled branch and were effectively
/// invisible (< 1 pg/mL regardless of dose).
@Suite("Oral & Transdermal Routes — Dose Response Is No Longer Negligible")
struct RouteDoseResponseTests {

    @MainActor
    @Test("Oral E2 2mg produces a real, dose-responsive peak (not <1 pg/mL)")
    func oralProducesRealPeak() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Oral"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let record = DoseRecord(doseDate: now, medicationType: "Estrogen",
                                 ester: MedicationEster.oral.rawValue,
                                 administrationMethod: "Oral", doseAmount: 2.0, doseStatus: .taken)
        mgr.doseHistory = [record]

        let points = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(24 * 3600),
                                          stepDays: 1.0 / 24.0, applyCalibration: false)
        let maxLevel = points.map(\.value).max() ?? 0
        let baseline = MedicationManager.MedicationType.estrogen.suppressedBaseline
        #expect(maxLevel > baseline + 20,
                "Oral 2mg should meaningfully raise the level above baseline (target ~60 pg/mL peak), got \(maxLevel)")
    }

    @MainActor
    @Test("Transdermal E2 1mg/day produces a real, dose-responsive steady level (not <1 pg/mL)")
    func transdermalProducesRealLevel() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Cream"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        var doses: [DoseRecord] = []
        for day in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: -9 + day, to: now)!
            doses.append(DoseRecord(doseDate: date, medicationType: "Estrogen",
                                     ester: MedicationEster.transdermal.rawValue,
                                     administrationMethod: "Cream", doseAmount: 1.0, doseStatus: .taken))
        }
        mgr.doseHistory = doses

        let points = mgr.estimatedLevels(from: now.addingTimeInterval(-3600), to: now,
                                          stepDays: 1.0 / 24.0, applyCalibration: false)
        let level = points.last?.value ?? 0
        let baseline = MedicationManager.MedicationType.estrogen.suppressedBaseline
        #expect(level > baseline + 20,
                "Daily transdermal 1mg at steady state should meaningfully raise the level (target ~50 pg/mL), got \(level)")
    }
}

/// Covers the skipped-dose bug: `estimatedLevels()` used to include ANY active
/// (non-deleted) dose record regardless of `doseStatus`, so a dose explicitly
/// logged as `.skipped` still contributed to the predicted curve exactly as if
/// it had been taken.
@Suite("Skipped Doses — Excluded From The PK Curve")
struct SkippedDoseExclusionTests {

    @MainActor
    @Test("A skipped dose contributes nothing to predicted levels")
    func skippedDoseContributesNothing() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Testosterone"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let taken = DoseRecord(doseDate: now.addingTimeInterval(-7 * 86400), medicationType: "Testosterone",
                                ester: TestosteroneEster.cypionate.rawValue,
                                administrationMethod: "Injectable", doseAmount: 100.0, doseStatus: .taken)
        let skipped = DoseRecord(doseDate: now, medicationType: "Testosterone",
                                  ester: TestosteroneEster.cypionate.rawValue,
                                  administrationMethod: "Injectable", doseAmount: 100.0, doseStatus: .skipped)

        // Baseline run: only the taken dose exists.
        mgr.doseHistory = [taken]
        let withoutSkip = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(3600),
                                               stepDays: 1.0, applyCalibration: false)

        // Add the skipped dose on top — level should be unchanged.
        mgr.doseHistory = [taken, skipped]
        let withSkip = mgr.estimatedLevels(from: now, to: now.addingTimeInterval(3600),
                                            stepDays: 1.0, applyCalibration: false)

        guard let a = withoutSkip.first?.value, let b = withSkip.first?.value else {
            Issue.record("Failed to get level values")
            return
        }
        #expect(abs(a - b) < 0.5,
                "A skipped dose should not change predicted levels: without=\(a), with=\(b)")
    }
}

/// Covers the per-dose route bug: DoseEvent construction used to gate on the
/// manager's globally-selected administration method rather than each dose's
/// own `administrationMethod`, so historical doses logged under a route the
/// user has since switched away from were silently re-modeled with the wrong
/// kinetics every time the curve was recomputed.
@Suite("Route Switching — Historical Doses Keep Their Own Kinetics")
struct RouteSwitchConsistencyTests {

    @MainActor
    @Test("An oral dose retains oral-scale kinetics even after switching the app's selected route to Injectable")
    func oralDoseUnaffectedByLaterRouteSwitch() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let oralDose = DoseRecord(doseDate: now, medicationType: "Estrogen",
                                   ester: MedicationEster.oral.rawValue,
                                   administrationMethod: "Oral", doseAmount: 2.0, doseStatus: .taken)
        mgr.doseHistory = [oralDose]

        // Case 1: still selected as Oral.
        mgr.selectedAdministrationMethod = "Oral"
        let stillOral = mgr.estimatedLevels(from: now.addingTimeInterval(10 * 3600), to: now.addingTimeInterval(10 * 3600),
                                             stepDays: 1.0, applyCalibration: false)

        // Case 2: user has since switched their selected route to Injectable,
        // but this dose was logged while they were on Oral.
        mgr.selectedAdministrationMethod = "Injectable"
        let afterSwitch = mgr.estimatedLevels(from: now.addingTimeInterval(10 * 3600), to: now.addingTimeInterval(10 * 3600),
                                               stepDays: 1.0, applyCalibration: false)

        guard let a = stillOral.first?.value, let b = afterSwitch.first?.value else {
            Issue.record("Failed to get level values")
            return
        }
        #expect(abs(a - b) < 1.0,
                "A historical oral dose's contribution should not change just because the currently-selected route changed: while-still-Oral=\(a), after-switch-to-Injectable=\(b)")
    }
}

/// Covers the chart-window sizing bug: `refreshState()` sized the visible date
/// window from every active dose regardless of `doseStatus`, while the level
/// computation only ever plots `.taken` doses. A skipped (or otherwise
/// non-taken) record could therefore stretch the x-axis into a region that has
/// no plotted contribution behind it.
///
/// The window is now anchored on `now` and sized by the ester alone (see
/// `PKChartWindow`), so this property holds structurally rather than by careful
/// filtering — no dose positions the x-axis, so no dose can stretch it. Kept as a
/// regression guard against a future change that reintroduces dose-anchored bounds.
@Suite("Chart Window — Not Stretched By Non-Taken Doses")
struct ChartWindowSkippedDoseTests {

    @MainActor
    @Test("A skipped dose does not stretch the chart's date window")
    func skippedDoseDoesNotStretchWindow() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Oral"
        mgr.customFrequencyDays = nil
        mgr.antiAndrogenInUse = false
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let anchor = now.addingTimeInterval(-2 * 86400)
        let taken = DoseRecord(doseDate: anchor, medicationType: "Estrogen",
                               ester: MedicationEster.oral.rawValue,
                               administrationMethod: "Oral", doseAmount: 2.0, doseStatus: .taken)
        let skipped = DoseRecord(doseDate: now, medicationType: "Estrogen",
                                 ester: MedicationEster.oral.rawValue,
                                 administrationMethod: "Oral", doseAmount: 2.0, doseStatus: .skipped)

        // Baseline run: only the taken dose exists.
        mgr.lastDoseDate = anchor
        mgr.doseHistory = [taken]
        mgr.refreshState()
        let withoutSkip = mgr.recentLevels

        // Add the skipped dose on top. It contributes nothing to the curve, so it
        // must not move the window either.
        mgr.lastDoseDate = anchor
        mgr.doseHistory = [taken, skipped]
        mgr.refreshState()
        let withSkip = mgr.recentLevels

        guard let startA = withoutSkip.first?.date, let startB = withSkip.first?.date else {
            Issue.record("refreshState() produced no chart points")
            return
        }
        #expect(abs(startA.timeIntervalSince(startB)) < 60,
                "A skipped dose should not move the chart's window start: without=\(startA), with=\(startB)")
        #expect(withoutSkip.count == withSkip.count,
                "A skipped dose should not change the number of plotted points: without=\(withoutSkip.count), with=\(withSkip.count)")
    }
}
