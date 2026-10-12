//
//  AppIconChoiceTests.swift
//  xTTests
//
//  I2/I4 — the icon set. The hue choices must align one-to-one with
//  `Theme.Seed.stops` (a stop and its icon always agree), alternate names
//  must round-trip through what `UIApplication` reports, "match my hue"
//  must respect the circular hue space, and every preview imageset the
//  picker shows must actually resolve in the app bundle.
//

import Testing
import UIKit
@testable import xT

@Suite("App icon choice (I2/I4)")
struct AppIconChoiceTests {

    // MARK: - Stop alignment

    @Test("Every quick stop has exactly one icon")
    func hueChoicesAlignWithStops() {
        let hueChoices = AppIconChoice.allCases.filter { $0.stopHue != nil }
        #expect(hueChoices.count == Theme.Seed.stops.count)

        // Order matters: the primary is the default rose (stops[0]), then
        // each hue choice in stop order — the picker grid and the quick
        // stops read the same sequence.
        for (choice, stop) in zip(hueChoices, Theme.Seed.stops) {
            #expect(choice.stopHue == stop)
        }
    }

    @Test("Degree labels round the real stop hue")
    func hueLabels() {
        #expect(AppIconChoice.primary.hueLabel == "3°")    // stop 2.52°
        #expect(AppIconChoice.hue48.hueLabel == "48°")       // stop 47.52°
        #expect(AppIconChoice.hue318.hueLabel == "318°")    // stop 317.52°
        #expect(AppIconChoice.discreet.hueLabel == nil)
    }

    // MARK: - Name round-trips

    @Test("Alternate names round-trip through UIApplication's report")
    func nameRoundTrip() {
        for choice in AppIconChoice.allCases {
            #expect(AppIconChoice(alternateIconName: choice.assetName) == choice)
        }
        // The primary reports nil; a stale or unknown name can never wedge
        // the picker — both read as the primary.
        #expect(AppIconChoice(alternateIconName: nil) == .primary)
        #expect(AppIconChoice(alternateIconName: "AppIconLongGone") == .primary)
    }

    @Test("Only the primary has no alternate name")
    func assetNames() {
        #expect(AppIconChoice.primary.assetName == nil)
        #expect(AppIconChoice.discreet.assetName == "AppIconDiscreet")
        let named = AppIconChoice.allCases.compactMap(\.assetName)
        #expect(named.count == AppIconChoice.allCases.count - 1)
        #expect(Set(named).count == named.count) // no duplicate asset names
    }

    // MARK: - Match my hue (I4)

    @Test("Exact stops match their own icons")
    func nearestAtStops() {
        #expect(AppIconChoice.nearest(toHue: 2.52) == .primary)
        #expect(AppIconChoice.nearest(toHue: 47.52) == .hue48)
        #expect(AppIconChoice.nearest(toHue: 317.52) == .hue318)
    }

    @Test("Between stops picks the closer neighbour, across the wrap too")
    func nearestBetweenStops() {
        #expect(AppIconChoice.nearest(toHue: 30) == .hue48)
        #expect(AppIconChoice.nearest(toHue: 60) == .hue48)
        #expect(AppIconChoice.nearest(toHue: 200) == .hue183)
        // The circular seam: 350° is the default rose's neighbour, not
        // 317°'s — 360 - 350 + 2.52 = 12.52° vs 32.48°.
        #expect(AppIconChoice.nearest(toHue: 350) == .primary)
        #expect(AppIconChoice.nearest(toHue: 0) == .primary)
    }

    // MARK: - Previews

    @Test("Every preview imageset resolves in the app bundle")
    func previewsResolve() throws {
        for choice in AppIconChoice.allCases {
            let image = UIImage(named: choice.previewAssetName, in: .main, compatibleWith: nil)
            #expect(image != nil, "missing preview imageset \(choice.previewAssetName)")
        }
    }
}
