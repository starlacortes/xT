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

    /// Persist in-place edits to an existing entry (J10). The caller has already mutated
    /// the `@Model`'s fields; this saves and re-sorts the cache in case the date changed.
    func update(_ entry: JournalEntry) {
        guard let context = modelContext else { return }
        do {
            try context.save()
            loadEntries()
        } catch {
            print("[JournalManager] Failed to update entry: \(error)")
        }
    }

    /// Delete an entry (J10). Hard delete — the journal carries no audit requirement.
    func delete(_ entry: JournalEntry) {
        guard let context = modelContext else { return }
        context.delete(entry)
        do {
            try context.save()
            entries.removeAll { $0.id == entry.id }
        } catch {
            print("[JournalManager] Failed to delete entry: \(error)")
        }
    }

    /// Most recent entry (`entries` is kept newest-first).
    var lastEntry: JournalEntry? {
        entries.first
    }

    // MARK: - Home/Journal projections (J2, J3)

    /// Whether the top of the Journal is a "now" card or an invitation (J3). It's a card
    /// only when the newest entry is from today; otherwise the ghost card shows.
    var topSlot: JournalTopSlot {
        if let first = entries.first, Calendar.current.isDateInToday(first.date) {
            return .card(first)
        }
        return .ghost
    }

    /// The calendar days within `interval` that carry at least one entry — the week strip's
    /// hollow entry dot (J2).
    func entryDays(in interval: DateInterval, calendar: Calendar = .current) -> Set<Date> {
        Set(
            entries
                .filter { interval.contains($0.date) }
                .map { calendar.startOfDay(for: $0.date) }
        )
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
