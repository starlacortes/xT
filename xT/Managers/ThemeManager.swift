//
//  ThemeManager.swift
//  xT
//
//  Owns the user-selectable theme (a single hue dial) and resolves every
//  design token in `Theme.Colors` from it into a cached `ThemePalette`. See
//  `xT/Theme/ThemeEngine.swift` for the color math and `xT/Theme/Theme.swift`
//  for how `Theme.Colors` reads from `ThemeManager.shared.palette`.
//

import SwiftUI

// MARK: - Resolved palette

/// One fully-resolved set of themed colors for a given seed hue. Recomputed
/// once per `seedHue`/increased-contrast change and cached on `ThemeManager` —
/// every `Theme.Colors.xxx` accessor does a cheap field read here rather than
/// re-running OKLab/contrast math per access.
struct ThemePalette {
    // Brand
    let accent: Color
    let accentSecondary: Color
    let glassTint: Color

    // Text ("ink" at full/60%/30% opacity — mirrors how `OnAccent` already
    // expresses its roles as one color at varying alpha instead of six
    // independently-tuned literals)
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Surfaces
    let cardSurface: Color
    let border: Color
    /// The non-themed clinical-safety red (element X10); backs `Theme.Colors.error`.
    let safety: Color
    /// Opaque screen canvas — replaces raw `Color(.systemBackground)` call sites.
    let appBackground: Color
    /// Opaque icon-tile fill — replaces raw `Color(.systemGray6)` call sites.
    let neutralSurface: Color

    // Graph level ramp
    let levelLow: Color
    let levelHigh: Color

    struct GraphPalette {
        let baseDark: Color
        let baseMid: Color
        let baseTop: Color
        let topGlow: Color
        let rightGlow: Color
        let gridLine: Color
        let yAxisLabel: Color
        let curveRose: Color
        let curveMid: Color
        let curveLavender: Color
        let dotRose: Color
        let dotMagenta: Color
        let dotPurple: Color
        let dotDeepPurple: Color
        let dotLavenderLight: Color
        let levelText: Color
        let levelTextSecondary: Color
        let dotUnfilled: Color
    }
    let graph: GraphPalette

    struct TimePalettes {
        let mind: Theme.Colors.TimePalette
        let skin: Theme.Colors.TimePalette
        let body: Theme.Colors.TimePalette
        let cycle: Theme.Colors.TimePalette
    }
    let time: TimePalettes

    struct OnAccentPalette {
        let primary: Color
        let secondary: Color
        let tertiary: Color
        let disabled: Color
        let fill: Color
        let stroke: Color
        let strokeSelected: Color
    }
    let onAccent: OnAccentPalette

    /// The rose→lavender brand sweep. Non-adaptive today (same two stops
    /// regardless of light/dark mode) — preserved as-is, just seed-tinted.
    let brandColors: [Color]

    // MARK: - Recipe table
    //
    // Every (lightHue, lightL, lightC, darkHue, darkL, darkC) below was computed
    // from today's actual hex constants in Theme.swift via
    // ThemeEngine.oklch(fromSRGB:), so resolving at `ThemeManager.defaultSeedHue`
    // reproduces today's colors. Hue values are degrees relative to the seed hue
    // (0 tracks the dial exactly). `lightHue` and `darkHue` are calibrated
    // *independently* per appearance — today's hand-picked light/dark hex pairs
    // were not authored to share one exact hue (measured deltas run from ~0° up
    // to ~18°), so a single shared offset would visibly drift dark mode away
    // from today's actual colors. `darkHue` defaults to `lightHue` for the
    // handful of tokens (new neutrals, non-adaptive brand stops) with no such
    // discrepancy to preserve.

    private typealias Recipe = ThemeEngine.ColorRecipe

