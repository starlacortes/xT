//
//  AppFormatters.swift
//  xT
//
//  Cached `DateFormatter` and `NumberFormatter` instances shared across the app.
//  (Merged from AppDateFormatters.swift and AppNumberFormatters.swift — two files
//  with one job each and a mirrored header comment.)
//
//  `DateFormatter` initialization is roughly two orders of magnitude more expensive
//  than calling `string(from:)` on an existing one. Several views were constructing a
//  formatter inside `body` — some inside a `ForEach` — which meant a fresh allocation
//  per row per render.
//
//  `AppNumberFormatters` replaces `String(format: "%.1f", …)`, which hardcodes the US
//  decimal separator and grouping. `%.1f` renders 1000.5 as "1000.5" in every locale;
//  these render "1,000.5" or "1 000,5" as the locale requires.
//

import Foundation

enum AppDateFormatters {

    /// Builds a formatter from a *template*, letting the locale choose field order
    /// and punctuation. A fixed `dateFormat` would render "Mar 4, 2026" in every
    /// locale; a template renders "4 mars 2026" where that is correct.
    private static func templated(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    /// "Mar 4" — compact day label for chips, timelines and axis ticks.
    static let monthDay: DateFormatter = templated("MMMd")

    /// "Mar 4, 2026" — dated rows in history and export summaries.
    static let monthDayYear: DateFormatter = templated("MMMdyyyy")

    /// "March 2026" — month headings and blood-test scheduling copy.
    static let monthYear: DateFormatter = templated("MMMMyyyy")

    /// "Wednesday" — weekday name for the next-dose row.
    static let weekday: DateFormatter = templated("EEEE")

    /// "Wed" — abbreviated weekday for dense schedule strips.
    static let weekdayShort: DateFormatter = templated("EEE")

    /// "Oct" — abbreviated month for long-horizon chart rules.
    static let monthShort: DateFormatter = templated("MMM")

    /// "Wed, Mar 4" — journal entry headers.
    static let weekdayShortMonthDay: DateFormatter = templated("EEEMMMd")

    /// "Wednesday, Mar 4" — journal detail and composer headers.
    static let weekdayMonthDay: DateFormatter = templated("EEEEMMMd")

    /// "Wednesday, March 4" — the composer's full-width date line.
    static let weekdayLongMonthDay: DateFormatter = templated("EEEEMMMMd")

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
}

enum AppNumberFormatters {

    private static func decimal(min: Int, max: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = min
        f.maximumFractionDigits = max
        return f
    }

    /// Dose mass in mg — "4", "2.5", "0.05".
    /// Trailing zeros are dropped so a whole dose reads "4 mg", not "4.0 mg".
    static let dose: NumberFormatter = decimal(min: 0, max: 2)

    /// Injection volume in mL — "0.125". Needs three places at low concentrations.
    static let volume: NumberFormatter = decimal(min: 0, max: 3)

    /// Concentration in mg/mL — "40", "200".
    static let concentration: NumberFormatter = decimal(min: 0, max: 1)

    /// Hormone level — "142", "1,000". Whole units; the model is not precise
    /// enough for decimals to carry meaning.
    static let hormoneLevel: NumberFormatter = decimal(min: 0, max: 0)

    /// Dose intensity multiplier — "1.25" (rendered with a following "×").
    static let multiplier: NumberFormatter = decimal(min: 0, max: 2)

    /// Percentage as a whole number — "83".
    static let percent: NumberFormatter = decimal(min: 0, max: 0)

    /// Whole-number month count — "14", "120". Separate from `percent` so the
    /// two formatters can diverge in future without touching the adherence display.
    static let months: NumberFormatter = decimal(min: 0, max: 0)
}

extension NumberFormatter {
    /// Formats a value, falling back to a plain description if the formatter
    /// somehow returns nil (it does not for finite doubles, but the API is optional).
    func string(_ value: Double) -> String {
        string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func string(_ value: Int) -> String {
        string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
