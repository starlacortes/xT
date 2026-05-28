//
//  JournalManager.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Journal management system for tracking mood, symptoms, and entries
//
//
import SwiftUI
import Foundation
import CryptoKit

class JournalManager: ObservableObject {
    static let shared = JournalManager()

    @Published var entries: [JournalEntry] = []
    @Published var currentMood: Mood = .neutral
    @Published var currentSymptoms: Set<Symptom> = []

    // Load from persistence
    init() {
        loadEntries()
        migrateToEncryptedStorage()
    }

    // CRUD operations
    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        persistEntries()
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

    // Persistence methods
    private func loadEntries() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Try encrypted data first
        if let encryptedEntriesData = defaults.data(forKey: "encryptedJournalEntries"),
           let decryptedEntriesData = securityManager.decryptData(encryptedEntriesData),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: decryptedEntriesData) {
            entries = decoded
        }
        // Fallback to unencrypted data (migration)
        else if let data = defaults.data(forKey: "journalEntries"),
                let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }

        // Set default current mood if no entries exist
        if entries.isEmpty {
            currentMood = .neutral
        } else if let lastEntry = entries.first {
            currentMood = lastEntry.mood
            currentSymptoms = lastEntry.symptoms
        }
    }

    private func persistEntries() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        if let encoded = try? JSONEncoder().encode(entries) {
            if let encryptedEntries = securityManager.encryptData(encoded) {
                defaults.set(encryptedEntries, forKey: "encryptedJournalEntries")
            }
        }

        // Clear old unencrypted data
        defaults.removeObject(forKey: "journalEntries")
    }

    /// Migrate existing unencrypted data to encrypted storage
    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Check if migration is needed
        if defaults.object(forKey: "encryptedJournalEntries") != nil {
            return // Already migrated
        }

        // Migrate journal entries
        if let unencryptedData = defaults.data(forKey: "journalEntries") {
            if let encryptedData = securityManager.encryptData(unencryptedData) {
                defaults.set(encryptedData, forKey: "encryptedJournalEntries")
                defaults.removeObject(forKey: "journalEntries")
            }
        }
    }

    // Clear all journal data (for testing)
    func clearAllData() {
        entries.removeAll()
        currentMood = .neutral
        currentSymptoms = []
        persistEntries()
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
        persistEntries()
    }
}

// Environment extension
struct JournalManagerKey: EnvironmentKey {
    static let defaultValue = JournalManager()
}

extension EnvironmentValues {
    var journalManager: JournalManager {
        get { self[JournalManagerKey.self] }
        set { self[JournalManagerKey.self] = newValue }
    }
}