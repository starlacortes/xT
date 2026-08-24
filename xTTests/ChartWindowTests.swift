//
//  ChartWindowTests.swift
//  xTTests
//
//  Covers `PKChartWindow` — the rule that sizes the chart's visible range and its
//  sampling resolution from the ester being plotted.
//

import Foundation
import Testing
@testable import xT

// MARK: - The rule itself

@Suite("PKChartWindow — window and step sizing")
struct PKChartWindowTests {

    private static let minuteInDays = 1.0 / (24.0 * 60.0)

    /// The worked numbers behind the rule, asserted as exact closed-form values.
    ///
    /// **EV is the load-bearing row.** The rule was derived to reproduce the 1-day-back /
    /// 2-days-forward window that shipped before it, so a change here means the chart
    /// that was signed off on has moved, not merely that a constant drifted.
    ///
    /// TP and both cream rows pass `nil`: TP is uncalibrated and the transdermal routes
    /// have no meaningful t_max. They fall back to the 2 d raw, which the daily routes
    /// then clamp to their 1.5 d ceiling.
    @Test("Window length and step match the derived rule for every type")
    func windowTableMatchesRule() {
        let now = Date()
        // label, gated t_max, interval days, expected window days, expected step days
        let rows: [(String, Double?, Double, Double, Double)] = [
            ("EV",       MedicationEster.valerate.timeToPeakDays,       7,   3.15147,  0.078787),
            ("EC",       MedicationEster.cypionate.timeToPeakDays,      7,   6.44753,  0.161188),
            ("E2 oral",  MedicationEster.oral.timeToPeakDays,           1,   1.50000,  0.031249),
            ("E2 cream", nil,                                           1,   1.50000,  0.037500),
            ("TC",       TestosteroneEster.cypionate.timeToPeakDays,    7,   2.75767,  0.068942),
            ("TE",       TestosteroneEster.enanthate.timeToPeakDays,    7,   2.36434,  0.059108),
            ("TP",       nil,                                           2,   2.00000,  0.050000),
            ("TU",       TestosteroneEster.undecanoate.timeToPeakDays,  70, 10.50001,  0.262500),
            ("T oral",   TestosteroneEster.oral.timeToPeakDays,         1,   1.50000,  0.015626),
            ("T cream",  nil,                                           1,   1.50000,  0.037500),
        ]

        for (label, tmax, interval, expectedDays, expectedStep) in rows {
            let w = PKChartWindow.compute(tmaxDays: tmax, intervalDays: interval, now: now)

            #expect(abs(w.totalDays - expectedDays) < 0.001,
                    "\(label) window should be \(expectedDays) d, got \(w.totalDays)")
            #expect(abs(w.stepDays - expectedStep) < 0.0001,
                    "\(label) step should be \(expectedStep) d, got \(w.stepDays)")

