//
//  MedicationManager+HomeData.swift
//  xT
//
//  The headless data layer the Home instrument reads from (elements H-D1–H-D5).
//  Every field the rebuilt Home UI consumes is modeled and unit-tested here, before
//  any of that UI exists. Nothing in this file draws; it is a pure projection of
//  already-loaded manager state, so it is cheap to call from a view body.
//
//  Two long-standing bugs are fixed on the way through: the dose day-state (`DoseDayState`)
//  replaces the "Today" computation that fired a day early and on the wrong interval
//  tier, and the range band (`RangeBand`) is nil unless the user actually set a range —
//  clinical defaults are not "your range".
//

import Foundation

extension MedicationManager {

    // MARK: - H-D1 · Dose day state

    /// Where the dosing schedule sits relative to today. Drives the overlay card's
    /// dose section (H11) and replaces `NextDoseRowView`'s "Today" logic, which read
    /// `completedDays >= cycleDays` on the method display tier and so showed "Today" a
    /// day early (always for daily routes, from day 6 for TU).
    ///
    /// The associated `Date` is always `nextDoseDate`, carried so the UI can format the
    /// countdown or the past-tense chip without re-reading the manager.
    enum DoseDayState: Equatable {
        /// Not fully configured, or no next-dose date yet.
        case unscheduled
        /// Next dose is after the end of today → compact "Next dose" row.
        case upcoming(Date)
        /// Next dose falls within today and has not yet passed.
        case dueToday(Date)
        /// Now is at or past the next-dose date, inside or beyond the grace window
        /// (X14 folds the old "missed" state in here with a neutral past-tense chip).
        case overdue(Date)
    }

