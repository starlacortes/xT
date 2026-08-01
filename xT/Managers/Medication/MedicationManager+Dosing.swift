//
//  MedicationManager+Dosing.swift
//  xT
//
//  Dose recording, editing, validation, concentration, and volume helpers.
//

import Foundation
import SwiftData

extension MedicationManager {

    // MARK: - Dose Helpers

    /// The currently selected ester (derived from the most recent logged dose, or default).
    ///
    /// `doseHistory` is ordered oldest-first, so this resolves the newest dose through
    /// `latestActiveDose()` rather than indexing into the array directly.
    var currentEster: (ester: String, halfLifeDays: Double)? {
        guard let medication = selectedMedication else { return nil }
        let recentEster = latestActiveDose()?.ester

        switch medication {
        case "Estrogen":
            if let raw = recentEster, let ester = MedicationEster(rawValue: raw) {
                return (raw, ester.halfLifeDays)
            }
            // Default for new setups
            let defaultE = MedicationEster.valerate
            return (defaultE.rawValue, defaultE.halfLifeDays)
        case "Testosterone":
            if let raw = recentEster, let ester = TestosteroneEster(rawValue: raw) {
                return (raw, ester.halfLifeDays)
            }
            let defaultT = TestosteroneEster.cypionate
            return (defaultT.rawValue, defaultT.halfLifeDays)
        default:
            return nil
        }
    }

    /// Returns the last logged dose record for the current medication.
    var lastLoggedDose: DoseRecord? { latestActiveDose() }

    // MARK: - Concentration & Volume Helpers

    /// Returns the default vial concentration (mg/mL) for the currently selected medication type.
    ///
    /// Resolution order: the most recently logged dose that recorded a concentration, then
    /// the default the user chose during onboarding, then the most commonly stocked vial
    /// strength for the medication.
    var defaultConcentrationMgPerMl: Double? {
        if let recent = latestDose(matching: {
            $0.isActive && $0.medicationType == selectedMedication && $0.concentrationMgPerMl != nil
        }) {
            return recent.concentrationMgPerMl
        }
        switch selectedMedication {
        case "Estrogen":
            return storedDefaultConcentration(\.defaultEstrogenConcentration) ?? 40.0   // EV 40 mg/mL is most common
        case "Testosterone":
            return storedDefaultConcentration(\.defaultTestosteroneConcentration) ?? 200.0  // TC 200 mg/mL is most common
        default:
            return nil
        }
    }

    /// Reads one of the per-medication default concentrations captured during onboarding.
    ///
    /// These preferences were written by the onboarding flow but never read back, so the
    /// user's choice silently had no effect. Only reached when no logged dose carries a
    /// concentration, so the fetch is off the hot path.
    private func storedDefaultConcentration(
        _ keyPath: KeyPath<UserPreferences, Double?>
    ) -> Double? {
        guard let context = modelContext,
              let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first
        else { return nil }
        return prefs[keyPath: keyPath]
    }

    /// Common vial concentrations (mg/mL) for a given ester string.
    /// Returns an array of typical concentrations, plus a sentinel for "Custom".
    static func commonConcentrations(forEster ester: String) -> [Double] {
        switch ester {
        // Estradiol esters
        case "Valerate (EV)":   return [10, 20, 40, -1]
        case "Cypionate (EC)":  return [5, 10, -1]
        // Testosterone esters
        case "Cypionate (TC)":  return [100, 200, -1]
        case "Enanthate (TE)":  return [200, 250, -1]
        case "Propionate (TP)": return [100, -1]
        case "Undecanoate (TU)": return [250, -1]
        default:                return [40, -1]
        }
    }

    /// Computes injection volume in mL from a dose amount and concentration.
    static func computedVolume(doseMg: Double, concentrationMgPerMl: Double) -> Double {
        guard concentrationMgPerMl > 0 else { return 0 }
        return doseMg / concentrationMgPerMl
    }

    /// True if the computed injection volume is below the practical measurement threshold.
    /// Volumes below `PKConstants.minMeasurableVolumeMl` are extremely difficult to measure
    /// accurately even with the smallest insulin syringe.
    static func isVolumeTooSmall(_ volumeMl: Double) -> Bool {
        return volumeMl < PKConstants.minMeasurableVolumeMl
    }

    /// True if the volume is large enough to cause injection discomfort for frequent dosing.
    /// For long-acting esters (TU), larger depots are normal; for short/medium-acting esters
    /// anything past the high-volume warning threshold is impractical.
    static func isVolumeTooLarge(_ volumeMl: Double, isLongActing: Bool = false) -> Bool {
        let threshold = isLongActing ? PKConstants.maxVolumePerSiteMl : PKConstants.highVolumeWarningMl
        return volumeMl > threshold
    }

    /// Recommends the smallest stocked syringe barrel that can hold the given volume.
    /// Volumes past the largest stocked size fall through to a 5 mL barrel.
    static func recommendedSyringe(for volumeMl: Double) -> String {
        guard let barrelMl = PKConstants.syringeSizesMl.first(where: { volumeMl <= $0 }) else {
            return "5 mL syringe"
        }
        // Sub-millilitre barrels are insulin syringes, which carry unit markings.
        let isInsulin = barrelMl < 1.0
        let size = String(format: isInsulin ? "%.1f" : "%.0f", barrelMl)
        return "\(size) mL \(isInsulin ? "insulin syringe" : "syringe")"
    }