            // 1 part history to 2 parts projection.
            let past = now.timeIntervalSince(w.start) / 86400.0
            #expect(abs(past - expectedDays / 3.0) < 0.001,
                    "\(label) should put one third of the window in the past, got \(past) of \(w.totalDays)")
        }
    }

    /// Guards the specific window the user approved. Stated separately from the table so
    /// a failure names the thing that actually broke.
    @Test("EV keeps the ~3 day window that shipped")
    func evWindowIsPreserved() {
        let w = PKChartWindow.compute(tmaxDays: MedicationEster.valerate.timeToPeakDays,
                                      intervalDays: 7, now: Date())
        #expect(abs(w.totalDays - 3.0) < 0.2,
                "EV should stay within a fifth of a day of the shipped 3-day window, got \(w.totalDays)")
    }

    /// The whole point of the change: the step must resolve the peak rather than alias
    /// it. The old oral path sampled at exactly one day against a t_max of six hours.
    @Test("Step resolves the peak for every calibrated ester")
    func stepResolvesPeak() {
        func check(_ label: String, _ tmax: Double, _ interval: Double) {
            let w = PKChartWindow.compute(tmaxDays: tmax, intervalDays: interval, now: Date())
            #expect(w.stepDays < tmax / 4.0,
                    "\(label) samples at \(w.stepDays) d against a t_max of \(tmax) d — too coarse to resolve the peak")
        }
        check("EV", MedicationEster.valerate.timeToPeakDays, 7)
        check("EC", MedicationEster.cypionate.timeToPeakDays, 7)
        check("E2 oral", MedicationEster.oral.timeToPeakDays, 1)
        check("TC", TestosteroneEster.cypionate.timeToPeakDays, 7)
        check("TE", TestosteroneEster.enanthate.timeToPeakDays, 7)
        check("TU", TestosteroneEster.undecanoate.timeToPeakDays, 70)
        check("T oral", TestosteroneEster.oral.timeToPeakDays, 1)
    }

    /// Defence in depth. Callers are required to gate to `nil`, but a NaN reaching the
    /// arithmetic would poison the window silently — Swift's `min`/`max` propagate NaN
    /// from the first operand and drop it from the second.
    @Test("A non-finite, zero or negative t_max never yields a NaN window")
    func degenerateTmaxIsSafe() {
        let candidates: [Double?] = [nil, .nan, .infinity, -.infinity, 0, -1, -0.0]
        for tmax in candidates {
            for interval in [0.0, -5.0, 1.0, 7.0, 70.0] {
                let w = PKChartWindow.compute(tmaxDays: tmax, intervalDays: interval, now: Date())
                let label = "t_max=\(String(describing: tmax)) interval=\(interval)"
                #expect(w.stepDays.isFinite && w.stepDays > 0, "\(label) produced step \(w.stepDays)")
                #expect(w.denseStepDays.isFinite && w.denseStepDays > 0,
                        "\(label) produced dense step \(w.denseStepDays)")
                #expect(w.totalDays.isFinite && w.totalDays > 0, "\(label) produced window \(w.totalDays)")
                #expect(w.start < w.end, "\(label) produced an inverted window")
            }
        }
    }

    /// For any interval under 4/3 d the lower bound (2 d) exceeds the ceiling
    /// (1.5 × interval). The window must collapse to the ceiling, not invert.
    @Test("Daily routes collapse to the interval ceiling rather than inverting")
    func dailyRouteClampDoesNotInvert() {
        for tmax: Double? in [nil, 0.25, 5.0] {
            let w = PKChartWindow.compute(tmaxDays: tmax, intervalDays: 1, now: Date())
            #expect(abs(w.totalDays - 1.5) < 0.001,
                    "a daily route should clamp to 1.5 d, got \(w.totalDays) for t_max \(String(describing: tmax))")
        }
    }

    @Test("Step and dense step honour their floors, and dense is finer")
    func stepFloors() {
        // A very short t_max would otherwise drive the step arbitrarily small.
        let w = PKChartWindow.compute(tmaxDays: 0.0001, intervalDays: 1, now: Date())
        #expect(w.stepDays >= Self.minuteInDays * 15 - 1e-9,
                "step should floor at 15 minutes, got \(w.stepDays * 24 * 60) min")
        #expect(w.denseStepDays >= Self.minuteInDays * 5 - 1e-9,
                "dense step should floor at 5 minutes, got \(w.denseStepDays * 24 * 60) min")
        #expect(w.denseStepDays <= w.stepDays,
                "the scrub grid must not be coarser than the drawn curve")
    }

    /// Point counts stay comparable across timescales, so curves read with the same
    /// density whether the ester turns over in hours or in weeks. TU used to get five.
    @Test("Every type yields a usable point count")
    func pointCountsAreComparable() {
        let rows: [(String, Double?, Double)] = [
            ("EV", MedicationEster.valerate.timeToPeakDays, 7),
            ("EC", MedicationEster.cypionate.timeToPeakDays, 7),
            ("E2 oral", MedicationEster.oral.timeToPeakDays, 1),
            ("E2 cream", nil, 1),
            ("TC", TestosteroneEster.cypionate.timeToPeakDays, 7),
            ("TE", TestosteroneEster.enanthate.timeToPeakDays, 7),
            ("TP", nil, 2),
            ("TU", TestosteroneEster.undecanoate.timeToPeakDays, 70),
            ("T oral", TestosteroneEster.oral.timeToPeakDays, 1),
            ("T cream", nil, 1),
        ]
        for (label, tmax, interval) in rows {
            let w = PKChartWindow.compute(tmaxDays: tmax, intervalDays: interval, now: Date())
            let points = Int(w.totalDays / w.stepDays) + 1
            #expect(points >= 20 && points <= 200,
                    "\(label) would draw \(points) points — outside the 20…200 band the rule targets")
        }
    }
}

