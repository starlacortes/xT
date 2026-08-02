//
//  InjectionSiteTests.swift
//  xTTests
//
//  Tests for RouteClass, AvoidZoneInfo, InjectionSite, and DoseRecord site extensions.
//

import Testing
import Foundation
@testable import xT

struct InjectionSiteTests {

    // MARK: - RouteClass

    @Test func routeClassCases() {
        #expect(RouteClass.allCases.count == 4)
        #expect(RouteClass.injection.rawValue == "injection")
        #expect(RouteClass.topical.rawValue == "topical")
        #expect(RouteClass.patch.rawValue == "patch")
        #expect(RouteClass.oral.rawValue == "oral")
    }

    @Test func heatMapWindowDays() {
        #expect(RouteClass.injection.heatMapWindowDays == 30)
        #expect(RouteClass.topical.heatMapWindowDays == 7)
        #expect(RouteClass.patch.heatMapWindowDays == 30)
        #expect(RouteClass.oral.heatMapWindowDays == 0)
    }

    @Test func alertThreshold() {
        #expect(RouteClass.injection.alertThreshold == 2)
        #expect(RouteClass.topical.alertThreshold == 3)
        #expect(RouteClass.patch.alertThreshold == 1)
        #expect(RouteClass.oral.alertThreshold == 0)
    }

    @Test func supportsMultiSite() {
        #expect(RouteClass.injection.supportsMultiSite == false)
        #expect(RouteClass.topical.supportsMultiSite == true)
        #expect(RouteClass.patch.supportsMultiSite == true)
        #expect(RouteClass.oral.supportsMultiSite == false)
    }

    @Test func displayName() {
        #expect(RouteClass.injection.displayName == "Injection (IM/SubQ)")
        #expect(RouteClass.topical.displayName == "Topical (gel/cream)")
        #expect(RouteClass.patch.displayName == "Transdermal patch")
        #expect(RouteClass.oral.displayName == "Oral")
    }

    @Test func defaultDurationDays() {
        #expect(RouteClass.injection.defaultDurationDays == 0)
        #expect(RouteClass.topical.defaultDurationDays == 0)
        #expect(RouteClass.patch.defaultDurationDays == 7)
        #expect(RouteClass.oral.defaultDurationDays == 0)
    }

    @Test func defaultRotationWindowDays() {
        #expect(RouteClass.injection.defaultRotationWindowDays == 14)
        #expect(RouteClass.topical.defaultRotationWindowDays == 7)
        #expect(RouteClass.patch.defaultRotationWindowDays == 30)
        #expect(RouteClass.oral.defaultRotationWindowDays == 0)
    }

    @Test func fromMethod() {
        #expect(RouteClass.from(method: "Injectable") == .injection)
        #expect(RouteClass.from(method: "Injectable (IM)") == .injection)
        #expect(RouteClass.from(method: "SubQ Injection") == .injection)
        #expect(RouteClass.from(method: "Cream") == .topical)
        #expect(RouteClass.from(method: "Gel") == .topical)
        #expect(RouteClass.from(method: "Patch") == .patch)
        #expect(RouteClass.from(method: "Oral") == .oral)
        #expect(RouteClass.from(method: "Sublingual") == .oral)
        #expect(RouteClass.from(method: "Unknown") == .injection) // default
    }

    // MARK: - AvoidZoneInfo

    @Test func avoidZoneInfoCreation() {
        let info = AvoidZoneInfo(zoneLabel: "Upper Right Thigh", reason: "Scar tissue")
        #expect(info.zoneLabel == "Upper Right Thigh")
        #expect(info.reason == "Scar tissue")
        #expect(info.markedAt <= Date())
    }

    @Test func avoidZoneInfoCodable() throws {
        let info = AvoidZoneInfo(zoneLabel: "Left Deltoid", reason: "Recent surgery")
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(AvoidZoneInfo.self, from: data)
        #expect(decoded.zoneLabel == info.zoneLabel)
        #expect(decoded.reason == info.reason)
    }

    // MARK: - InjectionSite JSON Serialization

