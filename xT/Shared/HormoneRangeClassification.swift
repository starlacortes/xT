//
//  HormoneRangeClassification.swift
//  xT
//
//  Medication-aware range classification shared across all graph and
//  level-display components. Thresholds differ between Estrogen (pg/mL)
//  and Testosterone (ng/dL).
//

import SwiftUI

enum HormoneRangeClassification {

    /// Human-readable label for the given level and medication.
    static func label(for level: Double, medication: String?) -> String? {
        guard let med = medication else { return nil }
        if med == "Estrogen" {
            switch level {
            case ..<50:  return "very low"
            case ..<100: return "low"
            case ..<200: return "optimal"
            case ..<500: return "high"
            default:     return "very high"
            }
        } else {
            switch level {
            case ..<50:  return "suppressed"
            case ..<200: return "low"
            case ..<800: return "in range"
            default:     return "high"
            }
        }
    }

    /// Semantic color corresponding to the range classification.
    static func color(for level: Double, medication: String?) -> Color {
        guard let med = medication else { return Theme.Colors.accent }
        if med == "Estrogen" {
            switch level {
            case ..<50:  return Theme.Colors.error
            case ..<100: return Theme.Colors.warning
            case ..<200: return Theme.Colors.success
            case ..<500: return Theme.Colors.warning
            default:     return Theme.Colors.error
            }
        } else {
            switch level {
            case ..<50:  return Theme.Colors.error
            case ..<200: return Theme.Colors.warning
            case ..<800: return Theme.Colors.success
            default:     return Theme.Colors.warning
            }
        }
    }
}