// MARK: - Resolution through the manager

@Suite("Chart window — manager resolution")
struct ChartWindowResolutionTests {

    @MainActor
    private func manager(medication: String, route: String,
                         ester: String, file: String = #fileID,
                         function: String = #function) -> MedicationManager {
        let mgr = MedicationManager(defaults: TestDefaults.suite(file: file, function: function))
        mgr.selectedMedication = medication
        mgr.selectedAdministrationMethod = route
        mgr.customFrequencyDays = nil
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []
        let now = Date()
        mgr.lastDoseDate = now.addingTimeInterval(-3600)
        mgr.doseHistory = [DoseRecord(doseDate: now.addingTimeInterval(-3600),
                                      medicationType: medication, ester: ester,
                                      administrationMethod: route, doseAmount: 2.0,
                                      doseStatus: .taken)]
        return mgr
    }

    /// The gate that keeps an uncalibrated or non-finite t_max out of the window rule.
    /// TP is uncalibrated; both transdermal routes have no meaningful t_max at all
    /// (`TestosteroneEster.transdermal.timeToPeakDays` is NaN by design).
    @MainActor
    @Test("Uncalibrated and transdermal esters fall back instead of sizing from t_max")
    func uncalibratedEstersFallBack() {
        let tp = manager(medication: "Testosterone", route: "Injectable",
                         ester: TestosteroneEster.propionate.rawValue).chartWindow()
        #expect(abs(tp.totalDays - 2.0) < 0.001,
                "TP is uncalibrated and should take the 2 d fallback, got \(tp.totalDays)")

        for (med, ester) in [("Testosterone", TestosteroneEster.cypionate.rawValue),
                             ("Estrogen", MedicationEster.valerate.rawValue)] {
            let cream = manager(medication: med, route: "Cream", ester: ester).chartWindow()
            #expect(cream.totalDays.isFinite && cream.stepDays.isFinite,
                    "\(med) cream produced a non-finite window")
            #expect(abs(cream.totalDays - 1.5) < 0.001,
                    "\(med) cream should clamp to 1.5 d, got \(cream.totalDays)")
        }
    }

    /// The route decides the constants, so a cream dose must not be sized by whichever
    /// injectable ester happens to be stored on the record.
    @MainActor
    @Test("The dose's route, not its stored ester, sizes the window")
    func routeDecidesWindow() {
        let injectable = manager(medication: "Testosterone", route: "Injectable",
                                 ester: TestosteroneEster.undecanoate.rawValue).chartWindow()
        let cream = manager(medication: "Testosterone", route: "Cream",
                            ester: TestosteroneEster.undecanoate.rawValue).chartWindow()
        #expect(abs(injectable.totalDays - 10.5) < 0.01,
                "injectable TU should get its 10.5 d window, got \(injectable.totalDays)")
        #expect(abs(cream.totalDays - 1.5) < 0.01,
                "a cream dose storing the TU ester must be sized as transdermal, got \(cream.totalDays)")
    }

    @MainActor
    @Test("Effective PK interval prefers custom, then ester, then method")
    func intervalResolutionOrder() {
        let mgr = manager(medication: "Testosterone", route: "Injectable",
                          ester: TestosteroneEster.undecanoate.rawValue)

        // The ester beats the method default — this is the case that separates
        // effectivePKIntervalDays (and the due interval that builds on it) from
        // effectiveFrequencyDays, which stays 7 for the cycle display.
        #expect(mgr.effectivePKIntervalDays(ester: TestosteroneEster.undecanoate.rawValue,
                                            route: "Injectable",
                                            medication: "Testosterone") == 70)
        #expect(mgr.effectiveDueIntervalDays == 70,
                "the due interval must follow the ester like the PK interval does")
        #expect(mgr.effectiveFrequencyDays == 7,
                "effectiveFrequencyDays must keep its method-based contract — the dot track and Day X of N display depend on it")

        // An unrecognised ester falls through to the method default.
        #expect(mgr.effectivePKIntervalDays(ester: "Nonsense", route: "Injectable",
                                            medication: "Testosterone") == 7)

        // A user-set frequency wins over everything.
        mgr.customFrequencyDays = 5
        #expect(mgr.effectivePKIntervalDays(ester: TestosteroneEster.undecanoate.rawValue,
                                            route: "Injectable",
                                            medication: "Testosterone") == 5)
    }
}