    /// Generates a warning message (or nil) for a given volume.
    static func volumeWarning(for volumeMl: Double, ester: String? = nil) -> String? {
        let isLong = ester == "Undecanoate (TU)"
        if isVolumeTooSmall(volumeMl) {
            let syringe = recommendedSyringe(for: volumeMl)
            return "A volume of \(String(format: "%.3f", volumeMl)) mL can be difficult to measure accurately. Consider a lower-concentration formulation or a \(syringe) with unit markings."
        }
        if isVolumeTooLarge(volumeMl, isLongActing: isLong) {
            return "A volume of \(String(format: "%.1f", volumeMl)) mL is quite large — consider splitting the dose or using multiple injection sites."
        }
        return nil
    }

    // MARK: - Public API (Management)

    func updateSelection(type: MedicationType, method: AdministrationMethod) {
        selectedMedication = type.rawValue
        selectedAdministrationMethod = method.rawValue
        persistSelection()

        let next = calculateNextDoseDate(from: Date())
        updateDoseDates(last: Date(), next: next)
        refreshState()
    }

    func clearSelection() {
        selectedMedication = nil
        selectedAdministrationMethod = nil
        lastDoseDate = nil
        nextDoseDate = nil
        persistSelection()
        persistDoseDates()
        refreshState()
    }

    /// Records a full dose with amount, ester, method, concentration, optional notes,
    /// and optional injection site tracking data.
    /// This is the primary method for logging doses going forward.
    func addDose(
        date: Date = Date(),
        type: String,
        ester: String,
        method: String,
        doseAmount: Double,
        concentrationMgPerMl: Double? = nil,
        notes: String? = nil,
        injectionSites: [InjectionSite] = [],
        isUserCorrected: Bool = false,
        originalDoseId: String? = nil,
        originalSites: [InjectionSite] = []
    ) {
        let record = DoseRecord(
            doseDate: date,
            medicationType: type,
            ester: ester,
            administrationMethod: method,
            doseAmount: doseAmount,
            concentrationMgPerMl: concentrationMgPerMl,
            notes: notes,
            injectionSites: injectionSites,
            recordedAt: Date(),
            isUserCorrected: isUserCorrected,
            originalDoseId: originalDoseId,
            originalSites: originalSites
        )

        // Don't add duplicates
        guard !doseHistory.contains(where: { $0.id == record.id }) else { return }
        doseHistory.append(record)

        // Insert into SwiftData
        modelContext?.insert(record)

        // Update simple date tracking for backward compat
        if type == selectedMedication, method == selectedAdministrationMethod {
            lastDoseDate = date
            nextDoseDate = calculateNextDoseDate(from: date)
        }

        try? modelContext?.save()
        persistDoseDates()

        // Bump celebration counter BEFORE refreshState so HomeView.onChange
        // triggers a UI-driven refresh while the doseHistory is already updated
        doseRecordedCount += 1

        refreshState()
        invalidateHeatMapCache()

        // Reschedule dose reminder to next dose date (frequency-aware)
        if let next = nextDoseDate {
            NotificationManager.shared.rescheduleAfterDose(nextDoseDate: next)
        }
    }

    /// Removes a dose (soft delete — keeps it in history for audit purposes).
    func removeDose(withId id: String) {
        if let index = doseHistory.firstIndex(where: { $0.id == id }) {
            doseHistory[index].isDeleted = true
            try? modelContext?.save()
            var updated = doseHistory
            updated.remove(at: index)
            doseHistory = updated
            refreshState()
        }
    }

    func recordDose(on date: Date = Date()) {
        lastDoseDate = date
        if selectedMedication != nil, selectedAdministrationMethod != nil {
            nextDoseDate = calculateNextDoseDate(from: date)
        }
        persistDoseDates()
        refreshState()

        // Reschedule dose reminder to next dose date (frequency-aware)
        if let next = nextDoseDate {
            NotificationManager.shared.rescheduleAfterDose(nextDoseDate: next)
        }
    }

    /// Logs an intentionally skipped dose. Does NOT advance `nextDoseDate`;
    /// the schedule stays anchored to the last *taken* dose. The skipped
    /// record is persisted so it shows in timelines and affects adherence rate.
    func skipDose(on date: Date = Date(), reason: String? = nil) {
        guard let medType = selectedMedication,
              let medMethod = selectedAdministrationMethod else { return }

        let ester = lastLoggedDose?.ester
            ?? (medType == "Estrogen" ? "Valerate (EV)" : "Cypionate (TC)")
        let amount = lastLoggedDose?.doseAmount
            ?? (medType == "Estrogen" ? 2.0 : 40.0)
        let concentration = lastLoggedDose?.concentrationMgPerMl

        let record = DoseRecord(
            doseDate: date,
            medicationType: medType,
            ester: ester,
            administrationMethod: medMethod,
            doseAmount: amount,
            concentrationMgPerMl: concentration,
            doseStatus: .skipped,
            skipReason: reason
        )

        guard !doseHistory.contains(where: { $0.id == record.id }) else { return }
        doseHistory.append(record)
        modelContext?.insert(record)

        // Do NOT advance lastDoseDate or nextDoseDate for skipped doses
        try? modelContext?.save()
        refreshState()
    }

    /// Calculates the next dose date from `effectiveFrequencyDays` — the user's custom
    /// frequency when set (#18), otherwise the administration method's default.
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: effectiveFrequencyDays, to: lastDose) ?? Date()
    }

}