    private static func recipe(lightHue: Double = 0, lightL: Double, lightC: Double, lightAbsolute: Bool = false,
                                darkHue: Double? = nil, darkL: Double, darkC: Double, darkAbsolute: Bool = false) -> Recipe {
        Recipe(light: .init(lightness: lightL, chroma: lightC, hueOffset: lightHue, absoluteHue: lightAbsolute),
               dark: .init(lightness: darkL, chroma: darkC, hueOffset: darkHue ?? lightHue, absoluteHue: darkAbsolute))
    }

    private static func colorPair(_ recipe: Recipe, seedHue: Double) -> (light: Color, dark: Color) {
        let r = ThemeEngine.resolve(recipe, seedHue: seedHue)
        return (ThemeEngine.srgb(fromOKLCH: r.light), ThemeEngine.srgb(fromOKLCH: r.dark))
    }

    private static func adaptiveColor(_ recipe: Recipe, seedHue: Double) -> Color {
        let pair = colorPair(recipe, seedHue: seedHue)
        return Color(light: pair.light, dark: pair.dark)
    }

    /// Repairs a resolved (light, dark) OKLCH pair against same-appearance
    /// backgrounds, using the direction appropriate for "normal ink" content —
    /// dark-on-light in light mode, light-on-dark in dark mode. This covers
    /// every converted token except `OnAccent`, which is always light content
    /// on a (non-adaptive) colored surface regardless of system appearance.
    private static func repairInk(
        _ pair: (light: ThemeEngine.OKLCH, dark: ThemeEngine.OKLCH),
        lightBackgrounds: [Color],
        darkBackgrounds: [Color],
        floor: ThemeEngine.ContrastFloor,
        increasedContrast: Bool
    ) -> (light: ThemeEngine.OKLCH, dark: ThemeEngine.OKLCH) {
        (
            light: ThemeEngine.repairContrast(foreground: pair.light, worstOf: lightBackgrounds, floor: floor,
                                               direction: .towardDark, increasedContrast: increasedContrast),
            dark: ThemeEngine.repairContrast(foreground: pair.dark, worstOf: darkBackgrounds, floor: floor,
                                              direction: .towardLight, increasedContrast: increasedContrast)
        )
    }

