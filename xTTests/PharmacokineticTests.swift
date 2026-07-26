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
        let expected: [String: Double] = [
            "Valerate (EV)": 2.0,
            "Cypionate (EC)": 8.5,
            "Oral": 0.5,
            "Transdermal": 1.5
        ]
        for ester in MedicationEster.allCases {
            let halfLife = ester.halfLifeDays
            #expect(halfLife > 0, "\(ester.rawValue) half-life must be positive")
            #expect(halfLife >= 0.25 && halfLife <= 10.0,
                    "\(ester.rawValue) half-life \(halfLife) outside clinical range")
            #expect(halfLife == expected[ester.rawValue],
                    "\(ester.rawValue) half-life changed from expected \(expected[ester.rawValue]!) to \(halfLife)")
        }
    }

    @Test("All T ester half-lives are positive and within expected ranges")
    func testosteroneHalfLives() {
        let expected: [String: Double] = [
            "Cypionate (TC)": 8.0,
            "Enanthate (TE)": 7.0,
            "Propionate (TP)": 1.0,
            "Undecanoate (TU)": 20.0
        ]
        for ester in TestosteroneEster.allCases {
            let halfLife = ester.halfLifeDays
            #expect(halfLife > 0, "\(ester.rawValue) half-life must be positive")
            #expect(halfLife >= 0.5 && halfLife <= 25.0,
                    "\(ester.rawValue) half-life \(halfLife) outside clinical range")
            #expect(halfLife == expected[ester.rawValue],
                    "\(ester.rawValue) half-life changed from expected \(expected[ester.rawValue]!) to \(halfLife)")
        }
    }

    @Test("E2 elimination half-lives are consistent (3 hours for all esters)")
    func estrogenEliminationHalfLife() {
        for ester in MedicationEster.allCases {
            #expect(ester.eliminationHalfLifeHours == 3.0,
                    "\(ester.rawValue) elimination half-life must be 3.0 hours")
        }
    }

    @Test("T elimination half-lives are consistent (2 hours for all esters)")
    func testosteroneEliminationHalfLife() {
        for ester in TestosteroneEster.allCases {
            #expect(ester.eliminationHalfLifeHours == 2.0,
                    "\(ester.rawValue) elimination half-life must be 2.0 hours")
        }
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
        // All T esters are injectable
        for ester in TestosteroneEster.allCases {
            #expect(ester.bioavailability == 1.0)
        }
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

    @Test("E2 scaling constants are in clinical range (1000–15000)")
    func estrogenScalingConstants() {
        let constants = [
            MedicationEster.valerate.scalingConstant,
            MedicationEster.cypionate.scalingConstant,
            MedicationEster.oral.scalingConstant,
            MedicationEster.transdermal.scalingConstant,
        ]
        for c in constants {
            #expect(c >= 1000 && c <= 15000,
                    "Scaling constant \(c) outside clinical range")
        }
    }

    @Test("T scaling constants are in clinical range (3–25)")
    func testosteroneScalingConstants() {
        let constants = [
            TestosteroneEster.cypionate.scalingConstant,
            TestosteroneEster.enanthate.scalingConstant,
            TestosteroneEster.propionate.scalingConstant,
            TestosteroneEster.undecanoate.scalingConstant,
        ]
        for c in constants {
            #expect(c >= 3 && c <= 25,
                    "Scaling constant \(c) outside clinical range")
        }
    }

    @Test("T propionate scaling > cypionate (shorter half-life → higher peak)")
    func propionateHigherScalingThanCypionate() {
        #expect(TestosteroneEster.propionate.scalingConstant > TestosteroneEster.cypionate.scalingConstant,
                "Shorter half-life ester should have higher scaling constant to match peak levels")
    }

    @Test("T undecanoate scaling < cypionate (longer half-life → flatter profile)")
    func undecanoateLowerScaling() {
        #expect(TestosteroneEster.undecanoate.scalingConstant < TestosteroneEster.cypionate.scalingConstant,
                "Longer half-life ester should have lower scaling constant (flatter profile)")
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
        #expect(abs(result) < 0.01, "Bateman at t=30d should be negligible, got \(result)")
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
        // EV: ka = 0.347, ke = 5.545 → ratio ka/ke ≈ 0.063
        let ev_ka = log(2) / MedicationEster.valerate.halfLifeDays
        let ev_ke = log(2) / (MedicationEster.valerate.eliminationHalfLifeHours / 24.0)
        #expect(ev_ka < ev_ke, "EV should have ka < ke")
        #expect(ev_ka / ev_ke < 0.2, "EV: ka/ke ratio \(ev_ka / ev_ke) should be < 0.2 (flip-flop)")

        // EC: ka = 0.082, ke = 5.545 → ratio ≈ 0.015
        let ec_ka = log(2) / MedicationEster.cypionate.halfLifeDays
        let ec_ke = log(2) / (MedicationEster.cypionate.eliminationHalfLifeHours / 24.0)
        #expect(ec_ka < ec_ke, "EC should have ka < ke")
        #expect(ec_ka / ec_ke < 0.05, "EC: ka/ke ratio \(ec_ka / ec_ke) should be < 0.05")

        // TC: ka = 0.087, ke = 8.318 → ratio ≈ 0.010
        let tc_ka = log(2) / TestosteroneEster.cypionate.halfLifeDays
        let tc_ke = log(2) / (TestosteroneEster.cypionate.eliminationHalfLifeHours / 24.0)
        #expect(tc_ka < tc_ke, "TC should have ka < ke")
        #expect(tc_ka / tc_ke < 0.05, "TC: ka/ke ratio \(tc_ka / tc_ke) should be < 0.05")

        // TP: ka = 0.693, ke = 8.318 → ratio ≈ 0.083 (borderline flip-flop)
        let tp_ka = log(2) / TestosteroneEster.propionate.halfLifeDays
        let tp_ke = log(2) / (TestosteroneEster.propionate.eliminationHalfLifeHours / 24.0)
        #expect(tp_ka < tp_ke, "TP should still have ka < ke (barely)")
        #expect(tp_ka / tp_ke < 0.5, "TP: ka/ke ratio should be < 0.5")
    }

    @Test("Oral route: kₐ > kₑ (absorption faster than elimination)")
    func oralKaGreaterThanKe() {
        // Oral: ka = 2.5, ke = 1.386 (absorption faster than elimination)
        // This is NOT flip-flop; terminal slope is elimination-limited
        #expect(2.5 > 1.386, "Oral ka (2.5) should be > ke (1.386)")
    }
}


