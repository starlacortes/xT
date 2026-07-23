//
//  DataExporter.swift
//  xT
//
//  Created 2026-07-04.
//  Pure formatting logic — no SwiftUI. Exports all user data as CSV or JSON.
//

import Foundation

/// Stateless formatter that reads current application state and produces
/// portable CSV / JSON representations of user-owned data.
struct DataExporter {

    // MARK: - Public Input Container

    /// Aggregated application state needed for a complete export.
    struct ExportState {
        let doseHistory: [DoseRecord]
        let journalEntries: [JournalEntry]
        let bloodTests: [BloodTestRecord]
        let swiftDataPreferences: UserPreferences?
        let selectedMedication: String?
        let hrtStartDate: Date?
        let antiAndrogenInUse: Bool
        let spironolactoneInUse: Bool
        let missedDoseGracePeriodHours: Double
        let doseReminderEnabled: Bool
        let doseReminderHour: Int
        let doseReminderMinute: Int
        let journalReminderEnabled: Bool
        let journalReminderHour: Int
        let journalReminderMinute: Int
        let useCustomTargets: Bool
        let targetTroughMin: Double
        let targetTroughMax: Double
        let targetPeakCeiling: Double
        let medicationUnit: String
        let profileName: String
        let avoidZones: [String: AvoidZoneInfo]
    }

    // MARK: - Public API

    /// Returns a multi-section CSV string containing all user data.
    static func exportCSV(state: ExportState) -> String {
        var csv = ""

        csv.append(doseHistoryCSV(state.doseHistory))
        csv.append("\n")
        csv.append(injectionSiteCSV(state.doseHistory))
        csv.append("\n")
        csv.append(journalEntriesCSV(state.journalEntries))
        csv.append("\n")
        csv.append(bloodTestsCSV(state.bloodTests))
        csv.append("\n")
        csv.append(avoidZonesCSV(state.avoidZones))
        csv.append("\n")
        csv.append(exportPreferencesCSV(state))

        return csv
    }