// MARK: - The aliasing regression

@Suite("Chart window — oral curve is not aliased")
struct OralChartAliasingTests {

    /// The defect this change exists to fix.
    ///
    /// The old non-injectable path took `estimatedLevels`' default `stepDays = 1.0`,
    /// which is exactly the oral dosing interval — so every sample landed at the same
    /// phase of the cycle and the drawn curve was a flat line, against a modeled swing
    /// of roughly 2.4× (oral E2) and 18× (oral T) over that same range.
    ///
    /// Sampling the *same* window both ways is what isolates the aliasing: the dose
    /// history, the engine and the range are identical, so any difference in the drawn
    /// swing is the step alone.
    @MainActor
    @Test("A daily oral regimen is flat at a 1-day step and not at the rule's step",
          arguments: [("Estrogen", MedicationEster.oral.rawValue, 2.0),
                      ("Testosterone", TestosteroneEster.oral.rawValue, 200.0)])
    func oralCurveIsNotFlat(medication: String, ester: String, dose: Double) {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = medication
        mgr.selectedAdministrationMethod = "Oral"
        mgr.customFrequencyDays = nil
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        // Ten days of on-schedule daily doses: comfortably at steady state, so the curve
        // under test is shaped by real accumulation alone. (This once noted that a
        // multi-dose history kept the forward projection out of the window; it never
        // actually did, and that projection has since been removed outright — see
        // `ForwardProjectionTests`.)
        let now = Date()
        let doses = (1...10).reversed().map { day in
            DoseRecord(doseDate: now.addingTimeInterval(-Double(day) * 86400.0 + 3600.0),
                       medicationType: medication, ester: ester,
                       administrationMethod: "Oral", doseAmount: dose, doseStatus: .taken)
        }
        mgr.doseHistory = doses
        mgr.lastDoseDate = doses.last?.doseDate

        let window = mgr.chartWindow(now: now)

        let aliased = mgr.estimatedLevels(from: window.start, to: window.end,
                                          stepDays: 1.0, applyCalibration: false)
        let resolved = mgr.estimatedLevels(from: window.start, to: window.end,
                                           stepDays: window.stepDays, applyCalibration: false)

        func swing(_ points: [MedicationManager.EstimatedPoint]) -> Double {
            let values = points.map(\.value)
            guard let lo = values.min(), let hi = values.max(), lo > 0 else { return 1.0 }
            return hi / lo
        }

        #expect(resolved.count > aliased.count,
                "the rule's step should sample far more finely than one point per day")
        #expect(swing(resolved) > 1.5,
                "\(medication) oral should show a real peak/trough swing, got \(swing(resolved))× across \(resolved.count) points")
        #expect(swing(resolved) > swing(aliased),
                "the finer step must reveal movement the 1-day step hid: resolved \(swing(resolved))× vs aliased \(swing(aliased))×")
    }

    /// `refreshState()` is what the chart actually renders, so assert the property on
    /// `recentLevels` itself rather than only on a hand-built call.
    @MainActor
    @Test("refreshState produces a non-flat oral curve")
    func refreshStateOralCurveIsNotFlat() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Oral"
        mgr.customFrequencyDays = nil
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        let doses = (1...10).reversed().map { day in
            DoseRecord(doseDate: now.addingTimeInterval(-Double(day) * 86400.0 + 3600.0),
                       medicationType: "Estrogen", ester: MedicationEster.oral.rawValue,
                       administrationMethod: "Oral", doseAmount: 2.0, doseStatus: .taken)
        }
        mgr.doseHistory = doses
        mgr.lastDoseDate = doses.last?.doseDate
        mgr.refreshState()

        let values = mgr.recentLevels.map(\.value)
        guard let lo = values.min(), let hi = values.max(), lo > 0 else {
            Issue.record("refreshState() produced no chart points")
            return
        }
        #expect(values.count > 20, "oral chart should have a usable point count, got \(values.count)")
        #expect(hi / lo > 1.5,
                "the rendered oral curve should not be flat, got \(hi / lo)× across \(values.count) points")
    }
}

