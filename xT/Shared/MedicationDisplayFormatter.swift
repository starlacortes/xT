//
//  MedicationDisplayFormatter.swift
//  xT
//
//  The instrument-label layer for Home (element H2). `HormoneLevelPresentation` turns a
//  `HormoneLevel` into prose; this file turns the *regimen* into the short mono-caps
//  labels the rebuilt Home reads — the readout eyebrow, the dose card's medication line,
//  and the provenance line under the number.
//
//  Everything here returns natural-case strings; the views apply the mono-caps rule with
//  `.eyebrow()` / `.statLabel()` / `.monoLabel()`, so translations keep their own casing.
//  Nothing draws, and nothing is judgemental — these are positional, factual labels.
//

import Foundation

@MainActor
enum MedicationDisplayFormatter {

    // MARK: - Regimen name

    /// The hormone + ester chemical name, e.g. "Estradiol Valerate" / "Testosterone
    /// Cypionate". `nil` until a medication is selected. The ester is read from the most
    /// recent taken dose (resolved for route), falling back to the configured ester.
    static func medicationName(_ m: MedicationManager) -> String? {
        guard let medication = m.selectedMedication else { return nil }
        let base = hormoneBase(medication)
        guard let ester = esterWord(for: m) else { return base }
        return "\(base) \(ester)"
    }

    /// The readout eyebrow: `ESTRADIOL VALERATE · DAY 3 OF 7`. The day clause is omitted
    /// for daily routes (interval below `PhaseStrip.minIntervalDays`), matching the phase
    /// strip's hidden-for-daily rule.
    static func readoutEyebrow(_ m: MedicationManager,
                               now: Date = .now,
                               calendar: Calendar = .current) -> String? {
        guard let name = medicationName(m) else { return nil }

        let interval = m.effectiveDueIntervalDays
        guard interval >= PhaseStrip.minIntervalDays, let day = dayOfInterval(m, now: now, calendar: calendar) else {
            return name
        }
        let clause = String(localized: "Day \(day) of \(interval)",
                            comment: "Where today falls in the dosing interval, shown mid-eyebrow: 'ESTRADIOL VALERATE · DAY 3 OF 7'")
        return "\(name) · \(clause)"
    }

    /// The dose card's medication line: `ESTRADIOL VALERATE 4 MG · INJECTION`. The route is
    /// the method word (INJECTION / CREAM / ORAL) — the schema carries no SC/IM distinction
    /// to show (U6). `nil` until configured.
    static func medicationLine(_ m: MedicationManager) -> String? {
        guard let name = medicationName(m) else { return nil }
        guard let method = methodWord(for: m) else { return name }

        if let amount = doseAmountString(for: m) {
            return "\(name) \(amount) · \(method)"
        }
        return "\(name) · \(method)"
    }

    // MARK: - Provenance line

    /// The provenance line under the readout number (§7). States what the modeled value
    /// rests on — never a count of labs (X13/U3).
    static func provenanceLine(_ provenance: MedicationManager.LevelProvenance,
                               now: Date = .now,
                               calendar: Calendar = .current) -> String {
        switch provenance.basis {
        case .noLabs:
            return String(localized: "Modeled · No labs yet",
                          comment: "Provenance line: the level is modeled with no lab to calibrate against")
        case .calibrated(let lastLab):
            let date = AppDateFormatters.monthDay.string(from: lastLab)
            return String(localized: "Modeled · Calibrated to your lab of \(date)",
                          comment: "Provenance line: the level is calibrated to the user's most recent lab draw")
        case .labNotUsable:
            return String(localized: "Modeled · Last lab not used for calibration",
                          comment: "Provenance line: a lab exists but could not reconcile with the model")
        }
    }

    /// The provenance line while scrubbing: `MODELED · FRI 2:00 PM`. Replaces the "Estimated"
    /// caption during a scrub.
    static func scrubProvenanceLine(_ date: Date) -> String {
        let day = AppDateFormatters.weekdayShort.string(from: date)
        let time = AppDateFormatters.time.string(from: date)
        let stamp = "\(day) \(time)"
        return String(localized: "Modeled · \(stamp)",
                      comment: "Provenance line while scrubbing the curve, showing the scrubbed time")
    }

    // MARK: - Private

    /// Estrogen's measured hormone is estradiol; testosterone is itself.
    private static func hormoneBase(_ medication: String) -> String {
        medication == "Estrogen"
            ? String(localized: "Estradiol", comment: "Hormone name for the estrogen regimen readout")
            : medication
    }

    /// The ester chemical word for the current regimen, route-resolved. "Valerate (EV)"
    /// → "Valerate"; oral / cream pseudo-esters render their route word.
    private static func esterWord(for m: MedicationManager) -> String? {
        let latest = m.latestActiveDose()
        let rawEster = latest?.ester ?? m.selectedEster ?? ""
        let route = latest?.administrationMethod ?? m.selectedAdministrationMethod ?? ""
        let effective = MedicationManager.effectiveEsterName(ester: rawEster, route: route)
        let trimmed = effective.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Strip a trailing "(EV)" / "(TC)" shortcode, keeping the chemical word.
        if let paren = trimmed.firstIndex(of: "(") {
            return String(trimmed[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    /// INJECTION / CREAM / ORAL from the active method, or the configured one.
    private static func methodWord(for m: MedicationManager) -> String? {
        let raw = m.latestActiveDose()?.administrationMethod ?? m.selectedAdministrationMethod
        guard let raw, let method = MedicationManager.AdministrationMethod(rawValue: raw) else { return nil }
        switch method {
        case .injectable:
            return String(localized: "Injection", comment: "Administration route word on the dose card")
        case .cream:
            return String(localized: "Cream", comment: "Administration route word on the dose card")
        case .oral:
            return String(localized: "Oral", comment: "Administration route word on the dose card")
        }
    }

    /// The last dose's amount, e.g. "4 mg" / "0.1 mL"-free — amount only, in mg.
    private static func doseAmountString(for m: MedicationManager) -> String? {
        guard let amount = m.latestActiveDose()?.doseAmount, amount > 0 else { return nil }
        let number = AppNumberFormatters.dose.string(amount)
        return String(localized: "\(number) mg",
                      comment: "A dose amount in milligrams on the dose card, e.g. '4 mg'")
    }

    /// Mono dose meta for a specific record, natural case: "Estradiol Valerate 2 mg" (J6).
    /// Used on the Journal top card beside the entry time. Views apply the caps.
    static func doseMetaLine(for dose: DoseRecord) -> String {
        let base = hormoneBase(dose.medicationType)
        let effective = MedicationManager.effectiveEsterName(ester: dose.ester,
                                                             route: dose.administrationMethod)
        let esterWord: String? = {
            let trimmed = effective.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if let paren = trimmed.firstIndex(of: "(") {
                return String(trimmed[..<paren]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
        }()
        let amount = AppNumberFormatters.dose.string(dose.doseAmount)
        let name = [base, esterWord].compactMap { $0 }.joined(separator: " ")
        return String(localized: "\(name) \(amount) mg",
                      comment: "Dose meta on a journal card, e.g. 'Estradiol Valerate 2 mg'")
    }

    /// Which day of the dosing interval today is (1-based), clamped to the interval.
    private static func dayOfInterval(_ m: MedicationManager,
                                      now: Date,
                                      calendar: Calendar) -> Int? {
        guard let last = m.lastDoseDate else { return nil }
        let interval = m.effectiveDueIntervalDays
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: last),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return min(max(days + 1, 1), max(interval, 1))
    }
}
