//
//  MedicationManager+Persistence.swift
//  xT
//
//  Migration, persistence, and storage extensions.
//

import Foundation
import SwiftData

extension MedicationManager {

    // MARK: - Migration (Legacy SwiftData Records)

    /// One-time migration: backfill `recordedAt` for legacy records that don't have it.
    func migrateRecordedAtForLegacyRecords() {
        let legacyRecords = doseHistory.filter { $0.recordedAt == nil }
        for record in legacyRecords {
            record.recordedAt = record.doseDate
        }
        if !legacyRecords.isEmpty {
            try? modelContext?.save()
        }
    }

    // MARK: - Migration (UserDefaults → UserPreferences)

    /// One-time migration from the old encrypted UserDefaults and mm.* keys into the
    /// UserPreferences SwiftData model. Runs once per device, guarded by a flag.
    /// After migration, UserPreferences is the single source of truth for all synced settings.
    func migrateToUserPreferences() {
        guard let context = modelContext else { return }
        guard !defaults.bool(forKey: Keys.cloudKitMigrationDone) else { return }

        guard let prefs = UserPreferences.canonical(in: context) else { return }

        let security = SecurityManager.shared
        var needsSave = false

        // Medication selection (from encrypted UserDefaults)
        if prefs.selectedMedication == nil {
            if let data = defaults.data(forKey: "encryptedMedicationSelection"),
               let decrypted = try? security.decryptData(data),
               let str = String(data: decrypted, encoding: .utf8) {
                let parts = str.components(separatedBy: "|")
                if parts.count >= 2 {
                    prefs.selectedMedication = parts[0].isEmpty ? nil : parts[0]
                    prefs.selectedAdministrationMethod = parts[1].isEmpty ? nil : parts[1]
                    prefs.selectedEster = parts.count >= 3 ? (parts[2].isEmpty ? nil : parts[2]) : nil
                    needsSave = true
                }
            } else if let sel = defaults.string(forKey: "selectedMedication") {
                prefs.selectedMedication = sel
                prefs.selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
                needsSave = true
            }
        }

        // HRT start date (from encrypted dose dates)
        if prefs.hrtStartDate == nil,
           let data = defaults.data(forKey: "encryptedDoseDates"),
           let decrypted = try? security.decryptData(data),
           let container = try? JSONDecoder().decode(DoseDatesContainer.self, from: decrypted),
           let startDate = container.hrtStartDate {
            prefs.hrtStartDate = startDate
            needsSave = true
        }

        // mm.* boolean settings
        if defaults.object(forKey: Keys.antiAndrogenInUse) != nil {
            prefs.antiAndrogenInUse = defaults.bool(forKey: Keys.antiAndrogenInUse)
            prefs.spironolactoneInUse = defaults.bool(forKey: Keys.spironolactoneInUse)
            needsSave = true
        }
        if defaults.object(forKey: Keys.missedDoseGracePeriodHours) != nil {
            prefs.missedDoseGracePeriodHours = defaults.double(forKey: Keys.missedDoseGracePeriodHours)
            needsSave = true
        }

        // Therapeutic target
        if let targetData = defaults.data(forKey: Keys.userTherapeuticTarget),
           let target = try? JSONDecoder().decode(TherapeuticTarget.self, from: targetData),
           let json = try? JSONEncoder().encode(target),
           let jsonStr = String(data: json, encoding: .utf8) {
            prefs.userTherapeuticTargetJSON = jsonStr
            needsSave = true
        }

        // Avoid zones
        if let avoidData = defaults.data(forKey: "injectionSiteAvoidZones"),
           let jsonStr = String(data: avoidData, encoding: .utf8) {
            prefs.avoidZonesJSON = jsonStr
            needsSave = true
        }

        // Body type
        if let bodyTypeStr = defaults.string(forKey: "bodyType"), !bodyTypeStr.isEmpty {
            prefs.bodyTypeRaw = bodyTypeStr
            needsSave = true
        }

        // Rotation windows
        let injKey = MedicationManager.rotationWindowDefaultsKey(for: .injection)
        let topKey = MedicationManager.rotationWindowDefaultsKey(for: .topical)
        let patKey = MedicationManager.rotationWindowDefaultsKey(for: .patch)
        if defaults.object(forKey: injKey) != nil {
            let inj = defaults.integer(forKey: injKey)
            let top = defaults.integer(forKey: topKey)
            let pat = defaults.integer(forKey: patKey)
            if inj > 0 { prefs.rotationWindowInjection = inj; needsSave = true }
            if top > 0 { prefs.rotationWindowTopical = top; needsSave = true }
            if pat > 0 { prefs.rotationWindowPatch = pat; needsSave = true }
        }

        if needsSave {
            try? context.save()
        }
        defaults.set(true, forKey: Keys.cloudKitMigrationDone)
    }