    static func resolve(seedHue: Double, increasedContrast: Bool) -> ThemePalette {
        // MARK: Surfaces first — everything else contrast-repairs against these.
        //
        // Isocline "paper" ground (element F3): cream by day at every dial position
        // (absolute hue 86.4°, decision X4), seed-tinted plum by night. The card is an
        // opaque raised-paper recipe read by its hairline, not an alpha blend.

        let appBackgroundRecipe = recipe(lightHue: 86.4, lightL: 0.965, lightC: 0.0155, lightAbsolute: true,
                                         darkHue: 0, darkL: 0.18, darkC: 0.03)
        let appBackgroundPair = colorPair(appBackgroundRecipe, seedHue: seedHue)
        let appBackground = Color(light: appBackgroundPair.light, dark: appBackgroundPair.dark)

        let cardRecipe = recipe(lightHue: 86.4, lightL: 0.985, lightC: 0.009, lightAbsolute: true,
                                darkHue: 0, darkL: 0.225, darkC: 0.036)
        let cardSurface = adaptiveColor(cardRecipe, seedHue: seedHue)

        let neutralSurface = adaptiveColor(
            recipe(lightL: 0.9626, lightC: 0.012, darkL: 0.2273, darkC: 0.014), seedHue: seedHue
        )

        // MARK: Text — one "ink" anchor at full/muted/faint alpha, repaired against paper.

        let inkRecipe = recipe(lightL: 0.10, lightC: 0.010, darkL: 0.94, darkC: 0.010)
        let inkRaw = ThemeEngine.resolve(inkRecipe, seedHue: seedHue)
        let inkForText = repairInk(inkRaw, lightBackgrounds: [appBackgroundPair.light],
                                    darkBackgrounds: [appBackgroundPair.dark],
                                    floor: .bodyText, increasedContrast: increasedContrast)
        let inkTextLight = ThemeEngine.srgb(fromOKLCH: inkForText.light)
        let inkTextDark = ThemeEngine.srgb(fromOKLCH: inkForText.dark)
        let textPrimary = Color(light: inkTextLight, dark: inkTextDark)
        // Ink alphas (tokens: inkAlpha): muted .62, faint .38.
        let textSecondary = Color(light: inkTextLight.opacity(0.62), dark: inkTextDark.opacity(0.62))
        let textTertiary = Color(light: inkTextLight.opacity(0.38), dark: inkTextDark.opacity(0.38))

        // `border` is the "line" hairline: ink at .14 (.28 under Increase Contrast).
        let lineAlpha = increasedContrast ? 0.28 : 0.14
        let border = Color(light: inkTextLight.opacity(lineAlpha), dark: inkTextDark.opacity(lineAlpha))

        // Safety red (tokens: recipes.safety) — the single non-themed data color (X10):
        // absolute hue 27°, contrast-repaired against paper. Backs `Theme.Colors.error`.
        let safetyRecipe = recipe(lightHue: 27, lightL: 0.53, lightC: 0.17, lightAbsolute: true,
                                  darkHue: 27, darkL: 0.72, darkC: 0.15, darkAbsolute: true)
        let safetyRaw = ThemeEngine.resolve(safetyRecipe, seedHue: seedHue)
        let safetyRepaired = repairInk(safetyRaw, lightBackgrounds: [appBackgroundPair.light],
                                       darkBackgrounds: [appBackgroundPair.dark],
                                       floor: .bodyText, increasedContrast: increasedContrast)
        let safety = Color(light: ThemeEngine.srgb(fromOKLCH: safetyRepaired.light),
                           dark: ThemeEngine.srgb(fromOKLCH: safetyRepaired.dark))

        // MARK: Graph canvas — decorative gradient stops, no repair (they *are* the background).

        let baseDarkRecipe = recipe(lightHue: 303.8878, lightL: 0.9531, lightC: 0.0155, darkHue: 292.6160, darkL: 0.1311, darkC: 0.0213)
        let baseMidRecipe = recipe(lightHue: 305.6283, lightL: 0.9252, lightC: 0.0259, darkHue: 290.4437, darkL: 0.1649, darkC: 0.0352)
        let baseTopRecipe = recipe(lightHue: 305.5101, lightL: 0.8990, lightC: 0.0348, darkHue: 324.2820, darkL: 0.1838, darkC: 0.0327)
        let topGlow = adaptiveColor(recipe(lightHue: 356.1779, lightL: 0.7668, lightC: 0.1007, darkHue: 358.7213, darkL: 0.5479, darkC: 0.1847), seedHue: seedHue)
        let rightGlow = adaptiveColor(recipe(lightHue: 287.2395, lightL: 0.6927, lightC: 0.1176, darkHue: 283.7439, darkL: 0.5611, darkC: 0.1664), seedHue: seedHue)

        let baseDarkPair = colorPair(baseDarkRecipe, seedHue: seedHue)
        let baseMidPair = colorPair(baseMidRecipe, seedHue: seedHue)
        let baseTopPair = colorPair(baseTopRecipe, seedHue: seedHue)
        let baseDark = Color(light: baseDarkPair.light, dark: baseDarkPair.dark)
        let baseMid = Color(light: baseMidPair.light, dark: baseMidPair.dark)
        let baseTop = Color(light: baseTopPair.light, dark: baseTopPair.dark)
        let graphLightBackgrounds = [baseDarkPair.light, baseMidPair.light, baseTopPair.light]
        let graphDarkBackgrounds = [baseDarkPair.dark, baseMidPair.dark, baseTopPair.dark]

        // Graph text/grid overlays — same "ink" anchor, repaired against the graph canvas
        // specifically (a different background than the app canvas above).
        let inkForGraph = repairInk(inkRaw, lightBackgrounds: graphLightBackgrounds,
                                     darkBackgrounds: graphDarkBackgrounds,
                                     floor: .bodyText, increasedContrast: increasedContrast)
        let inkGraphLight = ThemeEngine.srgb(fromOKLCH: inkForGraph.light)
        let inkGraphDark = ThemeEngine.srgb(fromOKLCH: inkForGraph.dark)
        // Chart grid (tokens: inkAlpha.grid): .05/.035, rising to .10/.07 under Increase Contrast.
        let gridLight = increasedContrast ? 0.10 : 0.05
        let gridDark = increasedContrast ? 0.07 : 0.035
        let gridLine = Color(light: inkGraphLight.opacity(gridLight), dark: inkGraphDark.opacity(gridDark))
        let yAxisLabel = Color(light: inkGraphLight.opacity(0.10), dark: inkGraphDark.opacity(0.15))
        let levelText = Color(light: inkGraphLight, dark: inkGraphDark)
        let levelTextSecondary = Color(light: inkGraphLight.opacity(0.55), dark: inkGraphDark.opacity(0.55))
        let dotUnfilled = Color(light: inkGraphLight.opacity(0.08), dark: inkGraphDark.opacity(0.12))

        // Curve/dot colors — a rose→lavender data-visualization progression. Repaired
        // (large-graphic floor, gentler than body text) so no stop can vanish into the
        // canvas at an extreme hue, without collapsing the progression under ordinary ones.
        func graphAccent(lightHue: Double, lightL: Double, lightC: Double, darkHue: Double, darkL: Double, darkC: Double) -> Color {
            let raw = ThemeEngine.resolve(recipe(lightHue: lightHue, lightL: lightL, lightC: lightC, darkHue: darkHue, darkL: darkL, darkC: darkC), seedHue: seedHue)
            let repaired = repairInk(raw, lightBackgrounds: graphLightBackgrounds, darkBackgrounds: graphDarkBackgrounds,
                                      floor: .largeTextOrGraphic, increasedContrast: increasedContrast)
            return Color(light: ThemeEngine.srgb(fromOKLCH: repaired.light), dark: ThemeEngine.srgb(fromOKLCH: repaired.dark))
        }
        let curveRose = graphAccent(lightHue: 1.3319, lightL: 0.5739, lightC: 0.1570, darkHue: 0, darkL: 0.6225, darkC: 0.1666)
        let curveMid = graphAccent(lightHue: 313.1050, lightL: 0.5651, lightC: 0.1691, darkHue: 318.2272, darkL: 0.6178, darkC: 0.1619)
        let curveLavender = graphAccent(lightHue: 284.6389, lightL: 0.5375, lightC: 0.1673, darkHue: 288.4203, darkL: 0.6218, darkC: 0.1403)
        let dotRose = graphAccent(lightHue: 1.3319, lightL: 0.5739, lightC: 0.1570, darkHue: 0, darkL: 0.6225, darkC: 0.1666)
        let dotMagenta = graphAccent(lightHue: 327.5437, lightL: 0.5411, lightC: 0.1902, darkHue: 325.1798, darkL: 0.5829, darkC: 0.1929)
        let dotPurple = graphAccent(lightHue: 308.6042, lightL: 0.5267, lightC: 0.1873, darkHue: 310.2635, darkL: 0.5807, darkC: 0.1879)
        let dotDeepPurple = graphAccent(lightHue: 298.0483, lightL: 0.5292, lightC: 0.1858, darkHue: 300.9432, darkL: 0.5856, darkC: 0.1858)
        let dotLavenderLight = graphAccent(lightHue: 291.0889, lightL: 0.5085, lightC: 0.1791, darkHue: 295.4920, darkL: 0.5871, darkC: 0.1857)

        let graph = GraphPalette(
            baseDark: baseDark, baseMid: baseMid, baseTop: baseTop, topGlow: topGlow, rightGlow: rightGlow,
            gridLine: gridLine, yAxisLabel: yAxisLabel,
            curveRose: curveRose, curveMid: curveMid, curveLavender: curveLavender,
            dotRose: dotRose, dotMagenta: dotMagenta, dotPurple: dotPurple,
            dotDeepPurple: dotDeepPurple, dotLavenderLight: dotLavenderLight,
            levelText: levelText, levelTextSecondary: levelTextSecondary, dotUnfilled: dotUnfilled
        )

        // MARK: Time category palettes — surface/border first (decorative), then base/text repaired against surface.

        // Each tuple below is (lightHue, darkHue, lightL, darkL, lightC, darkC).
        func timePalette(base: (Double, Double, Double, Double, Double, Double),
                          surface: (Double, Double, Double, Double, Double, Double),
                          border: (Double, Double, Double, Double, Double, Double),
                          text: (Double, Double, Double, Double, Double, Double)) -> Theme.Colors.TimePalette {
            let surfacePair = colorPair(recipe(lightHue: surface.0, lightL: surface.2, lightC: surface.4, darkHue: surface.1, darkL: surface.3, darkC: surface.5), seedHue: seedHue)
            let surfaceColor = Color(light: surfacePair.light, dark: surfacePair.dark)
            let borderColor = adaptiveColor(recipe(lightHue: border.0, lightL: border.2, lightC: border.4, darkHue: border.1, darkL: border.3, darkC: border.5), seedHue: seedHue)

            let baseRaw = ThemeEngine.resolve(recipe(lightHue: base.0, lightL: base.2, lightC: base.4, darkHue: base.1, darkL: base.3, darkC: base.5), seedHue: seedHue)
            let baseRepaired = repairInk(baseRaw, lightBackgrounds: [surfacePair.light], darkBackgrounds: [surfacePair.dark],
                                         floor: .largeTextOrGraphic, increasedContrast: increasedContrast)
            let baseColor = Color(light: ThemeEngine.srgb(fromOKLCH: baseRepaired.light), dark: ThemeEngine.srgb(fromOKLCH: baseRepaired.dark))

            let textRaw = ThemeEngine.resolve(recipe(lightHue: text.0, lightL: text.2, lightC: text.4, darkHue: text.1, darkL: text.3, darkC: text.5), seedHue: seedHue)
            let textRepaired = repairInk(textRaw, lightBackgrounds: [surfacePair.light], darkBackgrounds: [surfacePair.dark],
                                         floor: .bodyText, increasedContrast: increasedContrast)
            let textColor = Color(light: ThemeEngine.srgb(fromOKLCH: textRepaired.light), dark: ThemeEngine.srgb(fromOKLCH: textRepaired.dark))

            return Theme.Colors.TimePalette(base: baseColor, surface: surfaceColor, border: borderColor, text: textColor)
        }

        let mind = timePalette(
            base: (279.3403, 283.2229, 0.4806, 0.6139, 0.1663, 0.1477),
            surface: (286.1433, 281.9984, 0.9519, 0.2457, 0.0227, 0.0559),
            border: (285.7555, 280.0152, 0.8585, 0.3868, 0.0594, 0.1176),
            text: (279.6268, 283.6259, 0.3856, 0.7589, 0.1365, 0.1039)
        )
        let skin = timePalette(
            base: (167.5852, 165.0119, 0.4809, 0.7003, 0.0908, 0.1311),
            surface: (170.3344, 178.6929, 0.9535, 0.2396, 0.0230, 0.0311),
            border: (169.2524, 164.2908, 0.8593, 0.4271, 0.0735, 0.0755),
            text: (168.5353, 170.5471, 0.3827, 0.8390, 0.0706, 0.1011)
        )
        let body = timePalette(
            base: (61.8722, 62.3990, 0.4799, 0.6869, 0.1035, 0.1383),
            surface: (78.1392, 67.4632, 0.9533, 0.2446, 0.0294, 0.0455),
            border: (75.6077, 59.7843, 0.8580, 0.4077, 0.1157, 0.0888),
            text: (61.4093, 70.4223, 0.3717, 0.8041, 0.0772, 0.1227)
        )
        let cycle = timePalette(
            base: (0, -2.7412, 0.6225, 0.6974, 0.1666, 0.1543),
            surface: (351.4722, 2.7282, 0.9522, 0.2231, 0.0200, 0.0502),
            border: (354.4955, 358.6644, 0.8587, 0.4089, 0.0632, 0.1173),
            text: (2.1473, -3.6729, 0.4811, 0.8113, 0.1358, 0.0940)
        )
        let time = TimePalettes(mind: mind, skin: skin, body: body, cycle: cycle)

        // MARK: Brand — root reference colors, no single paired background to repair against.

        let accentRecipe = recipe(lightL: 0.6225, lightC: 0.1666, darkHue: -2.7412, darkL: 0.6974, darkC: 0.1543)
        let accent = adaptiveColor(accentRecipe, seedHue: seedHue)
        let accentSecondary = adaptiveColor(recipe(lightHue: 279.3403, lightL: 0.4806, lightC: 0.1663, darkHue: 283.2229, darkL: 0.6139, darkC: 0.1477), seedHue: seedHue)
        let glassTint = adaptiveColor(recipe(lightHue: 298.6913, lightL: 0.9497, lightC: 0.0165, darkHue: 288.3173, darkL: 0.1444, darkC: 0.0260), seedHue: seedHue)
        let levelLow = adaptiveColor(recipe(lightHue: -1.9539, lightL: 0.4818, lightC: 0.1390, darkHue: -3.6690, darkL: 0.5986, darkC: 0.1456), seedHue: seedHue)
        let levelHigh = adaptiveColor(recipe(lightHue: 288.4203, lightL: 0.6218, lightC: 0.1403, darkHue: 289.1560, darkL: 0.7545, darkC: 0.1000), seedHue: seedHue)

        // Non-adaptive today (fixed regardless of light/dark mode) — only the
        // light appearance is ever read below, so no dark calibration needed.
        let brandStop0Recipe = recipe(lightL: 0.6225, lightC: 0.1666, darkL: 0.6225, darkC: 0.1666)
        let brandStop1Recipe = recipe(lightHue: 288.4203, lightL: 0.6218, lightC: 0.1403, darkL: 0.6218, darkC: 0.1403)
        let brandStop0 = ThemeEngine.srgb(fromOKLCH: ThemeEngine.resolve(brandStop0Recipe, seedHue: seedHue).light)
        let brandStop1 = ThemeEngine.srgb(fromOKLCH: ThemeEngine.resolve(brandStop1Recipe, seedHue: seedHue).light)
        let brandColors = [brandStop0, brandStop1]

        // MARK: OnAccent — always light content on the (non-adaptive) brand surface.

        let onAccentRaw = ThemeEngine.resolve(recipe(lightL: 0.97, lightC: 0.008, darkL: 0.97, darkC: 0.008), seedHue: seedHue).light
        let accentLightOnly = ThemeEngine.srgb(fromOKLCH: ThemeEngine.resolve(accentRecipe, seedHue: seedHue).light)
        let onAccentBackgrounds = [brandStop0, brandStop1, accentLightOnly]
        let onAccentRepaired = ThemeEngine.repairContrast(foreground: onAccentRaw, worstOf: onAccentBackgrounds,
                                                           floor: .largeTextOrGraphic, direction: .towardLight,
                                                           increasedContrast: increasedContrast)
        let onAccentBase = ThemeEngine.srgb(fromOKLCH: onAccentRepaired)
        let onAccent = OnAccentPalette(
            primary: onAccentBase,
            secondary: onAccentBase.opacity(0.9),
            tertiary: onAccentBase.opacity(0.7),
            disabled: onAccentBase.opacity(0.5),
            fill: onAccentBase.opacity(0.15),
            stroke: onAccentBase.opacity(0.3),
            strokeSelected: onAccentBase.opacity(0.5)
        )

        return ThemePalette(
            accent: accent, accentSecondary: accentSecondary, glassTint: glassTint,
            textPrimary: textPrimary, textSecondary: textSecondary, textTertiary: textTertiary,
            cardSurface: cardSurface, border: border, safety: safety,
            appBackground: appBackground, neutralSurface: neutralSurface,
            levelLow: levelLow, levelHigh: levelHigh,
            graph: graph, time: time, onAccent: onAccent, brandColors: brandColors
        )
    }
}

