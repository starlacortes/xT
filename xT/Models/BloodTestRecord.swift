//
//  BloodTestRecord.swift
//  xT
//
//  Created by xT PK Engine on 6/30/26.
//

import Foundation
import SwiftData

/// A single lab draw entered by the user, used to calibrate the pharmacokinetic model.
/// Each record stores the measured hormone level, when the blood was drawn,
/// and how long it had been since the last dose (auto‑computed from dose history).
@Model
class BloodTestRecord: Identifiable, Hashable {
    @Attribute(.unique) var id: String
    var drawDate: Date                    // when the blood was drawn
    var measuredLevel: Double             // lab result in pg/mL (E2) or ng/dL (T)
    var hormoneType: String               // "Estrogen" or "Testosterone"
    var hoursSinceLastDose: Double?       // time between last dose and draw (auto‑calculated)
    var notes: String?                    // optional user notes (e.g., "Quest Diagnostics, trough draw")

    /// The calibration factor derived from this test.
    /// α = measured / predicted.  Values > 1 mean the model under‑predicts;
    /// values < 1 mean the model over‑predicts.
    /// Only meaningful after the model has been run for the draw date.
    var calibrationFactor: Double?        // transient, not persisted to disk

    /// Convenience initializer.
    init(
        id: String = UUID().uuidString,
        drawDate: Date,
        measuredLevel: Double,
        hormoneType: String,
        hoursSinceLastDose: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.drawDate = drawDate
        self.measuredLevel = measuredLevel
        self.hormoneType = hormoneType
        self.hoursSinceLastDose = hoursSinceLastDose
        self.notes = notes
        self.calibrationFactor = nil
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BloodTestRecord, rhs: BloodTestRecord) -> Bool { lhs.id == rhs.id }
}

// MARK: - Convenience

extension BloodTestRecord {
    /// The display unit for a hormone type's lab result.
    ///
    /// Hoisted out of `summary` so the composer and the labs chart can label their
    /// level fields with the same unit the summary uses, without duplicating the
    /// ternary. Estrogen is measured in pg/mL; testosterone in ng/dL.
    static func unit(for hormoneType: String) -> String {
        hormoneType == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    /// Human-readable summary (e.g., "E2: 185 pg/mL — Jun 15, 2026 (trough)")
    var summary: String {
        let unit = BloodTestRecord.unit(for: hormoneType)
        let dateStr = BloodTestRecord.dateFormatter.string(from: drawDate)
        var base = "\(hormoneType): \(String(format: "%.0f", measuredLevel)) \(unit) — \(dateStr)"
        if let hrs = hoursSinceLastDose {
            base += " (\(String(format: "%.1f", hrs))h post‑dose)"
        }
        return base
    }

    private static let dateFormatter: DateFormatter = {
        return AppDateFormatters.monthDayYear
    }()

    /// Whether this record has a valid calibration factor computed.
    var isCalibrated: Bool { calibrationFactor != nil }
}