//
//  BloodTestCalibrationTests.swift
//  xTTests
//
//  Calibration engine regression tests for the blood test calibration fixes:
//  α idempotency (no circularity), α order-independence, hormone-filtered
//  calibrationFactor, draw-date-anchored predictedLevel, and unconfigured-hormone
//  nil handling.
//

import Testing
import Foundation
@testable import xT

// MARK: - Calibration Engine Regression

@Suite("Blood Test Calibration Engine")
struct BloodTestCalibrationTests {

    /// Builds a manager configured for injectable estrogen with one dose,
    /// matching the established idiom in PharmacokineticTests.
    @MainActor
    private func makeEstrogenManager() -> MedicationManager {
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
        return mgr
    }

    @MainActor
    @Test("α is idempotent under recompute — no circularity")
    func alphaIdempotentUnderRecompute() {
        let mgr = makeEstrogenManager()
        let now = Date()
        let bloodRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(3 * 86400),
            measuredLevel: 300,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        mgr.bloodTestHistory = [bloodRecord]

        mgr.computeCalibrationFactor(for: bloodRecord)
        let first = bloodRecord.calibrationFactor
        #expect(first != nil, "First computation should produce a calibration factor")

        // Recompute. The old implementation fed the just-computed α back into the
        // prediction (`estimatedLevels` defaults `applyCalibration` to true), so the
        // second pass predicted against an already-scaled curve and returned a
        // different α. The fix samples uncalibrated, so α must be unchanged.
        mgr.computeCalibrationFactor(for: bloodRecord)
        let second = bloodRecord.calibrationFactor

        #expect(second != nil, "Recomputation should still produce a calibration factor")
        if let first, let second {
            #expect(abs(first - second) < 0.0001,
                    "α changed on recompute: \(first) → \(second) — circularity defect")
        }
    }

    @MainActor
    @Test("α is order-independent across bloodTestHistory")
    func alphaOrderIndependent() {
        let mgr = makeEstrogenManager()
        let now = Date()

        let older = BloodTestRecord(
            drawDate: now.addingTimeInterval(2 * 86400),
            measuredLevel: 250,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 48
        )
        let newer = BloodTestRecord(
            drawDate: now.addingTimeInterval(5 * 86400),
            measuredLevel: 350,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 120
        )

        // Compute in one order.
        mgr.bloodTestHistory = [older, newer]
        mgr.computeCalibrationFactor(for: older)
        mgr.computeCalibrationFactor(for: newer)
        let olderAlpha = older.calibrationFactor
        let newerAlpha = newer.calibrationFactor

        // Recompute in the reverse order.
        mgr.bloodTestHistory = [newer, older]
        mgr.computeCalibrationFactor(for: older)
        mgr.computeCalibrationFactor(for: newer)

        #expect(older.calibrationFactor != nil && newer.calibrationFactor != nil)
        if let olderAlpha, let newerAlpha {
            #expect(abs((older.calibrationFactor ?? 0) - olderAlpha) < 0.0001,
                    "older record's α changed when history order changed")
            #expect(abs((newer.calibrationFactor ?? 0) - newerAlpha) < 0.0001,
                    "newer record's α changed when history order changed")
        }
    }

    @MainActor
    @Test("calibrationFactor respects the selected hormone")
    func calibrationFactorRespectsSelectedHormone() {
        let mgr = makeEstrogenManager()
        let now = Date()

        // A newer Testosterone record with a large α. The old implementation
        // scanned every calibrated record regardless of hormone type, so this
        // would win the "latest" race and rescale the estrogen curve.
        let testosteroneRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(5 * 86400),
            measuredLevel: 800,
            hormoneType: "Testosterone",
            hoursSinceLastDose: 120
        )
        testosteroneRecord.calibrationFactor = 2.0

        let estrogenRecord = BloodTestRecord(
            drawDate: now.addingTimeInterval(3 * 86400),
            measuredLevel: 300,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        estrogenRecord.calibrationFactor = 1.5

        mgr.bloodTestHistory = [testosteroneRecord, estrogenRecord]
        mgr.selectedMedication = "Estrogen"

        #expect(mgr.calibrationFactor == 1.5,
                "Estrogen calibration should ignore the newer Testosterone record")
    }

    @MainActor
    @Test("predictedLevel is anchored at the draw date, not 30 minutes before")
    func predictedLevelAnchoredAtDrawDate() {
        let mgr = makeEstrogenManager()
        let now = Date()
        let drawDate = now.addingTimeInterval(3 * 86400)

        // The new sampling primitive evaluates the model exactly at the draw date.
        let predicted = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen")
        #expect(predicted != nil, "predictedLevel should return a value for a configured hormone")

        // The old implementation sampled a ±30-minute window at stepDays 1 (86400s),
        // which jumped past `end` and produced a single point at drawDate − 1800s.
        let oldWindowPoints = mgr.estimatedLevels(
            from: drawDate.addingTimeInterval(-1800),
            to: drawDate.addingTimeInterval(1800),
            stepDays: 1,
            applyCalibration: false
        )
        let oldPredicted = oldWindowPoints.last?.value

        if let predicted, let oldPredicted {
            // At 3 days post-dose the EV curve is past its ~2.1-day peak and decaying,
            // so the value 30 minutes earlier is measurably different. The fix must
            // anchor at the draw instant rather than half an hour before it.
            #expect(abs(predicted - oldPredicted) > 0.01,
                    "predictedLevel should differ from the old ±30min window sample")
        }
    }

    @MainActor
    @Test("predictedLevel returns nil for an unconfigured hormone")
    func predictedLevelNilForUnconfiguredHormone() {
        let mgr = makeEstrogenManager()
        let now = Date()

        #expect(mgr.predictedLevel(at: now, hormoneType: "Testosterone") == nil,
                "predictedLevel must return nil when the requested hormone is not selected")
    }

    @MainActor
    @Test("labsSeriesPoints filters, sorts, and maps blood test history")
    func labsSeriesPointsMapping() {
        let mgr = makeEstrogenManager()
        let now = Date()

        let older = BloodTestRecord(
            drawDate: now.addingTimeInterval(2 * 86400),
            measuredLevel: 250,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 48
        )
        let newer = BloodTestRecord(
            drawDate: now.addingTimeInterval(5 * 86400),
            measuredLevel: 350,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 120
        )
        let testosterone = BloodTestRecord(
            drawDate: now.addingTimeInterval(4 * 86400),
            measuredLevel: 600,
            hormoneType: "Testosterone",
            hoursSinceLastDose: 96
        )
        mgr.bloodTestHistory = [newer, testosterone, older]
        mgr.computeCalibrationFactor(for: older)
        mgr.computeCalibrationFactor(for: newer)

        let points = mgr.labsSeriesPoints(for: "Estrogen")

        #expect(points.count == 2, "Only Estrogen records should be mapped")
        #expect(points.first?.drawDate == older.drawDate,
                "Points should be sorted ascending by draw date")
        #expect(points.last?.drawDate == newer.drawDate,
                "Points should be sorted ascending by draw date")
        #expect(points.first?.measured == 250)
        #expect(points.last?.measured == 350)
        #expect(points.allSatisfy { $0.predicted != nil },
                "Predicted values should be present for a configured hormone")
        #expect(points.allSatisfy { $0.isCalibrated },
                "Computed records should be marked calibrated")
    }

    @MainActor
    @Test("α round-trips: re-predicting at the draw returns the measured level")
    func alphaRoundTrip() {
        let mgr = makeEstrogenManager()
        let now = Date()
        let drawDate = now.addingTimeInterval(3 * 86400)

        guard let raw = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen") else {
            Issue.record("predictedLevel returned nil for a configured hormone")
            return
        }
        let base = mgr.dynamicBaseline(for: .estrogen)
        let exogenous = raw - base
        #expect(exogenous > 0.01, "EV 2 mg should have a real drug contribution at day 3")

        // Force α to exactly 0.5 (inside the clamp), so the round-trip is exact
        // arithmetic rather than a clamp boundary.
        let measured = base + 0.5 * exogenous
        let record = BloodTestRecord(
            drawDate: drawDate,
            measuredLevel: measured,
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        // `predictedLevel(applyCalibration: true)` reads α through the manager's
        // `calibrationFactor`, which scans `bloodTestHistory` — so the record must be
        // registered there for the round-trip re-prediction to see the new α.
        mgr.bloodTestHistory = [record]
        mgr.computeCalibrationFactor(for: record)

        #expect(record.calibrationFactor != nil, "Draw above baseline should calibrate")
        if let alpha = record.calibrationFactor {
            #expect(abs(alpha - 0.5) < 0.0001, "α should be 0.5, got \(alpha)")
        }

        guard let calibrated = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen",
                                                  applyCalibration: true) else {
            Issue.record("calibrated predictedLevel returned nil")
            return
        }
        #expect(abs(calibrated - measured) < 0.01,
                "round-trip should reproduce the measurement: predicted \(calibrated) vs measured \(measured)")
    }

    @MainActor
    @Test("clamped α is bounded by the clamp, not by the measurement")
    func clampedAlphaDoesNotRoundTrip() {
        let mgr = makeEstrogenManager()
        let now = Date()
        let drawDate = now.addingTimeInterval(3 * 86400)

        guard let raw = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen") else {
            Issue.record("predictedLevel returned nil for a configured hormone")
            return
        }
        let base = mgr.dynamicBaseline(for: .estrogen)
        let exogenous = raw - base
        #expect(exogenous > 0.01, "EV 2 mg should have a real drug contribution at day 3")

        // Floor clamp: raw α = 0.05 (< 0.2) → stored 0.2. The calibrated curve then
        // over-predicts the measurement — round-trip is intentionally NOT exact when
        // the raw α would have been outside the clamp.
        let lowMeasured = base + 0.05 * exogenous
        let lowRecord = BloodTestRecord(drawDate: drawDate, measuredLevel: lowMeasured,
                                        hormoneType: "Estrogen", hoursSinceLastDose: 72)
        mgr.bloodTestHistory = [lowRecord]
        mgr.computeCalibrationFactor(for: lowRecord)
        #expect(lowRecord.calibrationFactor != nil, "above-floor draw should calibrate")
        if let alpha = lowRecord.calibrationFactor {
            #expect(abs(alpha - 0.2) < 0.0001, "raw α 0.05 should clamp to 0.2, got \(alpha)")
        }
        if let calibrated = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen",
                                               applyCalibration: true) {
            #expect(calibrated > lowMeasured,
                    "floor-clamped α should over-predict: \(calibrated) vs measured \(lowMeasured)")
        }

        // Ceiling clamp: raw α = 100 (> 5.0) → stored 5.0. The calibrated curve then
        // under-predicts the measurement.
        let highMeasured = base + 100.0 * exogenous
        let highRecord = BloodTestRecord(drawDate: drawDate, measuredLevel: highMeasured,
                                         hormoneType: "Estrogen", hoursSinceLastDose: 72)
        mgr.bloodTestHistory = [highRecord]
        mgr.computeCalibrationFactor(for: highRecord)
        #expect(highRecord.calibrationFactor != nil, "high draw should calibrate")
        if let alpha = highRecord.calibrationFactor {
            #expect(abs(alpha - 5.0) < 0.0001, "raw α 100 should clamp to 5.0, got \(alpha)")
        }
        if let calibrated = mgr.predictedLevel(at: drawDate, hormoneType: "Estrogen",
                                               applyCalibration: true) {
            #expect(calibrated < highMeasured,
                    "ceiling-clamped α should under-predict: \(calibrated) vs measured \(highMeasured)")
        }
    }

    @MainActor
    @Test("a draw at or below the endogenous floor declines to calibrate")
    func drawBelowFloorDeclinesToCalibrate() {
        let mgr = makeEstrogenManager()
        let now = Date()
        let drawDate = now.addingTimeInterval(3 * 86400)

        let base = mgr.dynamicBaseline(for: .estrogen)  // suppressed → 5 pg/mL
        let record = BloodTestRecord(
            drawDate: drawDate,
            measuredLevel: base - 1.0,   // below the endogenous floor
            hormoneType: "Estrogen",
            hoursSinceLastDose: 72
        )
        mgr.computeCalibrationFactor(for: record)
        #expect(record.calibrationFactor == nil,
                "a measured level at/below baseline must not fabricate a calibration factor")
    }
}

