//
//  JournalModels.swift
//  xT
//
//  Updated to add Energetic mood case and align icons with SF Symbols
//

import Foundation
import SwiftData

// MARK: - Journal Entry

@Model
class JournalEntry: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var mood: Mood = Mood.neutral
    var text: String = ""
    var hormoneLevel: Double?

    private var symptomsJSON: String = "[]"

    var symptoms: [Symptom] {
        get {
            guard let data = symptomsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Symptom].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                symptomsJSON = json
            } else {
                symptomsJSON = "[]"
            }
        }
    }

    init(id: UUID = UUID(), date: Date, mood: Mood, text: String, symptoms: [Symptom], hormoneLevel: Double? = nil) {
        self.id = id
        self.date = date
        self.mood = mood
        self.text = text
        self.hormoneLevel = hormoneLevel
        let encoded = { () -> String in
            guard let data = try? JSONEncoder().encode(symptoms),
                  let json = String(data: data, encoding: .utf8) else { return "[]" }
            return json
        }()
        self.symptomsJSON = encoded
    }

    var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 60 else { return trimmed }
        return String(trimmed.prefix(60)) + "…"
    }
}

// MARK: - Mood

enum Mood: String, Codable, CaseIterable {
    case happy    = "Happy"
    case calm     = "Calm"
    case neutral  = "Neutral"
    case tired    = "Tired"
    case anxious  = "Anxious"
    case sad      = "Sad"
    case energetic = "Energetic"

    var icon: String {
        switch self {
        case .happy:     return "face.smiling"
        case .calm:      return "moon"
        case .neutral:   return "minus.circle"
        case .tired:     return "zzz"
        case .anxious:   return "waveform.path.ecg"
        case .sad:       return "cloud.drizzle"
        case .energetic: return "bolt"
        }
    }
}

// MARK: - Symptom

struct Symptom: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String

    init(id: UUID = UUID(), name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    static func == (lhs: Symptom, rhs: Symptom) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let commonSymptoms: [Symptom] = [
        Symptom(name: "skin changes",  icon: "hand.raised"),
        Symptom(name: "hot flashes",   icon: "thermometer.sun"),
        Symptom(name: "fatigue",       icon: "bed.double"),
        Symptom(name: "headache",      icon: "brain.head.profile"),
        Symptom(name: "energy boost",  icon: "bolt"),
        Symptom(name: "mood swings",   icon: "arrow.up.arrow.down"),
        Symptom(name: "breast tenderness", icon: "heart"),
        Symptom(name: "nausea",        icon: "allergens"),
    ]
}