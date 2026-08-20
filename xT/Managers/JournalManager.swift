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

    // CRUD operations
    func addEntry(_ entry: JournalEntry) {
        guard let context = modelContext else {
            print("[JournalManager] Cannot save entry: no model context")
            return
        }
        context.insert(entry)
        do {
            try context.save()
            entries.insert(entry, at: 0)
        } catch {
            context.delete(entry)
            print("[JournalManager] Failed to save entry: \(error)")
        }
    }

    /// Most recent entry (`entries` is kept newest-first).
    var lastEntry: JournalEntry? {
        entries.first
    }

    // MARK: - Persistence

    // Loads journal entries from SwiftData, newest first. Sorted at the store
    // like its sibling loads, rather than fetched unsorted and sorted in memory.
    func loadEntries() {
        guard let context = modelContext else { return }
        let sort = SortDescriptor<JournalEntry>(\JournalEntry.date, order: .reverse)
        let descriptor = FetchDescriptor<JournalEntry>(sortBy: [sort])
        do {
            entries = try context.fetch(descriptor)
        } catch {
            print("[JournalManager] Failed to load entries: \(error) — keeping existing in-memory state")
            return
        }
    }
}

// MARK: - Environment Key
@MainActor
struct JournalManagerKey: @MainActor EnvironmentKey {
    static let defaultValue: JournalManager = JournalManager.shared
}

extension EnvironmentValues {
    @MainActor
    var journalManager: JournalManager {
        get { self[JournalManagerKey.self] }
        set { self[JournalManagerKey.self] = newValue }
    }
}