// MARK: - ThemeManager

@MainActor
@Observable
class ThemeManager {
    static let shared = ThemeManager()

    /// Computed from today's actual accent hex (`#D4537E`), not hand-typed, so it
    /// self-corrects if the brand color is ever changed in `Theme.swift`.
    static let defaultSeedHue: Double = ThemeEngine.oklch(fromSRGB: Color(hex: "#D4537E")).H

    enum Keys {
        static let seedHue = "theme.seedHue"
    }

    let defaults: UserDefaults

    /// The iCloud mirror the committed hue writes through to (X6). Injectable
    /// so the mirror logic can be tested without iCloud.
    let hueMirror: SeedHueMirrorStore

    var seedHue: Double {
        didSet {
            #if DEBUG
            print("[ThemeDebug] seedHue \(oldValue) -> \(seedHue)")
            #endif
            palette = ThemePalette.resolve(seedHue: seedHue, increasedContrast: increasedContrast)
        }
    }

    /// Recomputed whenever `seedHue` (or increased-contrast) changes — every
    /// `Theme.Colors.xxx` accessor reads a field here. Must stay tracked (never
    /// `@ObservationIgnored`) or dependent views silently stop updating.
    private(set) var palette: ThemePalette

    private var increasedContrast: Bool {
        didSet { palette = ThemePalette.resolve(seedHue: seedHue, increasedContrast: increasedContrast) }
    }

