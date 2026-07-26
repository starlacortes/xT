//
//  InjectionSite.swift
//  xT
//
//  Created by Starla Cortes on 7/21/26.
//
//  Contains all core types for injection site tracking:
//  RouteClass, AvoidZoneInfo, InjectionSite, and zone helpers.
//
//  Schema v3 (2026-07): Added optional 3D world-space position for SceneKit body picker.
//  Backward-compatible: pre-v3 records have nil 3D fields; zoneLabel is the migration key.

import Foundation
import SwiftUI

// MARK: - Route Classification

/// Classifies administration routes for heat-map windows, rotation
/// safety thresholds, multi-site support, and duration defaults.
enum RouteClass: String, CaseIterable, Codable {
    case injection = "injection"
    case topical   = "topical"
    case patch     = "patch"
    case oral      = "oral"

    /// Number of days the heat map should look back for dose contributions.
    var heatMapWindowDays: Int {
        switch self {
        case .injection: return 30
        case .topical:   return 7
        case .patch:     return 30
        case .oral:      return 0
        }
    }

    /// Minimum days before a zone rotation warning is shown.
    var alertThreshold: Int {
        switch self {
        case .injection: return 2
        case .topical:   return 3
        case .patch:     return 1
        case .oral:      return 0
        }
    }

    /// Whether the user needs to tap on a precise coordinate inside a zone.
    /// Topical/patch routes allow broad region taps; injections need precision.
    var requiresPreciseTap: Bool {
        switch self {
        case .injection: return true
        case .topical:   return false
        case .patch:     return false
        case .oral:      return false
        }
    }

    /// Whether the route allows recording multiple sites for a single dose.
    var supportsMultiSite: Bool {
        switch self {
        case .injection: return false
        case .topical:   return true
        case .patch:     return true
        case .oral:      return false
        }
    }

    /// Human-readable display name used in settings, exports, and pill bars.
    var displayName: String {
        switch self {
        case .injection: return "Injection (IM/SubQ)"
        case .topical:   return "Topical (Gel/Cream)"
        case .patch:     return "Transdermal Patch"
        case .oral:      return "Oral"
        }
    }

    /// Default number of days a continuous-administration product remains
    /// active at a single site (0 for discrete doses like injections).
    var defaultDurationDays: Int {
        switch self {
        case .injection: return 0
        case .topical:   return 0
        case .patch:     return 7
        case .oral:      return 0
        }
    }

    /// Default rotation safety window: how long to wait before re-using a zone.
    var defaultRotationWindowDays: Int {
        switch self {
        case .injection: return 14
        case .topical:   return 7
        case .patch:     return 30
        case .oral:      return 0
        }
    }

    /// SF Symbol name used for route-class icons in settings and picker UI.
    var iconName: String {
        switch self {
        case .injection: return "syringe"
        case .topical:   return "hand.raised"
        case .patch:     return "bandage"
        case .oral:      return "pills"
        }
    }

    /// Semantic tint color for each route class (matches Theme.Colors tokens).
    var tintColor: Color {
        switch self {
        case .injection: return Color(red: 0.831, green: 0.329, blue: 0.494) // #D4537E accent
        case .topical:   return Color(red: 0.325, green: 0.290, blue: 0.718) // #534AB7 accentSecondary
        case .patch:     return Color(red: 0.831, green: 0.514, blue: 0.169) // #D4862B warning
        case .oral:      return .secondary
        }
    }

    /// Map a MedicationManager-style `administrationMethod` string to a RouteClass.
    static func from(method: String) -> RouteClass {
        let lower = method.lowercased()
        if lower.contains("inject")  { return .injection }
        if lower.contains("cream")   { return .topical }
        if lower.contains("gel")     { return .topical }
        if lower.contains("patch")   { return .patch }
        if lower.contains("oral")    { return .oral }
        if lower.contains("sublingual") { return .oral }
        return .injection
    }
}

// MARK: - Avoid Zone Info

/// Tracks zones the user has explicitly marked as unsafe or undesirable.
/// Persisted in UserDefaults as a JSON dictionary keyed by zone label.
struct AvoidZoneInfo: Codable, Equatable {
    let zoneLabel: String
    let reason: String
    let markedAt: Date

    init(zoneLabel: String, reason: String = "", markedAt: Date = Date()) {
        self.zoneLabel = zoneLabel
        self.reason = reason
        self.markedAt = markedAt
    }
}

// MARK: - Injection Site Record

