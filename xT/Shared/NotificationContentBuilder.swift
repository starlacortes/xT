//
//  NotificationContentBuilder.swift
//  xT
//
//  Turns a `NotificationLayout` and a `DoseContext` into the actual notification
//  content (NT1). Pure and synchronous: no `MedicationManager`, no clock, no
//  `UserDefaults` — every input is a parameter, so it can be unit-tested and so
//  the live preview can render exactly what arrives on the lock screen.
//
//  The manager builds the `DoseContext` from the regimen; the view feeds the same
//  builder a sample context. Nothing here reads health data on its own.
//
//  Copy uses `String(localized:)`; own words pass through verbatim (`.own`).
//

import Foundation
import UserNotifications

/// The regimen facts a dose reminder is allowed to name, already resolved to
/// strings by the caller. Any field the layout asks for that is `nil` here is
/// dropped from the body rather than left blank.
struct DoseContext: Equatable {
    /// Display name, e.g. "Estradiol Valerate". `nil` until a medication is chosen.
    var medication: String?
    /// Dose mass in mg.
    var amountMg: Double?
    /// The U6 method word: "Injection" / "Cream" / "Oral".
    var route: String?
    /// When the dose is due — only the time is shown.
    var scheduledDate: Date?
    /// The zone to offer next, e.g. "Right Ventrogluteal". Dropped when `nil`.
    var suggestedSite: String?

    /// Sample data for the live preview. Never drawn from the person's regimen,
    /// so the preview shows the design without surfacing their data (§08).
    static var sample: DoseContext {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return DoseContext(
            medication: String(localized: "Estradiol valerate",
                               comment: "Sample medication name in the notification layout preview"),
            amountMg: 4,
            route: String(localized: "Injection",
                          comment: "Sample administration route in the notification layout preview"),
            scheduledDate: Calendar.current.date(from: components) ?? Date(),
            suggestedSite: String(localized: "Right thigh",
                                  comment: "Sample suggested injection site in the notification layout preview")
        )
    }
}

enum NotificationContentBuilder {

    /// The body iOS shows in place of the real one when previews are hidden while
    /// locked. "Reminder" for every category — a hidden preview names nothing.
    static let hiddenPreviewPlaceholder = String(localized: "Reminder",
        comment: "Placeholder shown instead of the notification body when previews are hidden")

    // MARK: - Content

    /// The content for a dose reminder under `layout`.
    static func content(for context: DoseContext, layout: NotificationLayout) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title(for: layout)
        content.body = body(for: context, layout: layout)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier(for: layout)
        return content
    }

    /// The content for the journal reminder. It uses the chosen title style, and
    /// its body carries no health data (NT1 rule).
    static func journalContent(layout: NotificationLayout) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title(for: layout)
        content.body = ""
        content.sound = .default
        content.categoryIdentifier = NotificationType.journalReminder.rawValue
        return content
    }

    // MARK: - Category

    /// The dose category for a layout: `doseReminder.log` when the action reads
    /// "Log dose", otherwise `doseReminder.open`. Two categories, registered once,
    /// so the action title never forces a re-registration.
    static func categoryIdentifier(for layout: NotificationLayout) -> String {
        (layout.actionLogsDose ? NotificationType.doseReminderLog : NotificationType.doseReminderOpen).rawValue
    }

    /// The action button reading "Log dose".
    static let logDoseActionTitle = String(localized: "Log dose",
                                           comment: "Notification action button that opens the dose entry screen")

    /// The action button reading "Open".
    static let openActionTitle = String(localized: "Open",
                                        comment: "Notification action button that opens the dose entry screen")

    /// The action label the layout produces — "Log dose" or "Open". Both open the
    /// record-dose sheet; nothing is logged from the lock screen.
    static func actionTitle(for layout: NotificationLayout) -> String {
        layout.actionLogsDose ? logDoseActionTitle : openActionTitle
    }

    // MARK: - Title

    /// The title line. Own words are trimmed; empty (or whitespace-only) falls
    /// back to "Reminder".
    static func title(for layout: NotificationLayout) -> String {
        switch layout.title {
        case .reminder:
            return String(localized: "Reminder",
                          comment: "Notification title: names nothing about the reminder")
        case .doseReminder:
            return String(localized: "Dose reminder",
                          comment: "Notification title naming that this is a dose reminder")
        case .doseDue:
            return String(localized: "Dose due",
                          comment: "Notification title when a scheduled dose has come due")
        case .isocline:
            return String(localized: "Isocline",
                          comment: "Notification title using the app's name")
        case .own(let words):
            let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? String(localized: "Reminder",
                         comment: "Notification title: names nothing about the reminder")
                : trimmed
        }
    }

    // MARK: - Body

    /// The body line: the enabled fields joined by " · ". Medication and amount
    /// read as one unit ("Estradiol Valerate 4 mg"); a field whose data is missing
    /// is dropped. With no renderable fields the discreet fallback stands.
    static func body(for context: DoseContext, layout: NotificationLayout) -> String {
        var parts: [String] = []

        let fields = layout.fields

        // Medication + amount glue with a space; every other field is its own segment.
        let doseUnit = [
            fields.contains(.medication) ? context.medication : nil,
            fields.contains(.amount) ? amountString(context.amountMg) : nil
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        if !doseUnit.isEmpty { parts.append(doseUnit) }

        if fields.contains(.route), let route = context.route, !route.isEmpty {
            parts.append(route)
        }

        if fields.contains(.time), let date = context.scheduledDate {
            parts.append(String(localized: "due \(AppDateFormatters.time.string(from: date))",
                                comment: "Notification body: the time a dose is due, e.g. 'due 6:00 PM'"))
        }

        if fields.contains(.site), let site = context.suggestedSite, !site.isEmpty {
            parts.append(String(localized: "suggested site: \(site)",
                                comment: "Notification body: the zone to use next, e.g. 'suggested site: Right thigh'"))
        }

        guard !parts.isEmpty else {
            return String(localized: "Your scheduled entry is ready.",
                          comment: "Discreet notification body that names nothing about the reminder")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Private

    /// "4 mg" — the amount in milligrams, locale-aware.
    private static func amountString(_ amountMg: Double?) -> String? {
        guard let amountMg, amountMg > 0 else { return nil }
        let number = AppNumberFormatters.dose.string(amountMg)
        return String(localized: "\(number) mg",
                      comment: "A dose amount in milligrams on a notification, e.g. '4 mg'")
    }
}
