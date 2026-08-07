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
