//
//  MedicationManager+Dosing.swift
//  xT
//
//  Dose recording, editing, validation, concentration, and volume helpers.
//

import Foundation

extension MedicationManager {





    // MARK: - Dose Helpers

    /// The currently selected ester (derived from the most recent logged dose, or default).
    var currentEster: (ester: String, halfLifeDays: Double)? {
        if let medication = selectedMedication, medication == "Estrogen" {
            if let recent = doseHistory
                .first(where: { $0.isActive && $0.medicationType == medication })
            {
                if let e = MedicationEster(rawValue: recent.ester) {
                    return (recent.ester, e.halfLifeDays)
                }
            }
            // Default for new setups
            let defaultE = MedicationEster.valerate
            return (defaultE.rawValue, defaultE.halfLifeDays)
        } else if let medication = selectedMedication, medication == "Testosterone" {
            if let recent = doseHistory
                .first(where: { $0.isActive && $0.medicationType == medication })
            {
                if let e = TestosteroneEster(rawValue: recent.ester) {
                    return (recent.ester, e.halfLifeDays)
                }
            }
            let defaultE = TestosteroneEster.cypionate
            return (defaultE.rawValue, defaultE.halfLifeDays)
        }
        return nil
    }

    /// Returns the effective dose factor (EWF × bioavailability) for the currently configured ester.
    var currentPotencyFactor: Double {
        guard let medication = selectedMedication else { return 1.0 }
        if medication == "Estrogen", let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == medication })
        {
            return MedicationEster(rawValue: recent.ester)?.effectiveDoseFactor ?? 1.0
        } else if medication == "Testosterone", let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == medication })
        {
            return TestosteroneEster(rawValue: recent.ester)?.effectiveDoseFactor ?? 1.0
        }
        return 1.0
    }

    /// Returns the actual dose amount for the most recent logged dose.
    /// Falls back to default if no dose is logged.
    var actualDoseAmount: Double {
        guard let lastDose = doseHistory.last(where: { $0.isActive && $0.medicationType == selectedMedication })
        else { return (MedicationType(rawValue: selectedMedication ?? "")?.baselineValue ?? 100.0) * 0.5 }
        return lastDose.doseAmount
    }

    /// Returns the last logged dose record for the current medication.
    var lastLoggedDose: DoseRecord? {
        doseHistory.first(where: { $0.isActive && $0.medicationType == selectedMedication })
    }

    // MARK: - Concentration & Volume Helpers

    /// Returns the default vial concentration (mg/mL) for the currently selected medication type.
    /// Reads from the most recent dose's concentration, or falls back to a sensible default.
    var defaultConcentrationMgPerMl: Double? {
        // First, check the most recent dose with a recorded concentration
        if let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == selectedMedication && $0.concentrationMgPerMl != nil })
        {
            return recent.concentrationMgPerMl
        }
        // Fall back to sensible defaults per medication type
        if selectedMedication == "Estrogen" {
            return 40.0   // EV 40 mg/mL is most common
        } else if selectedMedication == "Testosterone" {
            return 200.0  // TC 200 mg/mL is most common
        }
        return nil
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
    /// Volumes below 0.1 mL are extremely difficult to measure accurately even with
    /// a 0.3 mL insulin syringe.
    static func isVolumeTooSmall(_ volumeMl: Double) -> Bool {
        return volumeMl < 0.1
    }

    /// True if the volume is large enough to cause injection discomfort for frequent dosing.
    /// For long-acting esters (TU), volumes up to 4 mL are normal.
    /// For short/medium-acting esters, > 2-3 mL per injection is impractical.
    static func isVolumeTooLarge(_ volumeMl: Double, isLongActing: Bool = false) -> Bool {
        let threshold = isLongActing ? 4.5 : 2.5
        return volumeMl > threshold
    }

    /// Recommends a syringe size based on injection volume.
    static func recommendedSyringe(for volumeMl: Double) -> String {
        if volumeMl <= 0.3 {
            return "0.3 mL insulin syringe"
        } else if volumeMl <= 1.0 {
            return "1 mL syringe"
        } else if volumeMl <= 3.0 {
            return "3 mL syringe"
        } else {
            return "5 mL syringe"
        }
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

    /// Calculates the next dose date using the custom frequency if set (#18),
    /// otherwise falls back to the administration method's default frequency.
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        let interval: Int
        if let custom = customFrequencyDays, custom > 0 {
            interval = custom
        } else if let methodStr = selectedAdministrationMethod,
                  let method = AdministrationMethod(rawValue: methodStr) {
            interval = method.frequencyDays
        } else {
            interval = 7
        }
        return Calendar.current.date(byAdding: .day, value: interval, to: lastDose) ?? Date()
    }

}
