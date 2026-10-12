//
//  AppIconChoice.swift
//  xT
//
//  The app-icon set (I2): the primary icon, one alternate per quick-stop hue,
//  and the Discreet stealth icon (I3). The hue choices align with
//  `Theme.Seed.stops` — the same list the hue picker's quick stops use — so a
//  stop and its icon always agree.
//
//  Choices map 1:1 onto the Icon Composer bundles emitted by
//  tools/scripts/build_isocline_app_icons.py: `assetName` is what
//  `setAlternateIconName` takes (nil switches back to the primary), and
//  `previewAssetName` is the imageset the picker grid previews with.
//

import Foundation

enum AppIconChoice: String, CaseIterable, Identifiable {
    /// The "I." on the default rose ground — the icon the app ships with.
    case primary
    /// The "I." on the amber ground (quick stop 47.52°).
    case hue48
    /// The "I." on the olive ground (quick stop 92.52°).
    case hue93
    /// The "I." on the green ground (quick stop 137.52°).
    case hue138
    /// The "I." on the teal ground (quick stop 182.52°).
    case hue183
    /// The "I." on the cyan ground (quick stop 227.52°).
    case hue228
    /// The "I." on the periwinkle ground (quick stop 272.52°).
    case hue273
    /// The "I." on the lilac ground (quick stop 317.52°).
    case hue318
    /// The embossed mark on plain paper — no hue, names nothing (I3).
    case discreet

    var id: String { rawValue }

    /// The hue-carrying choices in `Theme.Seed.stops` order. The single
    /// alignment point between the enum and the stop list.
    private static let hueOrder: [AppIconChoice] = [
        .primary, .hue48, .hue93, .hue138,
        .hue183, .hue228, .hue273, .hue318
    ]

    /// The quick-stop hue whose ground this icon uses; nil for Discreet.
    var stopHue: Double? {
        guard let index = Self.hueOrder.firstIndex(of: self) else { return nil }
        return Theme.Seed.stops[index]
    }

    /// The alternate-icon asset name, or nil for the primary icon.
    var assetName: String? {
        switch self {
        case .primary: nil
        case .hue48: "AppIconHue48"
        case .hue93: "AppIconHue93"
        case .hue138: "AppIconHue138"
        case .hue183: "AppIconHue183"
        case .hue228: "AppIconHue228"
        case .hue273: "AppIconHue273"
        case .hue318: "AppIconHue318"
        case .discreet: "AppIconDiscreet"
        }
    }

    /// The degree label the picker and the gateway subtitle show — "48°".
    /// Nil for the primary and Discreet, which carry word labels instead.
    var hueLabel: String? {
        stopHue.map { "\(Int($0.rounded()))°" }
    }

    /// The imageset the picker grid previews the icon with. The app can't
    /// read a compiled app icon back from the catalog, so the picker shows
    /// the same artwork shipped as an ordinary image (rounded, as it reads
    /// in-app — no system mask applies here).
    var previewAssetName: String {
        switch self {
        case .primary: "IconPreviewPrimary"
        case .hue48: "IconPreviewHue48"
        case .hue93: "IconPreviewHue93"
        case .hue138: "IconPreviewHue138"
        case .hue183: "IconPreviewHue183"
        case .hue228: "IconPreviewHue228"
        case .hue273: "IconPreviewHue273"
        case .hue318: "IconPreviewHue318"
        case .discreet: "IconPreviewDiscreet"
        }
    }

    /// The choice an alternate-icon name (as `UIApplication` reports it)
    /// maps to. The primary icon reports nil; an unknown name also reads as
    /// `.primary` so a stale value can never wedge the picker.
    init(alternateIconName: String?) {
        self = AppIconChoice.allCases.first { $0.assetName == alternateIconName } ?? .primary
    }

    /// The icon whose quick-stop hue is nearest to `hue` — I4's "match my
    /// hue". Circular, so 350° and 10° are both the default rose's
    /// neighbours. Discreet never matches by hue; it's a deliberate
    /// departure, not a position on the dial.
    static func nearest(toHue hue: Double) -> AppIconChoice {
        let hueChoices = allCases.compactMap { choice -> (AppIconChoice, Double)? in
            choice.stopHue.map { (choice, $0) }
        }
        return hueChoices
            .min { lhs, rhs in
                circularDistance(hue, lhs.1) < circularDistance(hue, rhs.1)
            }?
            .0 ?? .primary
    }

    /// 350° and 10° are neighbours — plain |a − b| would call them 340° apart.
    private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        let delta = abs(a - b)
        return min(delta, 360 - delta)
    }
}
