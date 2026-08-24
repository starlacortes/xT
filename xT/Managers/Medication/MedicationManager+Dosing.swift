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
    /// the default the user chose during onboarding (cached by `loadUserPreferences()` —
    /// the prefs record used to be re-fetched here on every view render), then the most
    /// commonly stocked vial strength for the medication.
    var defaultConcentrationMgPerMl: Double? {
        if let recent = latestDose(matching: {
            $0.isActive && $0.medicationType == selectedMedication && $0.concentrationMgPerMl != nil
        }) {
            return recent.concentrationMgPerMl
        }
        switch selectedMedication {
        case "Estrogen":
            return cachedDefaultEstrogenConcentration ?? PKConstants.referenceEstrogenConcentrationMgPerMl
        case "Testosterone":
            return cachedDefaultTestosteroneConcentration ?? PKConstants.referenceTestosteroneConcentrationMgPerMl
        default:
            return nil
        }
    }

    /// Writes the onboarding-chosen default vial strength into the prefs record
    /// and the memory cache in one step, so the fallback chain above never
    /// serves a stale value to a user who just finished setup.
    func updateOnboardingDefaultConcentration(_ value: Double, for medication: String) {
        guard let context = modelContext,
              let prefs = UserPreferences.canonical(in: context)
        else { return }
        if medication == "Estrogen" {
            prefs.defaultEstrogenConcentration = value
            cachedDefaultEstrogenConcentration = value
        } else {
            prefs.defaultTestosteroneConcentration = value
            cachedDefaultTestosteroneConcentration = value
        }
        try? context.save()
    }

    // MARK: - Dose Defaulting

    /// The ester assumed for `medication` when no prior dose carries one, and its
    /// absorption half-life — the single source for the paired
    /// "Valerate (EV)"/"Cypionate (TC)" fallbacks that used to be hand-paired in
    /// four different files.
    static func defaultEsterInfo(for medication: String) -> (name: String, halfLifeDays: Double) {
        if medication == MedicationType.estrogen.rawValue {
            let ester = MedicationEster.valerate
            return (ester.rawValue, ester.halfLifeDays)
        }
        let ester = TestosteroneEster.cypionate
        return (ester.rawValue, ester.halfLifeDays)
    }

    /// The single canonical ester/amount/concentration fallback chain for recording
    /// a dose the caller only partially specified — previously hand-rolled in
    /// `QuickDoseSheet`, `UnifiedScheduleView`, onboarding, and `defaultDoseDetails`,
    /// and the three were already drifting apart.
    ///
    /// Resolution order per field: the most recent active dose for the medication,
    /// then the user's selections/onboarding defaults, then the medication-typical
    /// constants (see `PKConstants`).
    func resolvedDoseDefaults(
        medication: String?,
        method: String?
    ) -> (esterName: String, amountMg: Double, concentrationMgPerMl: Double) {
        let med = medication ?? selectedMedication ?? ""
        let isEstrogen = (med == MedicationType.estrogen.rawValue)
        let recent = latestDose { $0.isActive && $0.medicationType == med }

        let ester = recent?.ester
            ?? (med == selectedMedication ? selectedEster : nil)
            ?? Self.defaultEsterInfo(for: med).name
        let amount = recent?.doseAmount
            ?? (isEstrogen ? PKConstants.referenceEstrogenDoseMg
                           : PKConstants.defaultTestosteroneDoseMg)
        let concentration = recent?.concentrationMgPerMl
            ?? (isEstrogen
                ? cachedDefaultEstrogenConcentration ?? PKConstants.referenceEstrogenConcentrationMgPerMl
                : cachedDefaultTestosteroneConcentration ?? PKConstants.referenceTestosteroneConcentrationMgPerMl)
        return (ester, amount, concentration)
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
            return String(localized: "5 mL syringe")
        }
        // Sub-millilitre barrels are insulin syringes, which carry unit markings.
        let isInsulin = barrelMl < 1.0
        let size = String(format: isInsulin ? "%.1f" : "%.0f", barrelMl)
        return "\(size) mL \(isInsulin ? "insulin syringe" : "syringe")"
    }

    /// States a fact about the volume this dose works out to, when the number is
    /// outside the range a syringe measures well. It reports the measurement
    /// problem; choosing a different concentration, syringe or split is the
    /// user's call to make with their provider.
    static func volumeNote(for volumeMl: Double, ester: String? = nil) -> String? {
        let isLong = ester == "Undecanoate (TU)"
        if isVolumeTooSmall(volumeMl) {
            let syringe = recommendedSyringe(for: volumeMl)
            return String(localized: "This dose works out to \(AppNumberFormatters.volume.string(volumeMl)) mL, below what a standard syringe measures accurately. A \(syringe) has markings at this scale.",
                          comment: "Note shown when a computed injection volume is too small to measure reliably")
        }
        if isVolumeTooLarge(volumeMl, isLongActing: isLong) {
            return String(localized: "This dose works out to \(AppNumberFormatters.volume.string(volumeMl)) mL, a large volume for a single injection site.",
                          comment: "Note shown when a computed injection volume is large for one site")
        }
        return nil
    }

    // MARK: - Public API (Management)

    func updateSelection(type: MedicationType, method: AdministrationMethod) {
        selectedMedication = type.rawValue
        selectedAdministrationMethod = method.rawValue

        // Do NOT stamp a fake lastDoseDate — the user hasn't taken a dose.
        // Only recompute nextDoseDate if a real lastDoseDate exists.
        if let last = lastDoseDate {
            let next = calculateNextDoseDate(from: last)
            updateDoseDates(last: last, next: next)
        } else {
            persistUserPreferences()
        }
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
        persistUserPreferences()

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

    /// Delay before HomeView's celebration confetti fires after a dose recorded
    /// via `recordDose(on:)`. Longer than `MedicationManager.defaultCelebrationDelay`
    /// (tuned for `QuickDoseSheet`, which dismisses itself immediately) because
    /// `RecordDoseView` shows an in-sheet confirmation before dismissing.
    static let recordDoseCelebrationDelay: TimeInterval = 1.2

    /// Ester/amount/concentration to assume for a dose the caller didn't fully
    /// specify: the most recently logged dose's values, or a medication-typical
    /// default when there's no prior dose to read from. Shared by `skipDose` and
    /// `recordDose`, both of which only capture a date from the user.
    private func defaultDoseDetails(for medType: String) -> (ester: String, amount: Double, concentration: Double?) {
        let ester = lastLoggedDose?.ester
            ?? selectedEster
            ?? Self.defaultEsterInfo(for: medType).name
        let amount = lastLoggedDose?.doseAmount
            ?? (medType == "Estrogen" ? 2.0 : 40.0)
        let concentration = lastLoggedDose?.concentrationMgPerMl
        return (ester, amount, concentration)
    }

    /// Records a dose from the lightweight "Record dose" quick action (the
    /// next-dose row's sheet), which captures a date but no amount/ester/
    /// concentration. Routes through `addDose` — using the same last-logged-dose
    /// defaulting as `skipDose` — so this dose actually lands in `doseHistory`
    /// rather than only nudging the `lastDoseDate`/`nextDoseDate` convenience
    /// fields. Without a real `DoseRecord`, `estimatedLevels` (which builds the
    /// curve exclusively from `doseHistory` once it's non-empty) never saw this
    /// dose, and a later Journal delete's history-only recompute of `nextDoseDate`
    /// would silently discard it too.
    func recordDose(on date: Date = Date()) {
        guard let medType = selectedMedication,
              let medMethod = selectedAdministrationMethod else {
            lastDoseDate = date
            persistUserPreferences()
            refreshState()
            if let next = nextDoseDate {
                NotificationManager.shared.rescheduleAfterDose(nextDoseDate: next)
            }
            return
        }

        let details = defaultDoseDetails(for: medType)
        celebrationDelay = Self.recordDoseCelebrationDelay
        addDose(
            date: date,
            type: medType,
            ester: details.ester,
            method: medMethod,
            doseAmount: details.amount,
            concentrationMgPerMl: details.concentration
        )
    }

    /// Logs an intentionally skipped dose. Does NOT advance `nextDoseDate`;
    /// the schedule stays anchored to the last *taken* dose. The skipped
    /// record is persisted so it shows in timelines and affects adherence rate.
    func skipDose(on date: Date = Date(), reason: String? = nil) {
        guard let medType = selectedMedication,
              let medMethod = selectedAdministrationMethod else { return }

        let details = defaultDoseDetails(for: medType)

        let record = DoseRecord(
            doseDate: date,
            medicationType: medType,
            ester: details.ester,
            administrationMethod: medMethod,
            doseAmount: details.amount,
            concentrationMgPerMl: details.concentration,
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
