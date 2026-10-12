//
//  JournalManagerTests.swift
//  xTTests
//
//  J2 / J3 / J10 — the Journal projections the rebuilt UI reads: the top-slot card/ghost
//  rule, the week strip's entry- and dose-day sets, and symptom name matching across the
//  per-launch UUID churn.
//
//  These exercise the pure logic over the managers' in-memory arrays, the way the rest of
//  the suite does — the app under test already holds the one CloudKit-backed `ModelContainer`
//  the process allows, so tests never stand up a second one.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Journal projections (J2, J3, J10)")
struct JournalManagerTests {

    private func entry(_ text: String, daysAgo: Int = 0, mood: Mood = .neutral,
                       symptoms: [Symptom] = []) -> JournalEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return JournalEntry(date: date, mood: mood, text: text, symptoms: symptoms)
    }

    private func takenDose(daysAgo: Int, status: DoseStatus = .taken) -> DoseRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DoseRecord(doseDate: date, medicationType: "Estrogen",
                          ester: "Valerate (EV)", administrationMethod: "Injectable",
                          doseAmount: 4, doseStatus: status)
    }

    // MARK: - Symptom name matching (survives per-launch UUID churn, J10)

    @Test("Symptom matches by name, case-insensitively")
    func symptomNameMatch() {
        #expect(Symptom.matching(name: "Energy Boost")?.name == "energy boost")
        #expect(Symptom.matching(name: "FATIGUE")?.name == "fatigue")
        #expect(Symptom.matching(name: "not a symptom") == nil)
    }

    // MARK: - Top slot (J3)

    @Test("Empty journal shows the ghost slot")
    func topSlotEmpty() {
        let jm = JournalManager()
        jm.entries = []
        #expect(jm.topSlot == .ghost)
    }

    @Test("A today entry makes the top slot a card")
    func topSlotCardToday() {
        let jm = JournalManager()
        let today = entry("today", daysAgo: 0)
        jm.entries = [today]
        #expect(jm.topSlot == .card(today))
    }

    @Test("When the newest entry is not from today, the slot is the ghost")
    func topSlotGhostWhenStale() {
        let jm = JournalManager()
        jm.entries = [entry("yesterday", daysAgo: 1)]
        #expect(jm.topSlot == .ghost)
    }

    // MARK: - Entry days (J2)

    @Test("entryDays reports the calendar days with entries in range")
    func entryDaysInRange() {
        let jm = JournalManager()
        jm.entries = [entry("a", daysAgo: 0), entry("b", daysAgo: 2), entry("c", daysAgo: 2)]
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date())!
        let days = jm.entryDays(in: DateInterval(start: start, end: Date().addingTimeInterval(60)))
        #expect(days.count == 2)  // two distinct days, though day -2 has two entries
        #expect(days.contains(cal.startOfDay(for: Date())))
    }

    @Test("entryDays excludes entries outside the interval")
    func entryDaysOutsideRange() {
        let jm = JournalManager()
        jm.entries = [entry("recent", daysAgo: 1), entry("old", daysAgo: 30)]
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date())!
        let days = jm.entryDays(in: DateInterval(start: start, end: Date().addingTimeInterval(60)))
        #expect(days.count == 1)
    }

    // MARK: - Dose days + same-day lookup (J2, J6)

    @Test("doseDays counts taken doses only, excluding skipped")
    func doseDaysTakenOnly() {
        let m = TestDefaults.manager()
        m.doseHistory = [takenDose(daysAgo: 0), takenDose(daysAgo: 2, status: .skipped)]
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date())!
        let days = m.doseDays(in: DateInterval(start: start, end: Date().addingTimeInterval(60)))
        #expect(days.count == 1)
        #expect(days.contains(cal.startOfDay(for: Date())))
    }

    @Test("dose(onSameDayAs:) returns a taken dose on that day, else nil")
    func doseOnSameDay() {
        let m = TestDefaults.manager()
        let today = Date()
        m.doseHistory = [takenDose(daysAgo: 0)]
        #expect(m.dose(onSameDayAs: today) != nil)

        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        #expect(m.dose(onSameDayAs: threeDaysAgo) == nil)
    }
}
