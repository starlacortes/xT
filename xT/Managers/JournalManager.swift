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
    var currentSymptoms: [Symptom] = []

    // CRUD operations
    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        guard let context = modelContext else { return }
        context.insert(entry)
        do {
            try context.save()
        } catch {
            print("[JournalManager] Failed to save entry: \(error)")
        }
    }

    /// Most recent entry (`entries` is kept newest-first).
    var lastEntry: JournalEntry? {
        entries.first
    }

    // MARK: - Persistence

    // Loads journal entries from SwiftData.
    func loadEntries() {
        guard let context = modelContext else { return }
        do {
            let allEntries = try context.fetch(FetchDescriptor<JournalEntry>())
            entries = allEntries.sorted { $0.date > $1.date } // newest first
        } catch {
            print("[JournalManager] Failed to load entries: \(error)")
            entries = []
        }

        if entries.isEmpty {
            currentMood = .neutral
        } else if let lastEntry = entries.first {
            currentMood = lastEntry.mood
            currentSymptoms = lastEntry.symptoms
        }
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