    init(defaults: UserDefaults = .standard,
         hueMirror: SeedHueMirrorStore = UbiquitySeedHueStore()) {
        self.defaults = defaults
        self.hueMirror = hueMirror
        let hue = defaults.object(forKey: Keys.seedHue) as? Double ?? Self.defaultSeedHue
        let contrast = UIAccessibility.isDarkerSystemColorsEnabled
        self.seedHue = hue
        self.increasedContrast = contrast
        self.palette = ThemePalette.resolve(seedHue: hue, increasedContrast: contrast)

        // X6: adopt the iCloud-mirrored hue when this device is behind — a
        // fresh install, or another device moved the dial. KVS is usually
        // already merged at launch; changes that arrive later land through
        // the observer below.
        adoptSyncedSeedHue()

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.increasedContrast = UIAccessibility.isDarkerSystemColorsEnabled
        }

        // X6: the hue changed on another device while this one was closed.
        // Block-based, so the token cleans itself up with the manager.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.adoptSyncedSeedHue()
        }
    }

    /// Call from `onEditingChanged(false)` only — NOT from the `didSet` above.
    /// `seedHue` mutates dozens of times/sec while dragging; only the final
    /// value should hit disk.
    func commitSeedHue() {
        #if DEBUG
        print("[ThemeDebug] commitSeedHue -> \(seedHue) (persisted)")
        #endif
        defaults.set(seedHue, forKey: Keys.seedHue)
        mirrorSeedHue()
        // The widget's palette is baked into its snapshot as resolved RGB, so a
        // hue change must re-publish for the Home Screen to follow (no-op
        // without the App Group). Only ever user-triggered, so `.shared` is
        // safe here — unlike inside `refreshState()` (see the writer).
        WidgetSnapshotWriter.publish(from: MedicationManager.shared)
    }

    func resetToDefault() {
        seedHue = Self.defaultSeedHue
        commitSeedHue()
    }
}

// MARK: - Environment Key

@MainActor
struct ThemeManagerKey: @MainActor EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    @MainActor
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
