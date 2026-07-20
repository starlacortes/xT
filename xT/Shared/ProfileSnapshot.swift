//
//  ProfileSnapshot.swift
//  xT
//
//  DEBUG-only snapshot/restore of the user's real data so that enabling the
//  Sample (Jan) developer profile never destroys it. Snapshot captures the
//  relevant UserDefaults keys plus all SwiftData records into a JSON file in
//  the developer support directory; restore wipes the live (Jan) dataset,
//  writes the user's data back, and rehydrates every manager in place.
//
//  The snapshot is a "symbolic swap" of the active dataset — the main
//  CloudKit-backed store is never duplicated, only its records are copied
//  out and back in.
//

#if DEBUG

import Foundation
import SwiftData

@MainActor
enum ProfileSnapshot {

    // MARK: - Location

    private static var snapshotURL: URL {
        DeveloperSettings.developerSupportDirectory.appendingPathComponent("user-snapshot.json")
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: snapshotURL.path)
    }

    // MARK: - Captured UserDefaults keys

    /// Every UserDefaults key that belongs to the *user's* dataset (all of
    /// them are also touched by `SpoofProfile`). Snapshot stores the present
    /// values; restore writes them back and removes any key that was absent
    /// at snapshot time.
    private static let defaultsKeys: [String] = [
        // Onboarding
        "hasCompletedOnboarding",
        // Medication selection (encrypted + legacy fallbacks)
        "encryptedMedicationSelection", "selectedMedication", "selectedAdministrationMethod",
        // Dose dates (encrypted + legacy fallbacks)
        "encryptedDoseDates", "lastDoseDate", "nextDoseDate",
        // Profile (encrypted + legacy fallbacks)
        "encryptedProfileName", "profileName",
        "encryptedProfileImageData", "profileImageData",
        "profileDateOfBirth",
        // Reminders
        "doseReminderEnabled", "doseReminderHour", "doseReminderMinute",
        "journalReminderEnabled", "journalReminderHour", "journalReminderMinute",
        // Transient MedicationManager preferences (persisted via didSet)
        "mm.antiAndrogenInUse",
        "mm.spironolactoneInUse",
        "mm.spironolactoneClearanceEnabled",
        "mm.suppressionSpeed",
        "mm.customFrequencyDays",
        "mm.missedDoseGracePeriodHours",
        "mm.userTherapeuticTarget",
        // SpoofProfile "applied" marker — absent for a real user, so restore
        // clears it and a later Sample re-enable can re-apply Jan.
        "com.xt.spoofProfile_jan_v1",
    ]

    // MARK: - Snapshot

    /// Captures the user's current state unless a snapshot already exists.
    /// Idempotent by design: enabling Sample twice must never overwrite the
    /// real snapshot with Jan's data (implementation plan §2.3).
    static func snapshotIfNeeded() {
        guard !exists else { return }

        // UserDefaults — captured as a binary plist so heterogeneous value
        // types (Data/String/Bool/Int/Date) round-trip losslessly.
        let defaults = UserDefaults.standard
        var captured: [String: Any] = [:]
        for key in defaultsKeys {
            if let value = defaults.object(forKey: key) { captured[key] = value }
        }
        guard let defaultsPlist = try? PropertyListSerialization.data(
            fromPropertyList: captured, format: .binary, options: 0
        ) else {
            print("[ProfileSnapshot] failed to serialize UserDefaults — aborting snapshot")
            return
        }

        // SwiftData records → Codable payloads.
        var doses: [DosePayload] = []
        var bloodTests: [BloodTestPayload] = []
        var screenings: [ScreeningPayload] = []
        var preferences: [PreferencesPayload] = []
        if let ctx = MedicationManager.shared.modelContext {
            doses = ((try? ctx.fetch(FetchDescriptor<DoseRecord>())) ?? []).map(DosePayload.init)
            bloodTests = ((try? ctx.fetch(FetchDescriptor<BloodTestRecord>())) ?? []).map(BloodTestPayload.init)
            screenings = ((try? ctx.fetch(FetchDescriptor<ScreeningRecord>())) ?? []).map(ScreeningPayload.init)
            preferences = ((try? ctx.fetch(FetchDescriptor<UserPreferences>())) ?? []).map(PreferencesPayload.init)
        }
        var journalEntries: [JournalPayload] = []
        if let ctx = JournalManager.shared.modelContext {
            journalEntries = ((try? ctx.fetch(FetchDescriptor<JournalEntry>())) ?? []).map(JournalPayload.init)
        }

        let payload = SnapshotPayload(
            capturedAt: Date(),
            defaultsPlist: defaultsPlist,
            doses: doses,
            bloodTests: bloodTests,
            screenings: screenings,
            journalEntries: journalEntries,
            preferences: preferences
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try FileManager.default.createDirectory(
                at: DeveloperSettings.developerSupportDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: snapshotURL, options: .atomic)
            print("[ProfileSnapshot] captured user data (\(doses.count) doses, \(bloodTests.count) blood tests, \(journalEntries.count) journal entries)")
        } catch {
            print("[ProfileSnapshot] snapshot write failed: \(error)")
        }
    }

    // MARK: - Restore

    /// Restores the user's snapshot over the live dataset (wiping Jan's data),
    /// rehydrates every manager in place, and consumes the snapshot file.
    /// No-op when no snapshot exists (the user had no data to preserve).
    static func restore() {
        guard exists else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: snapshotURL),
              let payload = try? decoder.decode(SnapshotPayload.self, from: data) else {
            print("[ProfileSnapshot] snapshot unreadable — leaving current data untouched")
            return
        }

        // 1. UserDefaults: write captured values back; remove keys that were
        //    absent at snapshot time (e.g. Jan's spoof marker).
        let defaults = UserDefaults.standard
        let captured = (try? PropertyListSerialization.propertyList(
            from: payload.defaultsPlist, options: [], format: nil
        )) as? [String: Any] ?? [:]
        for key in defaultsKeys {
            if let value = captured[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        // 2. SwiftData: wipe the live (Jan) records, reinsert the user's.
        if let ctx = MedicationManager.shared.modelContext {
            do {
                for record in try ctx.fetch(FetchDescriptor<DoseRecord>()) { ctx.delete(record) }
                for record in try ctx.fetch(FetchDescriptor<BloodTestRecord>()) { ctx.delete(record) }
                for record in try ctx.fetch(FetchDescriptor<ScreeningRecord>()) { ctx.delete(record) }
                for record in try ctx.fetch(FetchDescriptor<JournalEntry>()) { ctx.delete(record) }
                for record in try ctx.fetch(FetchDescriptor<UserPreferences>()) { ctx.delete(record) }
                payload.doses.forEach { ctx.insert($0.record) }
                payload.bloodTests.forEach { ctx.insert($0.record) }
                payload.screenings.forEach { ctx.insert($0.record) }
                payload.journalEntries.forEach { ctx.insert($0.record) }
                payload.preferences.forEach { ctx.insert($0.record) }
                try ctx.save()
            } catch {
                print("[ProfileSnapshot] SwiftData restore error: \(error)")
            }
        }

        // 3. Rehydrate managers from the restored stores.
        rehydrateManagers()

        // 4. Consume the snapshot — the next Sample enable re-captures fresh state.
        try? FileManager.default.removeItem(at: snapshotURL)
        print("[ProfileSnapshot] user data restored")
    }

    /// Resets in-memory manager state to cold-launch defaults, then re-runs the
    /// same load path `MedicationManager.init` / `ProfileManager.init` use, so
    /// the live app reflects the restored stores without a relaunch.
    private static func rehydrateManagers() {
        let defaults = UserDefaults.standard

        // --- Profile ---
        let pm = ProfileManager.shared
        pm.profileName = ""
        pm.profileImage = nil
        pm.profileImageData = nil
        pm.dateOfBirth = nil
        pm.loadProfile()

        // --- Medication ---
        let mm = MedicationManager.shared
        // Reset all state to cold-launch condition to clear Jan's in-memory data.
        mm.selectedMedication = nil
        mm.selectedAdministrationMethod = nil
        mm.selectedEster = nil
        mm.lastDoseDate = nil
        mm.nextDoseDate = nil
        mm.hrtStartDate = nil
        mm.currentHormoneLevel = nil
        mm.recentLevels = []
        mm.doseHistory = []
        mm.bloodTestHistory = []
        mm.screeningRecords = []
        mm.predictedTroughDrop = nil
        // Transient properties: reset then reload from UserDefaults (step 1 of
        // restore() already wrote the user's snapshotted values back).
        mm.loadTransientPreferences()

        mm.loadSelection()
        mm.loadDoseDates()
        mm.loadDoseHistory()
        mm.loadBloodTestHistory()
        mm.loadScreeningHistory()
        mm.refreshState()
        mm.recomputeCalibrationFactors()

        // --- Journal ---
        JournalManager.shared.currentSymptoms = []
        JournalManager.shared.loadEntries()

        // --- Notifications ---
        let nm = NotificationManager.shared
        nm.doseReminderEnabled = defaults.bool(forKey: "doseReminderEnabled")
        nm.doseReminderHour = defaults.integer(forKey: "doseReminderHour")
        nm.doseReminderMinute = defaults.integer(forKey: "doseReminderMinute")
        nm.journalReminderEnabled = defaults.bool(forKey: "journalReminderEnabled")
        nm.journalReminderHour = defaults.integer(forKey: "journalReminderHour")
        nm.journalReminderMinute = defaults.integer(forKey: "journalReminderMinute")
        nm.scheduleAllReminders()
    }

    // MARK: - Payload types

    private struct SnapshotPayload: Codable {
        var capturedAt: Date
        var defaultsPlist: Data
        var doses: [DosePayload]
        var bloodTests: [BloodTestPayload]
        var screenings: [ScreeningPayload]
        var journalEntries: [JournalPayload]
        var preferences: [PreferencesPayload]
    }

    private struct DosePayload: Codable {
        var id: String
        var doseDate: Date
        var medicationType: String
        var ester: String
        var administrationMethod: String
        var doseAmount: Double
        var concentrationMgPerMl: Double?
        var notes: String?
        var isDeleted: Bool
        var doseStatus: String
        var skipReason: String?
        var injectionTime: Date?

        init(_ record: DoseRecord) {
            id = record.id
            doseDate = record.doseDate
            medicationType = record.medicationType
            ester = record.ester
            administrationMethod = record.administrationMethod
            doseAmount = record.doseAmount
            concentrationMgPerMl = record.concentrationMgPerMl
            notes = record.notes
            isDeleted = record.isDeleted
            doseStatus = record.doseStatus
            skipReason = record.skipReason
            injectionTime = record.injectionTime
        }

        var record: DoseRecord {
            let r = DoseRecord(
                id: id,
                doseDate: doseDate,
                medicationType: medicationType,
                ester: ester,
                administrationMethod: administrationMethod,
                doseAmount: doseAmount,
                concentrationMgPerMl: concentrationMgPerMl,
                notes: notes,
                doseStatus: DoseStatus(rawValue: doseStatus) ?? .taken,
                skipReason: skipReason,
                injectionTime: injectionTime
            )
            r.isDeleted = isDeleted
            return r
        }
    }

    private struct BloodTestPayload: Codable {
        var id: String
        var drawDate: Date
        var measuredLevel: Double
        var hormoneType: String
        var hoursSinceLastDose: Double?
        var notes: String?

        init(_ record: BloodTestRecord) {
            id = record.id
            drawDate = record.drawDate
            measuredLevel = record.measuredLevel
            hormoneType = record.hormoneType
            hoursSinceLastDose = record.hoursSinceLastDose
            notes = record.notes
        }

        var record: BloodTestRecord {
            BloodTestRecord(
                id: id,
                drawDate: drawDate,
                measuredLevel: measuredLevel,
                hormoneType: hormoneType,
                hoursSinceLastDose: hoursSinceLastDose,
                notes: notes
            )
        }
    }

    private struct ScreeningPayload: Codable {
        var id: String
        var date: Date
        var typeRawValue: String
        var notes: String?

        init(_ record: ScreeningRecord) {
            id = record.id
            date = record.date
            typeRawValue = record.typeRawValue
            notes = record.notes
        }

        var record: ScreeningRecord {
            ScreeningRecord(
                id: id,
                date: date,
                type: ScreeningType(rawValue: typeRawValue) ?? .other,
                notes: notes
            )
        }
    }

    private struct JournalPayload: Codable {
        var id: UUID
        var date: Date
        var mood: Mood
        var text: String
        var symptoms: [Symptom]

        init(_ entry: JournalEntry) {
            id = entry.id
            date = entry.date
            mood = entry.mood
            text = entry.text
            symptoms = Array(entry.symptoms)
        }

        var record: JournalEntry {
            JournalEntry(id: id, date: date, mood: mood, text: text, symptoms: Set(symptoms))
        }
    }

    private struct PreferencesPayload: Codable {
        var medicationRow: Int
        var medicationColumn: Int
        var lastDoseDate: Date?
        var nextDoseDate: Date?
        var defaultEstrogenConcentration: Double?
        var defaultTestosteroneConcentration: Double?
        var suppressionSpeed: String
        var spironolactoneClearanceEnabled: Bool
        var customFrequencyDays: Int?
        var defaultDoseAmount: Double?
        var defaultInjectionTime: Date?
        var showDoseIntensityInsights: Bool

        init(_ prefs: UserPreferences) {
            medicationRow = prefs.medicationRow
            medicationColumn = prefs.medicationColumn
            lastDoseDate = prefs.lastDoseDate
            nextDoseDate = prefs.nextDoseDate
            defaultEstrogenConcentration = prefs.defaultEstrogenConcentration
            defaultTestosteroneConcentration = prefs.defaultTestosteroneConcentration
            suppressionSpeed = prefs.suppressionSpeed
            spironolactoneClearanceEnabled = prefs.spironolactoneClearanceEnabled
            customFrequencyDays = prefs.customFrequencyDays
            defaultDoseAmount = prefs.defaultDoseAmount
            defaultInjectionTime = prefs.defaultInjectionTime
            showDoseIntensityInsights = prefs.showDoseIntensityInsights
        }

        var record: UserPreferences {
            let prefs = UserPreferences(
                medicationRow: medicationRow,
                medicationColumn: medicationColumn,
                lastDoseDate: lastDoseDate,
                nextDoseDate: nextDoseDate,
                defaultEstrogenConcentration: defaultEstrogenConcentration,
                defaultTestosteroneConcentration: defaultTestosteroneConcentration,
                suppressionSpeed: SuppressionSpeed(rawValue: suppressionSpeed) ?? .fast,
                spironolactoneClearanceEnabled: spironolactoneClearanceEnabled,
                customFrequencyDays: customFrequencyDays,
                defaultDoseAmount: defaultDoseAmount,
                defaultInjectionTime: defaultInjectionTime,
                showDoseIntensityInsights: showDoseIntensityInsights
            )
            return prefs
        }
    }
}

#endif
