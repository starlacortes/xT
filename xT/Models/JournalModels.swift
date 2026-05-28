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
class JournalEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var mood: Mood
    var text: String
    var symptoms: Set<Symptom>

    init(id: UUID = UUID(), date: Date, mood: Mood, text: String, symptoms: Set<Symptom>) {
        self.id = id
        self.date = date
        self.mood = mood
        self.text = text
        self.symptoms = symptoms
    }

    var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 60 else { return trimmed }
        return String(trimmed.prefix(60)) + "…"
    }

    // Manual Codable conformance to work with @Model macro
    enum CodingKeys: String, CodingKey {
        case id, date, mood, text, symptoms
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        mood = try container.decode(Mood.self, forKey: .mood)
        text = try container.decode(String.self, forKey: .text)
        symptoms = try container.decode(Set<Symptom>.self, forKey: .symptoms)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(mood, forKey: .mood)
        try container.encode(text, forKey: .text)
        try container.encode(symptoms, forKey: .symptoms)
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