    /// Classifies the schedule for `now`. Uses only `nextDoseDate`, the calendar, and
    /// `isFullyConfigured` — after a dose is logged `addDose` advances `nextDoseDate`,
    /// so the state becomes `.upcoming` with no special case.
    func doseDayState(now: Date = .now, calendar: Calendar = .current) -> DoseDayState {
        guard isFullyConfigured, let next = nextDoseDate else { return .unscheduled }

        // Overdue the instant the due date passes. The grace window governs the
        // "Missed" *label* (`hasMissedDose`), not whether the dose is overdue — X14.
        if now >= next { return .overdue(next) }

        // now < next from here. "Within today" means before the start of tomorrow.
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1,
                                             to: calendar.startOfDay(for: now)) ?? next
        return next < startOfTomorrow ? .dueToday(next) : .upcoming(next)
    }

    // MARK: - H-D2 · Cycle phase markers

    /// A single event on the phase strip under the curve (H9).
    ///
    /// `id` is the `Kind`, so at most one marker of each kind exists in a result — the
    /// strip never shows two "Peak" chips.
    struct PhaseMarker: Identifiable, Equatable {
        enum Kind { case dose, peak, trough, today }
        var id: Kind { kind }
        let date: Date
        let kind: Kind
    }

    /// The dose / peak / trough / today markers for the current cycle, sorted by date.
    ///
    /// - `dose` is the last dose date, `trough` is the next dose date (the lowest point
    ///   before it under no forward projection), `today` is `now`.
    /// - `peak` is `lastDose + tmax(ester)`, **omitted** when the ester's t_max isn't
    ///   calibrated (TP, the transdermal routes) — the honesty rule.
    /// - When another marker falls on today's calendar day, `today` absorbs it: only
    ///   `today` is returned for that day (the UI recovers the absorbed label as a
    ///   subtitle from the raw dates).
    /// - Empty for daily routes (`effectiveDueIntervalDays < PhaseStrip.minIntervalDays`),
    ///   which hides the strip (X11).
    func cyclePhaseMarkers(now: Date = .now, calendar: Calendar = .current) -> [PhaseMarker] {
        guard isFullyConfigured,
              effectiveDueIntervalDays >= PhaseStrip.minIntervalDays,
              let lastDose = lastDoseDate,
              let nextDose = nextDoseDate
        else { return [] }

        var markers: [PhaseMarker] = [
            PhaseMarker(date: lastDose, kind: .dose),
            PhaseMarker(date: nextDose, kind: .trough),
            PhaseMarker(date: now, kind: .today),
        ]
        if let peak = peakMarkerDate(after: lastDose) {
            markers.append(PhaseMarker(date: peak, kind: .peak))
        }

        // `today` absorbs any marker that shares its calendar day.
        let todayStart = calendar.startOfDay(for: now)
        markers = markers.filter { marker in
            marker.kind == .today || calendar.startOfDay(for: marker.date) != todayStart
        }
        return markers.sorted { $0.date < $1.date }
    }

    /// `lastDose + tmax` for the most recent taken dose's ester, or nil when t_max is
    /// uncalibrated / non-finite, or when there is no taken dose to read an ester from.
    private func peakMarkerDate(after lastDose: Date) -> Date? {
        let medication = selectedMedication ?? ""
        guard let taken = latestDose(matching: {
            $0.isActive && $0.medicationType == medication
                && DoseStatus(rawValue: $0.doseStatus) == .taken
        }) else { return nil }

        let effEster = Self.effectiveEsterName(ester: taken.ester, route: taken.administrationMethod)
        let tmaxDays: Double?
        if medication == "Estrogen", let e = MedicationEster(rawValue: effEster) {
            tmaxDays = e.isTmaxCalibrated ? e.timeToPeakDays : nil
        } else if medication == "Testosterone", let e = TestosteroneEster(rawValue: effEster) {
            tmaxDays = e.isTmaxCalibrated ? e.timeToPeakDays : nil
        } else {
            tmaxDays = nil
        }

        guard let tmaxDays, tmaxDays.isFinite, tmaxDays > 0 else { return nil }
        return lastDose.addingTimeInterval(tmaxDays * AppConstants.secondsPerDay)
    }

    // MARK: - H-D3 · Level provenance

    /// What the readout's modeled value rests on (the provenance line, §7). The copy is
    /// assembled by the presentation layer; this is the fact behind it. Never expresses
    /// a count of labs ("CALIBRATED TO N LABS" is on the never-write list, X13/U3).
    struct LevelProvenance: Equatable {
        enum Basis: Equatable {
            /// No lab on file for the selected hormone.
            case noLabs
            /// Anchored to the most recent lab, which reconciled.
            case calibrated(lastLab: Date)
            /// The most recent lab couldn't be reconciled (`calibrationAlpha` was nil).
            case labNotUsable(lastLab: Date)
        }

        /// Coarse age of a calibration lab, bucketed per `Provenance` (H-D0).
        enum LabAge: Equatable {
            case days(Int)
            case weeks(Int)
            case months(Int)
        }

        let basis: Basis
        /// Count of labs for the selected hormone only. Metadata; never rendered as a count.
        let labsOnFile: Int
    }

    /// The provenance of the current modeled level, for the selected hormone.
    ///
    /// A lab logged for the *other* hormone leaves this `.noLabs`. When labs exist, the
    /// newest one decides the basis: `.calibrated` if it reconciled, `.labNotUsable` if
    /// it didn't. The curve is drawn in full in every basis, including `.noLabs` (X8).
    var levelProvenance: LevelProvenance {
        let hormone = selectedMedication ?? ""
        let relevant = bloodTestHistory.filter { $0.hormoneType == hormone }
        let count = relevant.count

        guard let newest = relevant.max(by: { $0.drawDate < $1.drawDate }) else {
            return LevelProvenance(basis: .noLabs, labsOnFile: 0)
        }
        let basis: LevelProvenance.Basis = newest.isCalibrated
            ? .calibrated(lastLab: newest.drawDate)
            : .labNotUsable(lastLab: newest.drawDate)
        return LevelProvenance(basis: basis, labsOnFile: count)
    }

    /// Buckets a lab's age for the provenance line: days under `Provenance.daysMaxExclusive`,
    /// then weeks under `Provenance.weeksMaxExclusive`, then months (H-D0). Pure, so the
    /// presentation layer can localize the unit and the tests can pin the bucket edges.
    static func labAge(of drawDate: Date,
                       now: Date = .now,
                       calendar: Calendar = .current) -> LevelProvenance.LabAge {
        let startDraw = calendar.startOfDay(for: drawDate)
        let startNow = calendar.startOfDay(for: now)
        let days = max(0, calendar.dateComponents([.day], from: startDraw, to: startNow).day ?? 0)

        if days < Provenance.daysMaxExclusive {
            return .days(days)
        }
        let weeks = days / 7
        if weeks < Provenance.weeksMaxExclusive {
            return .weeks(weeks)
        }
        let months = max(1, calendar.dateComponents([.month], from: startDraw, to: startNow).month ?? 0)
        return .months(months)
    }

    // MARK: - H-D4 · Range band

    /// The user's therapeutic range, as the curve canvas draws it (§6). `low` is the
    /// trough floor, `high` is the peak ceiling (X9); `troughMax` stays in the readout's
    /// "within set trough" comparison, not the band.
    struct RangeBand: Equatable {
        let low: Double
        let high: Double
        let unit: HormoneUnit
    }

    /// The range band, or nil when the user has set no range.
    ///
    /// Nil whenever `userTherapeuticTarget` is nil — clinical defaults are not "your
    /// range", matching the presentation layer's existing rule.
    var rangeBand: RangeBand? {
        guard let target = userTherapeuticTarget else { return nil }
        let unit: HormoneUnit = (MedicationType(rawValue: selectedMedication ?? "") == .testosterone)
            ? .nanogramsPerDeciliter
            : .picogramsPerMilliliter
        return RangeBand(low: target.troughMin, high: target.peakCeiling, unit: unit)
    }

    // MARK: - H-D5 · Lab points

    /// A measured lab result reduced to what the curve plots.
    struct LabPoint: Equatable {
        let date: Date
        let measured: Double
    }

    /// The selected hormone's **measured** lab values whose draw date falls in `window`,
    /// oldest first. Plots the raw measurement, not the calibrated one — the lab rings
    /// on the curve (H6) are what the lab actually reported.
    func labPoints(in window: ClosedRange<Date>) -> [LabPoint] {
        let hormone = selectedMedication ?? ""
        return bloodTestHistory
            .filter { $0.hormoneType == hormone && window.contains($0.drawDate) }
            .sorted { $0.drawDate < $1.drawDate }
            .map { LabPoint(date: $0.drawDate, measured: $0.measuredLevel) }
    }
}