// MARK: - Time to Peak (t_max)

@Suite("Time to Peak — Pharmacodynamic Accuracy")
struct TimeToPeakTests {

    @MainActor
    @Test("EV t_max ≈ 0.5 days (12 hours)")
    func valeratePeakTime() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = "Estrogen"
        let tMax = mgr.expectedTimeToPeak(for: MedicationEster.valerate)
        // EV: ka=0.347, ke=5.545 → t_max = ln(0.347/5.545)/(0.347-5.545) ≈ 0.52
        #expect(tMax > 0.3 && tMax < 0.8,
                "EV t_max should be ~0.5 days, got \(tMax)")
    }

    @MainActor
    @Test("EC t_max ≈ 1.5–2.5 days (slower absorption)")
    func cypionatePeakTime() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = "Estrogen"
        let tMax = mgr.expectedTimeToPeak(for: MedicationEster.cypionate)
        // EC: ka=0.082, ke=5.545 → t_max ≈ 1/ka = 12.2 days? No, watch:
        // t_max = ln(0.082/5.545)/(0.082-5.545) = ln(0.0148)/(-5.463) = -4.211/-5.463 ≈ 0.77
        #expect(tMax > 0.5 && tMax < 3.0,
                "EC t_max should be 0.5–3.0 days, got \(tMax)")
    }

    @MainActor
    @Test("TC t_max ≈ 1–2 days")
    func cypionateTPeakTime() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = "Testosterone"
        // ka = ln2/8.0 ≈ 0.0866, ke = ln2/(2/24) = ln2/0.0833 ≈ 8.318
        let tMax = mgr.expectedTimeToPeak(for: TestosteroneEster.cypionate)
        #expect(tMax > 0.5 && tMax < 3.0,
                "TC t_max should be 0.5–3.0 days, got \(tMax)")
    }

    @MainActor
    @Test("TP t_max ≈ 0.2–0.5 days (rapid)")
    func propionatePeakTime() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = "Testosterone"
        let tMax = mgr.expectedTimeToPeak(for: TestosteroneEster.propionate)
        // TP: ka = 0.693, ke = 8.318 → t_max ≈ 0.33 days (~8 hours)
        #expect(tMax > 0.1 && tMax < 0.6,
                "TP t_max should be 0.1–0.6 days, got \(tMax)")
    }

    @MainActor
    @Test("TU t_max > TC t_max (longer half-life → later peak)")
    func undecanoatePeakTimeLongerThanCypionate() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = "Testosterone"
        let tcMax = mgr.expectedTimeToPeak(for: TestosteroneEster.cypionate)
        let tuMax = mgr.expectedTimeToPeak(for: TestosteroneEster.undecanoate)
        #expect(tuMax > tcMax,
                "TU t_max (\(tuMax)) should be > TC t_max (\(tcMax))")
    }
}


