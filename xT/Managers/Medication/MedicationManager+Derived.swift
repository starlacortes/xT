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