// MARK: - Calibration Alpha (pure derivation)

@Suite("Calibration Alpha — exogenous-only derivation")
struct CalibrationAlphaTests {

    @Test("known-value algebra: α = (measured − base) / exogenous")
    func knownValue() {
        // base = 100, exogenous = 400, measured = 300 → α = (300 − 100) / 400 = 0.5
        let alpha = MedicationManager.calibrationAlpha(measured: 300, base: 100, exogenous: 400)
        #expect(alpha != nil, "positive drug signal should yield an α")
        if let alpha {
            #expect(abs(alpha - 0.5) < 0.0001, "α should be 0.5, got \(alpha)")
            let reconstructed = 100.0 + 400.0 * alpha
            #expect(abs(reconstructed - 300.0) < 0.0001,
                    "base + exogenous·α should reconstruct the measurement")
        }
    }

    @Test("measured at or below base yields nil, not a fabricated 0.2")
    func belowFloorYieldsNil() {
        #expect(MedicationManager.calibrationAlpha(measured: 100, base: 100, exogenous: 400) == nil,
                "measured == base must not calibrate")
        #expect(MedicationManager.calibrationAlpha(measured: 99, base: 100, exogenous: 400) == nil,
                "measured < base must not calibrate")
    }

    @Test("negligible exogenous yields nil")
    func negligibleExogenousYieldsNil() {
        #expect(MedicationManager.calibrationAlpha(measured: 300, base: 100, exogenous: 0.001) == nil,
                "no meaningful drug signal to divide by")
    }

    @Test("result is clamped to [0.2, 5.0]")
    func clamping() {
        #expect(abs((MedicationManager.calibrationAlpha(measured: 100.001, base: 100, exogenous: 400) ?? 0) - 0.2) < 0.0001,
                "just-above-floor draw clamps to 0.2")
        #expect(abs((MedicationManager.calibrationAlpha(measured: 100_000, base: 100, exogenous: 400) ?? 0) - 5.0) < 0.0001,
                "very-high draw clamps to 5.0")
    }
}