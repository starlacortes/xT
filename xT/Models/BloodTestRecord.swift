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
    var id: String = UUID().uuidString
    var drawDate: Date = Date()           // when the blood was drawn
    var measuredLevel: Double = 0         // lab result in pg/mL (E2) or ng/dL (T)
    var hormoneType: String = ""          // "Estrogen" or "Testosterone"
    var hoursSinceLastDose: Double?       // time between last dose and draw (auto‑calculated)
    var notes: String?                    // optional user notes (e.g., "Quest Diagnostics, trough draw")

    /// The calibration factor derived from this test.
    /// α = (measured − base) / exogenous — the multiplier applied to the exogenous
    /// drug contribution only (`base + exogenous · α`). Values > 1 mean the model
    /// under‑predicts the drug term; values < 1 mean it over‑predicts.
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
    /// Single source for the pg/mL-vs-ng/dL ternary — the composer, the labs
    /// chart, and the data exporter all label their level fields from here.
    /// Estrogen is measured in pg/mL; testosterone in ng/dL.
    static func unit(for hormoneType: String) -> String {
        hormoneType == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    /// Whether this record has a valid calibration factor computed.
    var isCalibrated: Bool { calibrationFactor != nil }
}
