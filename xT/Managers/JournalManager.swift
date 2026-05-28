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