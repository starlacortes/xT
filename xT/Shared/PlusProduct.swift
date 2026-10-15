//
//  PlusProduct.swift
//  xT
//
//  The Isocline Plus subscription catalog. Product IDs are permanent once
//  they exist in App Store Connect, so they live here and nowhere else —
//  `EntitlementManager`, the paywall and `Isocline.storekit` (local testing)
//  all read from this list.
//

import Foundation

enum PlusProduct {
    static let monthly = "com.starlacortes.isocline.plus.monthly"
    static let yearly = "com.starlacortes.isocline.plus.yearly"

    /// Paywall order: yearly first (the category leans annual, and it carries
    /// the free trial).
    static let all: [String] = [yearly, monthly]
}

/// Where the user stands with Plus. Lapse de-emphasizes, never breaks
/// (calibration-and-subscriptions plan §2): a past subscriber keeps the
/// functional layer and loses only the visual one.
enum PlusAccess: String, Codable, Sendable {
    /// Never subscribed.
    case free
    /// Active subscription, including the billing grace period.
    case active
    /// Subscribed before; now expired or refunded.
    case lapsed

    /// `hasActive` is a verified, unrevoked current entitlement to a Plus
    /// product; `hasPastTransaction` is any verified Plus transaction on the
    /// account. Refunds count as lapsed (the plan's recommended default, §13).
    static func resolve(hasActive: Bool, hasPastTransaction: Bool) -> PlusAccess {
        if hasActive { return .active }
        return hasPastTransaction ? .lapsed : .free
    }
}