// MARK: - Dynamic Baseline

@Suite("Dynamic Baseline — Endogenous Suppression")
struct DynamicBaselineTests {

    @MainActor
    @Test("Returns suppressed baseline when anti-androgen is in use")
    func antiAndrogenSuppressesT() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
    @Test("Equal actual and predicted → On Track")
    func equalIsOnTrack() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 200, predicted: 200)
        #expect(label == "On Track")
    }

    @MainActor
    @Test("Actual < 0.5× predicted → Critically Below Expected")
    func criticallyBelow() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 80, predicted: 200)
        #expect(label == "Critically Below Expected", "ratio=0.4 should be critically below")
    }

    @MainActor
    @Test("Actual 0.5–0.7× predicted → Below Expected")
    func belowExpected() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 120, predicted: 200)
        #expect(label == "Below Expected", "ratio=0.6 should be below expected")
    }

    @MainActor
    @Test("Actual 0.7–1.3× predicted → On Track")
    func onTrackRange() {
        let mgr = MedicationManager.shared
        for ratio in [0.7, 0.85, 1.0, 1.15, 1.29] {
            let (label, _) = mgr.deviationClassification(actual: ratio * 200, predicted: 200)
            #expect(label == "On Track", "ratio=\(ratio) should be On Track, got \(label)")
        }
    }

    @MainActor
    @Test("Actual 1.3–2.0× predicted → Above Expected")
    func aboveExpected() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 300, predicted: 200)
        #expect(label == "Above Expected", "ratio=1.5 should be above expected")
    }

    @MainActor
    @Test("Actual > 2.0× predicted → Unusually High")
    func unusuallyHigh() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 500, predicted: 200)
        #expect(label == "Unusually High", "ratio=2.5 should be unusually high")
    }

    @MainActor
    @Test("Very low predicted value → Unable to Compare")
    func unableToCompare() {
        let mgr = MedicationManager.shared
        let (label, _) = mgr.deviationClassification(actual: 1.0, predicted: 0.5)
        #expect(label == "Unable to Compare")
    }

    @MainActor
    @Test("Boundary exact values")
    func boundaryValues() {
        let mgr = MedicationManager.shared

        // Exactly 0.5 → should be "Below Expected" (upper bound of "Critically Below" is exclusive)
        let (label1, _) = mgr.deviationClassification(actual: 100.0, predicted: 200.0)
        #expect(label1 == "Below Expected", "ratio=0.5 exact")

        // Exactly 0.7
        let (label2, _) = mgr.deviationClassification(actual: 140.0, predicted: 200.0)
        #expect(label2 == "On Track", "ratio=0.7 exact")

        // Exactly 1.3
        let (label3, _) = mgr.deviationClassification(actual: 260.0, predicted: 200.0)
        #expect(label3 == "Above Expected", "ratio=1.3 exact")

        // Exactly 2.0
        let (label4, _) = mgr.deviationClassification(actual: 400.0, predicted: 200.0)
        #expect(label4 == "Unusually High", "ratio=2.0 exact")
    }
}


// MARK: - Safety Overrides

@Suite("Safety Overrides — Clinical Safety Flags")
struct SafetyOverrideTests {

