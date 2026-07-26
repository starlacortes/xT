//
//  MedicationManager+Sites.swift
//  xT
//
//  Injection site tracking and avoid-zone management extensions.
//

import Foundation

extension MedicationManager {

// MARK: - Injection Site Tracking Methods
    /// Returns the injection sites from the most recent dose (if any).
    var lastInjectionSites: [InjectionSite]? {
        doseHistory
            .filter { $0.isActive && !$0.injectionSites.isEmpty }
            .sorted { $0.doseDate > $1.doseDate }
            .first?
            .injectionSites
    }

    /// Returns the doseDate of the most recent dose that has injection sites.
    /// Use this instead of InjectionSite.lastUsedDate for rotation-safety timing.
    var lastInjectionSiteDoseDate: Date? {
        doseHistory
            .filter { $0.isActive && !$0.injectionSites.isEmpty }
            .sorted { $0.doseDate > $1.doseDate }
            .first?
            .doseDate
    }

    /// Route-scoped variant: returns only sites from doses matching the given route class.
    func lastInjectionSites(for routeClass: RouteClass) -> [InjectionSite]? {
        doseHistory
            .filter { $0.isActive && !$0.injectionSites.isEmpty }
            .filter { RouteClass.from(method: $0.administrationMethod) == routeClass }
            .sorted { $0.doseDate > $1.doseDate }
            .first?
            .injectionSites
    }

    /// Route-scoped variant of lastInjectionSiteDoseDate.
    func lastInjectionSiteDoseDate(for routeClass: RouteClass) -> Date? {
        doseHistory
            .filter { $0.isActive && !$0.injectionSites.isEmpty }
            .filter { RouteClass.from(method: $0.administrationMethod) == routeClass }
            .sorted { $0.doseDate > $1.doseDate }
            .first?
            .doseDate
    }

    /// Async background precompute of injection site usage heat map.
    /// Cached by routeClass + windowDays; invalidated after each dose record.
    func injectionSiteHeatMap(for routeClass: RouteClass) async -> [String: Int] {
        let windowDays = routeClass.heatMapWindowDays
        guard windowDays > 0 else { return [:] }

        let cacheKey = "\(routeClass.rawValue)_\(windowDays)"
        if let cached = heatMapCache[cacheKey] { return cached }

        let history = doseHistory
        let counts = await Task.detached(priority: .utility) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()
            var counts: [String: Int] = [:]

            for dose in history where dose.isActive {
                for site in dose.injectionSites {
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

        await MainActor.run { heatMapCache[cacheKey] = counts }
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
        let originalSites = originalDose.injectionSites
        removeDose(withId: originalDose.id)
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
            originalDoseId: originalDose.id,
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
        guard let data = try? JSONEncoder().encode(avoidZones) else { return }
        UserDefaults.standard.set(data, forKey: "injectionSiteAvoidZones")
    }

    func loadAvoidZones() {
        guard let data = UserDefaults.standard.data(forKey: "injectionSiteAvoidZones"),
              let zones = try? JSONDecoder().decode([String: AvoidZoneInfo].self, from: data)
        else { return }
        avoidZones = zones
    }
}
