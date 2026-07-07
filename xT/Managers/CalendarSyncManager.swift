//
//  CalendarSyncManager.swift
//  xT
//
//  EventKit integration for syncing scheduled dose dates to system Calendar.
//  Creates all-day events for upcoming doses so users see them in their calendar.
//

import Foundation
import EventKit
import SwiftUI

@MainActor
final class CalendarSyncManager: ObservableObject {

    static let shared = CalendarSyncManager()

    @Published var isAuthorized: Bool = false
    @Published var lastSyncDate: Date?

    private let eventStore = EKEventStore()
    private let calendarKey = "xT_CalendarIdentifier"

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                isAuthorized = granted
                return granted
            } catch {
                isAuthorized = false
                return false
            }
        case .authorized, .fullAccess:
            isAuthorized = true
            return true
        case .denied, .restricted, .writeOnly:
            isAuthorized = false
            return false
        @unknown default:
            isAuthorized = false
            return false
        }
    }

    // MARK: - Calendar Management

    /// Returns the app's dedicated calendar (creates if missing).
    private func getOrCreateCalendar() -> EKCalendar? {
        // Check if we have a saved calendar ID
        if let savedId = UserDefaults.standard.string(forKey: calendarKey),
           let existing = eventStore.calendar(withIdentifier: savedId) {
            return existing
        }

        // Create a new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "xT Doses"
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
        calendar.cgColor = UIColor(red: 0.831, green: 0.325, blue: 0.494, alpha: 1.0).cgColor // Theme accent

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarKey)
            return calendar
        } catch {
            // Fall back to default calendar
            return eventStore.defaultCalendarForNewEvents
        }
    }

    // MARK: - Sync

    /// Syncs upcoming scheduled doses to the calendar.
    /// Removes stale events and creates new ones for the next 90 days.
    func syncUpcomingDoses(
        doseHistory: [DoseRecord],
        frequencyDays: Int,
        lastDoseDate: Date?,
        medicationType: String,
        ester: String,
        doseAmount: Double
    ) async {
        guard await requestAccess() else { return }
        guard let calendar = getOrCreateCalendar() else { return }
        guard let lastDose = lastDoseDate ?? doseHistory.filter({ DoseStatus(rawValue: $0.doseStatus) == .taken }).first?.doseDate else { return }

        // Remove all existing xT events for the upcoming window
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 90, to: now) else { return }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate).filter { $0.notes?.contains("xT dose event") == true }

        for event in existingEvents {
            do { try eventStore.remove(event, span: .thisEvent) }
            catch { /* best effort */ }
        }

        // Calculate upcoming dose dates
        let interval = TimeInterval(frequencyDays * 86400)
        var upcomingDates: [Date] = []
        var cursor = lastDose
        let maxDoses = Int(ceil(90.0 / Double(frequencyDays))) + 1

        for i in 1..<maxDoses {
            cursor = lastDose.addingTimeInterval(interval * Double(i))
            if cursor > endDate { break }
            if cursor > now {
                upcomingDates.append(cursor)
            }
        }

        // Create calendar events
        for doseDate in upcomingDates {
            let event = EKEvent(eventStore: eventStore)
            event.title = "💉 \(medicationType) — \(ester)"
            event.notes = "xT dose event — \(String(format: "%.1f", doseAmount)) mg.\nLogged automatically by the xT app."
            event.startDate = doseDate
            event.endDate = doseDate
            event.isAllDay = true
            event.calendar = calendar

            // Add alarm at 9 AM
            let alarm = EKAlarm(relativeOffset: 0)
            event.addAlarm(alarm)

            do { try eventStore.save(event, span: .thisEvent) }
            catch { /* best effort per event */ }
        }

        lastSyncDate = Date()
    }

    /// Removes all xT dose events from the calendar.
    func removeAllDoseEvents() async {
        guard isAuthorized, let calendar = getOrCreateCalendar() else { return }

        let now = Date()
        guard let farFuture = Calendar.current.date(byAdding: .year, value: 1, to: now) else { return }

        let predicate = eventStore.predicateForEvents(withStart: now, end: farFuture, calendars: [calendar])
        let events = eventStore.events(matching: predicate).filter { $0.notes?.contains("xT dose event") == true }

        for event in events {
            try? eventStore.remove(event, span: .thisEvent)
        }
    }
}