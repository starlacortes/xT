//
//  AppNumberFormatters.swift
//  xT
//
//  Cached `NumberFormatter` instances shared across the app, mirroring
//  `AppDateFormatters`.
//
//  These replace `String(format: "%.1f", …)`, which hardcodes the US decimal
//  separator and grouping. `%.1f` renders 1000.5 as "1000.5" in every locale;
//  these render "1,000.5" or "1 000,5" as the locale requires.
//

import Foundation

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
