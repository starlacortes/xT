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
    var effectiveFrequencyDays: Int {
        if let custom = customFrequencyDays, custom > 0 { return custom }
        if let methodString = selectedAdministrationMethod,
           let method = AdministrationMethod(rawValue: methodString) {
            return method.frequencyDays
        }
        return Self.fallbackFrequencyDays
    }

    /// `effectiveFrequencyDays` as a `Double`, for interval arithmetic.
    var effectiveFrequencyDaysValue: Double { Double(effectiveFrequencyDays) }

    /// Interval used when neither a custom frequency nor a known method is available.
    static let fallbackFrequencyDays = 7

    /// The dosing interval the PK model should assume for a given dose, in days.
    ///
    /// Resolution order: the user's custom frequency, then the **ester's** typical
    /// interval, then the administration method's default, then weekly.
    ///
    /// Deliberately distinct from `effectiveFrequencyDays`, which has no ester tier and
    /// is load-bearing for next-dose due dates (`calculateNextDoseDate()`), the schedule
    /// summary, and notification scheduling (`NotificationManager.doseFrequencyDays`).
    /// Giving *that* property an ester tier would silently move every user's due date.
    /// This one is for model sizing only — the single-dose forward projection in
    /// `estimatedLevels` and the chart window — where the ester is the better predictor.
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
        return PKChartWindow.compute(tmaxDays: tmaxDays,
                                     intervalDays: Double(interval),
                                     now: now)
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

    // MARK: - Rotation window

    /// User-defaults key holding the rotation window override for a route class.
    static func rotationWindowDefaultsKey(for routeClass: RouteClass) -> String {
        "mm.rotationWindow_\(routeClass.rawValue)"
    }

    /// How many days a zone should rest before it is offered again.
    ///
    /// Reads the user's per-route override when one has been set, falling back to the
    /// route's clinical default. The override was previously written by the schedule
    /// settings screen but never read anywhere, so the setting had no effect.
    func rotationWindowDays(for routeClass: RouteClass) -> Int {
        let key = Self.rotationWindowDefaultsKey(for: routeClass)
        let stored = defaults.integer(forKey: key)
        return stored > 0 ? stored : routeClass.defaultRotationWindowDays
    }
}
