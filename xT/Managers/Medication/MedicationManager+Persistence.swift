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

        let descriptor = FetchDescriptor<UserPreferences>()
        guard let prefs = (try? context.fetch(descriptor))?.first else { return }

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
        let descriptor = FetchDescriptor<UserPreferences>()

        let prefs: UserPreferences
        if let existing = (try? context.fetch(descriptor))?.first {
            prefs = existing
        } else {
            // First launch: create the singleton preferences record.
            let newPrefs = UserPreferences()
            context.insert(newPrefs)
            try? context.save()
            prefs = newPrefs
        }

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
        guard let context = modelContext, !isLoadingPreferences else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.selectedMedication = selectedMedication
            existing.selectedAdministrationMethod = selectedAdministrationMethod
            existing.selectedEster = selectedEster
            existing.lastDoseDate = lastDoseDate
            existing.nextDoseDate = nextDoseDate
            existing.hrtStartDate = hrtStartDate
            existing.customFrequencyDays = customFrequencyDays
            existing.defaultDoseAmount = defaultDoseAmount
            existing.defaultInjectionTime = defaultInjectionTime
            existing.showDoseIntensityInsights = showDoseIntensityInsights
            existing.suppressionSpeed = suppressionSpeed.rawValue
            existing.spironolactoneClearanceEnabled = spironolactoneClearanceEnabled
            existing.antiAndrogenInUse = antiAndrogenInUse
            existing.spironolactoneInUse = spironolactoneInUse
            existing.missedDoseGracePeriodHours = missedDoseGracePeriodHours
            existing.rotationWindowInjection = rotationWindowInjection
            existing.rotationWindowTopical = rotationWindowTopical
            existing.rotationWindowPatch = rotationWindowPatch
            existing.bodyTypeRaw = bodyTypeRaw
            existing.userTherapeuticTargetJSON = userTherapeuticTarget.flatMap { Self.jsonString($0) }
            if !avoidZones.isEmpty {
                // A failed encode keeps the previously stored zones rather than
                // wiping them — the nil else-branch is deliberate.
                existing.avoidZonesJSON = Self.jsonString(avoidZones) ?? existing.avoidZonesJSON
            } else {
                existing.avoidZonesJSON = nil
            }
        } else {
            let targetJSON = userTherapeuticTarget.flatMap { Self.jsonString($0) }
            let zonesJSON = avoidZones.isEmpty ? nil : Self.jsonString(avoidZones)
            let prefs = UserPreferences(
                selectedMedication: selectedMedication,
                selectedAdministrationMethod: selectedAdministrationMethod,
                selectedEster: selectedEster,
                lastDoseDate: lastDoseDate,
                nextDoseDate: nextDoseDate,
                hrtStartDate: hrtStartDate,
                suppressionSpeed: suppressionSpeed,
                spironolactoneClearanceEnabled: spironolactoneClearanceEnabled,
                antiAndrogenInUse: antiAndrogenInUse,
                spironolactoneInUse: spironolactoneInUse,
                customFrequencyDays: customFrequencyDays,
                missedDoseGracePeriodHours: missedDoseGracePeriodHours,
                defaultDoseAmount: defaultDoseAmount,
                defaultInjectionTime: defaultInjectionTime,
                showDoseIntensityInsights: showDoseIntensityInsights,
                userTherapeuticTargetJSON: targetJSON,
                rotationWindowInjection: rotationWindowInjection,
                rotationWindowTopical: rotationWindowTopical,
                rotationWindowPatch: rotationWindowPatch,
                avoidZonesJSON: zonesJSON,
                bodyTypeRaw: bodyTypeRaw
            )
            context.insert(prefs)
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
