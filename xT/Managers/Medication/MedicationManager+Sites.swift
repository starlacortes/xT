//
//  MedicationManager+Sites.swift
//  xT
//
//  Injection site tracking and avoid-zone management extensions.
//

import Foundation

/// A dose's site usage reduced to plain values, so it can safely cross an actor boundary.
///
/// `DoseRecord` is a SwiftData `@Model` bound to the main context, and reading
/// `injectionSites` decodes `injectionSitesJSON` off the managed object — that has to
/// happen on the main actor before any background work touches it.
private struct SiteUsageSnapshot {
    let doseDate: Date
    let sites: [InjectionSite]
}

extension MedicationManager {

// MARK: - Injection Site Tracking Methods
    /// Returns the injection sites from the most recent dose (if any).
    var lastInjectionSites: [InjectionSite]? { latestSitedDose()?.injectionSites }

    /// Returns the doseDate of the most recent dose that has injection sites.
    /// Use this instead of InjectionSite.lastUsedDate for rotation-safety timing.
    var lastInjectionSiteDoseDate: Date? { latestSitedDose()?.doseDate }

    /// Route-scoped variant: returns only sites from doses matching the given route class.
    func lastInjectionSites(for routeClass: RouteClass) -> [InjectionSite]? {
        latestSitedDose(routeClass: routeClass)?.injectionSites
    }

    /// Route-scoped variant of `lastInjectionSiteDoseDate`.
    func lastInjectionSiteDoseDate(for routeClass: RouteClass) -> Date? {
        latestSitedDose(routeClass: routeClass)?.doseDate
    }

    /// Async background precompute of injection site usage heat map.
    /// Cached by routeClass + windowDays; invalidated after each dose record.
    ///
    /// Main-actor isolated on purpose. It touches `doseHistory` (SwiftData `@Model`
    /// objects, which are bound to the main context) and mutates `heatMapCache`, so both
    /// the setup before the detached task and the cache write after it must run on the
    /// main actor. Only the pure counting work crosses to the background.
    @MainActor
    func injectionSiteHeatMap(for routeClass: RouteClass) async -> [String: Int] {
        let windowDays = routeClass.heatMapWindowDays
        guard windowDays > 0 else { return [:] }

        let cacheKey = "\(routeClass.rawValue)_\(windowDays)"
        if let cached = heatMapCache[cacheKey] { return cached }

        // Decode the managed objects here, on the main actor, and hand the background task
        // nothing but value types.
        let snapshot = doseHistory
            .filter { $0.isActive }
            .map { SiteUsageSnapshot(doseDate: $0.doseDate, sites: $0.injectionSites) }

        let counts = await Task.detached(priority: .utility) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()
            var counts: [String: Int] = [:]

            for dose in snapshot {
                for site in dose.sites {
                    let activeEnd = Calendar.current.date(
                        byAdding: .day, value: site.durationDays, to: dose.doseDate
                    ) ?? dose.doseDate
                    if activeEnd >= cutoff {
                        counts[site.zoneLabel, default: 0] += 1
                    }
                }
            }
            return counts
        }.value

        heatMapCache[cacheKey] = counts
        return counts
    }

    /// Invalidate the heat map cache (called after any dose mutation).
    func invalidateHeatMapCache() {
        heatMapCache.removeAll()
    }

    /// Returns set of zone labels used within the given number of days,
    /// accounting for patch/topical durationDays.
    func recentlyUsedZones(withinDays: Int) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
        return Set(doseHistory
            .filter { $0.isActive }
            .flatMap { dose in
                dose.injectionSites.filter { site in
                    let activeEnd = Calendar.current.date(
                        byAdding: .day, value: site.durationDays, to: dose.doseDate
                    ) ?? dose.doseDate
                    return activeEnd >= cutoff
                }.map { $0.zoneLabel }
            }
        )
    }

    /// Replace a dose's site with corrected values, preserving the original sites
    /// in the new record's `originalSiteJSON` field for audit trail.
    func replaceDoseWithCorrectedSite(originalDose: DoseRecord, newSites: [InjectionSite]) {
        let originalId    = originalDose.id
        let originalSites = originalDose.injectionSites
        softDeleteDose(id: originalId)
        addDose(
            date: originalDose.doseDate,
            type: originalDose.medicationType,
            ester: originalDose.ester,
            method: originalDose.administrationMethod,
            doseAmount: originalDose.doseAmount,
            concentrationMgPerMl: originalDose.concentrationMgPerMl,
            notes: originalDose.notes,
            injectionSites: newSites,
            isUserCorrected: true,
            originalDoseId: originalId,
            originalSites: originalSites
        )
    }

    // MARK: - Avoid Zone Management

    /// Mark a zone as "avoid" with an optional reason. Persists to UserDefaults.
    func markZoneAsAvoid(_ zone: String, reason: String = "") {
        avoidZones[zone] = AvoidZoneInfo(zoneLabel: zone, reason: reason, markedAt: Date())
        persistAvoidZones()
    }

    /// Remove a zone from the avoid list.
    func unmarkAvoidZone(_ zone: String) {
        avoidZones.removeValue(forKey: zone)
        persistAvoidZones()
    }

    private func persistAvoidZones() {
        persistUserPreferences()
    }
}

