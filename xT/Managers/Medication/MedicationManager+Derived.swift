//
//  MedicationManager+Derived.swift
//  xT
//
//  Single definitions for values that were previously re-derived at each call site.
//
//  Three pieces of logic had drifted into many hand-written copies:
//  the effective dosing interval (seven copies), "the most recent dose matching some
//  predicate" (four copies, plus three call sites that used `first(where:)` on an
//  ascending array and therefore silently read the *oldest* dose), and the per-route
//  rotation window (written to user defaults but never read back).
//
//  Everything here is a pure function of already-loaded state, so it is cheap to call.
//

import Foundation

extension MedicationManager {

    // MARK: - Dosing interval

    /// The dosing interval in days: the user's custom frequency when set, otherwise the
    /// selected administration method's default, otherwise a weekly fallback.
    ///
    /// Method-based by contract — this one sizes the cycle *display* (the next-dose
    /// row's dot track, "Day X of N" on the time screen). Due dates and reminders use
    /// `effectiveDueIntervalDays`, which adds an ester tier on top of the same chain.
    var effectiveFrequencyDays: Int {
        if let custom = customFrequencyDays, custom > 0 { return custom }
        if let methodString = selectedAdministrationMethod,
           let method = AdministrationMethod(rawValue: methodString) {
            return method.frequencyDays
        }
        return Self.fallbackFrequencyDays
    }

    /// The interval used for *due dates*: the next-dose date, reminders, the
    /// missed-dose window, adherence, and the on-time streak. Resolution order: the
    /// user's custom frequency, then the most recently **taken** dose's ester typical
    /// interval, then the administration method's default, then weekly.
    ///
    /// Deliberately distinct from `effectiveFrequencyDays`, which stays method-based
    /// for the cycle *display* — the next-dose row draws one dot per cycle day and the
    /// time screen renders "Day X of N", and a 70-day TU cycle would make both unusable
    /// as 70 dots and 70 day-labels.
    ///
    /// TU is the case that separates the two: it is dosed every ~10 weeks, but
    /// `AdministrationMethod.injectable.frequencyDays` is 7 for everything injectable.
    /// The old arrangement (due dates on the method tier) made every TU user look like
    /// a weekly dose was overdue 3 days after their last injection. The ester tier
    /// fixes the due date without re-drawing the dot track.
    var effectiveDueIntervalDays: Int {
        guard let medication = selectedMedication else { return effectiveFrequencyDays }
        let latest = latestDose {
            $0.isActive && $0.medicationType == medication
                && DoseStatus(rawValue: $0.doseStatus) == .taken
        }
        guard let latest else { return effectiveFrequencyDays }
        return effectivePKIntervalDays(ester: latest.ester,
                                       route: latest.administrationMethod,
                                       medication: medication)
    }

    /// Interval used when neither a custom frequency nor a known method is available.
    static let fallbackFrequencyDays = 7

    /// The dosing interval the PK model should assume for a given dose, in days.
    ///
    /// Resolution order: the user's custom frequency, then the **ester's** typical
    /// interval, then the administration method's default, then weekly.
    ///
    /// Deliberately distinct from `effectiveFrequencyDays`, which has no ester tier.
    /// This one feeds the PK model (the chart window, and — until 2026-08 — the
    /// forward projection) and, via `effectiveDueIntervalDays`, every due date.
    ///
    /// TU is the case that separates the two: it is dosed every ~10 weeks, but
    /// `AdministrationMethod.injectable.frequencyDays` is 7 for everything injectable.
    func effectivePKIntervalDays(ester: String, route: String, medication: String) -> Int {
        if let custom = customFrequencyDays, custom > 0 { return custom }
        let effEster = Self.effectiveEsterName(ester: ester, route: route)
        if medication == "Estrogen", let e = MedicationEster(rawValue: effEster) {
            return e.typicalIntervalDays
        }
        if medication == "Testosterone", let e = TestosteroneEster(rawValue: effEster) {
            return e.typicalIntervalDays
        }
        if let method = AdministrationMethod(rawValue: route) {
            return method.frequencyDays
        }
        return Self.fallbackFrequencyDays
    }

    // MARK: - Chart window

