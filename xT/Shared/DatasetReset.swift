//
//  DatasetReset.swift
//  xT
//
//  The one place "reset all manager state" is implemented. This logic used to
//  be hand-written three times — `SpoofProfile.resetAllManagers`,
//  `ProfileSnapshot.rehydrateManagers`, and `SettingsView.resetAppData` — and
//  the copies had already drifted: each forgot different properties (avoid
//  zones, rotation windows, dose counters), so which state survived a reset
//  depended on which button triggered it.
//
//  The shared entry point clears the superset. Callers layer their own
//  SwiftData/UserDefaults wipe and repopulation on top.
//

import Foundation
import SwiftData

@MainActor
enum DatasetReset {

    /// Resets every in-memory manager property to its cold-launch default,
    /// with didSet-driven persistence suppressed for the duration.
    ///
    /// The suppression is load-bearing: without it, clearing a persisted
    /// property writes the default straight back into the live
    /// `UserPreferences` record — which, on the snapshot-restore path, *is*
    /// the record being restored, so the reset would corrupt the data it
    /// exists to protect.
    static func resetManagerState() {
        let mm = MedicationManager.shared
        let pm = ProfileManager.shared

        mm.isLoadingPreferences = true
        defer { mm.isLoadingPreferences = false }

        // --- Profile ---
        pm.profileName = ""
        pm.profileImage = nil
        pm.profileImageData = nil
        pm.dateOfBirth = nil

        // --- Medication selection & dates ---
        mm.selectedMedication = nil
        mm.selectedAdministrationMethod = nil
        mm.selectedEster = nil
        mm.lastDoseDate = nil
        mm.nextDoseDate = nil
        mm.hrtStartDate = nil

        // --- Live PK state & history ---
        mm.currentHormoneLevel = nil
        mm.recentLevels = []
        mm.doseHistory = []
        mm.bloodTestHistory = []
        mm.screeningRecords = []

        // --- Synced preferences ---
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

        // --- Derived regimens & counters ---
        mm.regimenTransitionHistory = []
        mm.adherenceRate = nil
        mm.onTimeStreak = 0
        mm.doseRecordedCount = 0
        mm.invalidateHeatMapCache()

        // --- Journal ---
        JournalManager.shared.entries = []
    }

    /// Deletes every record of the app's four shared-zone entity types plus
    /// the preferences record. Shared by spoof-reseed, snapshot restore, and
    /// full app reset, which each hand-wrote the same fetch/delete/save loop.
    static func wipeSwiftData(in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<DoseRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<BloodTestRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<ScreeningRecord>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<JournalEntry>()) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<UserPreferences>()) { context.delete(record) }
        try context.save()
    }
}
