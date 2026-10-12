//
//  CyclePhaseMarkerTests.swift
//  xTTests
//
//  H-D2 — the dose / peak / trough / today markers under the curve. Covers the peak
//  honesty rule (omitted when t_max is uncalibrated), the daily-route empty case, and
//  the "today absorbs a same-day marker" collapse.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Cycle phase markers (H-D2)")
struct CyclePhaseMarkerTests {

    private let injectable = MedicationManager.AdministrationMethod.injectable.rawValue
    private let oral = MedicationManager.AdministrationMethod.oral.rawValue

    private func kinds(_ markers: [MedicationManager.PhaseMarker]) -> Set<MedicationManager.PhaseMarker.Kind> {
        Set(markers.map(\.kind))
    }

    @Test("EV produces dose, peak, trough and today")
    func evAllFour() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let now = Date()
        // Dose 20 days back so peak/trough/dose fall on distinct days from today.
        let dose = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        m.addDose(date: dose, type: "Estrogen", ester: MedicationEster.valerate.rawValue,
                  method: injectable, doseAmount: 2.0)

        let markers = m.cyclePhaseMarkers(now: now)
        #expect(kinds(markers) == [.dose, .peak, .trough, .today])
        // Sorted ascending.
        #expect(markers == markers.sorted { $0.date < $1.date })
    }

    @Test("EC also carries a peak (t_max calibrated)")
    func ecHasPeak() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let now = Date()
        let dose = Calendar.current.date(byAdding: .day, value: -20, to: now)!
        m.addDose(date: dose, type: "Estrogen", ester: MedicationEster.cypionate.rawValue,
                  method: injectable, doseAmount: 2.0)
        #expect(kinds(m.cyclePhaseMarkers(now: now)).contains(.peak))
    }

    @Test("TU markers are weeks apart")
    func tuWeeksApart() throws {
        let m = TestDefaults.manager()
        m.updateSelection(type: .testosterone, method: .injectable)
        let now = Date()
        let dose = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        m.addDose(date: dose, type: "Testosterone", ester: TestosteroneEster.undecanoate.rawValue,
                  method: injectable, doseAmount: 40.0)

        let markers = m.cyclePhaseMarkers(now: now)
        let trough = try #require(markers.first { $0.kind == .trough })
        // Trough is the next dose, ~70 days out — clearly weeks from the dose.
        let daysToTrough = Calendar.current.dateComponents([.day], from: dose, to: trough.date).day ?? 0
        #expect(daysToTrough >= 60)
    }

    @Test("TP omits the peak (t_max not calibrated)")
    func tpNoPeak() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .testosterone, method: .injectable)
        let now = Date()
        let dose = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        m.addDose(date: dose, type: "Testosterone", ester: TestosteroneEster.propionate.rawValue,
                  method: injectable, doseAmount: 40.0)

        let markers = m.cyclePhaseMarkers(now: now)
        #expect(!kinds(markers).contains(.peak))
        #expect(kinds(markers).contains(.trough))
    }

    @Test("Oral (daily) produces no strip")
    func oralEmpty() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .oral)
        m.addDose(date: Date(), type: "Estrogen", ester: MedicationEster.oral.rawValue,
                  method: oral, doseAmount: 2.0)
        #expect(m.cyclePhaseMarkers().isEmpty)
    }

    @Test("A dose today is absorbed into the today marker")
    func doseTodayCollapses() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let now = Date()
        m.addDose(date: now, type: "Estrogen", ester: MedicationEster.valerate.rawValue,
                  method: injectable, doseAmount: 2.0)

        let markers = m.cyclePhaseMarkers(now: now)
        // The dose shares today's calendar day, so it collapses: no standalone dose marker.
        #expect(!kinds(markers).contains(.dose))
        // Exactly one `today`, and nothing else shares today's day.
        let todayCount = markers.filter { $0.kind == .today }.count
        #expect(todayCount == 1)
        let todayStart = Calendar.current.startOfDay(for: now)
        for marker in markers where marker.kind != .today {
            #expect(Calendar.current.startOfDay(for: marker.date) != todayStart)
        }
    }
}
