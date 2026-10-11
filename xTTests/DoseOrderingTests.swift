//
//  DoseOrderingTests.swift
//  xTTests
//
//  Regression tests for the dose-history ordering bug.
//
//  `loadDoseHistory()` sorts `order: .forward`, so `doseHistory` is oldest-first.
//  Several call sites used `first(where:)` on it and therefore resolved "the most
//  recent dose" to the user's *first ever* dose — the ester, amount and vial
//  concentration shown in the UI were whatever they had logged when they started.
//  These tests pin the corrected end of the array.
//

import XCTest
@testable import xT

final class DoseOrderingTests: XCTestCase {

    var manager: MedicationManager!

    @MainActor override func setUp() {
        super.setUp()
        // Own suite per test — nothing this class writes can reach another test,
        // so the manual save/restore of `customFrequencyDays` is no longer needed.
        manager = TestDefaults.manager()
    }

    @MainActor override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    private func makeSite(
        zoneLabel: String,
        routeClass: RouteClass
    ) -> InjectionSite {
        InjectionSite(
            sketchId: "test",
            normalizedX: 0.5,
            normalizedY: 0.5,
            zoneLabel: zoneLabel,
            viewContext: "front",
            bodyRegion: "thigh",
            routeClass: routeClass.rawValue
        )
    }