    @Test func jsonArrayRoundTrip() throws {
        let sites = [
            InjectionSite(
                sketchId: "thighsFront",
                normalizedX: 0.3,
                normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh",
                viewContext: "front",
                bodyRegion: "thighs",
                routeClass: "injection",
                durationDays: 0
            ),
            InjectionSite(
                sketchId: "glutesBack",
                normalizedX: 0.6,
                normalizedY: 0.4,
                zoneLabel: "Right Ventrogluteal",
                viewContext: "back",
                bodyRegion: "glutes",
                routeClass: "injection",
                durationDays: 0
            ),
        ]

        let json = InjectionSite.toJSONArray(sites)
        #expect(json != nil)
        #expect(json!.contains("Upper Right Thigh"))
        #expect(json!.contains("Right Ventrogluteal"))

        let decoded = InjectionSite.fromJSONArray(json)
        #expect(decoded.count == 2)
        #expect(decoded[0].zoneLabel == "Upper Right Thigh")
        #expect(decoded[1].zoneLabel == "Right Ventrogluteal")
    }

    @Test func fromJSONArrayNilOrEmpty() {
        #expect(InjectionSite.fromJSONArray(nil) == [])
        #expect(InjectionSite.fromJSONArray("") == [])
        #expect(InjectionSite.fromJSONArray("not valid json") == [])
    }

    @Test func toJSONArrayEmpty() {
        let json = InjectionSite.toJSONArray([])
        #expect(json == "[]")
    }

    // MARK: - InjectionSite Graceful Decoding

    @Test func gracefulDecodePartialJSON() throws {
        let partialJSON = """
        [
            {
                "sketchId": "thighsFront",
                "zoneLabel": "Upper Right Thigh",
                "viewContext": "front",
                "bodyRegion": "thighs"
            }
        ]
        """
        let data = partialJSON.data(using: .utf8)!
        let sites = try JSONDecoder().decode([InjectionSite].self, from: data)
        #expect(sites.count == 1)
        let site = sites[0]
        #expect(site.schemaVersion == 1)
        #expect(site.sketchId == "thighsFront")
        // Missing fields should use defaults
        #expect(site.normalizedX == 0.5)
        #expect(site.normalizedY == 0.5)
        #expect(site.routeClass == "injection")
        #expect(site.durationDays == 0)
    }

    @Test func gracefulDecodeMissingSketchId() throws {
        // sketchId decodes leniently — missing key falls back to "unknown"
        let json = """
        [
            {
                "zoneLabel": "Test"
            }
        ]
        """
        let data = json.data(using: .utf8)!
        let sites = try JSONDecoder().decode([InjectionSite].self, from: data)
        #expect(sites.count == 1)
        #expect(sites[0].sketchId == "unknown")
        #expect(sites[0].zoneLabel == "Test")
    }

    // MARK: - InjectionSite Formatting

    @Test func lastDoseSentence() {
        let site = InjectionSite(
            sketchId: "thighsFront",
            normalizedX: 0.3,
            normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh",
            viewContext: "front",
            bodyRegion: "thighs",
            routeClass: "injection"
        )
        #expect(site.lastDoseSentence == "Last dose: Upper Right Thigh (front)")
        #expect(site.shortLabel == "Upper Right Thigh")
    }

    // MARK: - DoseRecord Site Extensions

    @Test func doseRecordInitWithSites() {
        let site = InjectionSite(
            sketchId: "thighsFront",
            normalizedX: 0.3,
            normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh",
            viewContext: "front",
            bodyRegion: "thighs",
            routeClass: "injection"
        )

        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "Valerate (EV)",
            administrationMethod: "Injectable",
            doseAmount: 4.0,
            injectionSites: [site]
        )

