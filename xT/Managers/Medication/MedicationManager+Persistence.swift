//
//  MedicationManager+Persistence.swift
//  xT
//
//  Migration, persistence, and storage extensions.
//

import Foundation
import SwiftData

extension MedicationManager {

    // MARK: - Migration (Legacy Records)

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

    // MARK: - Persistence (Private)

    func updateDoseDates(last: Date?, next: Date?) {
        lastDoseDate = last
        nextDoseDate = next
        persistDoseDates()
    }

    /// Loads transient preferences from UserDefaults that are persisted via didSet.
    /// Called during init() and rehydrateManagers() to restore snapshotted state.
    func loadTransientPreferences() {
        let defaults = UserDefaults.standard
        antiAndrogenInUse = defaults.bool(forKey: Keys.antiAndrogenInUse)
        spironolactoneInUse = defaults.bool(forKey: Keys.spironolactoneInUse)
        spironolactoneClearanceEnabled = defaults.bool(forKey: Keys.spironolactoneClearanceEnabled)
        if let raw = defaults.string(forKey: Keys.suppressionSpeed) {
            suppressionSpeed = SuppressionSpeed(rawValue: raw) ?? .fast
        }
        if defaults.object(forKey: Keys.customFrequencyDays) != nil {
            customFrequencyDays = defaults.integer(forKey: Keys.customFrequencyDays)
        }
        if defaults.object(forKey: Keys.missedDoseGracePeriodHours) != nil {
            missedDoseGracePeriodHours = defaults.double(forKey: Keys.missedDoseGracePeriodHours)
        }
        if let data = defaults.data(forKey: Keys.userTherapeuticTarget),
           let target = try? JSONDecoder().decode(TherapeuticTarget.self, from: data) {
            userTherapeuticTarget = target
        }
        loadAvoidZones()
    }

    func loadSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedMedicationSelection"),
           let decrypted = try? security.decryptData(data),
           let str = String(data: decrypted, encoding: .utf8) {
            let parts = str.components(separatedBy: "|")
            if parts.count >= 2 {
                selectedMedication = parts[0].isEmpty ? nil : parts[0]
                selectedAdministrationMethod = parts[1].isEmpty ? nil : parts[1]
                selectedEster = parts.count >= 3 ? (parts[2].isEmpty ? nil : parts[2]) : nil
            }
        } else {
            selectedMedication = defaults.string(forKey: "selectedMedication")
            selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
        }
        loadUserPreferences()
    }

    func persistSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let str = "\(selectedMedication ?? "")|\(selectedAdministrationMethod ?? "")|\(selectedEster ?? "")"
        if let data = str.data(using: .utf8), let encrypted = try? security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedMedicationSelection")
        }
    }

    func loadUserPreferences() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        let prefs = try? context.fetch(descriptor).first
        customFrequencyDays = prefs?.customFrequencyDays
        defaultDoseAmount = prefs?.defaultDoseAmount
        defaultInjectionTime = prefs?.defaultInjectionTime
        showDoseIntensityInsights = prefs?.showDoseIntensityInsights ?? false
    }

    func persistUserPreferences() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            existing.customFrequencyDays = customFrequencyDays
            existing.defaultDoseAmount = defaultDoseAmount
            existing.defaultInjectionTime = defaultInjectionTime
            existing.showDoseIntensityInsights = showDoseIntensityInsights
        } else {
            let prefs = UserPreferences(
                customFrequencyDays: customFrequencyDays,
                defaultDoseAmount: defaultDoseAmount,
                defaultInjectionTime: defaultInjectionTime,
                showDoseIntensityInsights: showDoseIntensityInsights
            )
            context.insert(prefs)
        }
        try? context.save()
    }

    func loadDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedDoseDates"),
           let decrypted = try? security.decryptData(data),
           let container = try? JSONDecoder().decode(DoseDatesContainer.self, from: decrypted) {
            lastDoseDate = container.lastDoseDate
            nextDoseDate = container.nextDoseDate
            hrtStartDate = container.hrtStartDate
        }
    }

    func persistDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let container = DoseDatesContainer(lastDoseDate: lastDoseDate, nextDoseDate: nextDoseDate, hrtStartDate: hrtStartDate)
        if let data = try? JSONEncoder().encode(container), let encrypted = try? security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedDoseDates")
        }
    }

    /// Loads dose history from SwiftData.
    func loadDoseHistory() {
        guard let context = modelContext else { return }
        let descriptor = SortDescriptor<DoseRecord>(\DoseRecord.doseDate, order: .forward)
        let fetchDescriptor = FetchDescriptor<DoseRecord>(sortBy: [descriptor])
        let allRecords = try? context.fetch(fetchDescriptor)
        doseHistory = (allRecords ?? []).filter { !$0.isDeleted }
    }

    /// Persists the managed context to SwiftData (all pending insertions/deletions).
    func saveContext() {
        guard let context = modelContext else { return }
        try? context.save()
    }

    func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "encryptedMedicationSelection") == nil { persistSelection() }
        if defaults.object(forKey: "encryptedDoseDates") == nil { persistDoseDates() }
    }

    private struct DoseDatesContainer: Codable {
        let lastDoseDate: Date?
        let nextDoseDate: Date?
        let hrtStartDate: Date?
    }
}