/// Stores a single administration site record.
///
/// Schema v3 adds optional 3D world-space position for the SceneKit body picker.
/// Older 2D records are preserved: `zoneLabel` serves as the migration key
/// between v1-2 (normalized coords) and v3 (3D coordinates).
///
/// Serialized as a JSON array in `DoseRecord.injectionSitesJSON` for SwiftData.
struct InjectionSite: Codable, Equatable {

    // MARK: - Current Schema Version

    static let currentSchemaVersion = 3

    // MARK: - Stored Properties

    let schemaVersion: Int

    // v1-2 (2D) — preserved for backward compatibility
    let sketchId: String
    let normalizedX: Double
    let normalizedY: Double
    let viewContext: String
    let routeClass: String

    // v3 (3D) — nil for pre-v3 records
    let worldPositionX: Double?
    let worldPositionY: Double?
    let worldPositionZ: Double?
    let viewNormalX: Double?
    let viewNormalY: Double?
    let viewNormalZ: Double?

    // Shared across all versions
    let zoneLabel: String
    let bodyRegion: String
    let lastUsedDate: Date
    let durationDays: Int

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sketchId
        case normalizedX, normalizedY
        case zoneLabel, viewContext, bodyRegion, routeClass
        case lastUsedDate, durationDays
        case worldPositionX, worldPositionY, worldPositionZ
        case viewNormalX, viewNormalY, viewNormalZ
    }

    // MARK: - Graceful Decoding (all schema versions)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion  = (try? container.decode(Int.self,    forKey: .schemaVersion))  ?? 1
        sketchId       = (try? container.decode(String.self,  forKey: .sketchId))      ?? "unknown"
        normalizedX    = (try? container.decode(Double.self,  forKey: .normalizedX))   ?? 0.5
        normalizedY    = (try? container.decode(Double.self,  forKey: .normalizedY))   ?? 0.5
        zoneLabel      = (try? container.decode(String.self,  forKey: .zoneLabel))    ?? "Unknown"
        viewContext    = (try? container.decode(String.self,  forKey: .viewContext))   ?? "front"
        bodyRegion     = (try? container.decode(String.self,  forKey: .bodyRegion))    ?? "unknown"
        routeClass     = (try? container.decode(String.self,  forKey: .routeClass))    ?? "injection"
        lastUsedDate   = (try? container.decode(Date.self,    forKey: .lastUsedDate))  ?? Date()
        durationDays   = (try? container.decode(Int.self,     forKey: .durationDays))  ?? 0
        // v3 3D fields (nil for pre-v3 records)
        worldPositionX = try? container.decodeIfPresent(Double.self, forKey: .worldPositionX)
        worldPositionY = try? container.decodeIfPresent(Double.self, forKey: .worldPositionY)
        worldPositionZ = try? container.decodeIfPresent(Double.self, forKey: .worldPositionZ)
        viewNormalX    = try? container.decodeIfPresent(Double.self, forKey: .viewNormalX)
        viewNormalY    = try? container.decodeIfPresent(Double.self, forKey: .viewNormalY)
        viewNormalZ    = try? container.decodeIfPresent(Double.self, forKey: .viewNormalZ)
    }

    // MARK: - v1-2 Initializer (2D, backward-compatible)

    init(
        schemaVersion: Int = currentSchemaVersion,
        sketchId: String,
        normalizedX: Double,
        normalizedY: Double,
        zoneLabel: String,
        viewContext: String,
        bodyRegion: String,
        routeClass: String,
        lastUsedDate: Date = Date(),
        durationDays: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.sketchId = sketchId
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.zoneLabel = zoneLabel
        self.viewContext = viewContext
        self.bodyRegion = bodyRegion
        self.routeClass = routeClass
        self.lastUsedDate = lastUsedDate
        self.durationDays = durationDays
        self.worldPositionX = nil
        self.worldPositionY = nil
        self.worldPositionZ = nil
        self.viewNormalX = nil
        self.viewNormalY = nil
        self.viewNormalZ = nil
    }

    // MARK: - v3 Initializer (3D body picker)

    init(
        schemaVersion: Int = currentSchemaVersion,
        zoneLabel: String,
        bodyRegion: String,
        viewContext: String = "",
        worldPosition: (x: Double, y: Double, z: Double)?,
        viewNormal: (x: Double, y: Double, z: Double)?,
        lastUsedDate: Date = Date(),
        durationDays: Int = 0,
        routeClass: String = "injection"
    ) {
        self.schemaVersion = schemaVersion
        self.zoneLabel = zoneLabel
        self.bodyRegion = bodyRegion
        self.lastUsedDate = lastUsedDate
        self.durationDays = durationDays
        // 2D fields set to sensible defaults for v3-only records
        self.sketchId = ""
        self.normalizedX = 0
        self.normalizedY = 0
        self.viewContext = viewContext
        self.routeClass = routeClass
        // 3D fields
        self.worldPositionX = worldPosition?.x
        self.worldPositionY = worldPosition?.y
        self.worldPositionZ = worldPosition?.z
        self.viewNormalX = viewNormal?.x
        self.viewNormalY = viewNormal?.y
        self.viewNormalZ = viewNormal?.z
    }

    // MARK: - 3D Accessors

    /// Returns the 3D world position, or nil for pre-v3 records.
    var worldPosition: (x: Double, y: Double, z: Double)? {
        guard let x = worldPositionX, let y = worldPositionY, let z = worldPositionZ else { return nil }
        return (x, y, z)
    }

    /// Returns the surface normal at the tap point, or nil for pre-v3 records.
    var viewNormal: (x: Double, y: Double, z: Double)? {
        guard let x = viewNormalX, let y = viewNormalY, let z = viewNormalZ else { return nil }
        return (x, y, z)
    }

    /// Whether this record was created by the 3D body picker (has 3D coordinates).
    var is3DRecord: Bool {
        worldPositionX != nil
    }
}