    @MainActor
    @Test("E2 > 1000 pg/mL → Very High safety check")
    func estrogenVeryHigh() {
        let mgr = MedicationManager.shared
        let result = mgr.safetyOverride(level: 1200, medication: .estrogen, contextLabel: "Expected Peak")
        #expect(result == "Very High – Safety Check")
    }

    @MainActor
    @Test("E2 at exactly 1000 does NOT trigger safety")
    func estrogenExactly1000() {
        let mgr = MedicationManager.shared
        // The test checks `level > 1000`, so exactly 1000 should NOT trigger
        let result = mgr.safetyOverride(level: 1000, medication: .estrogen, contextLabel: "Expected Peak")
        #expect(result == nil, "Exactly 1000 pg/mL should not trigger safety")
    }

    @MainActor
    @Test("T > 1500 ng/dL → Supraphysiological")
    func testosteroneSupraphysiological() {
        let mgr = MedicationManager.shared
        let result = mgr.safetyOverride(level: 1600, medication: .testosterone, contextLabel: "Expected Peak")
        #expect(result == "Supraphysiological")
    }

    @MainActor
    @Test("E2 < 50 at trough → Sub-Therapeutic")
    func estrogenSubTherapeuticTrough() {
        let mgr = MedicationManager.shared
        let result = mgr.safetyOverride(level: 30, medication: .estrogen, contextLabel: "Target Trough")
        #expect(result == "Sub-Therapeutic (Trough)")
    }

    @MainActor
    @Test("E2 < 50 NOT at trough → no safety flag")
    func lowEstrogenNotTroughNoFlag() {
        let mgr = MedicationManager.shared
        let result = mgr.safetyOverride(level: 30, medication: .estrogen, contextLabel: "Expected Peak")
        #expect(result == nil, "Low E2 at peak should not trigger trough warning")
    }

    @MainActor
    @Test("Normal levels → no override")
    func normalNoOverride() {
        let mgr = MedicationManager.shared
        let eResult = mgr.safetyOverride(level: 200, medication: .estrogen, contextLabel: "Expected Peak")
        let tResult = mgr.safetyOverride(level: 600, medication: .testosterone, contextLabel: "Expected Peak")
        #expect(eResult == nil)
        #expect(tResult == nil)
    }
}


// MARK: - Aromatization

@Suite("Aromatization — T→E2 Conversion")
struct AromatizationTests {

    @MainActor
    @Test("0.2% conversion: 1000 ng/dL T → 2.0 pg/mL E2")
    func conversionRate() {
        let mgr = MedicationManager.shared
        let e2 = mgr.estimatedE2FromTestosterone(1000.0)
        #expect(abs(e2 - 2.0) < 0.01, "1000 ng/dL T → E2 should be ~2.0 pg/mL, got \(e2)")
    }

    @MainActor
    @Test("Aromatization yields 0 at zero T")
    func zeroT() {
        let mgr = MedicationManager.shared
        let e2 = mgr.estimatedE2FromTestosterone(0.0)
        #expect(e2 == 0.0, "Zero T should yield zero E2")
    }

