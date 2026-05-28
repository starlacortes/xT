//
//  JournalModels.swift
//  xT
//
//  Created by Cline on 5/26/2026.
//  Data models for journaling functionality
//

import Foundation

// MARK: - Journal Entry Model
struct JournalEntry: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var mood: Mood
    var text: String
    var symptoms: Set<Symptom>

    var previewText: String {
        text.prefix(50) + (text.count > 50 ? "..." : "")
    }
}

// MARK: - Mood Enum
enum Mood: String, Codable, CaseIterable {
    case happy = "Happy"
    case neutral = "Neutral"
    case sad = "Sad"
    case anxious = "Anxious"
    case energetic = "Energetic"

    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .neutral: return "face.smiling"
        case .sad: return "face.frowning"
        case .anxious: return "face.dashed"
        case .energetic: return "bolt.fill"
        }
    }
}

// MARK: - Symptom Model
struct Symptom: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let icon: String

    // Common symptoms for hormone tracking
    static let commonSymptoms: [Symptom] = [
        Symptom(name: "Hot flashes", icon: "flame"),
        Symptom(name: "Mood swings", icon: "face.dashed"),
        Symptom(name: "Fatigue", icon: "bed.double"),
        Symptom(name: "Headache", icon: "headphone"),
        Symptom(name: "Energy boost", icon: "bolt.fill"),
        Symptom(name: "Skin changes", icon: "hand.raised")
    ]
}