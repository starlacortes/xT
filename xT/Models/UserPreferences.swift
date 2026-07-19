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
    var medicationRow: Int
    var medicationColumn: Int

    // Optional persisted dose dates
    var lastDoseDate: Date?
    var nextDoseDate: Date?

    // Default vial concentrations (mg/mL) per medication type
    // These pre-fill the dose entry UI so the user doesn't have to reselect every time.
    var defaultEstrogenConcentration: Double?   // e.g., 40.0 for EV
    var defaultTestosteroneConcentration: Double?  // e.g., 200.0 for TC

    // --- Physiology Settings (#9, #12) ---
    /// Endogenous suppression speed (fast/medium/slow), drives taper timescale.
    var suppressionSpeed: String                // rawValue of SuppressionSpeed
    /// Whether spironolactone clearance adjustment (ke × 1.15) is enabled.
    var spironolactoneClearanceEnabled: Bool

    // --- Flexible Dosing (#18) ---
    /// Custom dosing interval in days; when nil, falls back to AdministrationMethod.frequencyDays.
    var customFrequencyDays: Int?

    // --- Default Dose Settings ---
    /// Default dose amount in mg (pre-fills dose recording UI).
    var defaultDoseAmount: Double?
    /// Default injection time of day (pre-fills dose recording UI).
    var defaultInjectionTime: Date?

    // --- Dose-Intensity Toggle (plan §4.4) ---
    /// When true, the Time tab surfaces relativeDoseIntensity-derived copy.
    /// T5+ users default this to off. Not exposed in onboarding.
    var showDoseIntensityInsights: Bool

    init(
        medicationRow: Int = -1,
        medicationColumn: Int = -1,
        lastDoseDate: Date? = nil,
        nextDoseDate: Date? = nil,
        defaultEstrogenConcentration: Double? = nil,
        defaultTestosteroneConcentration: Double? = nil,
        suppressionSpeed: SuppressionSpeed = .fast,
        spironolactoneClearanceEnabled: Bool = false,
        customFrequencyDays: Int? = nil,
        defaultDoseAmount: Double? = nil,
        defaultInjectionTime: Date? = nil,
        showDoseIntensityInsights: Bool = false
    ) {
        self.medicationRow = medicationRow
        self.medicationColumn = medicationColumn
        self.lastDoseDate = lastDoseDate
        self.nextDoseDate = nextDoseDate
        self.defaultEstrogenConcentration = defaultEstrogenConcentration
        self.defaultTestosteroneConcentration = defaultTestosteroneConcentration
        self.suppressionSpeed = suppressionSpeed.rawValue
        self.spironolactoneClearanceEnabled = spironolactoneClearanceEnabled
        self.customFrequencyDays = customFrequencyDays
        self.defaultDoseAmount = defaultDoseAmount
        self.defaultInjectionTime = defaultInjectionTime
        self.showDoseIntensityInsights = showDoseIntensityInsights
    }
}

/*
 Future iCloud notes:
 - SwiftData can be configured to sync with iCloud by enabling CloudKit for the container in the app Target capabilities and using a shared model container with iCloud configuration.
 - At that point, this @Model will participate in syncing automatically.
 - Keep properties stable (avoid frequent schema changes) and prefer enums backed by Ints/Strings for forward compatibility.
*/