    // MARK: - Persistence

    // MARK: - Shared JSON coding

    /// `persistUserPreferences()` fires from the `didSet` of ~15 properties, so
    /// encoders/decoders must not be allocated per call.
    private static let prefsEncoder = JSONEncoder()
    private static let prefsDecoder = JSONDecoder()

    /// Encodes a value to a JSON string, or nil on failure — the pattern that
    /// `persistUserPreferences` and the legacy migration each hand-rolled.
    static func jsonString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? prefsEncoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func jsonValue<T: Decodable>(_ type: T.Type, from json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? prefsDecoder.decode(type, from: data)
    }

    func updateDoseDates(last: Date?, next: Date?) {
        lastDoseDate = last
        nextDoseDate = next
        persistUserPreferences()
    }

    func loadUserPreferences() {
        guard let context = modelContext else { return }
        // The canonical singleton row — consolidates any duplicates a CloudKit
        // import brought in (see UserPreferences.canonical(in:)).
        guard let prefs = UserPreferences.canonical(in: context) else { return }

        isLoadingPreferences = true
        defer { isLoadingPreferences = false }

        selectedMedication = prefs.selectedMedication
        selectedAdministrationMethod = prefs.selectedAdministrationMethod
        selectedEster = prefs.selectedEster
        lastDoseDate = prefs.lastDoseDate
        nextDoseDate = prefs.nextDoseDate
        hrtStartDate = prefs.hrtStartDate

        customFrequencyDays = prefs.customFrequencyDays
        defaultDoseAmount = prefs.defaultDoseAmount
        defaultInjectionTime = prefs.defaultInjectionTime
        showDoseIntensityInsights = prefs.showDoseIntensityInsights

        if let speed = SuppressionSpeed(rawValue: prefs.suppressionSpeed) {
            suppressionSpeed = speed
        }
        spironolactoneClearanceEnabled = prefs.spironolactoneClearanceEnabled
        antiAndrogenInUse = prefs.antiAndrogenInUse
        spironolactoneInUse = prefs.spironolactoneInUse
        if prefs.missedDoseGracePeriodHours > 0 {
            missedDoseGracePeriodHours = prefs.missedDoseGracePeriodHours
        }

        if let json = prefs.userTherapeuticTargetJSON,
           let target = Self.jsonValue(TherapeuticTarget.self, from: json) {
            userTherapeuticTarget = target
        }

        if let json = prefs.avoidZonesJSON,
           let zones = Self.jsonValue([String: AvoidZoneInfo].self, from: json) {
            avoidZones = zones
        }

        rotationWindowInjection = prefs.rotationWindowInjection > 0
            ? prefs.rotationWindowInjection : RouteClass.injection.defaultRotationWindowDays
        rotationWindowTopical = prefs.rotationWindowTopical > 0
            ? prefs.rotationWindowTopical : RouteClass.topical.defaultRotationWindowDays
        rotationWindowPatch = prefs.rotationWindowPatch > 0
            ? prefs.rotationWindowPatch : RouteClass.patch.defaultRotationWindowDays

        bodyTypeRaw = prefs.bodyTypeRaw.isEmpty ? BodyType.neutral.rawValue : prefs.bodyTypeRaw

        cachedDefaultEstrogenConcentration = prefs.defaultEstrogenConcentration
        cachedDefaultTestosteroneConcentration = prefs.defaultTestosteroneConcentration
    }