// MARK: - Forward region

@Suite("Chart window — the forward region never invents a dose")
struct ForwardProjectionTests {

    /// The chart window puts 2W/3 of its width *after* `now`, and `estimatedLevels`
    /// used to fill that region with synthetic doses at
    /// `latestReal + k · effectivePKIntervalDays`. The curve therefore rose to meet the
    /// next-dose marker as though that injection had already been given — drawn with the
    /// same stroke and fill as recorded history, so the chart showed levels climbing on
    /// the strength of a dose the user had not taken and might yet skip.
    ///
    /// Asserted as *monotonicity past the due date* rather than a level, so no threshold
    /// has to be guessed: once the last logged dose has finished releasing, nothing in
    /// the model can justify a rise.
    ///
    /// This deliberately is not "the forward region never rises at all". A dose that
    /// *was* logged keeps rising toward its own t_max, and transdermal releases as 24
    /// hourly micro-doses — cream legitimately climbs through the first stretch of the
    /// forward region off a real dose. The line being drawn is untaken doses, not
    /// future time.
    ///
    /// `lastDoseDaysAgo` is chosen per ester so the next scheduled dose lands strictly
    /// inside the forward region and not on either edge of it, and so the last real dose
    /// has finished absorbing (or releasing) by the time it falls due.
    @MainActor
    @Test("The forward region never rises once the next dose comes due",
          arguments: [("Estrogen", MedicationEster.oral.rawValue, "Oral", 2.0, 1, 0.6),
                      ("Estrogen", MedicationEster.valerate.rawValue, "Injectable", 4.0, 7, 5.5),
                      ("Estrogen", MedicationEster.transdermal.rawValue, "Cream", 3.0, 1, 0.6)])
    func forwardRegionIsNotAWashout(medication: String, ester: String,
                                    route: String, dose: Double, intervalDays: Int,
                                    lastDoseDaysAgo: Double) {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = medication
        mgr.selectedAdministrationMethod = route
        mgr.customFrequencyDays = nil
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        // Six on-schedule doses, the most recent `lastDoseDaysAgo` back, so the next one
        // is due partway into the window's forward region.
        let now = Date()
        let doses = (0..<6).reversed().map { k in
            let daysAgo = lastDoseDaysAgo + Double(k * intervalDays)
            return DoseRecord(doseDate: now.addingTimeInterval(-daysAgo * 86400.0),
                              medicationType: medication, ester: ester,
                              administrationMethod: route, doseAmount: dose, doseStatus: .taken)
        }
        mgr.doseHistory = doses
        mgr.lastDoseDate = doses.last?.doseDate

        let window = mgr.chartWindow(now: now)
        let points = mgr.estimatedLevels(from: window.start, to: window.end,
                                         stepDays: window.stepDays, applyCalibration: false)
        // The instant the next dose falls due — the start of the stretch that used to be
        // fabricated. No logged dose covers any of it.
        let nextDue = now.addingTimeInterval((Double(intervalDays) - lastDoseDaysAgo) * 86400.0)
        let afterDue = points.filter { $0.date >= nextDue }.map(\.value)

        #expect(afterDue.count > 2,
                "\(ester) needs points past the next scheduled dose to test, got \(afterDue.count)")