// MARK: - JSON Array Serialization

extension InjectionSite {

    /// Serialize an array of InjectionSite to a JSON string.
    /// Returns nil if encoding fails (empty array returns "[]").
    static func toJSONArray(_ sites: [InjectionSite]) -> String? {
        guard let data = try? JSONEncoder().encode(sites) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deserialize an array of InjectionSite from a JSON string.
    /// Returns an empty array on failure or nil input.
    static func fromJSONArray(_ string: String?) -> [InjectionSite] {
        guard let string, let data = string.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([InjectionSite].self, from: data)) ?? []
    }
}

// MARK: - Zone Formatting

extension InjectionSite {

    /// "Last dose: Upper Right Thigh (front)"
    var lastDoseSentence: String {
        let context = viewContext.isEmpty ? "3D" : viewContext
        return "Last dose: \(zoneLabel) (\(context))"
    }

    /// Compact label used in pill bars, history rows, and export summaries.
    var shortLabel: String { zoneLabel }
}

// MARK: - Rotation Safety Helpers

extension InjectionSite {

    /// Returns true if this site overlaps (same zone label) with any site
    /// from recent doses within `withinDays`, accounting for continuous
    /// administration via `durationDays`.
    ///
    /// A patch applied 5 days ago with a duration of 7 is still "active"
    /// at that site through day 7, so it counts as a conflict within a
    /// window that includes day 5.
    func conflictsWith(doses: [DoseRecord], withinDays: Int) -> Bool {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -withinDays, to: Date()
        ) ?? Date()

        return doses.contains { dose in
            for site in dose.injectionSites {
                guard site.zoneLabel == self.zoneLabel else { continue }
                let activeEnd = Calendar.current.date(
                    byAdding: .day, value: site.durationDays, to: dose.doseDate
                ) ?? dose.doseDate
                if activeEnd >= cutoff { return true }
            }
            return false
        }
    }

    /// Convenience overload: checks against the default rotation window
    /// for this site's RouteClass.
    func conflictsWith(doses: [DoseRecord]) -> Bool {
        let route = RouteClass(rawValue: routeClass) ?? .injection
        return conflictsWith(doses: doses, withinDays: route.defaultRotationWindowDays)
    }

    /// Returns the number of days since this site was last used,
    /// based on the most recent dose record (excluding this one) that
    /// shares the same zone label. Returns nil if never used before.
    func daysSinceLastUse(from doses: [DoseRecord]) -> Int? {
        let previousUses = doses
            .flatMap { dose in
                dose.injectionSites
                    .filter { $0.zoneLabel == self.zoneLabel }
                    .map { (dose.doseDate, $0) }
            }
            .filter { $0.1.lastUsedDate < self.lastUsedDate }
            .sorted { $0.1.lastUsedDate > $1.1.lastUsedDate }

        guard let lastUse = previousUses.first?.1.lastUsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastUse, to: Date()).day
    }
}