    /// Returns JSON-encoded data representing all user data.
    static func exportJSON(state: ExportState) -> Data? {
        let root = ExportPayload(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            doseHistory: state.doseHistory.filter(\.isActive).map(DoseExport.from),
            journalEntries: state.journalEntries.map(JournalExport.from),
            bloodTests: state.bloodTests.map(BloodTestExport.from),
            preferences: PreferencesExport.from(state),
            avoidZones: state.avoidZones.map { (zone, info) in
                AvoidZoneExport(zoneLabel: zone, reason: info.reason, markedAt: isoFormatter.string(from: info.markedAt))
            }.sorted(by: { $0.zoneLabel < $1.zoneLabel })
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(root)
    }

    // MARK: - CSV Section Formatters

    private static func doseHistoryCSV(_ records: [DoseRecord]) -> String {
        var csv = "# ---- DOSE RECORDS ----\n"
        csv.append("id,date,medication,ester,method,dose_mg,conc_mg_per_ml,status,skip_reason,injection_time,is_user_corrected,original_dose_id,recorded_at,site_count\n")
        for r in records where r.isActive {
            let status = r.doseStatus
            let conc = r.concentrationMgPerMl.map { String($0) } ?? ""
            let injectionTime = r.injectionTime.map { isoFormatter.string(from: $0) } ?? ""
            let skipReason = (r.skipReason ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let corrected = r.isUserCorrected ? "true" : "false"
            let origId = r.originalDoseId ?? ""
            let recordedStr = r.recordedAt.map { isoFormatter.string(from: $0) } ?? ""
            let siteCount = r.injectionSites.count
            let line = "\"\(r.id)\",\"\(isoFormatter.string(from: r.doseDate))\",\"\(r.medicationType)\",\"\(r.ester)\",\"\(r.administrationMethod)\",\(r.doseAmount),\(conc),\"\(status)\",\"\(skipReason)\",\"\(injectionTime)\",\(corrected),\"\(origId)\",\"\(recordedStr)\",\(siteCount)\n"
            csv.append(line)
        }
        return csv
    }

    /// Multi-row site export — one row per site per dose.
    private static func injectionSiteCSV(_ records: [DoseRecord]) -> String {
        // Only emit section if there's at least one record with site data.
        let hasSites = records.contains { !$0.injectionSites.isEmpty }
        guard hasSites else { return "" }

        var csv = "# ---- ADMINISTRATION SITES ----\n"
        csv.append("dose_id,dose_date,medication,ester,method,route_class,route_class_display,recorded_at,site_index,zone_label,view_context,sketch_id,body_region,normalized_x,normalized_y,duration_days,is_corrected,original_site,original_dose_id\n")

        for r in records where r.isActive && !r.injectionSites.isEmpty {
            let rc = RouteClass.from(method: r.administrationMethod)
            let recordedStr = r.recordedAt.map { isoFormatter.string(from: $0) } ?? ""
            let origId = r.originalDoseId ?? ""
            let medType = r.medicationType.replacingOccurrences(of: "\"", with: "\"\"")
            let ester = r.ester.replacingOccurrences(of: "\"", with: "\"\"")
            let method = r.administrationMethod.replacingOccurrences(of: "\"", with: "\"\"")

            for (idx, site) in r.injectionSites.enumerated() {
                let originalSite: String
                let orig = r.originalSites
                if r.isUserCorrected, idx < orig.count {
                    let o = orig[idx]
                    let escapedZone = o.zoneLabel.replacingOccurrences(of: "\"", with: "\"\"")
                    let escapedCtx = o.viewContext.replacingOccurrences(of: "\"", with: "\"\"")
                    originalSite = "\"\(escapedZone) (\(escapedCtx))\""
                } else {
                    originalSite = ""
                }

                let zoneLabel = site.zoneLabel.replacingOccurrences(of: "\"", with: "\"\"")
                let line = [
                    "\"\(r.id)\"",
                    "\"\(isoFormatter.string(from: r.doseDate))\"",
                    "\"\(medType)\"",
                    "\"\(ester)\"",
                    "\"\(method)\"",
                    "\"\(site.routeClass)\"",
                    "\"\(rc.displayName)\"",
                    "\"\(recordedStr)\"",
                    "\(idx + 1)",
                    "\"\(zoneLabel)\"",
                    "\"\(site.viewContext)\"",
                    "\"\(site.sketchId)\"",
                    "\"\(site.bodyRegion)\"",
                    "\(site.normalizedX)",
                    "\(site.normalizedY)",
                    "\(site.durationDays)",
                    r.isUserCorrected ? "true" : "false",
                    originalSite,
                    "\"\(origId)\""
                ].joined(separator: ",")
                csv.append("\(line)\n")
            }
        }
        return csv
    }

    /// Avoid zones section.
    private static func avoidZonesCSV(_ zones: [String: AvoidZoneInfo]) -> String {
        if zones.isEmpty { return "" }
        var csv = "# ---- AVOID ZONES ----\n"
        csv.append("zone_label,reason,marked_at\n")
        for (zone, info) in zones.sorted(by: { $0.key < $1.key }) {
            let reason = info.reason.replacingOccurrences(of: "\"", with: "\"\"")
            csv.append("\"\(zone)\",\"\(reason)\",\"\(isoFormatter.string(from: info.markedAt))\"\n")
        }
        return csv
    }

    private static func journalEntriesCSV(_ entries: [JournalEntry]) -> String {
        var csv = "# ---- JOURNAL ENTRIES ----\n"
        csv.append("id,date,mood,text,symptoms\n")
        for e in entries {
            let text = e.text.replacingOccurrences(of: "\"", with: "\"\"")
            let symptoms = e.symptoms.map(\.name).joined(separator: "; ")
            csv.append("\"\(e.id.uuidString)\",\"\(isoFormatter.string(from: e.date))\",\"\(e.mood.rawValue)\",\"\(text)\",\"\(symptoms)\"\n")
        }
        return csv
    }

    private static func bloodTestsCSV(_ records: [BloodTestRecord]) -> String {
        var csv = "# ---- BLOOD TEST RECORDS ----\n"
        csv.append("id,draw_date,measured_level,hormone_type,hours_since_last_dose,notes,calibration_factor\n")
        for r in records {
            let hours = r.hoursSinceLastDose.map { String($0) } ?? ""
            let notes = (r.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let cal = r.calibrationFactor.map { String($0) } ?? ""
            csv.append("\"\(r.id)\",\"\(isoFormatter.string(from: r.drawDate))\",\(r.measuredLevel),\"\(r.hormoneType)\",\(hours),\"\(notes)\",\(cal)\n")
        }
        return csv
    }

    private static func exportPreferencesCSV(_ state: ExportState) -> String {
        var csv = "# ---- USER PREFERENCES ----\n"
        csv.append("key,value\n")

        // Profile
        csv.append("\"profileName\",\"\(state.profileName)\"\n")
        csv.append("\"hrtStartDate\",\"\(state.hrtStartDate.map { isoFormatter.string(from: $0) } ?? "")\"\n")

        // Medication selection
        csv.append("\"selectedMedication\",\"\(state.selectedMedication ?? "")\"\n")
        csv.append("\"medicationUnit\",\"\(state.medicationUnit)\"\n")

        // Physiology
        csv.append("\"antiAndrogenInUse\",\"\(state.antiAndrogenInUse)\"\n")
        csv.append("\"spironolactoneInUse\",\"\(state.spironolactoneInUse)\"\n")

        // SwiftData UserPreferences
        if let prefs = state.swiftDataPreferences {
            csv.append("\"suppressionSpeed\",\"\(prefs.suppressionSpeed)\"\n")
            csv.append("\"spironolactoneClearanceEnabled\",\"\(prefs.spironolactoneClearanceEnabled)\"\n")
            csv.append("\"customFrequencyDays\",\"\(prefs.customFrequencyDays.map(String.init) ?? "")\"\n")
            csv.append("\"medicationRow\",\"\(prefs.medicationRow)\"\n")
            csv.append("\"medicationColumn\",\"\(prefs.medicationColumn)\"\n")
            let defE2 = prefs.defaultEstrogenConcentration.map { String($0) } ?? ""
            let defT = prefs.defaultTestosteroneConcentration.map { String($0) } ?? ""
            csv.append("\"defaultEstrogenConcentration\",\"\(defE2)\"\n")
            csv.append("\"defaultTestosteroneConcentration\",\"\(defT)\"\n")
        }

        // Dosing
        csv.append("\"missedDoseGracePeriodHours\",\"\(state.missedDoseGracePeriodHours)\"\n")

        // Notifications
        csv.append("\"doseReminderEnabled\",\"\(state.doseReminderEnabled)\"\n")
        csv.append("\"doseReminderHour\",\"\(state.doseReminderHour)\"\n")
        csv.append("\"doseReminderMinute\",\"\(state.doseReminderMinute)\"\n")
        csv.append("\"journalReminderEnabled\",\"\(state.journalReminderEnabled)\"\n")
        csv.append("\"journalReminderHour\",\"\(state.journalReminderHour)\"\n")
        csv.append("\"journalReminderMinute\",\"\(state.journalReminderMinute)\"\n")

        // Therapeutic targets
        csv.append("\"useCustomTargets\",\"\(state.useCustomTargets)\"\n")
        csv.append("\"targetTroughMin\",\"\(state.targetTroughMin)\"\n")
        csv.append("\"targetTroughMax\",\"\(state.targetTroughMax)\"\n")
        csv.append("\"targetPeakCeiling\",\"\(state.targetPeakCeiling)\"\n")

        return csv
    }

    // MARK: - Timestamp for filenames

    static func exportFilename(prefix: String, ext: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "xT_\(prefix)_\(df.string(from: Date())).\(ext)"
    }

    // MARK: - Helpers

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - JSON Export Payloads

private struct ExportPayload: Encodable {
    let exportedAt: String
    let doseHistory: [DoseExport]
    let journalEntries: [JournalExport]
    let bloodTests: [BloodTestExport]
    let preferences: PreferencesExport
    let avoidZones: [AvoidZoneExport]
}

private struct DoseExport: Encodable {
    let id: String
    let doseDate: String
    let medicationType: String
    let ester: String
    let administrationMethod: String
    let doseAmount: Double
    let concentrationMgPerMl: Double?
    let doseStatus: String
    let skipReason: String?
    let injectionTime: String?
    let injectionSites: [InjectionSiteExport]
    let recordedAt: String?
    let isUserCorrected: Bool
    let originalDoseId: String?
    let originalSite: InjectionSiteExport?

    static func from(_ r: DoseRecord) -> DoseExport {
        DoseExport(
            id: r.id,
            doseDate: DataExporter.isoFormatter.string(from: r.doseDate),
            medicationType: r.medicationType,
            ester: r.ester,
            administrationMethod: r.administrationMethod,
            doseAmount: r.doseAmount,
            concentrationMgPerMl: r.concentrationMgPerMl,
            doseStatus: r.doseStatus,
            skipReason: r.skipReason,
            injectionTime: r.injectionTime.map { DataExporter.isoFormatter.string(from: $0) },
            injectionSites: r.injectionSites.map(InjectionSiteExport.from),
            recordedAt: r.recordedAt.map { DataExporter.isoFormatter.string(from: $0) },
            isUserCorrected: r.isUserCorrected,
            originalDoseId: r.originalDoseId,
            originalSite: r.originalSites.first.map(InjectionSiteExport.from),
        )
    }
}

private struct InjectionSiteExport: Encodable {
    let sketchId: String
    let normalizedX: Double
    let normalizedY: Double
    let zoneLabel: String
    let viewContext: String
    let bodyRegion: String
    let routeClass: String
    let routeClassDisplay: String
    let durationDays: Int

    static func from(_ site: InjectionSite) -> InjectionSiteExport {
        let rc = RouteClass(rawValue: site.routeClass) ?? .injection
        return InjectionSiteExport(
            sketchId: site.sketchId,
            normalizedX: site.normalizedX,
            normalizedY: site.normalizedY,
            zoneLabel: site.zoneLabel,
            viewContext: site.viewContext,
            bodyRegion: site.bodyRegion,
            routeClass: site.routeClass,
            routeClassDisplay: rc.displayName,
            durationDays: site.durationDays
        )
    }
}

private struct AvoidZoneExport: Encodable {
    let zoneLabel: String
    let reason: String
    let markedAt: String
}

private struct JournalExport: Encodable {
    let id: String
    let date: String
    let mood: String
    let text: String
    let symptoms: [String]

    static func from(_ e: JournalEntry) -> JournalExport {
        JournalExport(
            id: e.id.uuidString,
            date: DataExporter.isoFormatter.string(from: e.date),
            mood: e.mood.rawValue,
            text: e.text,
            symptoms: e.symptoms.map(\.name)
        )
    }
}

private struct BloodTestExport: Encodable {
    let id: String
    let drawDate: String
    let measuredLevel: Double
    let hormoneType: String
    let hoursSinceLastDose: Double?
    let notes: String?
    let calibrationFactor: Double?

    static func from(_ r: BloodTestRecord) -> BloodTestExport {
        BloodTestExport(
            id: r.id,
            drawDate: DataExporter.isoFormatter.string(from: r.drawDate),
            measuredLevel: r.measuredLevel,
            hormoneType: r.hormoneType,
            hoursSinceLastDose: r.hoursSinceLastDose,
            notes: r.notes,
            calibrationFactor: r.calibrationFactor
        )
    }
}

private struct PreferencesExport: Encodable {
    let profileName: String
    let hrtStartDate: String?
    let selectedMedication: String?
    let medicationUnit: String?
    let antiAndrogenInUse: Bool
    let spironolactoneInUse: Bool
    let suppressionSpeed: String?
    let spironolactoneClearanceEnabled: Bool?
    let customFrequencyDays: Int?
    let missedDoseGracePeriodHours: Double
    let doseReminderEnabled: Bool
    let doseReminderHour: Int
    let doseReminderMinute: Int
    let journalReminderEnabled: Bool
    let journalReminderHour: Int
    let journalReminderMinute: Int
    let useCustomTargets: Bool
    let targetTroughMin: Double
    let targetTroughMax: Double
    let targetPeakCeiling: Double

    // SwiftData UserPreferences fields
    let medicationRow: Int?
    let medicationColumn: Int?
    let defaultEstrogenConcentration: Double?
    let defaultTestosteroneConcentration: Double?

    static func from(_ state: DataExporter.ExportState) -> PreferencesExport {
        let prefs = state.swiftDataPreferences
        return PreferencesExport(
            profileName: state.profileName,
            hrtStartDate: state.hrtStartDate.map { DataExporter.isoFormatter.string(from: $0) },
            selectedMedication: state.selectedMedication,
            medicationUnit: state.medicationUnit,
            antiAndrogenInUse: state.antiAndrogenInUse,
            spironolactoneInUse: state.spironolactoneInUse,
            suppressionSpeed: prefs?.suppressionSpeed,
            spironolactoneClearanceEnabled: prefs?.spironolactoneClearanceEnabled,
            customFrequencyDays: prefs?.customFrequencyDays,
            missedDoseGracePeriodHours: state.missedDoseGracePeriodHours,
            doseReminderEnabled: state.doseReminderEnabled,
            doseReminderHour: state.doseReminderHour,
            doseReminderMinute: state.doseReminderMinute,
            journalReminderEnabled: state.journalReminderEnabled,
            journalReminderHour: state.journalReminderHour,
            journalReminderMinute: state.journalReminderMinute,
            useCustomTargets: state.useCustomTargets,
            targetTroughMin: state.targetTroughMin,
            targetTroughMax: state.targetTroughMax,
            targetPeakCeiling: state.targetPeakCeiling,
            medicationRow: prefs?.medicationRow,
            medicationColumn: prefs?.medicationColumn,
            defaultEstrogenConcentration: prefs?.defaultEstrogenConcentration,
            defaultTestosteroneConcentration: prefs?.defaultTestosteroneConcentration
        )
    }
}
