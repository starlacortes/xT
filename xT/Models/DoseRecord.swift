//
//  DoseRecord.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//

import Foundation
import SwiftData

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
    var doseAmount: Double              // actual mg administered
    var notes: String?                  // optional user notes
    var isDeleted: Bool                 // soft-delete flag (for HIPAA-friendly audits)

    /// Convenience initializer — called by managers, not by SwiftData directly.
    init(
        id: String = UUID().uuidString,
        doseDate: Date,
        medicationType: String,
        ester: String,
        administrationMethod: String,
        doseAmount: Double,
        notes: String? = nil
    ) {
        self.id = id
        self.doseDate = doseDate
        self.medicationType = medicationType
        self.ester = ester
        self.administrationMethod = administrationMethod
        self.doseAmount = doseAmount
        self.notes = notes
        self.isDeleted = false
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
        return "\(medicationType) @ \(String(format: "%.1f", doseAmount))mg \(ester) \(administrationMethod) — \(dateStr)"
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
