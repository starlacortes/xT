//
//  LabPointsTests.swift
//  xTTests
//
//  H-D5 — the measured lab points the curve plots, scoped to the selected hormone and
//  a time window, oldest first.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Lab points (H-D5)")
struct LabPointsTests {

    private func lab(_ hormone: String, draw: Date, measured: Double) -> BloodTestRecord {
        BloodTestRecord(drawDate: draw, measuredLevel: measured, hormoneType: hormone)
    }

    @Test("Only the selected hormone's labs inside the window, oldest first, as measured")
    func filtersAndSorts() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"

        let now = Date()
        func day(_ ago: Int) -> Date { Calendar.current.date(byAdding: .day, value: -ago, to: now)! }

        m.bloodTestHistory = [
            lab("Estrogen", draw: day(2), measured: 250),      // in window
            lab("Estrogen", draw: day(10), measured: 180),     // in window, older
            lab("Estrogen", draw: day(400), measured: 120),    // out of window
            lab("Testosterone", draw: day(1), measured: 500),  // wrong hormone
        ]

        let window = day(30)...now
        let points = m.labPoints(in: window)

        #expect(points.count == 2)
        #expect(points.map(\.measured) == [180, 250])   // oldest first
        #expect(points.first?.date == day(10))
    }

    @Test("Empty when no labs fall in the window")
    func emptyOutsideWindow() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        let now = Date()
        m.bloodTestHistory = [lab("Estrogen", draw: Date(timeIntervalSinceNow: -400 * 86_400), measured: 100)]
        let window = Calendar.current.date(byAdding: .day, value: -30, to: now)!...now
        #expect(m.labPoints(in: window).isEmpty)
    }
}
