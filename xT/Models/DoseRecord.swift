//
//  DoseRecord.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//

import Foundation
import SwiftData

/// Tracks the status of each dose in the medication schedule.
/// Stored as a String raw value for SwiftData compatibility (enums don't persist natively).
enum DoseStatus: String, Codable, CaseIterable {
    case taken   = "taken"    // dose was administered on time
    case skipped = "skipped"  // user intentionally skipped this dose
    case missed  = "missed"   // dose was not taken and grace period passed
}

/// Represents a single logged dose event, persisted via SwiftData.
/// The full dose history enables the pharmacokinetic model to use actual
/// amounts instead of back-calculated ones.
@Model
class DoseRecord: Identifiable, Hashable {
    @Attribute(.unique) var id: String
    var doseDate: Date
    var medicationType: String          // "Estrogen" | "Testosterone"
    var ester: String                   // "Valerate (EV)" | "Cypionate (EC)" | etc.
    var administrationMethod: String    // "Injectable" | "Cream" | "Oral"
    var doseAmount: Double              // actual mg administered (always stored, regardless of input method)
    var concentrationMgPerMl: Double?   // vial concentration used; nil if dose was entered directly in mg
    var notes: String?                  // optional user notes
    var isDeleted: Bool                 // soft-delete flag (for HIPAA-friendly audits)

    // --- Missed/Skipped Dose Handling ---
    var doseStatus: String              // rawValue of DoseStatus enum (SwiftData-friendly)
    var skipReason: String?             // optional reason for intentionally skipping
    var injectionTime: Date?            // precise time-of-day for accurate PK modeling; nil = midnight

    /// Convenience initializer — called by managers, not by SwiftData directly.
    init(
        id: String = UUID().uuidString,
        doseDate: Date,
        medicationType: String,
        ester: String,
        administrationMethod: String,
        doseAmount: Double,
        concentrationMgPerMl: Double? = nil,
        notes: String? = nil,
        doseStatus: DoseStatus = .taken,
        skipReason: String? = nil,
        injectionTime: Date? = nil
    ) {
        self.id = id
        self.doseDate = doseDate
        self.medicationType = medicationType
        self.ester = ester
        self.administrationMethod = administrationMethod
        self.doseAmount = doseAmount
        self.concentrationMgPerMl = concentrationMgPerMl
        self.notes = notes
        self.isDeleted = false
        self.doseStatus = doseStatus.rawValue
        self.skipReason = skipReason
        self.injectionTime = injectionTime
    }

    // Hashable conformance for Set operations
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DoseRecord, rhs: DoseRecord) -> Bool { lhs.id == rhs.id }
}

// MARK: - Convenience Extensions

extension DoseRecord {
    /// Human-readable summary string (e.g., "Estrogen @ 2mg EV i.j. — Jun 10, 2026")
    var summary: String {
        let formatter = DoseRecord.dateFormatter
        let dateStr = formatter.string(from: doseDate)
        if let conc = concentrationMgPerMl {
            let volumeMl = doseAmount / conc
            return "\(medicationType) @ \(String(format: "%.1f", doseAmount))mg (\(String(format: "%.3f", volumeMl)) mL @ \(String(format: "%.0f", conc)) mg/mL) \(ester) \(administrationMethod) — \(dateStr)"
        }
        return "\(medicationType) @ \(String(format: "%.1f", doseAmount))mg \(ester) \(administrationMethod) — \(dateStr)"
    }

    /// Computed injection volume in mL (nil if concentration not recorded)
    var injectionVolumeMl: Double? {
        guard let conc = concentrationMgPerMl, conc > 0 else { return nil }
        return doseAmount / conc
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// Is this dose considered active (not soft-deleted)?
    var isActive: Bool { !isDeleted }

    /// Number of days since this dose (useful for decay calculations)
    var daysSinceDose: Double {
        let diff = Date().timeIntervalSince(doseDate) / 86400.0
        return max(0, diff)
    }
}