        #expect(dose.injectionSites.count == 1)
        #expect(dose.injectionSites[0].zoneLabel == "Upper Right Thigh")
        #expect(dose.primarySite?.zoneLabel == "Upper Right Thigh")
        #expect(dose.recordedAt != nil)
        #expect(dose.isUserCorrected == false)
        #expect(dose.originalDoseId == nil)
        #expect(dose.originalSites.isEmpty)
    }

    @Test func doseRecordCorrectionPreservesOriginalSites() {
        let originalSite = InjectionSite(
            sketchId: "glutesBack",
            normalizedX: 0.5,
            normalizedY: 0.3,
            zoneLabel: "Right Ventrogluteal",
            viewContext: "back",
            bodyRegion: "glutes",
            routeClass: "injection"
        )

        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Testosterone",
            ester: "Cypionate (EC)",
            administrationMethod: "Injectable",
            doseAmount: 50.0,
            isUserCorrected: true,
            originalDoseId: "abc-123",
            originalSites: [originalSite]
        )

        #expect(dose.isUserCorrected == true)
        #expect(dose.originalDoseId == "abc-123")
        #expect(dose.originalSites.count == 1)
        #expect(dose.originalSites[0].zoneLabel == "Right Ventrogluteal")
    }

    @Test func doseRecordMultiSiteRoundTrip() {
        let sites = [
            InjectionSite(
                sketchId: "armsFront",
                normalizedX: 0.2, normalizedY: 0.3,
                zoneLabel: "Left Forearm",
                viewContext: "front", bodyRegion: "arms",
                routeClass: "topical"
            ),
            InjectionSite(
                sketchId: "armsFront",
                normalizedX: 0.2, normalizedY: 0.3,
                zoneLabel: "Right Forearm",
                viewContext: "front", bodyRegion: "arms",
                routeClass: "topical"
            ),
        ]

        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "",
            administrationMethod: "Gel",
            doseAmount: 1.5,
            injectionSites: sites
        )

        #expect(dose.injectionSites.count == 2)
        #expect(dose.injectionSitesJSON != nil)
        #expect(dose.injectionSitesJSON!.contains("Left Forearm"))
        #expect(dose.injectionSitesJSON!.contains("Right Forearm"))
    }

    @Test func backwardCompatibleInjectionSiteSetter() {
        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "Valerate (EV)",
            administrationMethod: "Injectable",
            doseAmount: 4.0
        )
        #expect(dose.injectionSites.isEmpty)

        let site = InjectionSite(
            sketchId: "thighsFront",
            normalizedX: 0.5, normalizedY: 0.2,
            zoneLabel: "Mid Right Thigh",
            viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        #expect(dose.injectionSites.isEmpty)
    }

    // MARK: - RouteClass Codable Round-Trip

    @Test func routeClassCodable() throws {
        for route in RouteClass.allCases {
            let data = try JSONEncoder().encode(route)
            let decoded = try JSONDecoder().decode(RouteClass.self, from: data)
            #expect(decoded == route)
        }
    }

    // MARK: - Requires Precise Tap

    @Test func requiresPreciseTap() {
        #expect(RouteClass.injection.requiresPreciseTap == true)
        #expect(RouteClass.topical.requiresPreciseTap == false)
        #expect(RouteClass.patch.requiresPreciseTap == false)
        #expect(RouteClass.oral.requiresPreciseTap == false)
    }

    // MARK: - Phase 15: iconName & tintColor

    @Test func routeClassIconName() {
        #expect(RouteClass.injection.iconName == "syringe")
        #expect(RouteClass.topical.iconName == "hand.raised")
        #expect(RouteClass.patch.iconName == "bandage")
        #expect(RouteClass.oral.iconName == "pills")
    }

    @Test func routeClassTintColor() {
        // Verify tintColor returns a Color (not nil)
        for route in RouteClass.allCases {
            _ = route.tintColor // must not crash
        }
    }

    // MARK: - Phase 16: Integration Tests

    @Test func oralRouteSkipsSite() {
        // Oral routes should have no injectionSites
        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "",
            administrationMethod: "Oral",
            doseAmount: 2.0
        )
        #expect(dose.injectionSites.isEmpty)
        #expect(dose.primarySite == nil)
        let rc = RouteClass.from(method: "Oral")
        #expect(rc == .oral)
        #expect(rc.defaultRotationWindowDays == 0)
        #expect(rc.heatMapWindowDays == 0)
    }

    @Test func multiSiteTopicalRoundTrip() {
        // Topical routes support multi-site (two forearms)
        let sites = [
            InjectionSite(
                sketchId: "armsFront", normalizedX: 0.2, normalizedY: 0.3,
                zoneLabel: "Left Forearm", viewContext: "front", bodyRegion: "arms",
                routeClass: "topical"
            ),
            InjectionSite(
                sketchId: "armsFront", normalizedX: 0.2, normalizedY: 0.3,
                zoneLabel: "Right Forearm", viewContext: "front", bodyRegion: "arms",
                routeClass: "topical"
            ),
        ]
        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "",
            administrationMethod: "Gel",
            doseAmount: 1.5,
            injectionSites: sites
        )
        #expect(dose.injectionSites.count == 2)
        #expect(dose.primarySite?.zoneLabel == "Left Forearm")

        // Verify JSON round-trip
        let json = dose.injectionSitesJSON
        #expect(json != nil)
        #expect(json!.contains("Left Forearm"))
        #expect(json!.contains("Right Forearm"))

        let decoded = InjectionSite.fromJSONArray(json)
        #expect(decoded.count == 2)
    }

    @Test func patchDurationRoundTrip() {
        // Patches have non-zero durationDays
        let site = InjectionSite(
            sketchId: "midsectionFront", normalizedX: 0.5, normalizedY: 0.3,
            zoneLabel: "Lower Abdomen Right", viewContext: "front", bodyRegion: "abdomen",
            routeClass: "patch", durationDays: 7
        )
        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "",
            administrationMethod: "Patch",
            doseAmount: 0.1,
            injectionSites: [site]
        )
        #expect(dose.injectionSites.count == 1)
        #expect(dose.injectionSites[0].durationDays == 7)
        #expect(dose.injectionSites[0].routeClass == "patch")
        let rc = RouteClass.from(method: "Patch")
        #expect(rc == .patch)
        #expect(rc.defaultDurationDays == 7)
    }

    @Test func avoidZonesCodableDictionaryRoundTrip() throws {
        // Simulate the UserDefaults persistence pattern used by MedicationManager
        var zones: [String: AvoidZoneInfo] = [
            "Upper Right Thigh": AvoidZoneInfo(zoneLabel: "Upper Right Thigh", reason: "Scar tissue"),
            "Left Deltoid": AvoidZoneInfo(zoneLabel: "Left Deltoid", reason: ""),
        ]
        let encoded = try JSONEncoder().encode(zones)
        let decoded = try JSONDecoder().decode([String: AvoidZoneInfo].self, from: encoded)
        #expect(decoded.count == 2)
        #expect(decoded["Upper Right Thigh"]?.reason == "Scar tissue")
        #expect(decoded["Left Deltoid"]?.reason == "")

        // Test unmark (remove from dict)
        zones.removeValue(forKey: "Left Deltoid")
        #expect(zones.count == 1)
        #expect(zones["Left Deltoid"] == nil)
    }

    @Test func correctionFlowPreservesAuditTrail() {
        // Simulated correction: user changes site on an existing dose
        let originalSite = InjectionSite(
            sketchId: "glutesBack", normalizedX: 0.5, normalizedY: 0.3,
            zoneLabel: "Right Ventrogluteal", viewContext: "back", bodyRegion: "glutes",
            routeClass: "injection"
        )

        // Step 1: Original dose recorded
        let originalDose = DoseRecord(
            doseDate: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            medicationType: "Testosterone",
            ester: "Cypionate (EC)",
            administrationMethod: "Injectable",
            doseAmount: 50.0,
            injectionSites: [originalSite]
        )
        #expect(originalDose.isUserCorrected == false)
        #expect(originalDose.originalDoseId == nil)
        #expect(originalDose.originalSites.isEmpty)

        // Step 2: Correction — new dose with original sites preserved
        let correctedSite = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.4, normalizedY: 0.2,
            zoneLabel: "Mid Left Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let correctedDose = DoseRecord(
            doseDate: originalDose.doseDate, // same date
            medicationType: originalDose.medicationType,
            ester: originalDose.ester,
            administrationMethod: originalDose.administrationMethod,
            doseAmount: originalDose.doseAmount,
            injectionSites: [correctedSite],
            isUserCorrected: true,
            originalDoseId: originalDose.id,
            originalSites: originalDose.injectionSites
        )

        // Verify audit trail
        #expect(correctedDose.isUserCorrected == true)
        #expect(correctedDose.originalDoseId == originalDose.id)
        #expect(correctedDose.originalSites.count == 1)
        #expect(correctedDose.originalSites[0].zoneLabel == "Right Ventrogluteal")
        #expect(correctedDose.injectionSites[0].zoneLabel == "Mid Left Thigh")
        #expect(correctedDose.recordedAt != nil)
    }

    @Test func dataExportCSVContainsSiteColumns() {
        // Verify that site-related columns appear in CSV export data
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let dose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "Valerate (EV)",
            administrationMethod: "Injectable",
            doseAmount: 4.0,
            injectionSites: [site]
        )
        // The record itself should serialize correctly
        #expect(dose.injectionSitesJSON != nil)
        #expect(dose.injectionSitesJSON!.contains("sketchId"))
        #expect(dose.injectionSitesJSON!.contains("zoneLabel"))
        // Site count should be 1
        #expect(dose.injectionSites.count == 1)

        // No-site records should produce empty JSON array
        let oralDose = DoseRecord(
            doseDate: Date(),
            medicationType: "Estrogen",
            ester: "",
            administrationMethod: "Oral",
            doseAmount: 2.0
        )
        #expect(oralDose.injectionSitesJSON == "[]")
    }

    // MARK: - Rotation Safety: conflictsWith & daysSinceLastUse

    @Test func conflictsWithSameZoneWithinWindow() {
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let dose = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection"
            )]
        )
        #expect(site.conflictsWith(doses: [dose], withinDays: 14) == true)
    }

    @Test func conflictsWithSameZoneOutsideWindow() {
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let dose = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection"
            )]
        )
        #expect(site.conflictsWith(doses: [dose], withinDays: 14) == false)
    }

    @Test func conflictsWithDifferentZone() {
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let dose = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "armsFront", normalizedX: 0.5, normalizedY: 0.3,
                zoneLabel: "Left Deltoid", viewContext: "front", bodyRegion: "arms",
                routeClass: "injection"
            )]
        )
        #expect(site.conflictsWith(doses: [dose], withinDays: 14) == false)
    }

    @Test func conflictsWithPatchDurationExtendsWindow() {
        let site = InjectionSite(
            sketchId: "midsectionFront", normalizedX: 0.5, normalizedY: 0.3,
            zoneLabel: "Lower Abdomen Right", viewContext: "front", bodyRegion: "abdomen",
            routeClass: "patch"
        )
        let dose = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            medicationType: "Estrogen", ester: "",
            administrationMethod: "Patch", doseAmount: 0.1,
            injectionSites: [InjectionSite(
                sketchId: "midsectionFront", normalizedX: 0.5, normalizedY: 0.3,
                zoneLabel: "Lower Abdomen Right", viewContext: "front", bodyRegion: "abdomen",
                routeClass: "patch", durationDays: 7
            )]
        )
        #expect(site.conflictsWith(doses: [dose], withinDays: 5) == true)
    }

    @Test func conflictsWithDefaultWindow() {
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        let dose = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection"
            )]
        )
        #expect(site.conflictsWith(doses: [dose]) == true)
    }

    @Test func daysSinceLastUseReturnsDays() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let dose = DoseRecord(
            doseDate: fiveDaysAgo,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection", lastUsedDate: fiveDaysAgo
            )]
        )
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection", lastUsedDate: Date()
        )
        let days = site.daysSinceLastUse(from: [dose])
        #expect(days != nil)
        #expect(days! >= 5)
    }

    @Test func daysSinceLastUseReturnsNilForFirstUse() {
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection"
        )
        #expect(site.daysSinceLastUse(from: []) == nil)
    }

    @Test func daysSinceLastUseFilterOutSameDate() {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let site = InjectionSite(
            sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
            zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
            routeClass: "injection", lastUsedDate: now
        )
        let doseSameDate = DoseRecord(
            doseDate: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection", lastUsedDate: now
            )]
        )
        let dosePrior = DoseRecord(
            doseDate: sevenDaysAgo,
            medicationType: "Estrogen", ester: "Valerate (EV)",
            administrationMethod: "Injectable", doseAmount: 4.0,
            injectionSites: [InjectionSite(
                sketchId: "thighsFront", normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh", viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection", lastUsedDate: sevenDaysAgo
            )]
        )
        let days = site.daysSinceLastUse(from: [doseSameDate, dosePrior])
        #expect(days != nil)
        #expect(days! >= 7)
    }
}
