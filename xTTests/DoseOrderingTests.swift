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
        manager = MedicationManager()
        manager.clearSelection()
    }

    @MainActor override func tearDown() {
        manager.clearSelection()
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
                       "a soft-deleted newest dose must fall through to the one before it")
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

    @MainActor func testNextDoseDateUsesTheEffectiveFrequency() {
        manager.updateSelection(type: .estrogen, method: .injectable)
        manager.customFrequencyDays = 10

        let last = daysAgo(0)
        let next = manager.calculateNextDoseDate(from: last)
        let gap = Calendar.current.dateComponents([.day], from: last, to: next).day

        XCTAssertEqual(gap, 10)
    }
}
