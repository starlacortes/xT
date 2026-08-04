//
//  LabsChartSeriesTests.swift
//  xTTests
//
//  Pure-math tests for LabsChartSeries.range, plus a regression test for the
//  composer's edit-as-delete-and-re-add strategy (see BloodTestComposerView.save()).
//

import Testing
import Foundation
@testable import xT

// MARK: - LabsChartSeries.range

@Suite("LabsChartSeries range math")
struct LabsChartSeriesRangeTests {

    @Test("range returns (0, minimumSpan) for an empty series")
    func rangeEmptySeries() {
        let bounds = LabsChartSeries.range(for: [])
        #expect(bounds.min == 0)
        #expect(bounds.max == 1.0)
    }

    @Test("range spans at least minimumSpan around a single point")
    func rangeSinglePoint() {
        let point = LabsSeriesPoint(drawDate: Date(), measured: 200, predicted: 210, isCalibrated: true)
        let bounds = LabsChartSeries.range(for: [point], minimumSpan: 5)
        #expect(bounds.max - bounds.min >= 5)
        #expect(bounds.min < 200, "lower bound should pad below the lowest value")
        #expect(bounds.max > 210, "upper bound should pad above the highest value")
    }

    @Test("range pads 10% around the full measured+predicted extent")
    func rangePadsAroundExtent() {
        let now = Date()
        let points = [
            LabsSeriesPoint(drawDate: now, measured: 100, predicted: 90, isCalibrated: true),
            LabsSeriesPoint(drawDate: now.addingTimeInterval(86400), measured: 300, predicted: 320, isCalibrated: true)
        ]
        let bounds = LabsChartSeries.range(for: points)
        // Extent is [90, 320] → span 230 → 10% padding (23) on each side.
        #expect(abs(bounds.min - 67) < 0.01)
        #expect(abs(bounds.max - 343) < 0.01)
    }

    @Test("range ignores nil predicted values rather than treating them as 0")
    func rangeIgnoresNilPredicted() {
        let points = [
            LabsSeriesPoint(drawDate: Date(), measured: 150, predicted: nil, isCalibrated: false)
        ]
        let bounds = LabsChartSeries.range(for: points)
        // A nil predicted must not pull the lower bound toward 0 — only the
        // measured value (150) should anchor the padded single-point band.
        #expect(bounds.min > 100, "a nil predicted value must not be treated as 0")
        #expect(bounds.min < 150)
        #expect(bounds.max > 150)
    }
}

// MARK: - Composer edit round-trip

@Suite("Blood test edit round-trip")
struct BloodTestEditRoundTripTests {

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
    @Test("editing a blood test replaces it in place — same draw date, new values, new identity")
    func editRoundTrip() {
        let mgr = makeEstrogenManager()
        let drawDate = Date().addingTimeInterval(2 * 86400)
        mgr.addBloodTest(drawDate: drawDate, measuredLevel: 220, hormoneType: "Estrogen", notes: "original")

        #expect(mgr.bloodTestHistory.count == 1)
        let original = mgr.bloodTestHistory[0]

        // BloodTestComposerView.save() implements "edit" as remove + re-add, since
        // addBloodTest is what recomputes hoursSinceLastDose and the calibration
        // factor — an in-place mutation would leave both stale.
        mgr.removeBloodTest(withId: original.id)
        #expect(mgr.bloodTestHistory.isEmpty)

        mgr.addBloodTest(drawDate: drawDate, measuredLevel: 260, hormoneType: "Estrogen", notes: "corrected")

        #expect(mgr.bloodTestHistory.count == 1)
        let edited = mgr.bloodTestHistory[0]
        #expect(edited.measuredLevel == 260)
        #expect(edited.notes == "corrected")
        #expect(edited.drawDate == drawDate)
        #expect(edited.id != original.id, "edit creates a new record identity, not an in-place mutation")
    }
}
