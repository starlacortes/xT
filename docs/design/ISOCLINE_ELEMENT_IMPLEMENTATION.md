# Isocline — Element-by-Element Implementation

**Status:** Canonical design-system handoff · October 2026
**Spec:** [`ISOCLINE_DESIGN_SYSTEM.html`](ISOCLINE_DESIGN_SYSTEM.html) (prose + rationale)
**Token source of truth:** [`tokens/isocline.tokens.json`](tokens/isocline.tokens.json) (values, roles, recipes)
**Transition / change inventory:** [`../planning/implementation/isocline-app-transition.md`](../planning/implementation/isocline-app-transition.md) (PR phasing + crossroads)
**Codebase (verified tree, 108 Swift files):** `xT/`

This document enumerates every element the design system names — every color, type role, radius, spacing, line, surface, and component — and maps it to the exact Swift file and symbol that owns it in the `xT/` tree today, with implementation notes for what has to change. Element IDs (`F3`, `H7`, `J2`, …) match the transition plan so a PR can cite them. Token IDs come from `isocline.tokens.json`.

**Out of scope, documented elsewhere:**
- Calibration and subscription gating (`CalibrationPromptCard`, `EntitlementManager`, Premium settings): [`../planning/implementation/calibration-and-subscriptions-plan.md`](../planning/implementation/calibration-and-subscriptions-plan.md). Note decision X8 superseded its display gating: the curve always shows.
- Time tab content, stages, tiers and region copy: `docs/app-design/TIME_*.md`. This doc covers only the Time tab's visual elements (§29).

---

## 0 · How to read this document

| Field | Meaning |
|---|---|
| **Token** | Identifier in `isocline.tokens.json`. Never hand-copy a value from here into Swift; the generator produces the resolved numbers. |
| **Swift today** | The file and symbol in the live `xT/` tree that renders it right now. |
| **Swift after** | The symbol that should own it once the transition lands. |
| **Element** | Transition-plan ID(s) to consult for behavior, crossroads, and verification. |
| **Gap** | A spec item with no current home, or a home that doesn't match the spec. |

Reading rule of thumb, from the design system's §01 working principle:

> **What *is*** (who you are, where your level is now, what was measured) sits **flush on the paper**, no card. **What you *adjust*** (doses, settings, entries) sits in a **card**. If tapping it would change something, it's a card; otherwise it's flush.

---

# PART 1 · FOUNDATION ELEMENTS

These are the atoms every screen reads. Each one must be a token-driven value, not a literal.

## 1 · Color recipes

Every color on every surface is resolved from a single **seed hue** at runtime by `ThemeEngine.resolve`. The seed defaults to `#D4537E` (rose); the user may turn it anywhere. Out-of-gamut results lose chroma, never lightness. Text is contrast-repaired against its ground to WCAG 4.5:1 (7:1 under Increase Contrast).

