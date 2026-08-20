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
        case .injection: return String(localized: "Injection (IM/SubQ)",
                                       comment: "Administration route: intramuscular or subcutaneous injection")
        case .topical:   return String(localized: "Topical (gel/cream)",
                                       comment: "Administration route: gel or cream applied to skin")
        case .patch:     return String(localized: "Transdermal patch",
                                       comment: "Administration route: adhesive patch")
        case .oral:      return String(localized: "Oral",
                                       comment: "Administration route: taken by mouth")
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

    /// Semantic tint color for each route class — routes through the Theme
    /// tokens instead of hand-copied hex so these icons follow the user's theme.
    /// @MainActor because the accent tokens are actor-isolated to ThemeManager.
    @MainActor var tintColor: Color {
        switch self {
        case .injection: return Theme.Colors.accent
        case .topical:   return Theme.Colors.accentSecondary
        case .patch:     return Theme.Colors.warning
        case .oral:      return .secondary
        }
    }

    /// Map a MedicationManager-style `administrationMethod` string to a RouteClass.
    static func from(method: String) -> RouteClass {
        let lower = method.lowercased()
        if lower.contains("inject")  { return .injection }
        if lower.contains("cream")   { return .topical }
        if lower.contains("patch")   { return .patch }
        if lower.contains("oral")    { return .oral }
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
        sketchId       = (try? container.decode(String.self,  forKey: .sketchId))      ?? InjectionSite.unknownFallback
        normalizedX    = (try? container.decode(Double.self,  forKey: .normalizedX))   ?? 0.5
        normalizedY    = (try? container.decode(Double.self,  forKey: .normalizedY))   ?? 0.5
        zoneLabel      = (try? container.decode(String.self,  forKey: .zoneLabel))    ?? InjectionSite.unknownZoneFallback
        viewContext    = (try? container.decode(String.self,  forKey: .viewContext))   ?? "front"
        bodyRegion     = (try? container.decode(String.self,  forKey: .bodyRegion))    ?? InjectionSite.unknownFallback
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

    /// Fallback written when a field can't be decoded or a zone can't be
    /// resolved to a region. Lowercase to match historical records.
    static let unknownFallback = "unknown"
    /// Fallback for an unreadable zone label (historically capitalized).
    static let unknownZoneFallback = "Unknown"

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

    /// Compact label used in pill bars, history rows, and export summaries.
    var shortLabel: String { zoneLabel }
}