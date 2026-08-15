//
//  TimeContent.swift
//  xT
//
//  Content engine for the Time tab — generates personalized insights
//  based on medication type, months on HRT, and current hormone levels.
//

import Foundation
import SwiftUI

// MARK: - Tenure Tier

/// Seven-stage tenure classification that drives personalized UI & content.
///
/// Replaces the old 3-bucket (early/established/mature) model per
/// `TIME_TIERS_DESIGN.md` §2. The active phase (0–24 months) gets four
/// fine-grained tiers; the long tail (24+) gets three year-banded tiers.
/// T5–T7 share the mature *layout* (status dots, collapsed changes) and
/// differ only in copy + milestones.
///
/// Phase 3 of the implementation plan: T6/T7 currently alias T5's copy as a
/// placeholder. Phase 5 will author the real T6/T7 strings.
enum TenureTier: String, Comparable, CaseIterable {
    case t1Beginning    = "Beginning"    // 0–2 months
    case t2Emerging     = "Emerging"     // 3–5 months
    case t3InMotion     = "In motion"    // 6–11 months
    case t4Deepening    = "Deepening"    // 12–23 months
    case t5Settled      = "Settled"      // 24–59 months
    case t6Rooted       = "Rooted"       // 60–119 months
    case t7Veteran      = "Veteran"      // 120+ months

    init(months: Int) {
        switch months {
        case 0..<3:    self = .t1Beginning
        case 3..<6:    self = .t2Emerging
        case 6..<12:   self = .t3InMotion
        case 12..<24:  self = .t4Deepening
        case 24..<60:  self = .t5Settled
        case 60..<120: self = .t6Rooted
        default:       self = .t7Veteran
        }
    }

    /// Human-readable time band, shown greyed in the subtitle per spec §3.1.
    var timeBandLabel: String {
        switch self {
        case .t1Beginning: return "Month 0–2"
        case .t2Emerging:  return "Month 3–5"
        case .t3InMotion:  return "Month 6–11"
        case .t4Deepening: return "Year 1–2"
        case .t5Settled:   return "Year 2–5"
        case .t6Rooted:    return "Year 5–10"
        case .t7Veteran:   return "10+ years"
        }
    }

    // MARK: Comparable (declaration order = seniority)

    static func < (lhs: TenureTier, rhs: TenureTier) -> Bool {
        lhs.rawValueOrder < rhs.rawValueOrder
    }

    private var rawValueOrder: Int {
        switch self {
        case .t1Beginning: return 0
        case .t2Emerging:  return 1
        case .t3InMotion:  return 2
        case .t4Deepening: return 3
        case .t5Settled:   return 4
        case .t6Rooted:    return 5
        case .t7Veteran:   return 6
        }
    }
}

// MARK: - Body System Card

struct TimeBodySystem: Identifiable {
    /// Stable identity derived from the system key — keeps ForEach/NavigationLink
    /// identity stable across engine rebuilds (UUID() per construction would
    /// defeat SwiftUI diffing).
    var id: String { systemKey.rawValue }

    let title: String
    let subtitle: String
    let icon: String
    let palette: TimeContentPalette
    /// Status label shown on the row (e.g. "Stabilising", "Maintained", "Day 3 of 7").
    /// Per spec §3.4 the progress bar is removed entirely; this label remains
    /// as the row's tenure-aware status indicator (paired with a status dot).
    let progressLabel: String
    let systemKey: BodySystemKey   // identifies the system for detail lookup

    /// Month-specific factual focus sentence — updates continuously as months
    /// progress, even when the tier-level subtitle is unchanged. Provides the
    /// "what's happening right now" signal that the old percent bar couldn't.
    let focusText: String

    /// Tenure-aware status label. Set by the engine based on actual months on HRT.
    var statusLabel: String { progressLabel }
}

enum BodySystemKey: String {
    case moodAndMind    = "mood_mind"
    case skinAndGlow    = "skin_glow"
    case bodyShape      = "body_shape"
    case yourCycle      = "your_cycle"
    case voice          = "voice"
    case skinAndHair    = "skin_hair"
    case muscleStrength = "muscle_strength"
}

