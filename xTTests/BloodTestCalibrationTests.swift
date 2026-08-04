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
}