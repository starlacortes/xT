//
//  IsoclineTokenParityTests.swift
//  xTTests
//
//  Drift guard between the live theme engine and the canonical Isocline
//  tokens (docs/design/tokens/isocline.tokens.json). Web pages and Isocline
//  Research print use values resolved by tools/scripts/gen_isocline_tokens.py;
//  this pins that those values are still what `ThemePalette` produces at the
//  default seed. If it fails, either re-run the generator (the engine changed
//  on purpose) or fix the engine (it changed by accident).
//

import XCTest
import SwiftUI
import UIKit
@testable import xT

final class IsoclineTokenParityTests: XCTestCase {

    private func components(of color: Color, style: UIUserInterfaceStyle) -> (r: Double, g: Double, b: Double) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func color(for field: String, in p: ThemePalette) -> Color? {
        switch field {
        case "appBackground": return p.appBackground
        case "cardSurface": return p.cardSurface
        case "safety": return p.safety
        case "textPrimary": return p.textPrimary
        case "accent": return p.accent
        case "accentSecondary": return p.accentSecondary
        case "levelLow": return p.levelLow
        case "levelHigh": return p.levelHigh
        default: return nil
        }
    }

    @MainActor
    func testDefaultSeedPaletteMatchesGeneratedTokens() {
        let p = ThemePalette.resolve(seedHue: ThemeManager.defaultSeedHue, increasedContrast: false)
        XCTAssertFalse(IsoclineTokenExpectations.palette.isEmpty)

        for expectation in IsoclineTokenExpectations.palette {
            guard let live = color(for: expectation.field, in: p) else {
                XCTFail("Token '\(expectation.field)' has no ThemePalette mapping — add it to color(for:in:)")
                continue
            }
            for (style, hex) in [(UIUserInterfaceStyle.light, expectation.light), (.dark, expectation.dark)] {
                let actual = components(of: live, style: style)
                let expected = components(of: Color(hex: hex), style: style)
                let label = "\(expectation.field) \(style == .light ? "light" : "dark")"
                XCTAssertEqual(actual.r, expected.r, accuracy: 0.01, "\(label) — red")
                XCTAssertEqual(actual.g, expected.g, accuracy: 0.01, "\(label) — green")
                XCTAssertEqual(actual.b, expected.b, accuracy: 0.01, "\(label) — blue")
            }
        }
    }
}