// MARK: - Body System Detail (for tappable deep-dive pages)

struct TimeBodySystemDetail {
    let systemKey: BodySystemKey
    let title: String
    let heroIcon: String
    let palette: TimeContentPalette

    /// Science breakdown — what's physiologically happening.
    let scienceText: String

    /// Personalized timeline based on months on HRT.
    let timelineText: String

    /// Forward-looking: what to expect in the coming months/years.
    let whatToExpect: String

    /// For mature users: what's permanent vs. what requires ongoing dosing.
    /// Shown for T5+ (settled and beyond).
    let maintenanceNote: String?

    /// Additional context for the deepening tier (T4, formerly "established").
    let deepeningNote: String?
}

// MARK: - Milestone

struct TimeMilestone: Identifiable {
    /// Stable identity from the title — milestone lists are small and titles are unique per engine build.
    var id: String { title }

    let title: String
    let description: String
    let icon: String
    let palette: TimeContentPalette
    let badge: String?
}

// MARK: - Unlocked Change

struct TimeChange: Identifiable {
    /// Stable identity from the label — change lists are static per medication.
    var id: String { label }

    let label: String
    let unlocked: Bool
}

// MARK: - Hormone Insight

struct TimeHormoneInsight {
    let level: Double
    let unit: String
    let rangeLabel: String
    let bodyDescription: String
    let rangePalette: TimeContentPalette
}

// MARK: - Palette

/// Renamed from `TimePalette` to avoid collision with `Theme.Colors.TimePalette`
/// (a distinct type used by the `timeCard` modifier). This palette is the
/// content engine's internal color system for body-system / insight rows.
struct TimeContentPalette {
    let surface: Color
    let border: Color
    let accent: Color
    let title: Color
    let progress: Color
    let iconBorder: Color

    static let pink = TimeContentPalette(
        surface: Color(hex: "#FBEAF0"),
        border:  Color(hex: "#F4C0D1"),
        accent:  Color(hex: "#993556"),
        title:   Color(hex: "#72243E"),
        progress: Color(hex: "#ED93B1"),
        iconBorder: Color(hex: "#F4C0D1")
    )
    static let purple = TimeContentPalette(
        surface: Color(hex: "#EEEDFE"),
        border:  Color(hex: "#CECBF6"),
        accent:  Color(hex: "#534AB7"),
        title:   Color(hex: "#3C3489"),
        progress: Color(hex: "#AFA9EC"),
        iconBorder: Color(hex: "#CECBF6")
    )
    static let teal = TimeContentPalette(
        surface: Color(hex: "#E1F5EE"),
        border:  Color(hex: "#9FE1CB"),
        accent:  Color(hex: "#0F6E56"),
        title:   Color(hex: "#085041"),
        progress: Color(hex: "#5DCAA5"),
        iconBorder: Color(hex: "#9FE1CB")
    )
    static let amber = TimeContentPalette(
        surface: Color(hex: "#FAEEDA"),
        border:  Color(hex: "#FAC775"),
        accent:  Color(hex: "#854F0B"),
        title:   Color(hex: "#633806"),
        progress: Color(hex: "#EF9F27"),
        iconBorder: Color(hex: "#FAC775")
    )
    static let neutral = TimeContentPalette(
        surface: Color(hex: "#F1EFE8"),
        border:  Color(hex: "#D3D1C7"),
        accent:  Color(hex: "#5F5E5A"),
        title:   Color(hex: "#444441"),
        progress: Color(hex: "#B4B2A9"),
        iconBorder: Color(hex: "#D3D1C7")
    )
    static let optimal = TimeContentPalette(
        surface: Color(hex: "#EAF3DE"),
        border:  Color(hex: "#C0DD97"),
        accent:  Color(hex: "#3B6D11"),
        title:   Color(hex: "#27500A"),
        progress: Color(hex: "#97C459"),
        iconBorder: Color(hex: "#C0DD97")
    )
}

