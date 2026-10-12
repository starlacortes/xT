//
//  DoseDayStateTests.swift
//  xTTests
//
//  H-D1 — the dose day-state classifier that also fixes the "Today a day early" bug.
//  Covers the four cases across EV, TU and daily routes, the grace boundary, a
//  log-early advance, and a DST transition.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Dose day state (H-D1)")
struct DoseDayStateTests {

    private func d(_ year: Int, _ month: Int, _ day: Int,
                   _ hour: Int = 9, _ minute: Int = 0,
                   calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    @Test("Unconfigured manager is unscheduled")
    func unconfigured() {
        let m = TestDefaults.manager()
        #expect(m.doseDayState() == .unscheduled)
    }

    @Test("Configured with no next-dose date is unscheduled")
    func configuredNoNext() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        m.updateDoseDates(last: nil, next: nil)
        #expect(m.doseDayState() == .unscheduled)
    }

    @Test("Next dose beyond today is upcoming")
    func upcoming() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let next = d(2026, 1, 10)
        m.updateDoseDates(last: d(2026, 1, 3), next: next)
        #expect(m.doseDayState(now: d(2026, 1, 8, 12)) == .upcoming(next))
    }

    @Test("Next dose later today, not yet passed, is dueToday")
    func dueToday() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let next = d(2026, 1, 8, 18)
        m.updateDoseDates(last: d(2026, 1, 1), next: next)
        #expect(m.doseDayState(now: d(2026, 1, 8, 9)) == .dueToday(next))
    }

    @Test("A due date days in the past is overdue")
    func overduePast() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let next = d(2026, 1, 1)
        m.updateDoseDates(last: d(2025, 12, 25), next: next)
        #expect(m.doseDayState(now: d(2026, 1, 5)) == .overdue(next))
    }

    @Test("Overdue fires at the due instant, grace window notwithstanding")
    func graceBoundary() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        m.missedDoseGracePeriodHours = 48   // a long grace must not delay overdue
        let next = d(2026, 1, 8, 9)
        m.updateDoseDates(last: d(2026, 1, 1, 9), next: next)

        #expect(m.doseDayState(now: next.addingTimeInterval(-60)) == .dueToday(next))
        #expect(m.doseDayState(now: next) == .overdue(next))
        #expect(m.doseDayState(now: next.addingTimeInterval(60)) == .overdue(next))
    }

    @Test("EV weekly: day 6 upcoming, day 7 due")
    func evWeekly() throws {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let dose = d(2026, 1, 1, 9)
        m.addDose(date: dose, type: "Estrogen", ester: MedicationEster.valerate.rawValue,
                  method: MedicationManager.AdministrationMethod.injectable.rawValue, doseAmount: 2.0)

        let next = try #require(m.nextDoseDate)
        #expect(next == Calendar.current.date(byAdding: .day, value: 7, to: dose))
        #expect(m.doseDayState(now: d(2026, 1, 7, 9)) == .upcoming(next))   // day 6
        #expect(m.doseDayState(now: d(2026, 1, 8, 8)) == .dueToday(next))   // day 7, before dose time
    }

    @Test("TU 10-week: still upcoming a week in")
    func tuLongInterval() throws {
        let m = TestDefaults.manager()
        m.updateSelection(type: .testosterone, method: .injectable)
        let dose = d(2026, 1, 1, 9)
        m.addDose(date: dose, type: "Testosterone", ester: TestosteroneEster.undecanoate.rawValue,
                  method: MedicationManager.AdministrationMethod.injectable.rawValue, doseAmount: 40.0)

        let next = try #require(m.nextDoseDate)
        #expect(next == Calendar.current.date(byAdding: .day, value: 70, to: dose))
        #expect(m.doseDayState(now: d(2026, 1, 8, 9)) == .upcoming(next))
    }

    @Test("Oral daily before and after logging")
    func oralDaily() throws {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .oral)
        let first = d(2026, 1, 1, 9)
        m.addDose(date: first, type: "Estrogen", ester: MedicationEster.oral.rawValue,
                  method: MedicationManager.AdministrationMethod.oral.rawValue, doseAmount: 2.0)

        let next = try #require(m.nextDoseDate)
        #expect(next == Calendar.current.date(byAdding: .day, value: 1, to: first))
        #expect(m.doseDayState(now: d(2026, 1, 2, 8)) == .dueToday(next))

        // Logging the next day's dose advances the schedule — no special case.
        let second = d(2026, 1, 2, 9)
        m.addDose(date: second, type: "Estrogen", ester: MedicationEster.oral.rawValue,
                  method: MedicationManager.AdministrationMethod.oral.rawValue, doseAmount: 2.0)
        let next2 = try #require(m.nextDoseDate)
        #expect(next2 == Calendar.current.date(byAdding: .day, value: 1, to: second))
    }

    @Test("A dose logged early advances the schedule, becoming upcoming")
    func loggedEarly() throws {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        m.addDose(date: d(2026, 1, 1, 9), type: "Estrogen", ester: MedicationEster.valerate.rawValue,
                  method: MedicationManager.AdministrationMethod.injectable.rawValue, doseAmount: 2.0)
        // Log the next injection two days early.
        let early = d(2026, 1, 6, 9)
        m.addDose(date: early, type: "Estrogen", ester: MedicationEster.valerate.rawValue,
                  method: MedicationManager.AdministrationMethod.injectable.rawValue, doseAmount: 2.0)

        let next = try #require(m.nextDoseDate)
        #expect(next == Calendar.current.date(byAdding: .day, value: 7, to: early))
        #expect(m.doseDayState(now: d(2026, 1, 6, 12)) == .upcoming(next))
    }

    @Test("A DST transition does not misclassify the next dose")
    func dstTransition() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!   // spring-forward 2026-03-08

        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        let next = d(2026, 3, 9, 9, 0, calendar: cal)
        m.updateDoseDates(last: d(2026, 3, 2, 9, 0, calendar: cal), next: next)

        #expect(m.doseDayState(now: d(2026, 3, 8, 12, 0, calendar: cal), calendar: cal) == .upcoming(next))
        #expect(m.doseDayState(now: d(2026, 3, 9, 8, 0, calendar: cal), calendar: cal) == .dueToday(next))
    }
}
