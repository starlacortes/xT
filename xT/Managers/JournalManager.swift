//
//  JournalManager.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Journal management system for tracking mood, symptoms, and entries
//

import SwiftUI
import SwiftData
import Observation
import Foundation

@MainActor
@Observable
class JournalManager {
    static let shared = JournalManager()

    // Injected from the app container. Loading entries is deferred until the context arrives.
    var modelContext: ModelContext? {
        didSet { loadEntries() }
    }

    var entries: [JournalEntry] = []
    var currentMood: Mood = .neutral
    var currentSymptoms: Set<Symptom> = []

    // CRUD operations
    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        modelContext?.insert(entry)
        try? modelContext?.save()
    }

    func updateCurrentMood(_ mood: Mood) {
        currentMood = mood
    }

    func updateCurrentSymptoms(_ symptoms: Set<Symptom>) {
        currentSymptoms = symptoms
    }

    var lastEntry: JournalEntry? {
        entries.first
    }

    // Create a new entry with current state
    func createNewEntry(text: String) -> JournalEntry {
        let entry = JournalEntry(
            date: Date(),
            mood: currentMood,
            text: text,
            symptoms: currentSymptoms
        )
        return entry
    }

    // MARK: - Persistence

    // Loads journal entries from SwiftData.
    func loadEntries() {
        guard let context = modelContext else { return }
        let allEntries = try? context.fetch(FetchDescriptor<JournalEntry>())
        entries = allEntries?.sorted { $0.date > $1.date } ?? [] // newest first

        if entries.isEmpty {
            currentMood = .neutral
        } else if let lastEntry = entries.first {
            currentMood = lastEntry.mood
            currentSymptoms = lastEntry.symptoms
        }
    }

    // Clear all journal data (for testing)
    func clearAllData() {
        guard let context = modelContext else { return }
        let all = try? context.fetch(FetchDescriptor<JournalEntry>())
        for entry in all ?? [] {
            context.delete(entry)
        }
        entries.removeAll()
        currentMood = .neutral
        currentSymptoms = []
        try? context.save()
    }

    // Create sample entries for demo purposes
    func createSampleEntries() {
        let calendar = Calendar.current

        // Today's entry
        let todayEntry = JournalEntry(
            date: Date(),
            mood: .happy,
            text: "Skin has been so soft this week. Noticed my mood staying really level throughout the day too.",
            symptoms: Set([Symptom.commonSymptoms[0], Symptom.commonSymptoms[4]]) // skin changes, energy boost
        )

        // Yesterday's entry
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayEntry = JournalEntry(
            date: yesterday,
            mood: .calm,
            text: "A bit tired after work but overall okay. Hot flash in the afternoon that was a bit uncomfortable.",
            symptoms: Set([Symptom.commonSymptoms[1], Symptom.commonSymptoms[2]]) // hot flashes, fatigue
        )

        // Entry from 2 days ago
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let twoDaysAgoEntry = JournalEntry(
            date: twoDaysAgo,
            mood: .energetic,
            text: "Woke up feeling genuinely good. Dose day — remembered on time!",
            symptoms: Set([Symptom.commonSymptoms[4]]) // energy boost
        )

        // Entry from 5 days ago
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        let fiveDaysAgoEntry = JournalEntry(
            date: fiveDaysAgo,
            mood: .neutral,
            text: "Quiet day, not much to report. Mood was stable throughout.",
            symptoms: Set([])
        )

        // Entry from 6 days ago
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let sixDaysAgoEntry = JournalEntry(
            date: sixDaysAgo,
            mood: .happy,
            text: "Really good energy today, went for a walk and enjoyed the sunshine.",
            symptoms: Set([Symptom.commonSymptoms[4]]) // energy boost
        )

        // Add entries in reverse chronological order
        entries = [todayEntry, yesterdayEntry, twoDaysAgoEntry, fiveDaysAgoEntry, sixDaysAgoEntry]
        for entry in entries {
            modelContext?.insert(entry)
        }
        try? modelContext?.save()
    }
}

// EnvironmentKey for JournalManager.
// defaultValue is @MainActor because JournalManager is @MainActor.
// EnvironmentValues is also @MainActor, so there's no actual race condition.
@MainActor
struct JournalManagerKey: EnvironmentKey {
    @safe static var defaultValue: JournalManager {
        return JournalManager.shared
    }
}

extension EnvironmentValues {
    var journalManager: JournalManager {
        get { self[JournalManagerKey.self] }
        set { self[JournalManagerKey.self] = newValue }
    }
}