| Token | Light (OKLCH L·C·h) | Dark (OKLCH L·C·h) | Role | `xT/` home today | F3 change |
|---|---|---|---|---|---|
| `recipes.paper` | `.965 · .0155 · 86.4° (absolute)` | `.18 · .03 · seed` | Screen canvas. Day = cream (#F8F3E8), night = seed-tinted plum (#1C0C10). | `ThemeManager.ThemePalette.appBackground` (`.985/.008` light, `.05/.010` dark) | Re-recipe `appBackground` to `paper`; add `absoluteHue` flag to `ColorRecipe.Appearance`; add `paper` alias. |
| `recipes.card` | `.985 · .009 · 86.4° (absolute)` | `.225 · .036 · seed` | Raised paper card, read by its hairline, no shadow. | `ThemePalette.cardSurface = appBackground × 0.8` | Make it the opaque `card` recipe, not an alpha blend. |
| `recipes.ink` | `.1 · .01 · 0` | `.94 · .01 · 0` | All text and engraving. Muted/faint/line/grid are this ink at alpha. | `textPrimary` (repaired vs `appBackground`) | Repair against `paper`, not `appBackground`. |
| `recipes.accent` | `.6225 · .1666 · 0°` | `.6974 · .1543 · −2.74°` | The seed itself. Links, active tab, needle pivot. | `ThemeColors.accent` | Parity-tested; unchanged. |
| `recipes.accent2` | `.4806 · .1663 · +279.34°` | `.6139 · .1477 · +283.22°` | Secondary structure (the lavender of the old brand, seed-relative). | `ThemeColors.accentSecondary` | Parity-tested; unchanged. |
| `recipes.onAccent` | `.97 · .008 · 0` | `.97 · .008 · 0` | Ink on accent fills (action pills, icon ground). | `OnAccentPalette.primary` (repaired vs brand stops) | Compare the token's "repair against accent, direction: light" with today's logic; reconcile later, don't parity-test yet. |
| `recipes.levelLow` | `.4818 · .139 · −1.95°` | `.5986 · .1456 · −3.67°` | Bottom of the level ramp. | `Graph.levelLow` | Parity-tested. |
| `recipes.levelHigh` | `.6218 · .1403 · +288.42°` | `.7545 · .1 · +289.16°` | Top of the level ramp. | `Graph.levelHigh` | Parity-tested. |
| `recipes.safety` | `.53 · .17 · 27° (absolute)` | `.72 · .15 · 27° (absolute)` | Documented clinical thresholds (E2>1000, E2<50, T>1500). Outline+text+glyph, never fill, never on curve. | `Theme.Colors.error = Color.red` (static) | Re-recipe `error` to the `safety` token. Keep the accessor name so `HormoneLevelPresentation.statusTint` and `PharmacokineticTests` still hold. |

### 1.1 Ink alphas (ink at fixed opacity)

These are not palette fields with a recipe — they're the ink recipe at a constant alpha, per appearance. Under Increase Contrast the alphas rise (`inkAlphaIncreasedContrast`).

| Token | Light α | Dark α | Increase-Contrast α | Role | `xT/` home today | Gap |
|---|---|---|---|---|---|---|
| `inkAlpha.muted` | `.62` | `.62` | — | Secondary text. | `textSecondary = ink × 0.6` | Bump to `.62`. |
| `inkAlpha.faint` | `.38` | `.38` | — | Tertiary text. | `textTertiary = ink × 0.3` | Bump to `.38`. |
| `inkAlpha.line` | `.14` | `.14` | `.28` / `.28` | Hairline borders. | `border = (.94L, .010) × 0.2` (both modes) | Move to `line` = ink × .14; swap in `.28` under Increase Contrast. |
| `inkAlpha.grid` | `.05` | `.035` | `.1` / `.07` | Chart grid. | `Graph.gridLine` (repaired vs `Graph.base*`) | Re-target to `grid` = ink × .05/.035. |
| `inkAlpha.ylab` | `.1` | `.15` | — | Chart y-labels. | `Graph.yAxisLabel` | Re-target to `ylab`. |

### 1.2 Fixed colors (not seed-derived)

| Token | Hex | Role | `xT/` home today | Gap |
|---|---|---|---|---|
| `fixed.success` | `#3B8C6E` | **Legacy**: the old dashed trough lines on Home. | `Theme.Colors.successBrand` | Retired from the chart (H5). Delete if no other callers remain. Update tokens' `fixed.success.role` to note retirement. |
| `fixed.sage` | `#8FA382` | Secondary data series only. Never a status color. | — | Keep available; use only for secondary measurements. |
| `fixed.print.ink` / `fixed.print.paper` | `#1A1622` / `#FFFFFF` | Isocline Research print: near-black on white. | — | Print template only; not in app. |

### 1.3 Resolved seed helpers

| Token | Value | Role | `xT/` home today | Gap |
|---|---|---|---|---|
| `resolved.seedHue` | `2.5217°` | The default hue. | `ThemeManager.defaultSeedHue` | Match parity-tested. |
| `resolved.seedStops` | `[2.52, 47.52, 92.52, 137.52, 182.52, 227.52, 272.52, 317.52]` | 8 quick swatches; the alternate-icon set uses the same stops. | Hard-coded in `ThemePickerView` | Use the token-driven list through generated constants (X7) so icon and picker always agree. |

---

## 2 · Type

Three OFL families, mapped through `Theme.FontFace` and exposed as `Theme.Fonts` roles. Every role scales with Dynamic Type via `Font.custom(_:size:relativeTo:)`.

### 2.1 Families

| Token | Name | Weights | License | PS name | Bundled today |
|---|---|---|---|---|---|
| `type.families.display` | IBM Plex Serif | 600, 700 | SIL OFL 1.1 (reserved name "Plex") | `IBMPlexSerif-SemiBold`, `IBMPlexSerif-Bold` | ❌ No |
| `type.families.mono` | IBM Plex Mono | 400, 500 | SIL OFL 1.1 (reserved name "Plex") | `IBMPlexMono`, `IBMPlexMono-Medm` | ❌ No |
| `type.families.prose` | Atkinson Hyperlegible Next | 400, 700 | SIL OFL 1.1 (Google Fonts release) | `AtkinsonHyperlegibleNext-Regular`, `AtkinsonHyperlegibleNext-Bold` | ❌ No |

**F1 Gap.** No `.ttf`/`.otf` files in the repo; no `UIAppFonts` in `Info.plist`; no `Font.custom` call. Add `xT/Resources/Fonts/`, register bundles there, record SHA-256 checksums in `xT/Resources/Fonts/README.md`. Bundle the license texts into `xT/Resources/Licenses/` (used by the Acknowledgements screen in F8). Use the Google Fonts release for Atkinson Next, **not** TeX Live or Braille Institute (license-forbids-derivatives).

### 2.2 Role scale → `Theme.Fonts`

| Token | Family / weight / size / `relativeTo` | Used for | `xT/` home today |
|---|---|---|---|
| `display` | serif 700 · 64 · `largeTitle` | (reserved) | `Theme.Fonts.display` (system today) |
| `readout` | mono 500 · 52 · `largeTitle` | Home level readout (H2, ST8) | (unused) |
| `largeNumber` | mono 500 · 48 · `largeTitle` | Record figures | (unused) |
| `hero` | serif 700 · 34 · `largeTitle` | Screen titles (Journal, Settings, Time hero) | (unused) |
| `numeric` | mono 500 · 32 · `title` | Secondary figures | (unused) |
| `serifTitle` | serif 600 · 22 · `title2` | Section titles, profile name, sheet titles | (unused) |
| `body` | prose 400 · 17 · `body` | Journal prose, body copy | `Theme.Fonts.body` (3 uses; should be the default on the root) |
| `serifBody` | serif 600 · 17 · `body` | Journal day labels, dose-section time | (unused) |
| `detail` | prose 400 · 13 · `footnote` | Subtitles, captions | `Theme.Fonts.detail` (1 use) |
| `label` | mono 500 · 12 · `caption` | Meta lines, provenance, countdown chips | (unused, use `.monoLabel()`) |
| `eyebrow` | mono 500 · 11 · `caption2` · `.18em` · caps | Section headers (S6) | `Theme.Fonts.eyebrow` (3 uses) + a new `.eyebrow()` modifier that also applies tracking+case+muted |
| `pill` | mono 500 · 11 · `caption2` · `.08em` | Chips | `Theme.Fonts.pill` (2 uses) |
| `statLabel` | mono 400 · 9 · `caption2` · `.14em` · caps | Gridline values, fine print stat labels | (unused) |
| `micro` | mono 400 · 10 · `caption2` | Small print | `Theme.Fonts.micro` (5 uses) |
| `statValue` | mono 500 · 18 · `headline` | Stat values | (unused) |

### 2.3 Aliases (the 11 standard text-style names `Theme.Fonts` keeps)

These catch the existing 146 `.font(.<textStyle>)` call sites so they shift to the new families at once (X2 decision). Each alias is `relativeTo` its own style.

| Token | Family / weight / size |
|---|---|
| `largeTitle` | serif 600 · 34 |
| `title` | serif 600 · 28 |
| `title2` | serif 600 · 22 |
| `title3` | serif 600 · 20 |
| `headline` | prose 700 · 17 (Atkinson Bold) |
| `body`, `callout`, `subheadline`, `footnote`, `caption`, `caption2` | prose 400 · 17/16/15/13/12/11 |

`Theme.Fonts.icon` stays a system font for SF Symbols sizing.

### 2.4 Supporting view modifiers

A `Font` alone can't carry letter-tracking or case, so these live as `ViewModifier`s in `Theme/Theme.swift` (F2):

| Token / modifier | Rule | Where |
|---|---|---|
| `.eyebrow()` | mono 11 + `.textCase(.uppercase)` + `.tracking(size × .18)` + `.muted`, `lineLimit(1)` | Section headers, page eyebrows |
| `.monoLabel()` | mono label + `lineLimit(1)` + `minimumScaleFactor(.8)` | All mono labels — the rule that prevents the "HOM/E" wrap bug |
| `.statLabel()` | statLabel role + `.textCase(.uppercase)` + tracking | Gridline values, provenance fine print |
| `ThemedFont` | reads `@Environment(\.legibilityWeight)`; Bold Text accessibility swaps Regular → Atkinson Bold and Regular → Mono Medium | Body and mono roles |

---

## 3 · Spacing, radius, line

Values come from the token numeric groups; names live in Swift (`Theme.Spacing`, `Theme.Radius`, `Theme.Line`).

| Token | Values | Swift home | Notes |
|---|---|---|---|
| `radius.*` | hairline 2 · xs 4 · chip 6 · control 8 · tile 10 · sm 12 · md 16 · lg 20 · xl 24 · specimen 28 | `Theme.Radius` (most already exist; add `Radius.specimen` for the Appearance preview) | Different legacy names today: `tiny`=6, `row`=10, `section`=28, `jumbo`=32. Rename or alias. |
| `spacing.*` | xxs 2 · xs 4 · s6 6 · sm 8 · s10 10 · md 12 · card 14 · lg 16 · xl 20 · xxl 24 · s28 28 · xxxl 32 · gutter 22 | `Theme.Spacing` (rename `jumbo`→`xxxl` etc.; add `gutter` for the 22 pt screen-edge) | Current names diverge; align them so a token read is one-to-one. |
| `line.*` | hairline 1 · engrave 0.75 · curve 1.8 · curveHero 2.5 · labRing 1.3 | New `enum Theme.Line { hairline, engrave, curve, curveHero, labRing }` | New (F3). Swift reads `.hairlineWidth` (legacy 0.5); replace. |
| `inkAlpha.line`/`.grid` under Increase Contrast | `inkAlphaIncreasedContrast.line` (0.28) / `.grid` (0.07–0.1) | `ThemePalette.increasedContrast` swap (F3) | The flag already re-resolves the palette; add these. |

---

## 4 · Logo / icon tokens

The wordmark and "I." mark are SVG masters in `docs/design/brand/`. The app can't draw them today; that's the F7 Gap.

| Token | Value | Role |
|---|---|---|
| `logo.masters` | `docs/design/brand/` | Source of truth |
| `logo.renderings` | `ink, hairline, emboss` | Three renderings, one shape |
| `logo.clearSpace` | cap height of "O" on every side | Enforced by callers |
| `logo.minWordmarkWidthPx` | 96 (22mm print) | Below → use "I." |
| `logo.minMarkPx` | 16 | Minimum icon size |
| `logo.smallMark` | "I." — the wordmark's I + perfect-circle point | The diameter = Plex Serif's period width |
| `logo.emboss.*` | light `#FFFFFF` @ 85% · shadow `#251F33` @ 16% · depth ratios `.012` / 2000+ → `.004` | The discretion rendering; only reads on day paper (X4 decision) |

**F7 · `IsoclineMarkPaths.swift` — Gap.** Extend `tools/scripts/build_isocline_marks.py` to emit a Swift file holding two `Shape`s (`IsoclineWordmark`, `IsoclineMark`) built from the same path data as `isocline-wordmark-ink.svg` / `isocline-mark-ink.svg`. Expose each mark's `viewBox` so callers can scale with `aspectRatio`. Verify a snapshot matches the SVG byte-for-byte.

### 4.1 Renderings as Swift views (S9)

| Rendering | Swift signature | Where used |
|---|---|---|
| `ink` | `IsoclineMarkView(rendering: .ink, color: accent)` | App splash, About, Research pages |
| `hairline` | `IsoclineMarkView(rendering: .hairline)` — stroke at `Theme.Line.engrave` | Loading states, empty states, chart watermarks |
| `emboss` | `IsoclineMarkView(rendering: .emboss)` — three layers: paper face, white offset up-left @ .85, dark offset down-right @ .16 | **Stealth icon** (O2, I3), packaging, print covers, lock screen |
| Reduce Transparency | emboss → hairline | Same call sites |

### 4.2 Brand architecture (spec §03)

One logo, three arms, told apart by a mono descriptor, never a different mark.

| Surface | Logo | Rendering | Owner |
|---|---|---|---|
| App icon | "I." | Ink on a seed-hue gradient ground | I1–I2 |
| Stealth icon | "I." | Emboss on plain paper, no hue, no name | I3 |
| App splash / About | Wordmark | Ink, or emboss in discreet mode | O1, F8 |
| Isocline Research papers | Wordmark + `RESEARCH` | Ink on white stock | `docs/research/isocline.sty` |
| Isocline Labs (legal, company) | Wordmark + `LABS` | Ink | `docs/legal/` |
| Favicon | "I." | Ink on paper | web |

### 4.3 Media variants (spec §11, transition W1)

| Medium | Rules | Source |
|---|---|---|
| App | Live seed hue; paper/night paper follow iOS appearance (nothing calls `preferredColorScheme`); Dynamic Type; native chrome. Time tab is the one always-night surface (T2). | `ThemeManager`, `ThemeEngine` |
| Web | Default seed. Load `tokens/isocline.css`; `color-scheme: light dark` + `prefers-color-scheme`; `data-theme` only as a reader-chosen override; per-scheme `theme-color` metas listed in the generator's `THEME_COLOR_PAGES`; no colors outside the tokens. | `gen_isocline_tokens.py` (W1, done) |
| Print (Research) | Near-black ink on white (`fixed.print`), Plex Serif body, Plex Mono numbers/running heads, Atkinson captions, one accent, no status colors. | `docs/research/isocline.sty` |

---

## 5 · Motion tokens

The animation language lives at `xT/Theme/Motion.swift`. The design rule: **gauges settle like an analog needle — one damped swing and no spinner.**

| Token-ish constant | Where | Rule |
|---|---|---|
| `Theme.Motion.settle` | overlay card height change (H10), gauge needles (Time tab) | Spring, damped; honors Reduce Motion via crossfade |
| `Theme.Motion.dotSlide` | now point entrance (H7) | Slide-in from the right, slide honors Reduce Motion |
| `Theme.Motion.pulse` | `NextDoseRowView` countdown | Gap: should respect Reduce Motion (F6) |
| `CelebrationGlowModifier` | X19 — retire | The curve morphing into the new point IS the celebration (X19). Delete alongside the confetti. |
| `CurveLayout` morph | `FlatGraphView.swift:148` | Already Reduce-Motion-aware. |

**F6 Accessibility gaps.** Reduce Transparency has no handler anywhere today. Reduce Motion is missing in `CelebrationGlowModifier`, `PressableButtonStyle`, and the pulse. Map all Reduce-Motion variants to opacity/crossfade with no choreography.

---

## 6 · Curve (instrument) tokens

The Home curve is the product's hero element. Every drawing constant lives in `tokens/curve.*`. The `xT/` code reads them through `Theme.Curve` (new in F3, removing literals from `FlatGraphView`).

| Token | Value | Element | `xT/` home today |
|---|---|---|---|
| `curve.fill.color` | `levelTint` | H4 | `FlatGraphView.swift:268-298` already lerps levelLow→levelHigh. ceiling 1200 (T) / 600 (E) hard-coded — keep, it's a data constant not a design token. |
| `curve.fill.topOpacity` | `0.3` | H4 | Today `.42`. Change. |
| `curve.fill.bottomOpacity` | `0.0` | H4 | Match. |
| `curve.fill.direction` | vertical | H4 | Match. |
| `curve.stroke.from` | `levelLow` | H4 | `LinearGradient` horizontal (.leading→.trailing). × = time, monotonic on a function graph = "along the line" (U11). |
| `curve.stroke.to` | `levelHigh` | H4 | Same. |
| `curve.stroke.direction` | "along the curve" | H4 | Horizontal idiom above. |
| `curve.nowPoint.haloOpacity` | `0.15` | H7 | Today blur + higher alpha; retune. |
| `curve.nowPoint.haloColor` | `accent` | H7 | Halo replaces today's blurred glow. |
| `curve.nowPoint.dotColor` | `levelTint` | H7 | Today 12 pt `levelTint`. |
| `curve.nowPoint.dotDiameter` | `10` | H7 | Today 12. |
| `curve.nowPoint.haloDiameter` | `26` | H7 | Today 26, with blur. |
| `curve.labPoint.style` | hollow ring | H6 | Ink stroke at `Theme.Line.labRing`, paper fill, no cap decoration. |
| `curve.labPoint.diameter` | `9` | H6 | New. |
| `curve.rangeBand.color` | `accent` | H5 | Today three dashed `successBrand` lines (replaced). |
| `curve.rangeBand.opacity` | `0.05` | H5 | Today `.14` per line. |
| `curve.rangeBand.label` | `"YOUR RANGE {low}–{high}"` | H5 | Top-left inside plot, `statLabel` mono `muted`, respects U18 (no band without user-set range). |
| `curve.rangeBand.maxSpanRatio` | `2.5` | H5 | Cap band y-span; band may clip but label reads true numbers. |
| `curve.rangeBand.bounds` | `troughMin…peakCeiling` (X9) | H5, ST7 | `troughMax` still used in the readout comparison / "within set trough" status. |
| `curve.glow.appearance` | `dark` | H4 | Allow faint stroke glow on night paper only; never under Reduce Transparency. |
| `curve.glow.opacity` | `0.35` | H4 | Shadow config. |
| `curve.glow.radius` | `6` | H4 | Shadow radius. |

### 6.1 Rules carried in copy

| Token rule | Where it lives in the app | Notes |
|---|---|---|
| **No dashed segment on the curve** | H4 — remove `therapeuticReferenceLines`, `dashedLine` | The curve is almost always modeled. Provenance is carried by the provenance **line** under the readout, not by line style. |
| **Hollow ring = measured lab** | H6 — `labPoint` | If model and draw disagree, the visible gap is the point; never snap ring to curve. |
| **Concentric point = now** | H7 — `nowPoint` | Same perfect circle as the "I." mark. |
| **Range band only when user set** | H5 + ST7 + U18 | Never for clinical defaults. |

---

# PART 2 · COMPONENT ELEMENTS

Each component is named in the design-system components table (§08) and its `xT/` home is live today or flagged as a gap.

## 7 · Readout

The Home level readout. Type-read-only, no card, flush on the paper.

> Today: a material card that dodges the now dot. Target: type flush on the paper.

| Property | Value / token | Implementation |
|---|---|---|
| Number | `readout` role (mono 500 · 52) with unit (mono, muted) | `H2` — rebuild `LevelOverlayView` as `HomeReadout`. `AnimatedCounter` gains a `formatter:` parameter that defaults to `AppNumberFormatters.hormoneLevel` (locale-grouped; bug Appendix A). |
| Eyebrow above | `ESTRADIOL · DAY 3`, mono caps `eyebrow()` | Built by `MedicationDisplayFormatter` (hormone base + due-day; the ester and interval total live on the dose card / phase strip); omit for daily routes. Trailing clearance = measured `ChartWindowPicker` width (`PickerWidthKey`), eyebrow row only. |
| Provenance line below | Mono caps `label` in muted; one of: `MODELED · NO LABS YET` / `MODELED · CALIBRATED TO YOUR LAB OF 4 MAR` / `MODELED · LAST LAB NOT USED FOR CALIBRATION` / `MODELED · FRI 14:00` (while scrubbing) | `H-D3` — `LevelProvenance`. Never "CALIBRATED TO N LABS" (X13/U3). |
| Optional status line | `AT TROUGH · WITHIN YOUR SET TROUGH` | `X18` — InsightRowView retires here as a flush line. |
| Safety pill | Outline + text + glyph in `safety` token, no fill; taps to show the clinical note | `X10` — gate only on real `SafetyFlag` cases; never gated by calibration or entitlement (§6.3 of calibration plan). |
| While scrubbing | Readout shows scrub value in accent; provenance line shows scrub time | `H2`; replaces the "Estimated" caption. |

Celebration modifiers on the readout retire with X19 (Part 8).

---

## 8 · Curve canvas

The full-height Home graph, drawn to §6. Data comes from the H-D supports (catalog in the Appendix); land and test those before the UI.

**Layout:** `FlatGraphView(plotInsets:)` replaces `dataRegionFraction`. Top inset = readout block height + 12 (`ReadoutBlockHeightKey`); bottom inset = overlay card + phase strip + 12 (`OverlayCardHeightKey`). The fill still closes at the screen bottom, behind the card; the bottom inset tracks the card's live height as the dose state changes (H1).

---

## 9 · Phase strip

Four stationary text columns under the curve — weekday over the positional word. Only the Today column is ringed in accent (the Journal week strip's today-circle motif); the rest are bare muted type.

| Property | Token / rule | `xT/` home |
|---|---|---|
| Copy | `MON Dose · WED Peak · FRI Today · SUN Trough` (weekday when ≤ 14 d interval, `MAR 4 Dose · APR 2 Peak · …` above) | New (Home). Two-line `PhaseColumn`s, weekday `.statLabel()` over word `.monoLabel()` |
| Layout | Stationary even columns across the card's margins — never scrolls | 2–4 markers, `.frame(maxWidth: .infinity)` each |
| Today column | accent text + accent hairline rounded-rect ring (`Radius.sm`) | same |
| Alignment | NOT x-aligned to the chart (window is ~3 d, interval is 1–70 d) | `H9`, X11 decision (U5) |
| Hidden when | `cyclePhaseMarkers()` is empty (daily routes) | `H9`, X11 |
| PEAK omitted when | tmax isn't calibrated (`PharmacokineticConstants.isTmaxCalibrated`) | `H-D2` honesty rule |
| Words are positional, never goals | `PEAK`, `TROUGH`, `DOSE`, `TODAY`; `STEADY` is reserved for the readout status | `H9`, X18 |

---

## 10 · Overlay card

One paper card docked above the tab bar on Home, holding sections split by hairlines. It is only as tall as its content.

| Token | Value | Implementation |
|---|---|---|
| Surface | `paperCard(radius: Theme.Radius.lg /* 20 */)` — card fill, hairline `Theme.Line.hairline`, no shadow | `S1` — replaces `.asGlassCard()` |
| Sections | Dose (H11) ↑ hairline ↑ latest journal (H12) | `H10` — replaces `UnifiedStackView` (InsightRow/MoodRow/NextDoseRow/ActionBar all retire) |
| Height animation | `Theme.Motion.settle`, or crossfade under Reduce Motion | `H10` |
| Height report | `OverlayCardHeightKey` consumed by `FlatGraphView(plotInsets:)` | `H1` |
| Dose section states | `.dueToday` full height + Log Dose · `.upcoming` one row `NEXT DOSE Fri 6:00 PM · IN 2D`, no pill · `.overdue` like dueToday with neutral ink chip `2D AGO` (never red) · `.unscheduled` → H15 card | `H11`, `H-D1`, X14, X16 |
| Medication line | `ESTRADIOL VALERATE 4 MG · INJECTION` — route is the **method word** (`INJECTION` / `CREAM` / `ORAL`). The spec's `· SC` can't be shown: the data has no SC/IM distinction | `H11`, U6 (route depth deferred — schema change) |

---

## 11 · Action pill

The only filled, high-chroma control in the system.

| Property | Token / value | Current | Target |
|---|---|---|---|
| Fill | `accent` (recipe) | `AccentActionButton` — accent × .8 (translucent) | Solid accent |
| Text | `OnAccentPalette.primary` in Atkinson Bold (the `headline` alias) | `.white` `.headline.weight(.medium)` | Token-driven |
| Shape | Capsule, minimum height `components.actionPill.minHeight` (`44`) | `Radius.md` `56pt` rounded rect | Capsule |
| Variants | `.inline` (inside cards) · `.floating` (centered, resting on a paper fade) | single full-width | `ActionPill(title:systemImage:variant:action:)` |
| Uses | Log Dose (Home card) · New entry (floating on Journal) | `+` circle FAB on Journal | FAB retires (J8) |

The `.floating` variant rests on the floating fade (§20).

---

## 12 · Journal entries

The "what is / what you adjust" principle applied in time. Today the top entry is a card (still open to you — "now"); everything older is flush rows (the record).

### 12.1 Top slot: card or ghost

```swift
enum JournalTopSlot { case card(JournalEntry), ghost }
// card iff entries.first exists && Calendar.current.isDateInToday(entries.first!.date)
```

| Element | Spec | Implementation |
|---|---|---|
| **Top card** (`paperCard`) | time-of-day glyph in an icon tile · serif day + muted period (**Sunday morning**) · mono meta `08:30 · ESTRADIOL VALERATE 2.0 MG` · quote in Atkinson · mood chips | `J3`; rebuilds the current flat row at the top |
| **Ghost card** (`ghostCard`, hairline only) | `Tap "New entry" below to write in your journal.` in muted Atkinson, centered. NOT a button. | `J3`; replaces `EmptyJournalView` (deleted) |
| Only the NEWEST card today | one entry per "now" — extras from today are flush | `J3`, X20 decision |

### 12.2 Flush rows (older entries)

| Element | Spec | Implementation |
|---|---|---|
| Surface | none — straight on paper | `J4` |
| Separators | `HairlineDivider(inset:)` | `S3`, `J4` |
| Glyph | time-of-day without tile | `J4` |
| Day | serif, e.g. `Saturday evening` | `J5` via `DayPeriod` helper |
| Quote | one line in Atkinson | `J4` |
| Time | mono, at right | `J4` |
| Day group header | eyebrow mono caps `SUNDAY 12 OCT`, localized `journalDateLabel` | `J4`, `J11` |

### 12.3 Week strip

Replaces `TimelineScrubber` (capsules-with-entries-only). From `Calendar.current.firstWeekday`:

| Element | Spec | Implementation |
|---|---|---|
| Day numbers | mono 7-day row | `J2` |
| Today's number | accent hairline ring | `J2` |
| Dose dot | filled accent (below the day) | `J2`; uses `doseDays(in:)` |
| Entry dot | hollow ink-muted (filled vs hollow differs by shape, not only color — F6) | `J2`; uses `entryDays(in:)` |
| Paging | horizontal paged ScrollView, starts current week, bounded by first dose/entry | `J2` |
| Tap behavior | taps scroll to that day's group; days without entries are inert | `J2` |
| Accessibility | "Thursday 17, dose recorded, 2 entries" | `J2` |

### 12.4 Composer (the sheet)

| Element | Spec | Implementation |
|---|---|---|
| Surface | Sheet glass system — the glass IS the card surface (U13) | `J9`; remove the opaque `appBackground` + `.regularMaterial` bar |
| Title | `serifTitle` in ink, "New entry" | `J9` |
| Text area | `ghostCard` outline + `body` (Atkinson) with ink text | `J9`, `S2` |
| Level row | mono value + unit, with `levelBandLabel` band | `J9` — voice check |
| Buttons | Cancel (`ToolbarItem(.cancellationAction)`) · Save (`ToolbarItem(.confirmationAction)`) — iOS 26 renders these as glass natively | `J9` |
| Detents | `[.medium, .large]` from every entry point | `J9` (today Home shows no detents) |
| Edit mode | `mode: .new \| .edit(JournalEntry)` — tapping a card opens it | `J10`, X22 decision |

### 12.5 Edit + delete

Today neither exists. Add `JournalManager.update(_:)` / `delete(_:)` (both save + refresh the cache); the detail sheet shows Edit in the toolbar; rows get swipe-to-delete with confirmation (J10). Symptom match by **name** not UUID (regenerates per launch — bug, `J10`, `JournalModels.swift:102-111`).

---

## 13 · Section card (Settings gateway)

The Settings gateway pattern: paper card, accent icon tile (one accent everywhere), serif title (per the screen sketch), **mono subtitle with live values**, chevron. The root composes under an ISOCLINE brand eyebrow over the serif screen title.

| Token | Value | `xT/` home |
|---|---|---|
| Card | `paperCard(radius: lg)` | New — replaces the 2×2 quick-card grid + inline sections (ST1, X24) |
| Icon tile | `components.tile.size` (32) · `fillOpacity` (0.13) · radius `control` (8) | `SettingsRowKit.swift` — the tile follows the token, **no caller colors** (S7) |
| Title | `serifBody` (the screen sketch; was sans `callout` — supersedes the earlier "sans title" read of §08) | `SettingsRowKit.swift` (`SettingsGatewayCard`) |
| Subtitle | mono `label` role, live values (`ESTRADIOL VALERATE · 4.0 MG Q7D`) | `SettingsRowKit.swift`, built by `SettingsView` (ST5) + `MedicationDisplayFormatter` (H2) |
| Root icons | `plus` / `diamond` / `circle.righthalf.filled` / `square` (Medication · Labs · Appearance & Curve · Privacy) | `SettingsView.swift` — the sketch's set |

Live subtitle examples (ST5):

| Gateway | Live values | Implementation |
|---|---|---|
| Medication & Dose | `ESTRADIOL VALERATE · 4.0 MG Q7D` | `MedicationDisplayFormatter` + `resolvedDoseDefaults` + `effectiveDueIntervalDays` |
| Labs & Records | `2 LABS · LAST 14 D AGO` / `NO LABS YET` | `bloodTestHistory` + last-draw age (^ inflects via `AttributedString` — `String(localized:)` leaks the directive) |
| Appearance & Curve | `HUE 2° · DEFAULT ICON` | `seedHue` + icon name |
| Privacy & Data | `FACE ID · ICLOUD ON` / `LOCK OFF · ICLOUD OFF` | `AuthenticationManager` state + `icloudSyncEnabled` |

The footer (flush, no card): `ISOCLINE · VERSION 1.0 (42)` · Acknowledgements link · `SHAPED PROTOCOL.` — mono at `faint`, from `CFBundleShortVersionString`+`CFBundleVersion` (ST10, F8; kills hardcoded "0.9").

---

## 14 · Profile avatar

**Flush on the paper, no card.** The spec's most deliberate "what is" element.

| Token | Value | `xT/` home |
|---|---|---|
| Sizes | `components.avatar.row`=56 · `.header`=72 · `.settingsHero`=88 (centered Settings block) · `.editor`=112 | `SettingsView.swift`, `ProfileEditorView.swift`, `OnboardingView+StepsLate.swift` |
| Ring | `components.avatar.ring` → 1 px `Theme.Line.hairline` in `line` color | Today: 0/2/3 pt rings + a 3 pt gradient ring + shadow in the editor (S8, ST2) |
| Placeholder | Accent disc with `person.fill` glyph in `OnAccent`, **drawn in SwiftUI** so it tracks the hue live | `ProfileManager.renderPlaceholder` is a static 200×200 UIImage (S8 Gap) |
| Photo | User's own, chosen from library / camera, stored on-device / iCloud | `ProfileManager.profilePhoto` |
| Never | On the icon, in notifications, in widgets | S8 — same rule; design mockups must use placeholder not stock photography |
| Layout | Screen sketch: centered column — avatar, serif name, mono tenure in caps — flush on the paper | `SettingsView.profileHeader` (ST2) |
| Edit | Explicit EDIT mono caption in accent beneath the tenure line (X26) — the centered block itself is not the control | ST2 |

---

## 15 · Hue specimen (Appearance)

The Appearance screen opens on a **specimen**: a near-square window (1 : 1.08 aspect) of sample UI that follows the hue dial. It must be built from the real components at their real sizes with **sample data**, never a screenshot, never user numbers.

| Element | Spec | Implementation |
|---|---|---|
| Frame | `RoundedRectangle(cornerRadius: Theme.Radius.specimen /* 28 */ , style: .continuous)` at aspect 1 : 1.08 on paper with a `line` hairline | `S11` — `ThemeSpecimenView(preview:)` — Gap; `ThemePickerView` today shows three `timeSwatch` chips on `timeCard` |
| Contents (sample) | readout + provenance · curve with sweep + lab ring + now point + range band · phase strip · dose card with **Log Dose** ActionPill · chips · icon tile · toggle · the "I." app icon | `S11` — built by composing the real primitives over `SpecimenSample` static fixture |
| Dynamic Type inside | capped at `.large` (it's a preview) | `S11` |
| Accessibility | one element, one summary label, "Preview of the app in the chosen hue" | `S11` |
| Day/Night preview | `Pill`s "Day" · "Night" scoped to the specimen only via `.environment(\.colorScheme, preview)` | `S11` |
| Hue band | existing control — restyle thumb to paper with ink hairline and accent core | `ST8` |
| Quick stops | 8 circles from `resolved.seedStops` (§1.3) | `ST8` — Gap today |
| Readout row | mono `HUE 2.5° · ACCENT #D4537E`, plus "Default rose" as plain accent text | `ST8` |
| Drag behavior | updates specimen on `input` (every frame) and commits on `up`; profiling will tell if a preview palette is needed | `ST8`, `S11` |
| Onboarding reuse | same picker appears in onboarding — specimen shows the app before setup | `O1` rule |

---

## 16 · Notification layout

The dose reminder, customizable by the user. The default is **Discreet** (names nothing). Four presets plus custom field-by-field control.

| Preset | Title | Body | Action |
|---|---|---|---|
| **Discreet** (default) | Reminder | "Your scheduled entry is ready." | Open |
| Standard | Dose reminder | `{med} {amount}` | Log dose |
| Detailed | Dose due | `{med} {amount} · {route} · due {time} · suggested site: {site}` | Log dose |
| Custom | Reminder / Dose reminder / Isocline / *own words* (≤ `NotificationLayout.ownWordsMaxLength`=40, device-only) | any subset of: med, amount, route, time, site | Open or Log dose (user's pick) |

**Home in the app:** Settings → Medication & Dose → Reminders (X25), next to the reminder times. Both actions open the record-dose sheet; **nothing is logged from the lock screen**.

| Implementation | Notes |
|---|---|
| `NotificationLayout: Codable, Equatable` | preset, title, fields, actionLogsDose; persisted in UserDefaults; default `.discreet` (NT1 + X35) |
| `NotificationContentBuilder.content(for:doseContext, layout:)` | pure and unit-tested; uses `MedicationDisplayFormatter` + site suggestion (NT1, H-D6) |
| Two dose categories (`doseReminder.open`, `doseReminder.log`) | registered once at launch, swapped based on layout (NT1) |
| Hidden-previews placeholder = **"Reminder"** for both | Today it says "Dose reminder" — discretion leak (Appendix A) |
| `NotificationLayoutView` live preview | renders via the builder with sample data, alongside the hidden-previews placeholder (NT1) |
| Note beside preview | iOS always draws app name + icon ("ISOCLINE") — pair Discreet with the Discreet icon (I3, U19) |

**Journal reminders** take the same title style, body carries no health data.

---

## 17 · Pill / chip

The flat, hairline-bordered control. Used for mood chips, quick tags, preset selectors, count-down chips.

| Token | Value | `xT/` home today | Gap |
|---|---|---|---|
| Font | `pill` role (mono 11 · .08em) | `Pill.swift` | keep |
| Border | `line` hairline | varies | one tint |
| Active state | accent **border**, not a fill | `.tinted` `.material` `.gradient` styles exist | collapse styles to `.neutral` + `.active`; delete `.material` `.gradient`; remove `.gradient` from `Pill.swift:58`; active state on `SelectableOptionRow` gets the same treatment (S5) |
| Shape | full radius (capsule) | yes | keep |
| Fix prelude copy | old preview uses "optimal" success / "3 days late" error — both violate voice | `Pill.swift` previews | Rewrite to `Within set trough`, `Next dose in 2d` |

---

## 18 · Eyebrow / section header

The mono 11 + .18em caps muted eyebrow is the system's quiet "you are here" sign.

| Token | Value | Implementation |
|---|---|---|
| Type | mono 500 · size 11 · relativeTo `caption2` | New `.eyebrow()` modifier (F2) |
| Tracking | `.18em` (points = size × em — compute with `@ScaledMetric` so Dynamic Type keeps the relationship, or accept fixed tracking at this size) | F2 |
| Case | caps via `.textCase(.uppercase)` (so translations keep their own casing) | `S6` |
| Color | `muted` | `S6` |
| Optional serif title beneath | `serifTitle` role (`Theme.Fonts.serifTitle`) | `S6` — `SectionHeader` accepts an optional `LocalizedStringResource` |
| Localized | `LocalizedStringResource`, not `String` (X31) | `S6`, ST13 |
| Today's bug | `SectionHeader` takes `String` and renders verbatim | `S6` rewrite |

---

## 19 · Tile (icon tile)

A 32 pt rounded square carrying an accent glyph at low chroma. One accent everywhere (S7).

| Token | Value | `xT/` home today | Gap |
|---|---|---|---|
| Size | `components.tile.size` = 32 | `SettingsRowKit.swift:89-106` | Live |
| Fill | `accent` at `components.tile.fillOpacity` = 0.13 | Caller-chosen colors (8 variants across Settings today) | Delete the parameters; compiler flags the call sites |
| Radius | `components.tile.radius` → `control` (8) | Yes | — |
| Glyph | accent | varies | one accent |

Use site: Settings gateway cards, top-Journal-card mood glyph, dose summary chips. Settings review: `InjectionSite.swift:119`'s `.patch → warning` is a data color, not a tile — review in H13.

---

## 20 · Floating fade

The subtle paper fade a floating action pill (New entry) rests on so rows scroll beneath.

| Token | Value | `xT/` home today | Gap |
|---|---|---|---|
| Height | `components.floatingFade.height` = 48 | none (FAB today with shadow) | `J8` — try `safeAreaBar` first; fall back to `LinearGradient(paper.opacity(0) → paper)`; Reduce Transparency → solid paper band (U15) |

---

## 21 · Surface primitives

Spec §07 names four surfaces — flush, paper card, emboss, glass (system only). The modifier layer below implements them; `ThemedFont` lives with type in §2.4.

| Modifier | Rule | Uses |
|---|---|---|
| `PaperCardModifier` (`paperCard(padding:radius:)`) | padding `.card`(14) · radius `.lg`(20), card fill, `line` hairline `strokeBorder` so it stays inside, no shadow | `S1`; replaces `asGlassCard`, `timeCard`, `settingsCard`; replaces 9 hand-written cards in `DoseScheduleSettingsView` + `ProfileEditorView` |
| `GhostCardModifier` (`ghostCard()`) | Same shape+hairline as paperCard, **no fill**, not a control, no tap target | Journal ghost slot (J3), composer text area (J9), engraved empty states (H15) |
| `HairlineDivider(inset:)` | `line` color at `Theme.Line.hairline` | `S3`; replaces `Divider().opacity(0.5)` everywhere |
| `paperList()` | `.scrollContentBackground(.hidden)` + `.background(paper)` + `.listRowBackground(card)` + `.listRowSeparatorTint(line)` | `ST6`; on every pushed `List`/`Form` |
| **Flush** (no modifier) | Type straight on paper — reserved for what *is* | Readout, profile header, older journal rows |
| **Emboss surface** | Relief on paper, no ink — same treatment as the emboss mark (§4.1) | Discreet states: lock screen (O2), stealth icon (I3). Reduce Transparency → hairline |
| **Glass** | System chrome only: tab bar and sheets. Never `.glassEffect` on content; inside a sheet the sheet glass *is* the card | `S10`, U13 |

---

## 22 · Fixed shadows & glow

| Token | Allowed | Rule |
|---|---|---|
| Shadow | **none on paper** (depth reads from the hairline) | F10: delete `Theme.Shadows.floating`, `accentFab`, raw `.shadow` calls |
| Glow | night paper only, on the curve stroke only, at `curve.glow.opacity` and `curve.glow.radius` | H4; off under Reduce Transparency |

---

# PART 3 · NAVIGATION & SHELL

## 23 · Tab bar (N1)

Four destinations in this order: **Home · Journal · Time · Settings** — matches `MainTabView` today.

| Token | Rule | Implementation |
|---|---|---|
| Order | H·J·T·S | keep |
| Style | iOS 26 system glass pill (floating, no custom drawing) | `N1` — migrate to `Tab("Home", systemImage: "house", value: .home)` + `TabView(selection: $router.tab)` |
| Iconography | SF Symbols, regular weight, one family across every tab | keep |
| Labels | system font (U1 / X34 — mono caps labels rejected as unsupportable; amend spec §09) | keep |
| Active tint | `accent` | `.tint(accent)` keep |
| `tabBarMinimizeBehavior` | off for v1 | `N1` — Home doesn't scroll, Journal pill would have to track it. Revisit after J8. |

---

## 24 · Router (N2)

Today `NotificationManager.pendingRoute` is set but never consumed (Appendix A defect). Add `@Observable AppRouter` injected at the scene:

| Route | Action |
|---|---|
| `.logDose` | `tab = .home`, `presentRecordDose = true`, then clear |
| `.journal` | `tab = .journal`, `journalScrollToTop = true`, then clear |

`ContentView` observes `notificationManager.pendingRoute` and applies routes *after* unlock. Home's journal section (H12) uses the same router.

---

## 25 · Toolbars (N3)

| Status | Rule |
|---|---|
| Today | every tab hides/blanks its navigation title (`toolbar(.hidden)`, `navigationTitle("")`) |
| Keep | in-content serif titles per tab |
| Pushed sub-screens | standard inline titles in the system font — do NOT customize the nav-bar font on iOS 26 (fights the glass bar) |

Cancel/confirm live in `ToolbarItem(placement: .cancellationAction / .confirmationAction)` — iOS 26 renders them as glass natively (J9).

---

# PART 4 · VOICE (spec §10)

Position, direction, provenance — never judgment. This is the design system's tone rulebook. Every appearance of data on screen obeys it; a handful of curated examples from the spec live here as the canonical reference.

| Write | Not |
|---|---|
| "218 pg/mL · inside your range" | "Great job! Levels look good 🎉" |
| "YOUR RANGE 100–600" · "PEAK" · "TROUGH" | "TARGET PEAK" · "TROUGH LIMIT" |
| "Modeled from your last lab, 14 days ago" | "Warning: level too low" |
| "Lower than this time last cycle" | "You missed a dose!" |
| "No entry yet today" | "7-day streak" |

The one exception to "no red" is the safety pill (X10) for the documented clinical thresholds — and even that states the clinical association, never instructs. Copy describing `TIME_REGION_COPY.md` is revisited against this standard in that doc's own PR.

---

# PART 5 · SCREEN-SPECIFIC REGISTERS

Concise "what lives where" indexes for each screen. PR-level detail is in `isocline-app-transition.md`; this is the map. Registers carry **mapping + ID + screen-specific deltas only** — tokens for each element are detailed in Parts 1–3, referenced here not restated.

## 26 · Home element register

| Element (token ref →) | `xT/` home today | Element ID |
|---|---|---|
| Ground (§1 paper) | `HomeGradientBackground` + black veil | H1 |
| Eyebrow (§18) | "Estimated" caption in `LevelOverlayView` | H2 |
| Readout (§7) | material card + animated counter | H2 |
| Provenance (§7) | none | H3, H-D3 |
| Curve (§6/§8) | `FlatGraphView` — solid stroke, dashed ref lines, high-alpha fill | H4–H7 |
| Range band (§6) | three dashed `successBrand` lines + "Peak ceiling" / "Trough" labels | H5 |
| Lab rings (§6) | none on Home (only LabsChartView) | H6 |
| Now point (§6) | 26pt blurred halo + 12pt dot | H7 |
| Dose markers | **retire**: hollow next-dose ring reads as a measured lab — `lastDoseDot` + `nextDoseDot` | H8 |
| Phase strip (§9) | none | H9 |
| Overlay card (§10) | `UnifiedStackView` (glass) | H10 |
| Dose section (§10) | buggy "Today/Next" line + dot track + red-missed badge | H11 |
| Journal section (§12) | `MoodRowView` today-only | H12 |
| Record-dose | always `QuickDoseSheet` with `LAST SITE`/`SUGGESTED` (H-D6) | H13 |
| Dose-log feedback (§5) | `HomeConfettiBurst` + `.celebrationGlow` — replace with curve morph + haptic | H14 |
| Empty "Engraved" | text placeholder → single ink hairline curve + Atkinson copy + `paperCard` + `ActionPill` | H15 |
| Accessibility-size scroll | not handled — wrap in ScrollView at `dynamicTypeSize.isAccessibilitySize`, curve at `HomeLayout.accessibilityCurveFraction` (0.4) | H1, U17 |

## 27 · Journal element register

| Element (token ref →) | `xT/` home today | Element ID |
|---|---|---|
| Title (§2 hero) | `.system(size:52,bold)` + brand gradient + bogus count | J1 |
| Week strip (§12.3) | `TimelineScrubber` capsules+gradient | J2 |
| Top slot (§12.1) | flat row or `EmptyJournalView` | J3 |
| Rows (§12.2) | flat row + valence dot | J4 |
| Day period glyph (§12.2) | no helper | J5 |
| Top card meta (§12.1) | none — doses not linked | J6 |
| Mood (§17) | `JournalTheme.palette(for:)` valence tint | J7 |
| Floating `New entry` (§11, §20) | 56 pt FAB + `accentFab` shadow + secondary 50 pt material dose-history circle | J8 |
| Composer (§12.4) | opaque bg + material bar + serif colored text | J9 |
| Edit / delete (§12.5) | none | J10 |
| Localized strings (Part 7) | several raw `String`s | J11 |
| Seed personas | spoof entries all at midnight, symptoms never match | J12 |

## 28 · Settings element register

| Element (token ref →) | `xT/` home today | Element ID |
|---|---|---|
| Profile header (§14) | semi-flush today; editor view pushed with its own NavigationStack | ST2 |
| Gateway cards ×4 (§13) | five inline sections + 2×2 quick grid | ST1 |
| Footer (§13) | hard-coded "0.9" + "Encrypted" mislabel (X28) | ST10 |
| Sub-screens (§21) | mixed; `DeveloperSettingsView` uses private clones | ST4, ST6 |
| "Your range" (§6 range band) | today: `Trough lower bound` etc. + the **load bug** (`useCustomTargets` never read) | ST7 |
| Appearance screen (§15) | swatch chips on timeCard | ST8, S11 |
| Labs chart (§6) | index-based x + solid + dashed modeled + 7pt dots | ST9 |
| Dose record (§12.2 dot vocabulary) | 140pt ring + "consecutive on-schedule" (verdict) | ST11, X30 |
| Row-title localization (Part 7) | `String`s throughout (verbatim) | ST13, X31 |
| Reset row (§13) | today sits in 2×2 quick grid; move to last card in Privacy & Data, **no tile**, destructive-red label, kept 3-button alert | ST12 |

## 29 · Time tab element register

| Element (token ref →) | `xT/` home today | Element ID |
|---|---|---|
| Night tab | piecemeal `.environment(\.colorScheme, .dark)` — apply at `TimeView` root | T2 |
| Type scale (§2) | raw sizes — map: 42→`hero`, 20→`serifTitle`, 13/14→`detail`, 11 caps→`.eyebrow()` | T1 |
| Explicit `Color.white` | keep — the tab is always night | T1 |
| ProfileSurface glass | `.glassEffect(.regular.tint(.base.opacity(.12)))` at `TimeRegionDetailView.swift:398` → night card (`card` dark recipe × .85 + `line` hairline + `Radius.xl`) | T3 |
| TierCelebrationOverlay | `TimeView.swift:182-250` → quiet `MONTH 13 · NEW CHAPTER UNLOCKED` line inside `TimeHeroHeader` | T4 |
| Time palettes | keep `TimeContentPalette` + `Theme.Colors.Time.*`; exclude file from theme-lint baseline | T5 |

## 30 · Onboarding / lock / launch register

| Element (token ref →) | `xT/` home today | Element ID |
|---|---|---|
| Ground (§1 paper) | brand gradient at `OnboardingView.swift:101`, `CloudSyncChoiceView.swift:16` | O1 |
| Welcome (§4) | none yet — `IsoclineWordmark.ink` via F7 output | O1, S9 |
| Avatar (§14) | 100 pt + 2 pt OnAccent ring + shadow → hairline ring, no shadow | O1 |
| Primary buttons (§11) | rounded rect → `ActionPill` capsule | O1 |
| Text styles (§2) | 53 bare text-style + 5 `.system` → alias-mapped | O1 |
| Hue picker (§15) | inherits from Settings — same specimen-driven picker | O1 |
| Lock screen (§4 emboss) | brand-gradient auth views → paper + embossed "I." centered, no name, no color block | O2 |
| Launch storyboard | white bg → static `LaunchPaper` color asset (default-seed paper light/dark); leave the mark out | O3 |
| `ProfileNamePromptView` | sheet with opaque bg → sheet glass + `ghostCard` field + `ActionPill` | O4 |
| Calibration step (post-review) | none — "Want to add a lab result now to unlock your level curve?" [Add a blood test] / tap-and-hold "Skip for now" | `calibration-and-subscriptions-plan.md` §9 |

## 31 · App icon / alternates register

| Variant | Token ref | Implementation | ID |
|---|---|---|---|
| Primary icon | §4 "I." on `brandColors` gradient; Icon Composer derives dark/clear/tinted | rebuild `xTGlassIcon.icon` from `isocline-mark-ink.svg`; delete the mismatched byte-identical "Picsart" PNGs | I1 |
| Hue alternates | one icon per stop in §1.3 + default = 9 | additional `.icon` files under `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`; verify Xcode 26 accepts Icon Composer outputs as alternates, else export PNG sets | I2 |
| Discreet / stealth (§4) | embossed "I." on neutral paper; no hue | "Discreet" choice in the picker | I3 |
| Icon picker | grid with "Match my hue" → nearest stop | `setAlternateIconName` guarded `#if !targetEnvironment(macCatalyst)`; never switch silently — show "Update icon to match?" row | I4 |

---

# PART 6 · ACCESSIBILITY ELEMENTS

Each element's accessibility rule, in one place. Voice reads what *is*, in the same measured tone.

| Feature | Rule | Implementation |
|---|---|---|
| Dynamic Type | every role scales via `Font.custom(_:size:relativeTo:)`; the **specimen** caps at `.large` | F2, S11 |
| Increase Contrast | `inkAlphaIncreasedContrast` swaps `line` (0.28) and `grid` (0.07/0.10); text floor 7:1 | F3, F6 |
| Reduce Motion | `pressable scale`→opacity · `pulse`→static · dose-card height→crossfade · curve morph→crossfade · celebration→off | F6 |
| Reduce Transparency | emboss→hairline · floating fade→solid band · now-point halo→solid 30% | F6 |
| Bold Text (legibilityWeight) | `ThemedFont` swaps Atkinson Regular→Bold and Mono Regular→Medium | F2 |
| Differentiate Without Color | week-strip dose dot filled vs entry dot hollow — shape differs, not only color; safety pill carries glyph; no red/green data verdicts anywhere | F6, J2, X10 |
| VoiceOver | ActionPill = announced button · Action row = single element · specimen = one summary label · hues band = adjustable ±10° per swipe · phase chips = labels not buttons · lab rings = "Lab, 4 March, 212 pg/mL" | F2, S11, H6 |
| Mono label rule | never wrap mid-word — `lineLimit(1)` + `minimumScaleFactor(0.8)`, or shorten copy | `.monoLabel()`, **canonical bug**: Stitch "HOM/E" — F2 |

---

# PART 7 · LOCALIZATION ELEMENTS

| Token / fix | Rule | Where |
|---|---|---|
| `String(localized:)` / `LocalizedStringResource` | every new user-facing string | Ground rules |
| Mono caps | `.textCase(.uppercase)` on the modifier, never `.uppercased()` | `S6`, `H11` |
| Day-period format | localized `"%1$@ %2$@"` string so locales can reorder ("Sunday morning" vs "matin dimanche") | `J5`, U9 |
| Provenance age buckets | days < 14 · weeks < 60 · months (named constants) | `H-D0`, `H-D3` |
| Verbatim titles to retire | "Type & method", "Medication & Body", "Theme", "iCloud Sync", Settings row titles (current bug) | `ST13` |
| "Today"/"Yesterday" | route through a calendar-aware localized key | `J11`, `JournalTheme.swift:105-109` |

---

# PART 8 · RETIRED ELEMENTS (migration targets)

Retire these along with their owning PR. After PR 10 none of these symbols should exist; `lint_theme.sh` (F9) enforces.

| Retire | Why | Replacement |
|---|---|---|
| `Theme.Gradients.brand` as a ground (11 uses) | F4 ground-rule; keep only for the icon brand colors | paper |
| `asGlassCard` / `GlassCardModifier` + dead `#available` branch | iOS 26 only; glass on content banned | `paperCard()` (S1) |
| `timeCard` | one caller (ThemePickerView swatches) | `paperCard()` |
| `settingsCard` | zero production callers | `paperCard()` |
| 9 hand-written cards (`DoseScheduleSettingsView{120,174,207,245,496,556,602}`, `ProfileEditorView{128,177}`) | duplicated work | `paperCard()` (S1) |
| `.glassEffect` on content (UnifiedStackView:37, QuickDoseSheet:445, TimeRegionDetailView:398) | glass belongs to system chrome | paperCard / night card (T3) |
| `HomeGradientBackground` + black veil + `Graph.base*` | paper ground is flat; glow is allowed only on the curve | H1 |
| `HomeConfettiBurst`, `CelebrationGlowModifier`, `.entranceScale` | X19 | curve morph + haptic (H14) |
| `therapeuticReferenceLines`, `dashedLine` | no dashed segments; band replaces lines | H5 |
| `InsightRowView`, `MoodRowView`, `NextDoseRowView`, `ActionBarView` | overlay card holds dose+journal only | H10–H12 |
| `RecordDoseView` ("fast" date-only sheet) | perf-clipped at `.height(300)`, skips site | QuickDoseSheet (H13 + X15) |
| `TimelineScrubber` | week strip is the page header | J2 |
| Valence mood palette (`JournalTheme.palette(for:)` + four hex pairs) | colors are verdicts, chips are neutral | J7 |
| 56pt FAB + `accentFab` shadow + material dose-history circle | one floating action per screen | J8 |
| Opaque composer background + material bar + serif color swatches (#72243E / #F4A8C0) | sheet glass is the surface (U13) | J9 |
| `AdherenceView` (ring + consecutive count + "since missed") | a ring reads as a score, a streak reads as a verdict | "Dose record" ST11 |
| Brand gradient in `SettingsView+Header` avatar placeholder | SwiftUI placeholder tracks hue live | S8 |
| Quick-card 2×2 grid (Settings) | duplicates live values that gateways now carry | ST3 |
| `successBrand` (if no other callers after H5) | retired from chart per H5; tokens' `fixed.success` note updated | F3 |
| `AccentButtonModifier` + old `AccentActionButton` shape (keep as deprecated typealias during transition) | `ActionPill` capsule | S4 |
| Safety red on curve / data | X10 — red only on a documented-clinical pill with glyph | H5 |
| `Pill` `.material` `.gradient` styles | neutral+active only | S5 |
| `Theme.Shadows.floating` and `accentFab` | no shadows on paper | F10 |
| `ThemePickerView` swatch preview `timeCard` | specimen replaces | ST8, S1 |
| Hard-coded "0.9" version string | read from bundle | F8 |
| `xTlogoLetters.png` + "Picsart" PNGs + duplicate PNG | rebuilt in Icon Composer | I1 |
| "Dose reminder"/medication on lock screen | discretion (NT1) — was naming medication in the banner body and in the hidden-previews placeholder | Discreet default |

---

# PART 9 · VERIFICATION MAP

Every element above has a verifying surface. Lint runs before each phase PR via `tools/scripts/lint_theme.sh` (F9). Tests run through the Xcode MCP (`RunSomeTests` / `RunAllTests`), not `xcodebuild test`.

| Verify | What it gates |
|---|---|
| `xTTests/FontRegistrationTests` | every `Theme.FontFace` resolves to a real face (catches `IBMPlexMono-Medm` typo — real PS name is Medm not Medium) |
| `xTTests/IsoclineTokenParityTests` (extend) | paper / card / safety in light and dark at the default seed; light paper and card identical across the 15° hue sweep |
| `xTTests/ThemeEngineTests` (extend) | ink vs paper ≥ 4.5:1 (7:1 Increased) across sweep; line alpha swap under Increased Contrast |
| `xTTests/DoseDayStateTests` | unscheduled/upcoming/dueToday/overdue with EV, TU, daily, DST, grace boundary, log-early |
| `xTTests/CyclePhaseMarkerTests` | EV 7d, EC, TU 70d, TP no-peak, oral empty, dose+today collapse |
| `xTTests/LevelProvenanceTests` | noLabs / calibrated / unreconcilable / two labs / age-bucket formatting |
| `xTTests/RangeBandTests` | nil when unset; bounds per X9 |
| `xTTests/SiteSuggestionTests` | rotation across 4 preferred; avoid; empty history; tie-break by side |
| `xTTests/JournalManagerTests` | add/update/delete on in-memory container; symptom name matching; topSlot rules |
| `xTTests/NotificationContentTests` | each preset, custom subsets, own-words edge cases, dropped fields, "Reminder" placeholder |
| **Visual pass per screen PR** (RenderPreview + simulator) | light + dark · hues 0°/90°/180°/270° + default · Dynamic Type default/XXXL/AX3 · Increase Contrast · Reduce Motion · Reduce Transparency · Bold Text · SpoofProfile personas · unconfigured profile · no-labs and with-labs profiles |
| **`lint_theme.sh`** | `.font(.system` count · bare text-style fonts · `Color(hex:` / hex literals outside `Theme/` and `TimeContentTypes.swift` · `.glassEffect(` outside system chrome · `Gradients.brand` count · `Color(.system…` — each must not rise vs `tools/scripts/theme_lint_baseline.txt`; per-phase retire targets in F9 |

---

# APPENDIX · GAP INDEX (what doesn't exist yet)

Sorted by phase. Each line is a thing the spec names that has no home in `xT/` today. The transition plan covers how to build each.

**F/F:** fonts, palette, root
- F1 `xT/Resources/Fonts/` + `UIAppFonts` + `Resources/Licenses/` with OFL texts
- F2 `Theme.FontFace`, rewritten `Theme.Fonts`, `.eyebrow()`, `.monoLabel()`, `.statLabel()`, `ThemedFont` modifier
- F3 `Theme.Line` enum, `Theme.Curve` namespace (optional generated), `absoluteHue` in `ColorRecipe.Appearance`, increased-contrast alphas swap
- F4 paper ground (delete brand gradients at root + 11 call sites)
- F7 `IsoclineMarkPaths.swift` generator + `IsoclineWordmark`/`IsoclineMark` `Shape`s + `IsoclineMarkView` ink/hairline/emboss
- F8 `AcknowledgementsView` + bundle-derived version string
- F9 `tools/scripts/lint_theme.sh` + `theme_lint_baseline.txt`

**S:** primitives
- S1 `PaperCardModifier` (+ `.paperList()` for ST6)
- S2 `GhostCardModifier`
- S4 `ActionPill(title:systemImage:variant:action:)` with `.inline`/`.floating` variants
- S5 `Pill` styles collapsed to `.neutral`/`.active`
- S6 `SectionHeader` rework with `LocalizedStringResource` + optional serif title
- S7 `SettingsIconTile` (one accent, no params)
- S8 SwiftUI `AvatarView(size:)` + cached `getDefaultProfileImage()` (only where `UIImage` forced)
- S9 `IsoclineMarkView(rendering:)` with ReduceTransparency fallback
- S10 Sheet surfaces rework: remove opaque bgs, material bars, in-sheet glass
- S11 `ThemeSpecimenView(preview: ColorScheme?)` + `SpecimenSample` static fixture

**Home data (H-D):** every field the Home UI consumes, no UI, fully tested
- H-D0 named constants (`PhaseStrip.*`, `Provenance.ageBuckets`, `DayPeriod` hour ranges, `DoseSection.*`, `HomeLayout.*`, `NotificationLayout.ownWordsMaxLength=40`)
- H-D1 `DoseDayState` + `doseDayState(now:calendar:)`
- H-D2 `cyclePhaseMarkers(now:) -> [PhaseMarker]`
- H-D3 `LevelProvenance` (basis, labsOnFile) + `var levelProvenance: LevelProvenance`
- H-D4 `RangeBand { low, high, unit }` + `var rangeBand: RangeBand?` (nil when unset)
- H-D5 `labPoints(in window: ClosedRange<Date>) -> [LabPoint]`
- H-D6 `siteSuggestion(routeClass:) -> SiteSuggestion`
- H-D7 `JournalManager` remote-change reload; `MedicationManager.refreshState()` remote-dose reactivity

**Screens:** Home §26 · Journal §27 · Settings §28 · Time §29 · Onboarding/lock/launch §30 · Icon §31 · Notifications §16 · Tab bar/router §23–§24.

**I:** icon
- I1 rebuild `xTGlassIcon.icon` in Icon Composer from `isocline-mark-ink.svg` on `brandColors` ground
- I2 8 alternate `.icon` files, one per §1.3 stop (verify Xcode 26 handles Composer files as alternates)
- I3 Discreet (embossed) icon
- I4 Icon picker

---

*End. Every value above lives in `tokens/isocline.tokens.json`; resolved numbers live in its `resolved` block (generated by `tools/scripts/gen_isocline_tokens.py`). Edit the tokens first, run the generator, then land Swift. `IsoclineTokenParityTests` must stay green.*
