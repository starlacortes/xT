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
        NotificationManager.Keys.doseReminderEnabled,
        NotificationManager.Keys.doseReminderHour,
        NotificationManager.Keys.doseReminderMinute,
        NotificationManager.Keys.journalReminderEnabled,
        NotificationManager.Keys.journalReminderHour,
        NotificationManager.Keys.journalReminderMinute,
        // Transient MedicationManager preferences (persisted via didSet)
        MedicationManager.Keys.antiAndrogenInUse,
        MedicationManager.Keys.spironolactoneInUse,
        MedicationManager.Keys.spironolactoneClearanceEnabled,
        MedicationManager.Keys.suppressionSpeed,
        MedicationManager.Keys.customFrequencyDays,
        MedicationManager.Keys.missedDoseGracePeriodHours,
        MedicationManager.Keys.userTherapeuticTarget,
        // SpoofProfile "applied" marker — absent for a real user, so restore
        // clears it and a later Sample re-enable can re-apply Jan.
        SpoofProfile.spfKey,
        // One-time overlay dismissals
        "hasSeenRecommendedZonesInfo",
    ]

    // MARK: - Snapshot

    /// Captures the user's current state unless a snapshot already exists.
    /// Idempotent by design: enabling Sample twice must never overwrite the
    /// real snapshot with Jan's data (implementation plan §2.3).
    /// Returns true if a snapshot was either created or already existed.
    @discardableResult
    static func snapshotIfNeeded() -> Bool {
        guard !exists else { return true }

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
            return false
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
            return true
        } catch {
            print("[ProfileSnapshot] snapshot write failed: \(error)")
            return false
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
        // `isLoadingPreferences` suppresses the didSet-driven persist: without
        // it, clearing a persisted property would immediately write the nil over
        // the *restored* UserPreferences record (and the spoof persona's
        // therapeutic target used to leak into the user's prefs this way).
        mm.isLoadingPreferences = true
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
        mm.userTherapeuticTarget = nil
        mm.avoidZones = [:]
        mm.customFrequencyDays = nil
        mm.defaultDoseAmount = nil
        mm.defaultInjectionTime = nil
        mm.suppressionSpeed = .fast
        mm.spironolactoneClearanceEnabled = false
        mm.antiAndrogenInUse = false
        mm.spironolactoneInUse = false
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours
        mm.showDoseIntensityInsights = false
        mm.bodyTypeRaw = BodyType.neutral.rawValue
        mm.rotationWindowInjection = RouteClass.injection.defaultRotationWindowDays
        mm.rotationWindowTopical = RouteClass.topical.defaultRotationWindowDays
        mm.rotationWindowPatch = RouteClass.patch.defaultRotationWindowDays
        mm.regimenTransitionHistory = []
        mm.adherenceRate = nil
        mm.onTimeStreak = 0
        mm.doseRecordedCount = 0
        mm.isLoadingPreferences = false

        mm.loadUserPreferences()
        mm.loadDoseHistory()
        mm.loadBloodTestHistory()
        mm.loadScreeningHistory()
        mm.refreshState()
        mm.recomputeCalibrationFactors()

        // --- Journal ---
        JournalManager.shared.loadEntries()

        // --- Notifications ---
        let nm = NotificationManager.shared
        nm.loadFromDefaults()
        Task { await nm.scheduleAllReminders() }
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

    /// A `DoseRecord` reduced to plain values.
    ///
    /// This must cover **every** stored property on `DoseRecord`. Restore deletes the
    /// live records and reinserts these, then consumes the snapshot file — so any field
    /// missing here is destroyed permanently the first time the user toggles the Sample
    /// profile off. It previously carried 12 of the 17, which silently erased every
    /// injection-site record and the whole dose-correction audit trail.
    ///
    /// The two site collections are carried as their raw JSON rather than as decoded
    /// `[InjectionSite]`. `InjectionSite`'s decoder is deliberately lenient — it
    /// substitutes defaults for anything it cannot read — so a decode/re-encode round
    /// trip would quietly rewrite older records into the current schema. Moving the
    /// stored string through untouched cannot lose anything.
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
        var injectionSitesJSON: String?
        var recordedAt: Date?
        /// Optional purely for decoding: a snapshot written before these fields existed
        /// has no key for it, and the synthesized `Codable` initialiser throws on a
        /// missing non-optional — which would make the old snapshot unreadable and strand
        /// the user's real data behind the Sample profile. Absent means `false`.
        var isUserCorrected: Bool?
        var originalDoseId: String?
        var originalSiteJSON: String?

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
            injectionSitesJSON = record.injectionSitesJSON
            recordedAt = record.recordedAt
            isUserCorrected = record.isUserCorrected
            originalDoseId = record.originalDoseId
            originalSiteJSON = record.originalSiteJSON
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
            r.injectionSitesJSON = injectionSitesJSON
            r.recordedAt = recordedAt
            r.isUserCorrected = isUserCorrected ?? false
            r.originalDoseId = originalDoseId
            r.originalSiteJSON = originalSiteJSON
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
        var calibrationFactor: Double?

        init(_ record: BloodTestRecord) {
            id = record.id
            drawDate = record.drawDate
            measuredLevel = record.measuredLevel
            hormoneType = record.hormoneType
            hoursSinceLastDose = record.hoursSinceLastDose
            notes = record.notes
            calibrationFactor = record.calibrationFactor
        }

        var record: BloodTestRecord {
            let r = BloodTestRecord(
                id: id,
                drawDate: drawDate,
                measuredLevel: measuredLevel,
                hormoneType: hormoneType,
                hoursSinceLastDose: hoursSinceLastDose,
                notes: notes
            )
            // `recomputeCalibrationFactors()` would rederive this during rehydration, but
            // carrying it keeps the restored store byte-identical to what was captured.
            r.calibrationFactor = calibrationFactor
            return r
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
        /// The modelled hormone level at the time of writing. Omitting it dropped the
        /// data point every journal-vs-level correlation is drawn from.
        var hormoneLevel: Double?

        init(_ entry: JournalEntry) {
            id = entry.id
            date = entry.date
            mood = entry.mood
            text = entry.text
            symptoms = entry.symptoms
            hormoneLevel = entry.hormoneLevel
        }

        var record: JournalEntry {
            JournalEntry(id: id, date: date, mood: mood, text: text,
                         symptoms: symptoms, hormoneLevel: hormoneLevel)
        }
    }

    /// A `UserPreferences` record reduced to plain values.
    ///
    /// Like `DosePayload`, this must cover **every** stored property on the model:
    /// restore deletes the live record and reinserts this one. It previously
    /// carried 12 of the 26 fields — restoring a snapshot silently destroyed the
    /// user's HRT start date, avoid zones, rotation windows, body type, ester,
    /// and therapeutic target. Every field added after the first snapshot ships
    /// is declared optional so an old snapshot (lacking the key) still decodes;
    /// nil fields fall through to the model's defaults at rebuild.
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
        // Totality pass — everything below was missing from the first snapshot
        // format and is optional purely for old-snapshot decode compatibility.
        var selectedMedication: String?
        var selectedAdministrationMethod: String?
        var selectedEster: String?
        var hrtStartDate: Date?
        var antiAndrogenInUse: Bool?
        var spironolactoneInUse: Bool?
        var missedDoseGracePeriodHours: Double?
        var userTherapeuticTargetJSON: String?
        var rotationWindowInjection: Int?
        var rotationWindowTopical: Int?
        var rotationWindowPatch: Int?
        var avoidZonesJSON: String?
        var bodyTypeRaw: String?
        var profileName: String?
        var profileImageData: Data?
        var profileDateOfBirth: Date?

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
            selectedMedication = prefs.selectedMedication
            selectedAdministrationMethod = prefs.selectedAdministrationMethod
            selectedEster = prefs.selectedEster
            hrtStartDate = prefs.hrtStartDate
            antiAndrogenInUse = prefs.antiAndrogenInUse
            spironolactoneInUse = prefs.spironolactoneInUse
            missedDoseGracePeriodHours = prefs.missedDoseGracePeriodHours
            userTherapeuticTargetJSON = prefs.userTherapeuticTargetJSON
            rotationWindowInjection = prefs.rotationWindowInjection
            rotationWindowTopical = prefs.rotationWindowTopical
            rotationWindowPatch = prefs.rotationWindowPatch
            avoidZonesJSON = prefs.avoidZonesJSON
            bodyTypeRaw = prefs.bodyTypeRaw
            profileName = prefs.profileName
            profileImageData = prefs.profileImageData
            profileDateOfBirth = prefs.profileDateOfBirth
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
            // Apply the totality fields only when present — a nil means either
            // "never set" or "written by an old snapshot", and both should keep
            // the model defaults rather than be overwritten with nil.
            prefs.selectedMedication = selectedMedication
            prefs.selectedAdministrationMethod = selectedAdministrationMethod
            prefs.selectedEster = selectedEster
            prefs.hrtStartDate = hrtStartDate
            if let antiAndrogenInUse { prefs.antiAndrogenInUse = antiAndrogenInUse }
            if let spironolactoneInUse { prefs.spironolactoneInUse = spironolactoneInUse }
            if let missedDoseGracePeriodHours { prefs.missedDoseGracePeriodHours = missedDoseGracePeriodHours }
            prefs.userTherapeuticTargetJSON = userTherapeuticTargetJSON
            if let rotationWindowInjection { prefs.rotationWindowInjection = rotationWindowInjection }
            if let rotationWindowTopical { prefs.rotationWindowTopical = rotationWindowTopical }
            if let rotationWindowPatch { prefs.rotationWindowPatch = rotationWindowPatch }
            prefs.avoidZonesJSON = avoidZonesJSON
            if let bodyTypeRaw { prefs.bodyTypeRaw = bodyTypeRaw }
            prefs.profileName = profileName
            prefs.profileImageData = profileImageData
            prefs.profileDateOfBirth = profileDateOfBirth
            return prefs
        }
    }
}

#endif
