//
//  SiteSuggestionTests.swift
//  xTTests
//
//  H-D6 — the next-site suggestion. Exercises the empty-history pick, left/right
//  rotation across the preferred zones, the avoid list, and the side tie-break.
//  Uses Testosterone|injection, whose preferred order begins
//  Right Ventrogluteal · Left Ventrogluteal · Upper Right Thigh · Upper Left Thigh.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Site suggestion (H-D6)")
struct SiteSuggestionTests {

    private let injectable = MedicationManager.AdministrationMethod.injectable.rawValue

    private func site(_ label: String) -> InjectionSite {
        InjectionSite(sketchId: "test", normalizedX: 0.5, normalizedY: 0.5,
                      zoneLabel: label, viewContext: "front", bodyRegion: "test",
                      routeClass: "injection")
    }

    /// Configures a Testosterone injection regimen.
    private func configured() -> MedicationManager {
        let m = TestDefaults.manager()
        m.updateSelection(type: .testosterone, method: .injectable)
        return m
    }

    private func record(_ m: MedicationManager, zone: String, date: Date) {
        m.addDose(date: date, type: "Testosterone", ester: TestosteroneEster.cypionate.rawValue,
                  method: injectable, doseAmount: 40.0, injectionSites: [site(zone)])
    }

    @Test("Oral has no site suggestion")
    func oralNil() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .oral)
        #expect(m.siteSuggestion(routeClass: .oral).suggested == nil)
    }

    @Test("Empty history suggests the first candidate")
    func emptyHistory() {
        let m = configured()
        #expect(m.siteSuggestion(routeClass: .injection).suggested == "Right Ventrogluteal")
    }

    @Test("Rotation alternates sides across the preferred zones")
    func rotation() {
        let m = configured()
        let now = Date()
        func day(_ ago: Int) -> Date { Calendar.current.date(byAdding: .day, value: -ago, to: now)! }

        #expect(m.siteSuggestion(routeClass: .injection).suggested == "Right Ventrogluteal")
        record(m, zone: "Right Ventrogluteal", date: day(4))
        #expect(m.siteSuggestion(routeClass: .injection).suggested == "Left Ventrogluteal")
        record(m, zone: "Left Ventrogluteal", date: day(3))
        #expect(m.siteSuggestion(routeClass: .injection).suggested == "Upper Right Thigh")
        record(m, zone: "Upper Right Thigh", date: day(2))
        #expect(m.siteSuggestion(routeClass: .injection).suggested == "Upper Left Thigh")
    }

    @Test("Side tie-break: a left last site yields a right suggestion")
    func sideTieBreak() {
        let m = configured()
        record(m, zone: "Left Ventrogluteal", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let suggestion = m.siteSuggestion(routeClass: .injection)
        #expect(suggestion.last.first?.zoneLabel == "Left Ventrogluteal")
        // Opposite side, least recently used (never used) → the first right candidate.
        #expect(suggestion.suggested == "Right Ventrogluteal")
    }

    @Test("An avoided zone is never suggested")
    func avoidList() {
        let m = configured()
        m.markZoneAsAvoid("Right Ventrogluteal")
        let suggested = m.siteSuggestion(routeClass: .injection).suggested
        #expect(suggested != "Right Ventrogluteal")
        #expect(suggested == "Left Ventrogluteal")
    }
}
