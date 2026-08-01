//
//  AppDateFormatters.swift
//  xT
//
//  Cached `DateFormatter` instances shared across the app.
//
//  `DateFormatter` initialization is roughly two orders of magnitude more expensive
//  than calling `string(from:)` on an existing one. Several views were constructing a
//  formatter inside `body` — some inside a `ForEach` — which meant a fresh allocation
//  per row per render. Every formatter the app needs lives here so call sites can use
//  a `static let` instead.
//

import Foundation

enum AppDateFormatters {

    /// "Mar 4" — compact day label for chips, timelines and axis ticks.
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "Mar 4, 2026" — dated rows in history and export summaries.
    static let monthDayYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// "March 2026" — month headings and blood-test scheduling copy.
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "Wednesday" — weekday name for the next-dose row.
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    /// "Wed" — abbreviated weekday for dense schedule strips.
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    /// "9:00 AM" — locale-aware time only.
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// "Mar 4, 2026 at 9:00 AM" — full timestamp for detail sheets.
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Locale-independent `yyyy-MM-dd`, for export columns and dictionary keys.
    /// Uses a fixed locale so the output never varies by device settings.
    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Full ISO-8601 timestamp for data export.
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
