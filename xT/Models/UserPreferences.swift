//
//  UserPreferences.swift
//  xT
//
//  Created by Starla Cortes on 2/17/26.
//


import Foundation
import SwiftData

/// User-configurable suppression speed for endogenous hormone taper.
/// Stored as a String raw value for SwiftData compatibility.
enum SuppressionSpeed: String, Codable, CaseIterable {
    case fast   = "fast"    // 4-week taper (default)
    case medium = "medium"  // 8-week taper
    case slow   = "slow"    // 12-week taper

    var weeks: Double {
        switch self {
        case .fast:   return 4
        case .medium: return 8
        case .slow:   return 12
        }
    }
}

@Model
final class UserPreferences {
    // Persisted indices for selection. Using Int keeps compatibility with enums.
    var medicationRow: Int = -1
    var medicationColumn: Int = -1

    // --- Medication Selection (moved from encrypted UserDefaults) ---
    var selectedMedication: String?
    var selectedAdministrationMethod: String?
    var selectedEster: String?

    // Optional persisted dose dates
    var lastDoseDate: Date?
    var nextDoseDate: Date?
    /// When the user actually began HRT (may predate app install).
    var hrtStartDate: Date?

    // Default vial concentrations (mg/mL) per medication type
    var defaultEstrogenConcentration: Double?
    var defaultTestosteroneConcentration: Double?

    // --- Physiology Settings ---
    var suppressionSpeed: String = "fast"       // rawValue of SuppressionSpeed
    var spironolactoneClearanceEnabled: Bool = false
    var antiAndrogenInUse: Bool = false
    var spironolactoneInUse: Bool = false

    // --- Flexible Dosing ---
    var customFrequencyDays: Int?
    var missedDoseGracePeriodHours: Double = 12.0

    // --- Default Dose Settings ---
    var defaultDoseAmount: Double?
    var defaultInjectionTime: Date?

    // --- Dose-Intensity Toggle ---
    var showDoseIntensityInsights: Bool = false

    // --- Therapeutic Target ---
    var userTherapeuticTargetJSON: String?      // JSON-encoded TherapeuticTarget; nil = use clinical defaults

    // --- Rotation Windows (moved from mm.rotationWindow_* UserDefaults) ---
    var rotationWindowInjection: Int = 14
    var rotationWindowTopical: Int = 7
    var rotationWindowPatch: Int = 30

    // --- Avoid Zones (moved from injectionSiteAvoidZones UserDefaults) ---
    var avoidZonesJSON: String?                 // JSON-encoded [String: AvoidZoneInfo]

    // --- Body Type (moved from @AppStorage("bodyType")) ---
    var bodyTypeRaw: String = "neutral"         // rawValue of BodyType

    // --- Profile (moved from encrypted UserDefaults for cross-device sync) ---
    var profileName: String?
    var profileImageData: Data?
    var profileDateOfBirth: Date?

    init(
        medicationRow: Int = -1,
        medicationColumn: Int = -1,
        selectedMedication: String? = nil,
        selectedAdministrationMethod: String? = nil,
        selectedEster: String? = nil,
        lastDoseDate: Date? = nil,
        nextDoseDate: Date? = nil,
        hrtStartDate: Date? = nil,
        defaultEstrogenConcentration: Double? = nil,
        defaultTestosteroneConcentration: Double? = nil,
        suppressionSpeed: SuppressionSpeed = .fast,
        spironolactoneClearanceEnabled: Bool = false,
        antiAndrogenInUse: Bool = false,
        spironolactoneInUse: Bool = false,
        customFrequencyDays: Int? = nil,
        missedDoseGracePeriodHours: Double = 12.0,
        defaultDoseAmount: Double? = nil,
        defaultInjectionTime: Date? = nil,
        showDoseIntensityInsights: Bool = false,
        userTherapeuticTargetJSON: String? = nil,
        rotationWindowInjection: Int = RouteClass.injection.defaultRotationWindowDays,
        rotationWindowTopical: Int = RouteClass.topical.defaultRotationWindowDays,
        rotationWindowPatch: Int = RouteClass.patch.defaultRotationWindowDays,
        avoidZonesJSON: String? = nil,
        bodyTypeRaw: String = BodyType.neutral.rawValue,
        profileName: String? = nil,
        profileImageData: Data? = nil,
        profileDateOfBirth: Date? = nil
    ) {
        self.medicationRow = medicationRow
        self.medicationColumn = medicationColumn
        self.selectedMedication = selectedMedication
        self.selectedAdministrationMethod = selectedAdministrationMethod
        self.selectedEster = selectedEster
        self.lastDoseDate = lastDoseDate
        self.nextDoseDate = nextDoseDate
        self.hrtStartDate = hrtStartDate
        self.defaultEstrogenConcentration = defaultEstrogenConcentration
        self.defaultTestosteroneConcentration = defaultTestosteroneConcentration
        self.suppressionSpeed = suppressionSpeed.rawValue
        self.spironolactoneClearanceEnabled = spironolactoneClearanceEnabled
        self.antiAndrogenInUse = antiAndrogenInUse
        self.spironolactoneInUse = spironolactoneInUse
        self.customFrequencyDays = customFrequencyDays
        self.missedDoseGracePeriodHours = missedDoseGracePeriodHours
        self.defaultDoseAmount = defaultDoseAmount
        self.defaultInjectionTime = defaultInjectionTime
        self.showDoseIntensityInsights = showDoseIntensityInsights
        self.userTherapeuticTargetJSON = userTherapeuticTargetJSON
        self.rotationWindowInjection = rotationWindowInjection
        self.rotationWindowTopical = rotationWindowTopical
        self.rotationWindowPatch = rotationWindowPatch
        self.avoidZonesJSON = avoidZonesJSON
        self.bodyTypeRaw = bodyTypeRaw
        self.profileName = profileName
        self.profileImageData = profileImageData
        self.profileDateOfBirth = profileDateOfBirth
    }
}

