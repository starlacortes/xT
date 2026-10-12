//
//  LevelProvenanceTests.swift
//  xTTests
//
//  H-D3 — what the modeled level rests on. Bases are driven by constructing lab
//  records directly (calibration factor set in-hand) so the test pins the provenance
//  logic, not the PK calibration engine. Also covers the age-bucket edges.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Level provenance (H-D3)")
struct LevelProvenanceTests {

    /// A lab record with a given calibration outcome, appended straight to history.
    private func lab(_ hormone: String, draw: Date, calibrated: Bool, measured: Double = 300) -> BloodTestRecord {
        let record = BloodTestRecord(drawDate: draw, measuredLevel: measured, hormoneType: hormone)
        record.calibrationFactor = calibrated ? 1.1 : nil
        return record
    }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test("No labs on file")
    func noLabs() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        let provenance = m.levelProvenance
        #expect(provenance.basis == .noLabs)
        #expect(provenance.labsOnFile == 0)
    }

    @Test("A lab for the other hormone leaves the selected hormone with no labs")
    func otherHormoneOnly() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        m.bloodTestHistory = [lab("Testosterone", draw: Date(), calibrated: true)]
        let provenance = m.levelProvenance
        #expect(provenance.basis == .noLabs)
        #expect(provenance.labsOnFile == 0)
    }

    @Test("A calibrated lab anchors the level")
    func calibrated() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        let draw = Date()
        m.bloodTestHistory = [lab("Estrogen", draw: draw, calibrated: true)]
        #expect(m.levelProvenance.basis == .calibrated(lastLab: draw))
        #expect(m.levelProvenance.labsOnFile == 1)
    }

    @Test("An unreconcilable lab is flagged not-usable")
    func notUsable() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        let draw = Date()
        m.bloodTestHistory = [lab("Estrogen", draw: draw, calibrated: false)]
        #expect(m.levelProvenance.basis == .labNotUsable(lastLab: draw))
        #expect(m.levelProvenance.labsOnFile == 1)
    }

    @Test("With two labs the newest wins")
    func newestWins() {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        let older = Date(timeIntervalSinceNow: -60 * 86_400)
        let newer = Date(timeIntervalSinceNow: -5 * 86_400)
        m.bloodTestHistory = [
            lab("Estrogen", draw: older, calibrated: true),
            lab("Estrogen", draw: newer, calibrated: true),
        ]
        #expect(m.levelProvenance.basis == .calibrated(lastLab: newer))
        #expect(m.levelProvenance.labsOnFile == 2)
    }

    @Test("Age buckets at their edges")
    func ageBuckets() {
        let cal = utc
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        func age(_ daysAgo: Int) -> MedicationManager.LevelProvenance.LabAge {
            let draw = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            return MedicationManager.labAge(of: draw, now: now, calendar: cal)
        }

        #expect(age(13) == .days(13))     // last day in the days bucket
        #expect(age(14) == .weeks(2))     // first day in the weeks bucket
        #expect(age(419) == .weeks(59))   // last week before the months bucket (59 < 60)

        // 420 days → 60 weeks → months bucket.
        if case .months(let n) = age(420) {
            #expect(n >= 1)
        } else {
            Issue.record("expected a months bucket at 420 days")
        }
    }
}