    func persistUserPreferences() {
        guard modelContext != nil, !isLoadingPreferences else { return }
        guard let context = modelContext, let prefs = UserPreferences.canonical(in: context) else { return }
        prefs.selectedMedication = selectedMedication
        prefs.selectedAdministrationMethod = selectedAdministrationMethod
        prefs.selectedEster = selectedEster
        prefs.lastDoseDate = lastDoseDate
        prefs.nextDoseDate = nextDoseDate
        prefs.hrtStartDate = hrtStartDate
        prefs.customFrequencyDays = customFrequencyDays
        prefs.defaultDoseAmount = defaultDoseAmount
        prefs.defaultInjectionTime = defaultInjectionTime
        prefs.showDoseIntensityInsights = showDoseIntensityInsights
        prefs.suppressionSpeed = suppressionSpeed.rawValue
        prefs.spironolactoneClearanceEnabled = spironolactoneClearanceEnabled
        prefs.antiAndrogenInUse = antiAndrogenInUse
        prefs.spironolactoneInUse = spironolactoneInUse
        prefs.missedDoseGracePeriodHours = missedDoseGracePeriodHours
        prefs.rotationWindowInjection = rotationWindowInjection
        prefs.rotationWindowTopical = rotationWindowTopical
        prefs.rotationWindowPatch = rotationWindowPatch
        prefs.bodyTypeRaw = bodyTypeRaw
        prefs.userTherapeuticTargetJSON = userTherapeuticTarget.flatMap { Self.jsonString($0) }
        if !avoidZones.isEmpty {
            // A failed encode keeps the previously stored zones rather than
            // wiping them — the nil else-branch is deliberate.
            prefs.avoidZonesJSON = Self.jsonString(avoidZones) ?? prefs.avoidZonesJSON
        } else {
            prefs.avoidZonesJSON = nil
        }
        try? context.save()
    }

    func loadDoseHistory() {
        guard let context = modelContext else { return }
        let descriptor = SortDescriptor<DoseRecord>(\DoseRecord.doseDate, order: .forward)
        let fetchDescriptor = FetchDescriptor<DoseRecord>(sortBy: [descriptor])
        let allRecords = try? context.fetch(fetchDescriptor)
        doseHistory = (allRecords ?? []).filter { !$0.isDeleted }
    }

    /// One-time repair for dates persisted under the old method-based due interval.
    ///
    /// Before 2026-08, `nextDoseDate` was computed from `effectiveFrequencyDays`, which
    /// is 7 days for every injectable — so a testosterone-undecanoate user (dosed every
    /// ~10 weeks) carried a "due in 7 days" date. Recompute it from the last dose with
    /// the ester-aware `calculateNextDoseDate` once the history that resolves the ester
    /// is loaded. Skips when the user set a custom frequency: that interval is the
    /// rule, so the stored date is already correct.
    ///
    /// Runs after `loadDoseHistory()` in `reloadFromContext()`, so the due interval can
    /// see the latest taken dose's ester. Idempotent: with the ester tier in effect,
    /// recomputing from the same inputs reproduces the same date, and the non-TU esters
    /// resolve to the same interval the method tier used to produce.
    func repairStoredNextDoseDate() {
        guard customFrequencyDays == nil || customFrequencyDays == 0,
              let last = lastDoseDate else { return }
        let recomputed = calculateNextDoseDate(from: last)
        guard recomputed != nextDoseDate else { return }
        nextDoseDate = recomputed
        persistUserPreferences()
    }

    func saveContext() {
        guard let context = modelContext else { return }
        try? context.save()
    }

    private struct DoseDatesContainer: Codable {
        let lastDoseDate: Date?
        let nextDoseDate: Date?
        let hrtStartDate: Date?
    }
}
