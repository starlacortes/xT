//
//  NotificationLayout.swift
//  xT
//
//  What a dose reminder says on the lock screen (NT1 · X35). Four presets —
//  Discreet (the default), Standard, Detailed and Custom — and the one value
//  both the scheduler and the live preview read.
//
//  Discreet names nothing: no medication, no dose, no body part. The other
//  presets name progressively more, and Custom lets someone assemble the body
//  from individual fields and write their own title.
//
//  Own words are device-local by design: stored in `UserDefaults` and never
//  synced or exported (`resolvedDoseDefaults` and the CloudSync paths never see
//  this type).
//

import Foundation

struct NotificationLayout: Codable, Equatable {

    // MARK: - Preset

    /// One of the four layouts. A preset is just a named starting point; the
    /// builder reads `title`, `fields` and `actionLogsDose` regardless of it, so
    /// Custom can be any combination those three can express.
    enum Preset: String, Codable, CaseIterable, Identifiable {
        case discreet
        case standard
        case detailed
        case custom

        var id: String { rawValue }

        var displayName: LocalizedStringResource {
            switch self {
            case .discreet: return "Discreet"
            case .standard: return "Standard"
            case .detailed: return "Detailed"
            case .custom:   return "Custom"
            }
        }
    }

    // MARK: - Title

    /// The notification's title line. `.own` holds the person's own words,
    /// verbatim; an empty or whitespace-only value falls back to "Reminder".
    ///
    /// `.doseDue` is the Detailed preset's title. It is not offered as a picker
    /// option (the picker mirrors the spec's Reminder / Dose reminder / Isocline /
    /// own words), so switching Detailed → Custom seeds with `.doseReminder`.
    enum Title: Codable, Equatable, Hashable {
        case reminder
        case doseReminder
        case doseDue
        case isocline
        case own(String)

        /// The options the Custom title picker offers, in order.
        static let selectable: [Title] = [.reminder, .doseReminder, .isocline]
    }

    // MARK: - Field

    /// A body field, in the order the builder joins them.
    enum Field: String, Codable, CaseIterable, Identifiable {
        case medication
        case amount
        case route
        case time
        case site

        var id: String { rawValue }

        var displayName: LocalizedStringResource {
            switch self {
            case .medication: return "Medication"
            case .amount:     return "Amount"
            case .route:      return "Route"
            case .time:       return "Scheduled time"
            case .site:       return "Suggested site"
            }
        }
    }

    // MARK: - Stored

    var preset: Preset
    var title: Title
    var fields: Set<Field>
    var actionLogsDose: Bool

    // MARK: - Constants

    /// The most characters own words may hold. Enforced on write and clamped on
    /// load, so a value written before the limit existed still reads back bounded.
    static let ownWordsMaxLength = 40

    /// The `UserDefaults` key. Owned here so the manager's `Keys` enum and the
    /// layout agree on one string.
    static let storageKey = "notification_layout"

    // MARK: - Presets

    static let discreet = NotificationLayout(
        preset: .discreet,
        title: .reminder,
        fields: [],
        actionLogsDose: false
    )

    static let standard = NotificationLayout(
        preset: .standard,
        title: .doseReminder,
        fields: [.medication, .amount],
        actionLogsDose: true
    )

    static let detailed = NotificationLayout(
        preset: .detailed,
        title: .doseDue,
        fields: [.medication, .amount, .route, .time, .site],
        actionLogsDose: true
    )

    /// The starting point for Custom before someone edits anything: the scheduled
    /// time, and nothing that names the person's regimen.
    static let custom = NotificationLayout(
        preset: .custom,
        title: .reminder,
        fields: [.time],
        actionLogsDose: false
    )

    /// The canonical layout for a preset — what a preset pill selects.
    static func preset(_ preset: Preset) -> NotificationLayout {
        switch preset {
        case .discreet: return .discreet
        case .standard: return .standard
        case .detailed: return .detailed
        case .custom:   return .custom
        }
    }

    // MARK: - Editing

    /// Returns this layout as `Custom`, seeding from the current preset the first
    /// time Custom is entered so a tweak starts from where the person was rather
    /// than from scratch. Already-custom layouts come back unchanged.
    func asCustom() -> NotificationLayout {
        guard preset != .custom else { return self }
        return NotificationLayout(
            preset: .custom,
            title: title == .doseDue ? .doseReminder : title,
            fields: fields,
            actionLogsDose: actionLogsDose
        )
    }

    // MARK: - Normalization

    /// Clamps own words to `ownWordsMaxLength`. Applied before every save so the
    /// limit can't be bypassed by a paste.
    func normalized() -> NotificationLayout {
        guard case .own(let words) = title else { return self }
        let clamped = String(words.prefix(Self.ownWordsMaxLength))
        return NotificationLayout(preset: preset, title: .own(clamped),
                                  fields: fields, actionLogsDose: actionLogsDose)
    }

    // MARK: - Persistence

    /// Reads the saved layout, or Discreet when nothing (or nothing decodable) is
    /// stored. `key` is injectable so a test can use its own suite.
    static func load(from defaults: UserDefaults = .standard,
                     key: String = storageKey) -> NotificationLayout {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationLayout.self, from: data) else {
            return .discreet
        }
        return decoded.normalized()
    }

    /// Persists this layout. `key` is injectable, matching `load(from:key:)`.
    func save(to defaults: UserDefaults = .standard, key: String = storageKey) {
        guard let data = try? JSONEncoder().encode(normalized()) else { return }
        defaults.set(data, forKey: key)
    }
}