    /// The chart's visible time range and sampling resolution, sized from the ester and
    /// route actually being plotted. See `PKChartWindow` for the rule and its derivation.
    ///
    /// Both consumers — `refreshState()`, which builds `recentLevels`, and
    /// `FlatGraphView.generateDensePoints()`, which builds the scrub grid — read their
    /// step from here. That is the point: the two used to compute their own, and had
    /// already drifted apart (`halfLife / 30` against `halfLife / 40`).
    ///
    /// The ester is resolved from the most recent **taken** dose, matching the filter
    /// `estimatedLevels` applies when deciding what actually contributes to the curve.
    /// With no dose logged, the route alone still resolves the oral and cream
    /// pseudo-esters; an injectable with no dose yet has no ester to read, so it falls
    /// back to an uncalibrated window.
    ///
    /// This is the **only** place `isTmaxCalibrated` gates a window. `PKChartWindow`
    /// takes an `Optional` precisely so the check cannot be half-applied elsewhere.
    func chartWindow(now: Date = Date()) -> PKChartWindow.Window {
        let medication = selectedMedication ?? ""
        let latestTaken = latestDose {
            $0.isActive && $0.medicationType == medication
                && DoseStatus(rawValue: $0.doseStatus) == .taken
        }

        let route = latestTaken?.administrationMethod
            ?? selectedAdministrationMethod
            ?? AdministrationMethod.injectable.rawValue
        let ester = latestTaken?.ester ?? ""
        let effEster = Self.effectiveEsterName(ester: ester, route: route)

        // The gate. An uncalibrated t_max (TP) or a non-finite one (the transdermal
        // routes, where ke = 0 makes the Bateman inapplicable) becomes `nil` here and
        // never reaches arithmetic.
        let tmaxDays: Double? = {
            func usable(_ value: Double, calibrated: Bool) -> Double? {
                guard calibrated, value.isFinite, value > 0 else { return nil }
                return value
            }
            if medication == "Estrogen", let e = MedicationEster(rawValue: effEster) {
                return usable(e.timeToPeakDays, calibrated: e.isTmaxCalibrated)
            }
            if medication == "Testosterone", let e = TestosteroneEster(rawValue: effEster) {
                return usable(e.timeToPeakDays, calibrated: e.isTmaxCalibrated)
            }
            return nil
        }()

        let interval = effectivePKIntervalDays(ester: ester, route: route, medication: medication)
        let cycle = PKChartWindow.compute(tmaxDays: tmaxDays,
                                          intervalDays: Double(interval),
                                          now: now)

        // X12c: the fortnight trend view fixes its own span trailing to now,
        // with this ester-tuned window's step as its floor.
        guard chartWindowMode != .cycle else { return cycle }
        return PKChartWindow.window(mode: chartWindowMode, now: now, cycle: cycle)
    }

    // MARK: - Most recent dose

    /// The most recent dose satisfying `predicate`.
    ///
    /// `doseHistory` is loaded in **ascending** date order, so `first(where:)` returns the
    /// oldest match. Always route "latest dose" lookups through this helper rather than
    /// depending on the array's ordering at the call site.
    func latestDose(matching predicate: (DoseRecord) -> Bool = { _ in true }) -> DoseRecord? {
        doseHistory.last(where: predicate)
    }

    /// The most recent active dose for the currently selected medication.
    func latestActiveDose() -> DoseRecord? {
        latestDose { $0.isActive && $0.medicationType == selectedMedication }
    }

    /// The most recent active dose that recorded injection sites, optionally scoped to a
    /// route class. Replaces four copies of the same filter/sort/first chain.
    func latestSitedDose(routeClass: RouteClass? = nil) -> DoseRecord? {
        latestDose { dose in
            guard dose.isActive, !dose.injectionSites.isEmpty else { return false }
            guard let routeClass else { return true }
            return RouteClass.from(method: dose.administrationMethod) == routeClass
        }
    }

    // MARK: - Dose lists

    /// All active (non-deleted), *taken* doses for a medication.
    ///
    /// Replaces the seven hand-written `filter(isActive, medicationType, .taken)`
    /// chains scattered through the PK and schedule extensions. `doseHistory` is
    /// maintained in ascending date order, so the ascending result needs no re-sort;
    /// the descending variant sorts explicitly.
    func activeTakenDoses(medication: String? = nil, ascending: Bool = true) -> [DoseRecord] {
        let med = medication ?? selectedMedication ?? ""
        let matches = doseHistory.filter {
            $0.isActive && $0.medicationType == med && DoseStatus(rawValue: $0.doseStatus) == .taken
        }
        return ascending ? matches : matches.sorted { $0.doseDate > $1.doseDate }
    }

    // MARK: - Rotation window

    /// User-defaults key holding the rotation window override for a route class.
    static func rotationWindowDefaultsKey(for routeClass: RouteClass) -> String {
        "mm.rotationWindow_\(routeClass.rawValue)"
    }

    /// How many days a zone should rest before it is offered again.
    /// Reads from in-memory state (loaded from UserPreferences SwiftData, synced via CloudKit).
    func rotationWindowDays(for routeClass: RouteClass) -> Int {
        switch routeClass {
        case .injection: return rotationWindowInjection > 0 ? rotationWindowInjection : routeClass.defaultRotationWindowDays
        case .topical:   return rotationWindowTopical > 0 ? rotationWindowTopical : routeClass.defaultRotationWindowDays
        case .patch:     return rotationWindowPatch > 0 ? rotationWindowPatch : routeClass.defaultRotationWindowDays
        case .oral:      return 0
        }
    }
}