    /// Builds an ascending (oldest-first) history, matching how `loadDoseHistory` sorts.
    @MainActor private func seedAscendingHistory() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.doseHistory = [
            DoseRecord(
                doseDate: daysAgo(30),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0,
                concentrationMgPerMl: 20.0
            ),
            DoseRecord(
                doseDate: daysAgo(14),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 3.0,
                concentrationMgPerMl: 40.0
            ),
            DoseRecord(
                doseDate: daysAgo(1),
                medicationType: "Estrogen",
                ester: MedicationEster.cypionate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 5.0,
                concentrationMgPerMl: 100.0
            )
        ]
    }

    // MARK: - latestDose

    @MainActor func testLatestDoseReturnsNewestNotOldest() {
        seedAscendingHistory()

        let latest = manager.latestDose()
        XCTAssertEqual(latest?.doseAmount, 5.0,
                       "latestDose must read the newest end of an oldest-first array")
        XCTAssertNotEqual(latest?.doseAmount, 2.0,
                          "regression: latestDose returned the user's first-ever dose")
    }

    @MainActor func testLatestDoseSkipsInactiveRecords() {
        seedAscendingHistory()
        manager.doseHistory.last?.isDeleted = true

        XCTAssertEqual(manager.latestActiveDose()?.doseAmount, 3.0,
                       "an inactive newest dose must fall through to the one before it")
    }

    @MainActor func testLatestDoseIsNilForEmptyHistory() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.doseHistory = []

        XCTAssertNil(manager.latestDose())
        XCTAssertNil(manager.latestActiveDose())
        XCTAssertNil(manager.lastLoggedDose)
    }

    // MARK: - Derived values

    @MainActor func testCurrentEsterFollowsTheNewestDose() {
        seedAscendingHistory()

        XCTAssertEqual(manager.currentEster?.ester, MedicationEster.cypionate.rawValue,
                       "switching ester should be reflected immediately, not on first-dose ester")
        XCTAssertEqual(manager.currentEster?.halfLifeDays,
                       MedicationEster.cypionate.halfLifeDays)
    }

    @MainActor func testLastLoggedDoseIsTheNewestDose() {
        seedAscendingHistory()

        XCTAssertEqual(manager.lastLoggedDose?.doseAmount, 5.0)
    }

    @MainActor func testDefaultConcentrationFollowsTheNewestDose() {
        seedAscendingHistory()

        XCTAssertEqual(manager.defaultConcentrationMgPerMl, 100.0,
                       "the vial strength offered should be the one most recently used")
    }

    @MainActor func testDefaultConcentrationSkipsDosesWithoutOne() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.doseHistory = [
            DoseRecord(
                doseDate: daysAgo(10),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0,
                concentrationMgPerMl: 40.0
            ),
            DoseRecord(
                doseDate: daysAgo(2),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0,
                concentrationMgPerMl: nil
            )
        ]

        XCTAssertEqual(manager.defaultConcentrationMgPerMl, 40.0,
                       "a dose logged without a concentration must not blank the default")
    }

    // MARK: - Sited doses

    @MainActor func testLatestSitedDoseIgnoresDosesWithoutSites() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.doseHistory = [
            DoseRecord(
                doseDate: daysAgo(9),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0,
                injectionSites: [makeSite(zoneLabel: "Left thigh", routeClass: .injection)]
            ),
            DoseRecord(
                doseDate: daysAgo(2),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0
            )
        ]

        XCTAssertEqual(manager.lastInjectionSites?.first?.zoneLabel, "Left thigh",
                       "rotation timing must come from the last dose that recorded a site")
    }

    @MainActor func testLatestSitedDoseScopesByRouteClass() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.doseHistory = [
            DoseRecord(
                doseDate: daysAgo(8),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Injectable",
                doseAmount: 2.0,
                injectionSites: [makeSite(zoneLabel: "Right thigh", routeClass: .injection)]
            ),
            DoseRecord(
                doseDate: daysAgo(1),
                medicationType: "Estrogen",
                ester: MedicationEster.valerate.rawValue,
                administrationMethod: "Cream",
                doseAmount: 2.0,
                injectionSites: [makeSite(zoneLabel: "Inner forearm", routeClass: .topical)]
            )
        ]

        XCTAssertEqual(manager.lastInjectionSites(for: .injection)?.first?.zoneLabel,
                       "Right thigh")
        XCTAssertEqual(manager.lastInjectionSites(for: .topical)?.first?.zoneLabel,
                       "Inner forearm")
        XCTAssertNil(manager.lastInjectionSites(for: .patch))
    }

    // MARK: - Effective frequency

    @MainActor func testEffectiveFrequencyPrefersTheCustomInterval() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = 5

        XCTAssertEqual(manager.effectiveFrequencyDays, 5,
                       "a custom interval must win over the method default")
    }

    @MainActor func testEffectiveFrequencyFallsBackToTheMethodDefault() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = nil

        XCTAssertEqual(manager.effectiveFrequencyDays,
                       MedicationManager.AdministrationMethod.injectable.frequencyDays)
    }

    @MainActor func testEffectiveFrequencyIgnoresANonPositiveCustomInterval() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = 0

        XCTAssertEqual(manager.effectiveFrequencyDays,
                       MedicationManager.AdministrationMethod.injectable.frequencyDays,
                       "zero is not a dosing interval; it must not divide into the schedule")
    }

    @MainActor func testDueIntervalUsesTheEsterWhenNoCustomFrequency() {
        manager.updateSelection(type: .testosterone, method: .injectable)
        manager.customFrequencyDays = nil
        manager.doseHistory = [
            DoseRecord(doseDate: daysAgo(3), medicationType: "Testosterone",
                       ester: TestosteroneEster.undecanoate.rawValue,
                       administrationMethod: "Injectable", doseAmount: 1000.0, doseStatus: .taken)
        ]

        XCTAssertEqual(manager.effectiveDueIntervalDays, 70,
                       "TU is dosed every ~10 weeks; the due interval must follow the ester, not the 7-day method default")
        XCTAssertEqual(manager.effectiveFrequencyDays, 7,
                       "the cycle display stays method-based even though the due date does not")

        let last = daysAgo(3)
        let next = manager.calculateNextDoseDate(from: last)
        // Measured in calendar days, not elapsed time: a 70-day window that crosses a
        // DST boundary is 70 days ± 1 hour of absolute time, and the calendar-day
        // reading is the user-facing contract ("same local time, 10 weeks later").
        let gapDays = Calendar.current.dateComponents([.day], from: last, to: next).day
        XCTAssertEqual(gapDays, 70,
                       "the TU due date should be 10 weeks after the last dose")
    }

    @MainActor func testDueIntervalFallsBackToMethodWithoutHistory() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = nil
        manager.doseHistory = []

        XCTAssertEqual(manager.effectiveDueIntervalDays, 7,
                       "with no dose to read an ester from, the due interval is the method default")
    }

    @MainActor func testNextDoseDateUsesTheEffectiveFrequency() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = 10

        let last = daysAgo(0)
        let next = manager.calculateNextDoseDate(from: last)
        let gap = Calendar.current.dateComponents([.day], from: last, to: next).day

        XCTAssertEqual(gap, 10)
    }

    // MARK: - recordDose

    /// Regression tests for the "Record dose" quick action silently bypassing
    /// `doseHistory`. It used to only nudge `lastDoseDate`/`nextDoseDate`, so the
    /// PK curve never reflected the recorded dose, and a later Journal delete's
    /// history-only recompute of `nextDoseDate` would discard it entirely.

    @MainActor func testRecordDoseCreatesADoseRecord() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        XCTAssertTrue(manager.doseHistory.isEmpty)

        let date = daysAgo(0)
        manager.recordDose(on: date)

        XCTAssertEqual(manager.doseHistory.count, 1,
                       "recordDose must append a real DoseRecord, not just update the convenience date fields")
        XCTAssertEqual(manager.doseHistory.first?.doseDate, date)
    }

    @MainActor func testRecordDoseDefaultsEsterAndAmountFromLastLoggedDose() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.addDose(
            date: daysAgo(7),
            type: "Estrogen",
            ester: MedicationEster.cypionate.rawValue,
            method: "Injectable",
            doseAmount: 5.0,
            concentrationMgPerMl: 100.0
        )

        manager.recordDose(on: daysAgo(0))

        let recorded = manager.doseHistory.last
        XCTAssertEqual(recorded?.ester, MedicationEster.cypionate.rawValue,
                       "recordDose should carry forward the ester of the most recent real dose")
        XCTAssertEqual(recorded?.doseAmount, 5.0)
        XCTAssertEqual(recorded?.concentrationMgPerMl, 100.0)
    }

    @MainActor func testSoftDeleteAfterRecordDoseKeepsNextDoseInTheFuture() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.addDose(
            date: daysAgo(10),
            type: "Estrogen",
            ester: MedicationEster.valerate.rawValue,
            method: "Injectable",
            doseAmount: 2.0,
            concentrationMgPerMl: 40.0
        )
        let oldDoseId = manager.doseHistory.first!.id

        manager.recordDose(on: daysAgo(0))
        XCTAssertEqual(manager.doseHistory.count, 2)

        manager.softDeleteDose(id: oldDoseId)

        XCTAssertNotNil(manager.nextDoseDate)
        XCTAssertGreaterThan(manager.nextDoseDate!, Date(),
                             "next dose must stay anchored to the dose just recorded, not collapse to the deleted dose's stale schedule")
    }
}