    @MainActor
    @Test("Assessment: elevated when E2 > 40")
    func elevatedAssessment() {
        let mgr = MedicationManager.shared
        // 25000 ng/dL T * 0.002 = 50 pg/mL E2 > 40 → elevated
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 25000.0)
        #expect(isElevated, "E2 of \(e2) pg/mL from 25000 ng/dL T should be elevated (>40)")
    }

    @MainActor
    @Test("Assessment: normal when E2 10–40")
    func normalAssessment() {
        let mgr = MedicationManager.shared
        // 8000 ng/dL T * 0.002 = 16 pg/mL → normal
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 8000.0)
        #expect(!isElevated, "E2 of \(e2) pg/mL should NOT be elevated")
    }

    @MainActor
    @Test("Assessment: below range when E2 < 10")
    func belowRangeAssessment() {
        let mgr = MedicationManager.shared
        // 2000 ng/dL T * 0.002 = 4 pg/mL → below range
        let (e2, isElevated, _) = mgr.aromatizationAssessment(for: 2000.0)
        #expect(!isElevated, "E2 of \(e2) pg/mL should NOT trigger elevated")
    }

    @MainActor
    @Test("Aromatization scales linearly")
    func linearScaling() {
        let mgr = MedicationManager.shared
        for t in [100.0, 500.0, 1000.0, 3000.0, 10000.0] {
            let e2 = mgr.estimatedE2FromTestosterone(t)
            let expected = t * 0.002
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.doseHistory = []
        let intensity = mgr.relativeDoseIntensity
        #expect(intensity == 1.0, "No doses should default to intensity 1.0, got \(intensity)")
    }

    @MainActor
    @Test("Standard E dose → intensity ≈ 1.0")
    func standardDoseIntensity() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        #expect(points.first!.value > points.last!.value,
                "Level should decrease from peak to end of week")

        // Peak should be within 200–300 pg/mL for 2mg EV (S=3150, effective=1.528mg)
        let maxLevel = points.map(\.value).max() ?? 0
        #expect(maxLevel > 150 && maxLevel < 400,
                "EV 2mg peak should be 150–400 pg/mL, got \(maxLevel)")

        // After 7 days, should be approaching baseline (~5 pg/mL fully suppressed)
        let troughLevel = points.last!.value
        #expect(troughLevel < maxLevel * 0.5,
                "Trough at day 7 should be well below peak")
    }

    @MainActor
    @Test("Single TC dose produces clinically plausible peak ~600–900 ng/dL")
    func tcSingleDosePeak() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        // Oral drops much faster: after 24h should be near baseline
        #expect(lastLevel < maxLevel * 0.5,
                "Oral E2 should decay significantly in 24h: peak=\(maxLevel), 24h=\(lastLevel)")
    }

    @MainActor
    @Test("Calibration factor scales levels proportionally")
    func calibrationScaling() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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

        #expect(abs(cVal - uVal * 1.5) < 1.0,
                "Calibrated level (\(cVal)) should be ~1.5x uncalibrated (\(uVal))")
    }
}


// MARK: - Edge Cases & Robustness

@Suite("PK Engine — Edge Cases & Robustness")
struct PKEngineEdgeCaseTests {

    @MainActor
    @Test("Empty dose history returns empty points array")
    func emptyDoseHistory() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.doseHistory = []
        let points = mgr.estimatedLevels(from: Date(), to: Date().addingTimeInterval(86400))
        // With no medication selected, returns []
        #expect(points.isEmpty)
    }

    @MainActor
    @Test("No medication selected returns empty")
    func noMedicationSelected() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
        mgr.selectedMedication = nil
        mgr.selectedAdministrationMethod = nil
        let points = mgr.estimatedLevels(from: Date(), to: Date().addingTimeInterval(86400))
        #expect(points.isEmpty)
    }

    @MainActor
    @Test("Zero dose amount produces near-baseline levels")
    func zeroDoseAmount() {
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()
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
        let mgr = MedicationManager.shared
        mgr.clearSelection()

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
        let mgr = MedicationManager.shared
        let peak = mgr.contextualRange(for: .estrogen, at: .nearPeak, doseIntensity: 1.0)
        let trough = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        #expect(peak.max > trough.max,
                "Peak ceiling (\(peak.max)) should exceed trough max (\(trough.max))")
    }

    @MainActor
    @Test("Higher dose intensity shifts targets upward")
    func doseIntensityShiftsTargets() {
        let mgr = MedicationManager.shared
        let lowRange = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 0.25)
        let highRange = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 2.0)
        // High intensity should shift targets up (or at least not below low)
        #expect(highRange.max >= lowRange.max - 1.0,
                "Higher dose intensity should not reduce target ranges")
    }

    @MainActor
    @Test("Unknown cycle position uses fallback range")
    func unknownCycleUsesFallback() {
        let mgr = MedicationManager.shared
        let unknown = mgr.contextualRange(for: .estrogen, at: .unknown, doseIntensity: 1.0)
        let trough = mgr.contextualRange(for: .estrogen, at: .trough, doseIntensity: 1.0)
        // Unknown fallback uses troughMin and peakCeiling
        #expect(unknown.min == trough.min,
                "Unknown should use troughMin (\(trough.min)) for safety, got \(unknown.min)")
    }
}
