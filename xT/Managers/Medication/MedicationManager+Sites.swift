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
        // nothing but value types.  Capture `now` here so the cutoff uses the same
        // instant as the snapshot.
        let now = Date()
        let genAtCallStart = heatMapCacheGeneration
        let snapshot = doseHistory
            .filter { $0.isActive }
            .map { SiteUsageSnapshot(doseDate: $0.doseDate, sites: $0.injectionSites) }

        let counts = await Task.detached(priority: .utility) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) ?? now
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

        // Only cache if the cache was NOT invalidated while we were computing.
        if heatMapCacheGeneration == genAtCallStart {
            heatMapCache[cacheKey] = counts
        }
        return counts
    }

    /// Invalidate the heat map cache (called after any dose mutation).
    func invalidateHeatMapCache() {
        heatMapCache.removeAll()
        heatMapCacheGeneration &+= 1
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
        let originalDate  = originalDose.doseDate
        let originalType  = originalDose.medicationType
        let originalEster = originalDose.ester
        let originalMethod = originalDose.administrationMethod
        let originalAmount = originalDose.doseAmount
        let originalConc  = originalDose.concentrationMgPerMl
        let originalNotes = originalDose.notes
        softDeleteDose(id: originalId)
        addDose(
            date: originalDate,
            type: originalType,
            ester: originalEster,
            method: originalMethod,
            doseAmount: originalAmount,
            concentrationMgPerMl: originalConc,
            notes: originalNotes,
            injectionSites: newSites,
            isUserCorrected: true,
            originalDoseId: originalId,
            originalSites: originalSites
        )
    }

    // MARK: - H-D6 · Next-site suggestion

    /// The last dose's sites, when they were used, and the zone to offer next (H13).
    ///
    /// `suggested` is a **zone label**, not an `InjectionSite`: a suggestion names a
    /// zone, not a precise coordinate inside it, and that is exactly what the record-dose
    /// summary renders (`SUGGESTED · RIGHT THIGH`). (This narrows the spec's nominal
    /// `InjectionSite?` to the information the suggestion actually carries.)
    struct SiteSuggestion: Equatable {
        /// Sites from the most recent dose in this route class.
        let last: [InjectionSite]
        /// When that dose was recorded.
        let lastDate: Date?
        /// The zone to offer next, or nil for oral and for routes with no configured zones.
        let suggested: String?
    }

    /// The least-recently-used eligible zone for the given route, with the last dose's
    /// sites for context.
    ///
    /// Eligible = `(preferred ∪ recommended) − avoid`, scored over the route's
    /// `heatMapWindowDays` window. The least recently used zone wins; a zone never used
    /// in the window counts as maximally stale. Ties break toward the opposite side from
    /// the last site, which yields a natural left/right rotation. Returns `nil` for
    /// `suggested` on oral and whenever no zone is eligible.
    func siteSuggestion(routeClass: RouteClass) -> SiteSuggestion {
        let last = lastInjectionSites(for: routeClass) ?? []
        let lastDate = lastInjectionSiteDoseDate(for: routeClass)

        guard routeClass != .oral else {
            return SiteSuggestion(last: last, lastDate: lastDate, suggested: nil)
        }

        // Candidate zones, preferred first, then recommended extras, minus avoids,
        // order-preserving so rotation is deterministic.
        let preferred = ZoneCentroidStore.preferredZones(medication: selectedMedication ?? "",
                                                          routeClass: routeClass)
        let recommended = ZoneCentroidStore.recommendedZones(for: routeClass)
        var seen = Set<String>()
        let candidates = (preferred + recommended).filter { label in
            guard avoidZones[label] == nil else { return false }
            return seen.insert(label).inserted
        }
        guard !candidates.isEmpty else {
            return SiteSuggestion(last: last, lastDate: lastDate, suggested: nil)
        }

        // Most recent use of each candidate within the window; absent = never used.
        let windowDays = routeClass.heatMapWindowDays
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) ?? now
        var lastUsed: [String: Date] = [:]
        for dose in doseHistory where dose.isActive
            && RouteClass.from(method: dose.administrationMethod) == routeClass
            && dose.doseDate >= cutoff {
            for site in dose.injectionSites {
                if let existing = lastUsed[site.zoneLabel], existing >= dose.doseDate { continue }
                lastUsed[site.zoneLabel] = dose.doseDate
            }
        }

        // Least recently used (never-used sorts as `.distantPast`), keeping ties.
        let staleness: (String) -> Date = { lastUsed[$0] ?? .distantPast }
        let oldest = candidates.map(staleness).min() ?? .distantPast
        let leastRecent = candidates.filter { staleness($0) == oldest }

        let suggested: String
        if leastRecent.count == 1 {
            suggested = leastRecent[0]
        } else if let preferredSide = Self.oppositeSide(of: last.first?.zoneLabel),
                  let opposite = leastRecent.first(where: { Self.side(of: $0) == preferredSide }) {
            suggested = opposite
        } else {
            suggested = leastRecent[0]
        }
        return SiteSuggestion(last: last, lastDate: lastDate, suggested: suggested)
    }

    /// The body side a zone label names, read from the "Left"/"Right" token in it, or
    /// nil for midline zones (e.g. "Periumbilical", "Neck").
    private static func side(of zoneLabel: String?) -> String? {
        guard let zoneLabel else { return nil }
        if zoneLabel.contains("Left") { return "Left" }
        if zoneLabel.contains("Right") { return "Right" }
        return nil
    }

    /// The side opposite the one the label names, for the rotation tie-break.
    private static func oppositeSide(of zoneLabel: String?) -> String? {
        switch side(of: zoneLabel) {
        case "Left":  return "Right"
        case "Right": return "Left"
        default:      return nil
        }
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

