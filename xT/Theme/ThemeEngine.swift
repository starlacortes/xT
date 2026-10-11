//
//  ThemeEngine.swift
//  xT
//
//  Pure color math backing the user-selectable theme: OKLCH conversion (a
//  perceptually uniform space, so "rotate hue, hold lightness" behaves
//  predictably — raw HSB brightness does not correlate with perceived
//  lightness, which is why naive hue rotation in RGB/HSB breaks contrast),
//  WCAG contrast, and a gamut-aware contrast-repair pass. No view/manager
//  state lives here — everything is a free function over Color/OKLCH values.
//

import SwiftUI

enum ThemeEngine {

    // MARK: - Color spaces

    struct OKLab {
        var L: Double
        var a: Double
        var b: Double
    }

    struct OKLCH {
        var L: Double
        var C: Double
        var H: Double  // degrees, [0, 360)

        init(L: Double, C: Double, H: Double) {
            self.L = L
            self.C = C
            let normalized = H.truncatingRemainder(dividingBy: 360)
            self.H = normalized < 0 ? normalized + 360 : normalized
        }
    }

    // MARK: - sRGB <-> linear

    private static func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private static func components(of color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    // MARK: - OKLab <-> linear sRGB
    //
    // Public-domain formulas by Björn Ottosson (https://bottosson.github.io/posts/oklab/).

    private static func oklab(fromLinearRGB r: Double, _ g: Double, _ b: Double) -> OKLab {
        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        return OKLab(
            L: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        )
    }

    /// Returns linear (not gamma-encoded) sRGB components — used internally for
    /// gamut testing, where we care about raw channel range, not display value.
    private static func linearRGB(fromOKLab lab: OKLab) -> (r: Double, g: Double, b: Double) {
        let l_ = lab.L + 0.3963377774 * lab.a + 0.2158037573 * lab.b
        let m_ = lab.L - 0.1055613458 * lab.a - 0.0638541728 * lab.b
        let s_ = lab.L - 0.0894841775 * lab.a - 1.2914855480 * lab.b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        return (
            r: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    // MARK: - Public conversions

    static func oklab(fromSRGB color: Color) -> OKLab {
        let c = components(of: color)
        return oklab(fromLinearRGB: srgbToLinear(c.r), srgbToLinear(c.g), srgbToLinear(c.b))
    }

    static func srgb(fromOKLab lab: OKLab, opacity: Double = 1) -> Color {
        let linear = linearRGB(fromOKLab: lab)
        return Color(
            .sRGB,
            red: linearToSRGB(min(max(linear.r, 0), 1)),
            green: linearToSRGB(min(max(linear.g, 0), 1)),
            blue: linearToSRGB(min(max(linear.b, 0), 1)),
            opacity: opacity
        )
    }

    static func oklch(fromOKLab lab: OKLab) -> OKLCH {
        let c = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        let h = atan2(lab.b, lab.a) * 180 / .pi
        return OKLCH(L: lab.L, C: c, H: h)
    }

    static func oklab(fromOKLCH lch: OKLCH) -> OKLab {
        let radians = lch.H * .pi / 180
        return OKLab(L: lch.L, a: lch.C * cos(radians), b: lch.C * sin(radians))
    }

    static func oklch(fromSRGB color: Color) -> OKLCH {
        oklch(fromOKLab: oklab(fromSRGB: color))
    }

    static func srgb(fromOKLCH lch: OKLCH, opacity: Double = 1) -> Color {
        srgb(fromOKLab: oklab(fromOKLCH: lch), opacity: opacity)
    }

    // MARK: - Gamut

    /// Whether `lch`, converted to linear sRGB, lands inside the displayable
    /// [0, 1] range on every channel. Arbitrary hue/lightness/chroma combinations
    /// (i.e. anything the user can dial to) are not guaranteed to round-trip into
    /// sRGB the way today's hand-picked hexes do.
    static func isInGamut(_ lch: OKLCH, tolerance: Double = 1e-4) -> Bool {
        let linear = linearRGB(fromOKLab: oklab(fromOKLCH: lch))
        return linear.r >= -tolerance && linear.r <= 1 + tolerance
            && linear.g >= -tolerance && linear.g <= 1 + tolerance
            && linear.b >= -tolerance && linear.b <= 1 + tolerance
    }

    /// Reduces chroma (holding L and H fixed) via binary search until the color
    /// re-enters the sRGB gamut. Achromatic (C=0) is always in-gamut for any L in
    /// [0,1], so this always terminates with a usable result.
    static func clampToGamut(_ lch: OKLCH, maxIterations: Int = 12) -> OKLCH {
        guard !isInGamut(lch) else { return lch }
        var lo = 0.0
        var hi = lch.C
        var best = OKLCH(L: lch.L, C: 0, H: lch.H)
        for _ in 0..<maxIterations {
            let mid = (lo + hi) / 2
            let candidate = OKLCH(L: lch.L, C: mid, H: lch.H)
            if isInGamut(candidate) {
                best = candidate
                lo = mid
            } else {
                hi = mid
            }
        }
        return best
    }

    // MARK: - WCAG contrast

    static func relativeLuminance(_ color: Color) -> Double {
        let c = components(of: color)
        let r = srgbToLinear(c.r)
        let g = srgbToLinear(c.g)
        let b = srgbToLinear(c.b)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    enum ContrastFloor {
        case bodyText
        case largeTextOrGraphic

        /// WCAG 2.x floors (4.5:1 / 3:1) are the adopted-standard compliance
        /// floor; when the user has iOS's "Increase Contrast" accessibility
        /// setting on, we hold ourselves to the stricter AA-enhanced values
        /// (7:1 / 4.5:1) instead of silently ignoring that preference.
        func minimumRatio(increasedContrast: Bool) -> Double {
            switch self {
            case .bodyText: return increasedContrast ? 7.0 : 4.5
            case .largeTextOrGraphic: return increasedContrast ? 4.5 : 3.0
            }
        }
    }

    // MARK: - Contrast repair

    /// Which way a token is allowed to move to gain contrast. This is a property
    /// of the token's *design intent*, not something to auto-detect from the
    /// current colors — e.g. `OnAccent` text must stay light (never flip to dark
    /// text on a colorful surface just because that would score higher contrast),
    /// while `Time.*.text` must stay dark ink on a light card. Auto-detecting
    /// from whichever side of the background the foreground currently sits on
    /// would also reinforce an already-wrong relationship if a recipe happens to
    /// land on the wrong side at some rotated hue — the exact case repair exists
    /// to catch.
    enum RepairDirection {
        case towardLight
        case towardDark
    }

    /// Nudges `foreground`'s lightness (chroma and hue held fixed, modulo gamut
    /// re-clamping) toward `direction` until its contrast against `background`
    /// clears `floor`, or the search budget is exhausted. Returns the smallest
    /// displacement from `foreground` that clears the floor; if even the extreme
    /// (pure black or pure white at this hue/chroma) can't clear it, returns that
    /// extreme as a best effort rather than looping forever.
    static func repairContrast(
        foreground: OKLCH,
        background: Color,
        floor: ContrastFloor,
        direction: RepairDirection,
        increasedContrast: Bool,
        maxIterations: Int = 16
    ) -> OKLCH {
        let target = floor.minimumRatio(increasedContrast: increasedContrast)
        let initial = clampToGamut(foreground)

        func ratio(atLightness l: Double) -> Double {
            let candidate = clampToGamut(OKLCH(L: l, C: initial.C, H: initial.H))
            return contrastRatio(srgb(fromOKLCH: candidate), background)
        }

        if ratio(atLightness: initial.L) >= target { return initial }

        let goLighter = direction == .towardLight
        let extreme = goLighter ? 1.0 : 0.0

        guard ratio(atLightness: extreme) >= target else {
            // Even the extreme can't clear the floor at this chroma/hue — best effort.
            return clampToGamut(OKLCH(L: extreme, C: initial.C, H: initial.H))
        }

        // Invariant: `hi` always satisfies the floor, `lo` never does (mirrored if !goLighter).
        var lo = goLighter ? initial.L : extreme
        var hi = goLighter ? extreme : initial.L
        for _ in 0..<maxIterations {
            let mid = (lo + hi) / 2
            if ratio(atLightness: mid) >= target {
                if goLighter { hi = mid } else { lo = mid }
            } else {
                if goLighter { lo = mid } else { hi = mid }
            }
        }
        let resultL = goLighter ? hi : lo
        return clampToGamut(OKLCH(L: resultL, C: initial.C, H: initial.H))
    }

    /// Contrast-repairs `foreground` against whichever of `backgrounds` is
    /// hardest to read against (lowest contrast) — for tokens (like OnAccent
    /// text) that must stay legible no matter which themed surface they land on.
    static func repairContrast(
        foreground: OKLCH,
        worstOf backgrounds: [Color],
        floor: ContrastFloor,
        direction: RepairDirection,
        increasedContrast: Bool,
        maxIterations: Int = 16
    ) -> OKLCH {
        guard let hardest = backgrounds.min(by: {
            contrastRatio(srgb(fromOKLCH: foreground), $0) < contrastRatio(srgb(fromOKLCH: foreground), $1)
        }) else { return clampToGamut(foreground) }
        return repairContrast(foreground: foreground, background: hardest, floor: floor,
                               direction: direction, increasedContrast: increasedContrast,
                               maxIterations: maxIterations)
    }

    // MARK: - Recipes

    /// A token's shape in OKLCH terms, relative to the dial. Each appearance
    /// carries its *own* `hueOffset` (degrees away from the seed hue; 0 tracks
    /// the dial exactly) — today's hand-picked light/dark hex pairs were not
    /// authored to share an exact hue (measured deltas between a token's light
    /// and dark hex range from ~0° to ~18°), so collapsing both appearances
    /// onto one shared hue would visibly drift dark mode away from today's
    /// actual colors. Both offsets still move together as the dial turns —
    /// they just start from their own current calibration.
    struct ColorRecipe {
        struct Appearance {
            let lightness: Double
            let chroma: Double
            let hueOffset: Double
            /// When true, `hueOffset` is read as an *absolute* hue in degrees and the
            /// dial is ignored — day paper is cream at every position (86.4°) and the
            /// safety red is never themed (27°). Decision X4/X10.
            let absoluteHue: Bool

            init(lightness: Double, chroma: Double, hueOffset: Double = 0, absoluteHue: Bool = false) {
                self.lightness = lightness
                self.chroma = chroma
                self.hueOffset = hueOffset
                self.absoluteHue = absoluteHue
            }
        }
        let light: Appearance
        let dark: Appearance
    }

    static func resolve(_ recipe: ColorRecipe, seedHue: Double) -> (light: OKLCH, dark: OKLCH) {
        func hue(_ a: ColorRecipe.Appearance) -> Double {
            a.absoluteHue ? a.hueOffset : seedHue + a.hueOffset
        }
        return (
            light: clampToGamut(OKLCH(L: recipe.light.lightness, C: recipe.light.chroma, H: hue(recipe.light))),
            dark: clampToGamut(OKLCH(L: recipe.dark.lightness, C: recipe.dark.chroma, H: hue(recipe.dark)))
        )
    }
}