        // 1.001 absorbs float noise; anything above it is an untaken dose being modelled.
        let rises = zip(afterDue, afterDue.dropFirst()).contains { $1 > $0 * 1.001 }
        #expect(!rises,
                "\(ester) rises after the next dose comes due (\(afterDue.first ?? 0) → \(afterDue.max() ?? 0)) — an untaken dose is being modelled")
    }

    /// The forward region is shaped by the MOST RECENT dose, not the oldest. Both
    /// histories share an ancient dose that has fully washed out, so any difference in
    /// the forward peak comes from which real dose is driving the curve.
    ///
    /// This outlived the synthetic projection it was originally written against: with
    /// the forward fill gone the newest dose still governs the forward region — now
    /// because it is the only one still contributing, rather than because it was the
    /// one the projection copied.
    @MainActor
    @Test("The forward region follows the most recent dose, not the first")
    func projectionFollowsTheLatestDose() {
        func forwardPeak(oldAmount: Double, recentAmount: Double) -> Double {
            let mgr = TestDefaults.manager()
            mgr.selectedMedication = "Estrogen"
            mgr.selectedAdministrationMethod = "Oral"
            mgr.customFrequencyDays = nil
            mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
            mgr.bloodTestHistory = []

            let now = Date()
            func makeDose(_ daysAgo: Double, _ amount: Double) -> DoseRecord {
                DoseRecord(doseDate: now.addingTimeInterval(-daysAgo * 86400.0),
                           medicationType: "Estrogen", ester: MedicationEster.oral.rawValue,
                           administrationMethod: "Oral", doseAmount: amount, doseStatus: .taken)
            }
            mgr.doseHistory = [makeDose(30, oldAmount), makeDose(1, recentAmount)]
            mgr.lastDoseDate = mgr.doseHistory.last?.doseDate

            let window = mgr.chartWindow(now: now)
            let points = mgr.estimatedLevels(from: window.start, to: window.end,
                                             stepDays: window.stepDays, applyCalibration: false)
            return points.filter { $0.date > now }.map(\.value).max() ?? 0
        }

        let steppedUp = forwardPeak(oldAmount: 1.0, recentAmount: 6.0)
        let steppedDown = forwardPeak(oldAmount: 6.0, recentAmount: 1.0)

        #expect(steppedUp > steppedDown,
                "projecting from the latest dose should put the 6 mg regimen above the 1 mg one, got \(steppedUp) vs \(steppedDown)")
    }

    /// A history of nothing but skipped doses must not produce a rising curve out of
    /// thin air: `activeTakenDoses` filters every one of them out, so there are no dose
    /// events at all and the forward region has nothing to climb from.
    @MainActor
    @Test("Skipped-only history projects nothing")
    func skippedOnlyHistoryProjectsNothing() {
        let mgr = TestDefaults.manager()
        mgr.selectedMedication = "Estrogen"
        mgr.selectedAdministrationMethod = "Injectable"
        mgr.customFrequencyDays = nil
        mgr.hrtStartDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        mgr.bloodTestHistory = []

        let now = Date()
        mgr.doseHistory = (1...3).reversed().map { n in
            DoseRecord(doseDate: now.addingTimeInterval(-Double(n * 7) * 86400.0),
                       medicationType: "Estrogen", ester: MedicationEster.valerate.rawValue,
                       administrationMethod: "Injectable", doseAmount: 4.0, doseStatus: .skipped)
        }
        mgr.lastDoseDate = mgr.doseHistory.last?.doseDate

        let window = mgr.chartWindow(now: now)
        let points = mgr.estimatedLevels(from: window.start, to: window.end,
                                         stepDays: window.stepDays, applyCalibration: false)
        let forward = points.filter { $0.date > now }.map(\.value)
        let rises = zip(forward, forward.dropFirst()).contains { $0 < $1 * 0.999 }

        #expect(!rises, "no dose was ever taken, so nothing should be projected forward")
    }
}
