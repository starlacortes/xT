//
//  ScreeningRecord.swift
//  xT
//
//  Health screening log for long-term tenure milestones (impl plan §4.1).
//  Mirrors the BloodTestRecord persistence pattern so the Time engine can
//  query "last done date" by screening type and flip milestone badges
//  from "due" to "done".
//

import Foundation
import SwiftData

enum ScreeningType: String, Codable, CaseIterable {
    case bloodPanel      = "blood_panel"
    case dexaScan        = "dexa_scan"
    case breastScreening = "breast_screening"
    case cardioCheck     = "cardio_check"
    case liverPanel      = "liver_panel"
    case cbc             = "cbc"
    case other           = "other"

    var label: String {
        switch self {
        case .bloodPanel:      return "Blood panel"
        case .dexaScan:        return "DEXA scan"
        case .breastScreening: return "Breast screening"
        case .cardioCheck:     return "Cardio check"
        case .liverPanel:      return "Liver panel"
        case .cbc:             return "CBC"
        case .other:           return "Other"
        }
    }
}

@Model
class ScreeningRecord: Identifiable {
    var id: String = UUID().uuidString
    var date: Date = Date()
    var typeRawValue: String = "other" // rawValue of ScreeningType (SwiftData-friendly)
    var notes: String?

    var type: ScreeningType {
        get { ScreeningType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        date: Date,
        type: ScreeningType,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.typeRawValue = type.rawValue
        self.notes = notes
    }
}