// MARK: - Canonical singleton row

extension UserPreferences {
    /// Returns the single canonical preferences row for `context`.
    ///
    /// The table was designed as a singleton, but CloudKit can break that
    /// invariant: every install or onboarding attempt that ever created a row
    /// exports its own, and a fresh install imports them all. Unordered
    /// `.first` fetches then load an arbitrary — often blank — row, which made
    /// restore report "No iCloud Data Found" while a fully populated row sat
    /// in the store.
    ///
    /// This consolidates: pick the most active completed profile, merge any
    /// values the duplicates hold that it lacks, delete the duplicates, and
    /// return the survivor. A no-op once the table is back to one row.
    static func canonical(in context: ModelContext) -> UserPreferences? {
        let rows = (try? context.fetch(FetchDescriptor<UserPreferences>())) ?? []

        guard !rows.isEmpty else {
            // First launch with a genuinely empty store: create the singleton.
            let prefs = UserPreferences()
            context.insert(prefs)
            try? context.save()
            return prefs
        }

        guard rows.count > 1 else { return rows[0] }

        // Completed profiles (medication selected) first, most recently active
        // first; blank rows from installs that never onboarded sort last.
        let ordered = rows.sorted { lhs, rhs in
            let lhsActive = lhs.selectedMedication != nil
            let rhsActive = rhs.selectedMedication != nil
            if lhsActive != rhsActive { return lhsActive }
            return activityStamp(lhs) > activityStamp(rhs)
        }
        guard let canonical = ordered.first else { return nil }

        for duplicate in ordered.dropFirst() {
            mergeValues(from: duplicate, into: canonical)
            context.delete(duplicate)
        }
        try? context.save()
        return canonical
    }

    /// Fill any value the canonical row is missing from a duplicate before the
    /// duplicate is deleted. Defaults below mirror the model's declared
    /// defaults.
    private static func mergeValues(from duplicate: UserPreferences, into canonical: UserPreferences) {
        if canonical.medicationRow == -1 { canonical.medicationRow = duplicate.medicationRow }
        if canonical.medicationColumn == -1 { canonical.medicationColumn = duplicate.medicationColumn }
        if canonical.selectedMedication == nil { canonical.selectedMedication = duplicate.selectedMedication }
        if canonical.selectedAdministrationMethod == nil { canonical.selectedAdministrationMethod = duplicate.selectedAdministrationMethod }
        if canonical.selectedEster == nil { canonical.selectedEster = duplicate.selectedEster }
        if canonical.lastDoseDate == nil { canonical.lastDoseDate = duplicate.lastDoseDate }
        if canonical.nextDoseDate == nil { canonical.nextDoseDate = duplicate.nextDoseDate }
        if canonical.hrtStartDate == nil { canonical.hrtStartDate = duplicate.hrtStartDate }
        if canonical.defaultEstrogenConcentration == nil { canonical.defaultEstrogenConcentration = duplicate.defaultEstrogenConcentration }
        if canonical.defaultTestosteroneConcentration == nil { canonical.defaultTestosteroneConcentration = duplicate.defaultTestosteroneConcentration }
        if canonical.suppressionSpeed == "fast" { canonical.suppressionSpeed = duplicate.suppressionSpeed }
        canonical.spironolactoneClearanceEnabled = canonical.spironolactoneClearanceEnabled || duplicate.spironolactoneClearanceEnabled
        canonical.antiAndrogenInUse = canonical.antiAndrogenInUse || duplicate.antiAndrogenInUse
        canonical.spironolactoneInUse = canonical.spironolactoneInUse || duplicate.spironolactoneInUse
        if canonical.customFrequencyDays == nil { canonical.customFrequencyDays = duplicate.customFrequencyDays }
        if canonical.missedDoseGracePeriodHours == 12.0 { canonical.missedDoseGracePeriodHours = duplicate.missedDoseGracePeriodHours }
        if canonical.defaultDoseAmount == nil { canonical.defaultDoseAmount = duplicate.defaultDoseAmount }
        if canonical.defaultInjectionTime == nil { canonical.defaultInjectionTime = duplicate.defaultInjectionTime }
        canonical.showDoseIntensityInsights = canonical.showDoseIntensityInsights || duplicate.showDoseIntensityInsights
        if canonical.userTherapeuticTargetJSON == nil { canonical.userTherapeuticTargetJSON = duplicate.userTherapeuticTargetJSON }
        if canonical.rotationWindowInjection == 14 { canonical.rotationWindowInjection = duplicate.rotationWindowInjection }
        if canonical.rotationWindowTopical == 7 { canonical.rotationWindowTopical = duplicate.rotationWindowTopical }
        if canonical.rotationWindowPatch == 30 { canonical.rotationWindowPatch = duplicate.rotationWindowPatch }
        if canonical.avoidZonesJSON == nil { canonical.avoidZonesJSON = duplicate.avoidZonesJSON }
        if canonical.bodyTypeRaw == "neutral" { canonical.bodyTypeRaw = duplicate.bodyTypeRaw }
        if canonical.profileName == nil { canonical.profileName = duplicate.profileName }
        if canonical.profileImageData == nil { canonical.profileImageData = duplicate.profileImageData }
        if canonical.profileDateOfBirth == nil { canonical.profileDateOfBirth = duplicate.profileDateOfBirth }
    }

    private static func activityStamp(_ prefs: UserPreferences) -> Date {
        prefs.lastDoseDate ?? prefs.hrtStartDate ?? .distantPast
    }
}
