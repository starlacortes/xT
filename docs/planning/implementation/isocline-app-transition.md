# Isocline redesign: app transition plan

Status: **Draft for review** (six crossroads decided, see the log below)
Owner: starla
Last updated: 2026-10-11

## About this document

**What it is.** The element-by-element plan for moving the `xT` app from its current look (system fonts, a brand-gradient root, glass cards, a dark Home canvas) to the **Paper & Instrument** design system.

**The spec.** The canonical spec is [`docs/design/ISOCLINE_DESIGN_SYSTEM.html`](../../design/ISOCLINE_DESIGN_SYSTEM.html), and its tokens live in [`docs/design/tokens/isocline.tokens.json`](../../design/tokens/isocline.tokens.json). This document is the change inventory that sits between the spec and the code. It refines the spec's §15 roadmap.

**Where the facts come from.** Every "today" statement below was read from the working tree on branch `build/time-tab-first-compile` on 2026-10-10/11. Line numbers include uncommitted edits in:
- `SettingsView.swift`
- `JournalComposerView.swift`
- `MoodRowView.swift`
- `Localizable.xcstrings`

Re-check line numbers before editing.

### How to read it

- **Element IDs** (`F3`, `H7`, `J2`, …) are stable, so PRs and commits can cite them.
- **`X` numbers** point into the [Crossroads register](#crossroads-register). These are decisions with real trade-offs. Each has a recommendation; the ones marked *blocking* must be settled before their phase starts.
- **`U` numbers** point into [Unsupported features and suggested rewrites](#unsupported-features-and-suggested-rewrites). These are spec items the platform or the data model can't deliver as written.
- **Element card fields.** Each element card uses some or all of:
  - **Today**: the current state.
  - **Target**: the spec.
  - **Touches**: the files.
  - **Supports**: new types or APIs the element needs.
  - **Steps**
  - **Verify**

### Decisions log

| Date | # | Decision | Already applied to |
|---|---|---|---|
| 2026-10-11 | X1 | **Atkinson Hyperlegible Next**, bundled from the Google Fonts release under **SIL OFL 1.1** (no reserved font name). | Tokens (`type.families.prose`), `brand/licenses/Atkinson-Hyperlegible-Next-OFL.txt` (replaces the 2020 Braille Institute text), web font links, spec §05/§13 |
| 2026-10-11 | X4 | **Cream day paper at every dial position**: absolute hue 86.4°, paper `#F8F3E8`, card `#FDFAF3`. Night paper stays seed-tinted (`#1C0C10` at the default). **Native dark mode on the web**: follow the browser's `prefers-color-scheme`, with `color-scheme: light dark`; `data-theme` is only a manual override. | Tokens (recipes gain `"hue": {"light": "absolute"}`), generator, `isocline.css`, design-system page (metas, live system following), spec §04/§11, W1 |
| 2026-10-11 | X8 | **Always show the curve**, calibrated or not. The provenance line says which (`MODELED · NO LABS YET`). The calibration plan's display gating is superseded. | Spec §06, H-D3, H15, a note on `calibration-and-subscriptions-plan.md` |
| 2026-10-11 | X9 | The **range band spans `troughMin…peakCeiling`**, as `YOUR RANGE 100–600`. There's no band without a user-set range. | Spec §06, H-D4, H5, ST7 |
| 2026-10-11 | X10 | **Red only for documented clinical concerns** (`SafetyFlag` thresholds), drawn as the outline, text and glyph of the pill. Never a fill, never on the curve. | Tokens (`recipes.safety`: `#BA3630` / `#F47C70`, absolute hue, contrast-repaired), spec §04, F3, H2 |
| 2026-10-11 | X24 | **Settings uses four gateway cards**, as in Stitch. | ST1 |
| 2026-10-11 | X35 | **The dose notification layout is user-customizable**: Discreet, Standard, Detailed or Custom (fields plus own words), with a live lock-screen preview. Discreet is the default (recommended; flag if you want otherwise). | Spec §08 (live mock), NT1, ST1 / X25 |
| 2026-10-12 | X6 | **The seed hue mirrors to iCloud KVS while sync is on** (a missing flag reads as on, per the onboarding convention): commits write through to the ubiquity store, and a differing mirrored value is adopted at launch and on external-change notifications — last writer wins, so a second device looks like the first. The hue is stored as a string so presence is detectable (`double(forKey:)` can't tell "missing" from 0°). The "This Device and iCloud" reset clears the mirror so a wiped hue can't come back from the cloud; the local-only reset keeps it, since its iCloud copy survives by design. | `Managers/ThemeHueMirror.swift`, `ThemeManager` (init, `commitSeedHue`), `SettingsPrivacyView` (reset), `xTTests/SeedHueMirrorTests.swift` |
| 2026-10-12 | X7 | **The generator emits `IsoclineTokens.swift` for the numeric groups** (radius, spacing, line, curve, components, seed stops) and Theme's constants read from it, so the app, web and print draw from one source. Adopted for numbers only: `type.*` stays hand-kept in `Theme.Fonts` (F2), where size, weight and `relativeTo` interplay as one decision a plain constant emission can't express. Colors stay engine-computed, pinned by the hex parity test; the new numeric expectations pin every Theme-facing spelling (both spacing alias sets included) against the tokens. | `tools/scripts/gen_isocline_tokens.py`, `xT/Theme/IsoclineTokens.swift` (generated), `Theme.swift` (Spacing/Radius/Seed), `Theme+Isocline.swift` (Line/Curve/aliases), `IsoclineTokenParityTests` |
| 2026-10-12 | X12 | **(a) + (c) together: in-window lab rings, and a Home window control.** The trend windows ("90 d", "all") fix their own span around now — 90 d centred; "all" from the first dose or lab draw of the selected medication (whichever is older), trailing one cycle-forward — with the cycle window's ester-tuned step as the resolution floor and a 160-point budget cap, so a years-long "all" stays a fixed, cheap sample count. "All" with nothing logged collapses to the cycle window. The mode is a device-local view preference (never synced, like the notification layout); a mode change resamples `recentLevels` directly, without paying for the regimen/adherence/streak recomputes. The phase strip stays cycle-scoped whatever the window (X11), and the now point, scrub, range band and lab rings all read the window generically. The picker sits flush top-right as chips on paper — the readout's twin in the same band. | `PKChartWindow` (`WindowMode`, `window(mode:)`), `PKConstants` (trend constants), `MedicationManager` (`chartWindowMode`, `earliestTrendDate`, `resampleRecentLevels`), `ChartWindowPicker`, `HomeView`, `ChartWindowTests` |
| 2026-10-11 | — | **The Appearance picker opens on a hue specimen**: a near-square, rounded window of sample UI (curve, buttons, chips, dose card and more) that follows the hue, with a Day/Night preview and quick stops. | Spec §08 (live sketch), tokens (`radius.specimen`, `components.specimen`, `seed.stops`), ST8, S11 |
| 2026-10-12 | X36 | **The icon set ships as delivered by the external icon work** (`docs/design/external-work/isocline-logos/`): the "I." in ink on a light seed-tint gradient ground — one icon per quick stop, with the default rose as the primary and the remaining seven as alternates — plus the embossed Discreet icon on plain paper. This supersedes I1's sketch of a `brandColors` ground with an OnAccent mark. Icon Composer `.icon` files **do** work as alternates under `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (the I2 "verify" is resolved); in `icon.json`, groups render **front-first**, so the mark group precedes the ground group. The picker shows the shipped artwork as preview imagesets; "Update icon to match your hue?" appears when a hue icon drifts from the dial, never for Discreet. | I1–I4, `tools/scripts/build_isocline_app_icons.py`, `xT/xTGlassIcon.icon`, `xT/AppIcon{Hue48…Hue318,Discreet}.icon`, `Models/AppIconChoice.swift`, `Managers/AppIconManager.swift`, `SettingsAppearanceView.swift`, U2 |
| 2026-10-12 | — | **The phase strip renders as stationary two-line columns**, per the screen sketches: weekday over the positional word (`MON / Dose · WED / Peak · FRI / Today · SUN / Trough`), evenly spread across the card's margins — no scrolling, no chips. Only the Today column carries the accent hairline rounded-rect ring (`Radius.sm`; the Journal week strip's today-circle motif); the rest are bare muted type — labels, not buttons. All H9 behavior is unchanged: cycle-scoped and never chart-aligned (X11), hidden for daily routes, PEAK omitted without a calibrated t_max, positional words only (X18). | `Elements/Home/Components/PhaseStripView.swift` (`PhaseColumn`), `HomeView` (strip shares card `hPad`), spec §9, S5 usage list |
| 2026-10-12 | — | **Home tidy-up trio.** (1) The curve's day rules keep their hairlines but lose their weekday labels — the phase strip is the single calendar element (H9); the `CurveLayout.timeMarkers` tiering (day/week/month) still governs line density. (2) The scrub reflow is fixed at its source: `HomeReadout` keeps its status block in the layout while scrubbing (invisible, accessibility-hidden), so the measured readout height — and the curve's top inset — never changes mid-drag. (3) The `ChartWindowPicker`'s measured width (`PickerWidthKey`) becomes the readout eyebrow's trailing clearance (eyebrow row only — the number and provenance lines never reach the chips), and the eyebrow copy drops to `ESTRADIOL · DAY 3`, per the screen sketches — the ester lives on the dose card's medication line, the interval total on the phase strip. Together the eyebrow and chips share their band without overlap or everyday truncation. | `FlatGraphView` (`dayGridLayer`), `HomeReadout`, `HomeView`, `MedicationDisplayFormatter` (`readoutEyebrow`) |
| 2026-10-12 | — | **The Settings root composes per the screen sketch.** An ISOCLINE brand eyebrow rides over the serif title; the profile centers flush on the paper — avatar (new 88pt `settingsHero` canonical), serif name, mono tenure in caps, and a quiet accent EDIT caption — the block itself stays non-interactive, so X26 stands (editing opens only from the caption, as a sheet). Gateway cards get the sketch's icon set (`plus` / `diamond` / `circle.righthalf.filled` / `square`), serif titles, and the third card is renamed "Appearance & Curve"; their live mono subtitles (ST5) are unchanged. A latent grammar bug is fixed on the way: `String(localized:)` doesn't resolve `^[…](inflect: true)` directives, so the tenure line and the labs "last draw" age now build through `AttributedString` (the raw directive text had been leaking into the header). | `SettingsView` (eyebrow, centered profile header, card order/icons), `SettingsRowKit` (`SettingsGatewayCard` serif title), `AvatarView` (`Size.settingsHero`) |

---

## 0. Summary

### What the redesign is, in one paragraph

**From:**
- system fonts;
- a seed-tinted brand gradient behind everything;
- glass and material cards;
- a dark gradient Home canvas with a glass readout.

**To:**
- three bundled OFL typefaces: Plex Serif for display, Plex Mono for values, Atkinson Hyperlegible Next for prose;
- a **cream paper** ground by day and a seed-tinted night paper by dark;
- hairline paper cards for anything adjustable, and flush type for anything that simply *is*;
- glass only where iOS 26 supplies it (the tab bar and sheets);
- a Home whose full-height filled curve carries honest provenance: no dashes, lab rings, a neutral range band and a mono provenance line.

### Findings that change the original roadmap

Code reading turned up the following. Each one is handled in the element cards.

**Design and data gaps**

1. **The Home chart window is about 3 days for EV** (`Shared/PKChartWindow.swift:75-120`; EV window 3.15 d per `xTTests/ChartWindowTests.swift`). A seven-weekday phase strip can't line up with it, and lab rings will almost never fall inside it. → X11, X12, U4, U5
2. **Calibration is a single α from the most recent lab** (`MedicationManager.swift:279-294`). "CALIBRATED TO 2 LABS" would be false. → X13, U3
3. **A draft plan wanted the uncalibrated curve hidden.** `docs/planning/implementation/calibration-and-subscriptions-plan.md` hides the curve until a lab exists; the spec shows it with "MODELED · NO LABS YET". **Resolved by X8: always show.** The plan now carries a note saying so.
4. **Labs never reach the Home chart.** Only `LabsChartView` plots them, and it draws the modeled series *dashed* (`LabsChartView.swift:91`), which the spec retires. → H6, ST9
5. **There is no range band.** Three dashed `successBrand` lines are drawn only when a target is set, and they can fall off-screen because the y-scale fits the data (`FlatGraphView.swift:341-378`). → H5, X9
6. **The site picker is already off Home.** It is step 2 of `QuickDoseSheet`. What's missing is "last site + suggested next". The APIs (`lastInjectionSites(for:)` in `+Sites.swift:24-38`) exist but nothing calls them. → H13

**Bugs**

7. **"Today" is a day early and uses the wrong interval tier.** The new dose section must not inherit it. → H-D1
8. **The personal-target toggle always loads "off".** → ST7
9. **Notification routes are dead**: nothing reads `pendingRoute`. → N2

All three, with their line references, are in [Appendix A](#appendix-a--fix-along-defects-found-during-the-audit) with the other fix-along defects.

**Principle conflicts**

10. **Celebrations conflict with "no congratulation":**
    - Home confetti and the readout glow after a dose (`HomeView.swift:69-74, 122-141`);
    - the Time tab's `TierCelebrationOverlay`;
    - `AdherenceView`'s rate ring and "Consecutive on-schedule doses".

    → X19, X30, X32
11. **Discretion: the dose reminder names the medication on the lock screen** ("4 mg Estrogen", `NotificationManager.swift:282-293, 439-445`). → NT1, X35

**Foundations**

12. **Fonts:**
    - no custom fonts, no `UIAppFonts`, and `relativeTo:` is used nowhere;
    - 12 of the 25 `Theme.Fonts` roles have no callers;
    - 112 `.font(.system(…))` call sites and 156 `.font(.<textStyle>)` call sites bypass `Theme.Fonts` entirely.

    → F2, F9
13. **Glass and cards are smaller than expected.** Glass is used on content in only 3 places:
    - `UnifiedStackView.swift:37`
    - `QuickDoseSheet.swift:445`
    - `TimeRegionDetailView.swift:398`

    `.settingsCard()` has **zero** production callers, while the same card is hand-written 9 times. → S1
14. **No schema change is needed.** Every new element derives from existing SwiftData and UserDefaults state. The only optional addition, SC vs IM route depth, is deferred (U6).

### Phases, PRs and estimates

This is the only schedule table. Each row is one PR unless noted.

| PR | Phase | Scope | Elements | Depends on | Est. |
|---|---|---|---|---|---|
| 0 | Prep | Land the in-flight docs reorg and Swift WIP. Settle the remaining *blocking* crossroads (see the register). Branch per phase from `main`. | — | — | 0.5 d |
| 1 | 1 · Foundations | Fonts, licenses, Acknowledgements, bundle version. No visual change yet. | F1, F8 | 0 | 1 d |
| 2 | 1 · Foundations | `Theme.Fonts` switch and aliases, theme lint and baseline | F2, F9 | 1 | 1 d |
| 3 | 1 · Foundations | Palette (paper, card, ink, safety, onAccent), gradient retirement, hue reset, a11y floors, shadows | F3–F6, F10 | 2 | 1–2 d |
| 4 | 2 · Primitives | Cards, pill, chip, eyebrow, tile, avatar, mark shapes, sheet surfaces, hue specimen | F7, S1–S11 | 3 | 2–3 d |
| 5 | 3a · Home data | `DoseDayState`, phase markers, provenance, range band, lab points, site suggestion, all unit-tested with no UI | H-D0–H-D7 | 3 | 2 d |
| 6 | 3b · Home UI | Canvas, readout, curve, band, rings, now point, phase strip, overlay card | H1–H12, H14–H15 | 4, 5 | 3–4 d |
| 7 | 3c · Record-dose sheet | One sheet, last and suggested site, router, tabs | H13, N1, N2 | 6 | 1–2 d |
| 8 | 3d · Journal | Week strip, top card / ghost card, flush rows, New entry pill, composer, edit | J1–J12 | 4, 7 | 3–4 d |
| 9 | 3e · Settings | Gateway IA, flush profile, section cards, live subtitles, range screen, Appearance specimen, sub-screens | ST1–ST13 | 4 | 4–5 d |
| 10 | 3f · Time, onboarding, lock | Type pass, forced-dark consistency, paper onboarding, embossed lock screen | T1–T5, O1–O4 | 4 | 2 d |
| 11 | 3g · Notifications | Customizable dose notification layout with live preview | NT1 | 7, 9 | 1–2 d |
| 12 | 4 · Icon | "I." icon, alternates on `seed.stops`, stealth emboss, picker | I1–I4 | 9, 10 | 2–3 d |
| | | | | **Total** | **≈ 25–33 d** |

PRs 8, 9 and 10 can run in parallel after PR 4. PR 5 can start right after PR 3, while PR 4 is in review.

Each phase leaves the app shippable. Phases 1 and 2 change the look globally but keep every screen's layout. Phase 3 changes one screen per PR.

---

## 1. Ground rules for every phase

- **Platform.** iOS 26.0 only (`IPHONEOS_DEPLOYMENT_TARGET = 26.0` for all three targets), iPhone, portrait. `SUPPORTS_MACCATALYST = YES` is set, so guard UIKit-only calls such as alternate icons.
  - The single `if #available(iOS 26.0, *)` (`Theme.swift:321`) has a dead fallback. Delete it when `GlassCardModifier` goes (S1).
- **Glass belongs to the system.** Never put `.glassEffect` on content. Inside a sheet, the sheet's own glass is the card surface. `presentationBackground(.clear)` is ignored on iOS 26 (see memory: *iOS 26 sheet glass is the card surface*).
- **The two kinds of surface.** "What is" sits flush on paper; "what you adjust" sits in a card. It's a strong default, not a law. When unsure, ask whether tapping the thing would change something.
- **Voice.** Copy describes position, direction and provenance, never judgment:
  - no "good/bad";
  - no red/green status on data;
  - no streaks, counts or congratulation.

  The one exception to "no red" is the safety pill for documented clinical thresholds (X10, decided).
- **Tests.** Run them through the Xcode MCP (`RunSomeTests` / `RunAllTests`), not `xcodebuild test`. New test files are picked up automatically because `xT/` and `xTTests/` are synchronized groups.
- **Where to edit.** Edit the main checkout, not `.claude/worktrees/*`, which is stale.
- **Tokens before code.** Change a value in `isocline.tokens.json` first, then run `python3 -I tools/scripts/gen_isocline_tokens.py`. `IsoclineTokenParityTests` must stay green.
- **Strings.** New user-facing copy goes through `String(localized:comment:)` or `LocalizedStringResource`. Mono caps use `.textCase(.uppercase)`, not `.uppercased()`, so translations keep their own casing. See X31 for the verbatim Settings titles.

---

## 2. Affected systems map

| System | Files (primary) | Change | Risk |
|---|---|---|---|
| Type | `Theme/Theme.swift:122-171`, `xT/Info.plist`, new `Resources/Fonts/` | Bundle fonts, rewrite roles | Med: global visual change |
| Palette | `Managers/ThemeManager.swift:19-323`, `Theme/Theme.swift:17-117` | Paper, card and ink recipes; ink alphas; line tokens | Med: every screen reads these |
| Token pipeline | `tools/scripts/gen_isocline_tokens.py`, `docs/design/tokens/*`, `xTTests/IsoclineToken*` | Add paper/card expectations; optional generated Swift constants | Low |
| Root and backgrounds | `ContentView.swift:18-27`, `HomeView.swift:46-52, 222-254`, 11 `Theme.Gradients.brand` sites | Paper everywhere; gradient retires from grounds | Low |
| Shared primitives | `Shared/Components/*` (949 lines), `Theme.swift:315-385` | New modifiers and components; old ones retired | Low–Med |
| Home | `Elements/Home/HomeView.swift`, `FlatGraphView.swift`, `Components/*`, `Shared/CurveLayout.swift` | Layout, chart vocabulary, overlay card, dose states | **High**: most new behavior |
| Dosing logic | `Managers/Medication/MedicationManager+{Derived,Dosing,Schedule,Sites,Pharmacokinetics}.swift` | New derived APIs; "Today" fix | Med: tested logic |
| Record-dose flow | `Components/QuickDoseSheet.swift`, `RecordDoseView.swift`, `NextDoseRowView.swift` | Consolidate into one sheet; site suggestion | Med |
| Journal | `Elements/Journal/*`, `Managers/JournalManager.swift`, `Theme/JournalTheme.swift`, `Models/JournalModels.swift` | Week strip, top card/ghost, rows, edit API | Med |
| Settings | `Elements/Settings/SettingsView*.swift`, `Shared/Components/SettingsRowKit.swift`, 15 sub-screens | Gateway IA, flush profile, single-accent tiles | **High**: IA change |
| Profile | `Managers/ProfileManager.swift`, `Elements/Profile/*` | Avatar view; edit-as-sheet | Low |
| Time tab | `Elements/Time/*`, `Shared/Components/NightSkyBackdrop.swift` | Type only, plus consistency fixes | Low |
| Onboarding, lock, launch | `Elements/Onboarding/*`, `Managers/AuthenticationManager.swift:265+`, `xTLaunchScreen.storyboard` | Paper, emboss mark | Low |
| Navigation and routing | `Elements/Home/MainTabView.swift`, `ContentView.swift`, `Managers/NotificationManager.swift` | `Tab` API, selection binding, router | Low |
| Notifications | `Managers/NotificationManager.swift:181-330, 451-478, 504` | Customizable dose layout (Discreet default), two categories, live preview | Low–Med |
| App icon | `xT/xTGlassIcon.icon`, `Assets.xcassets/App Icon.appiconset`, pbxproj icon settings | "I." icon, alternates, picker | Med: asset pipeline |
| Localization | `xT/Localizable.xcstrings` (610 keys, en only, 158 stale) | New keys; retire stale ones | Low |
| Tests | `xTTests/*` | New logic tests; extended parity; font registration | Low |

**What does not change:**
- the PK engine (`estimatedLevels`, the superposition and calibration math);
- `PKChartWindow`;
- the SwiftData schema and CloudKit container;
- `TimeContentEngine` and Time copy;
- `ProfileManager` encryption and storage;
- `AuthenticationManager` logic.

---

## Phase 1 · Foundations

### F1 · Bundle the typefaces

**Today**
- No `.ttf`/`.otf` files in the repo, no `UIAppFonts` key, and no `Font.custom` calls.
- License texts exist only under `docs/design/brand/licenses/`.

**Target**
- IBM Plex Serif SemiBold and Bold.
- IBM Plex Mono Regular and Medium.
- Atkinson Hyperlegible **Next** Regular and Bold (X1), from the Google Fonts release (`googlefonts/atkinson-hyperlegible-next`, SIL OFL 1.1).

**Touches**
- New `xT/Resources/Fonts/` (picked up automatically because `xT/` is a `PBXFileSystemSynchronizedRootGroup`, pbxproj 57-66).
- `xT/Info.plist`: add a `UIAppFonts` array. The project merges this plist through `INFOPLIST_FILE` while `GENERATE_INFOPLIST_FILE = YES`.

**Steps**
1. Source the fonts:
   - **Plex** from the official IBM/plex GitHub release, pinned to a version, rather than TeX Live (TeX Live has Serif 3.001 and Mono 2.004).
   - **Atkinson Next** from the Google Fonts release (`google/fonts` → `ofl/atkinsonhyperlegiblenext`, or `googlefonts/atkinson-hyperlegible-next`). Prefer static Regular/Bold instances over the variable font so the PostScript names are fixed. **Not** from TeX Live or the Braille Institute download: those copies carry the Braille Institute license, whose embedded text forbids derivatives.

   Record SHA-256 checksums in `xT/Resources/Fonts/README.md`.
2. **Subsetting.**
   - **Plex:** don't subset or modify it. Its reserved font name "Plex" means a modified file couldn't keep the name.
   - **Atkinson Next:** OFL with no reserved name, so subsetting is allowed. Bundle it whole anyway; the saving isn't worth a custom build step.
3. Add the `UIAppFonts` entries using bundle-root file names. Synchronized groups flatten resources into the bundle root; confirm this in the built `.app`.
4. Use these PostScript names, verified from the font files with fontTools:

   | Face | PostScript name |
   |---|---|
   | Plex Serif SemiBold | `IBMPlexSerif-SemiBold` |
   | Plex Serif Bold | `IBMPlexSerif-Bold` |
   | Plex Mono Regular | `IBMPlexMono` (**not** `-Regular`) |
   | Plex Mono Medium | `IBMPlexMono-Medm` (**not** `-Medium`) |
   | Atkinson Next Regular | `AtkinsonHyperlegibleNext-Regular` (read from the TeX Live copy; re-check the Google release, it may differ) |
   | Atkinson Next Bold | `AtkinsonHyperlegibleNext-Bold` (same caveat) |

5. Copy both license texts (`docs/design/brand/licenses/IBM-Plex-OFL.txt`, `Atkinson-Hyperlegible-Next-OFL.txt`) into `xT/Resources/Licenses/` for F8.

**Verify**
- New `xTTests/FontRegistrationTests.swift` asserts that `UIFont(name:size:)` is non-nil for every face in `Theme.FontFace`. This catches PS-name typos like `-Medm`.
- The app-size delta stays under 2 MB.

### F2 · Rewrite `Theme.Fonts`

**Today**
- `Theme.swift:122-171`: 25 roles, all system fonts.
- Only the 11 text-style aliases and 2 serif roles scale with Dynamic Type.
- Call counts: caption 42, callout 36, caption2 24, footnote 14, title3 5, micro 5, headline 5, eyebrow 3, body 3, title2 2, subheadline 2, pill 2, icon 2, detail 1.
- Unused: display, largeNumber, label, statLabel, statValue, hero, numeric, readout, serifTitle, serifBody, largeTitle, title.

**Target.** Every role is `Font.custom(face, size:, relativeTo:)`, following the tokens' `type.roles`.

**Supports**
- `Theme.FontFace` (the PS names) and `Theme.Tracking`, both em-based.
- View modifiers that carry tracking and case, which a `Font` can't hold:
  - `.eyebrow()`: mono 11, +0.18em, uppercase, muted;
  - `.monoLabel()`: `lineLimit(1)` plus `minimumScaleFactor(0.8)`, the spec's rule against mid-word wraps;
  - `.statLabel()`.

**Faces, sizes, weights and `relativeTo` styles live in the tokens**, so this plan doesn't repeat them:
- `type.roles` holds the 15 spec roles;
- `type.aliases` holds the 11 system text-style names `Theme.Fonts` keeps, with their 146 call sites, plus the `icon` exception.

X2 settles whether the aliases switch in one commit.

| Role | Used for |
|---|---|
| `display` | (reserved) |
| `hero` | Screen titles (Journal, Settings), Time hero |
| `serifTitle` | Section titles, profile name, sheet titles |
| `serifBody` | Journal day labels, dose-section time |
| `readout` | Home level readout |
| `largeNumber`, `numeric`, `statValue` | Record figures, secondary figures, stat values |
| `label` | Meta lines, provenance, countdown chips |
| `eyebrow`, `pill`, `statLabel`, `micro` | Section headers, chips, gridline values, fine print |
| `body`, `detail` | Prose and journal text; subtitles and captions |
| aliases (`title`…`caption2`) | Every existing call site, unchanged in code |

**Steps**
1. Add `FontFace`, rewrite the roles and aliases, and add the modifiers.
2. Apply `.font(Theme.Fonts.body)` once at the root (`ContentView`). Plain `Text` that has no explicit font then inherits Atkinson.
3. Bold Text accessibility:
   - First check whether `.fontWeight(.bold)` on a `Font.custom` resolves the family's Bold face.
   - If it doesn't, add a `legibilityWeight`-aware path. A `ThemedFont` modifier reads `@Environment(\.legibilityWeight)` and swaps Regular for Bold (Atkinson) and Regular for Medium (Mono).
4. Tracking in points doesn't scale with Dynamic Type. Compute it as `size × em` with `@ScaledMetric`, or accept fixed tracking. Fixed tracking is fine at caption sizes.
5. Leave raw `.font(.system…)` call sites for the screen passes (F9 lint tracks them).

**Verify**
- In `RenderPreview`, check Settings, Journal and Home at default size, XXXL and AX3.
- No mono label wraps mid-word.

### F3 · Paper, card and ink recipes in `ThemePalette`

**Today** (`ThemeManager.swift:141-323`):

| Field | Recipe today |
|---|---|
| `appBackground` | light (.985, .008), dark (.05, .010) |
| `cardSurface` | `appBackground` × 0.8 opacity |
| `border` | (.94, .010) × 0.2, the same in both appearances |
| `textSecondary` | ink × .6 |
| `textTertiary` | ink × .3 |
| `Theme.Colors.hairlineWidth` | 0.5 |

**Target.** All of it lives in `isocline.tokens.json`; the resolved values are in its `resolved` block and are never copied into code or this plan.

| Token group | What the app needs from it |
|---|---|
| `recipes.paper`, `recipes.card` | Cream by day (absolute hue, X4); seed-tinted night |
| `recipes.ink` | Repaired against **paper** at `bodyText` |
| `recipes.safety` | Absolute hue in both appearances; repaired against paper (X10) |
| `recipes.onAccent` | Ink on accent fills, repaired toward light. Compare with today's `OnAccentPalette`, which isn't parity-tested. |
| `inkAlpha` (muted, faint, line, grid, ylab) | Fixed alphas of ink |
| `inkAlphaIncreasedContrast` | Replaces `line` and `grid` under Increase Contrast |
| `line.*` | `Theme.Line` widths |

**Supports**
- New `ThemePalette` fields: `paper`, `card`, `line`, `grid`, `inkMuted`, `inkFaint`.
- New `Theme.Colors` accessors: `paper`, `card`, `line`, `grid`, `muted`, `faint`.
- New `enum Theme.Line { hairline, engrave, curve, curveHero, labRing }`.
- **Absolute-hue recipes.** `ThemeEngine.ColorRecipe.Appearance` (`ThemeEngine.swift:290`) gains `absoluteHue: Bool` (default false), and `ThemeEngine.resolve(_:seedHue:)` (306) uses the hue as given when it's set. This mirrors the generator's `"hue": {"light": "absolute"}`. Day paper and card use it in light only; `safety` uses it in both appearances.
- **`safety`** joins `ThemePalette` (repaired against paper). `Theme.Colors.error` (`Theme.swift:48`, today `Color.red`) points at it. Keep the accessor name so `HormoneLevelPresentation.statusTint` and the `PharmacokineticTests` assertions (~1715, ~1735) still hold.

**Steps**
1. Re-recipe `appBackground` to paper (cream by day, absolute hue), and make `paper` an alias (X5).
2. Make `cardSurface` the opaque card recipe.
3. Point `border` at `line`. Raise `textSecondary` to .62 and `textTertiary` to .38.
4. **Increased contrast.** The `increasedContrast` flag already re-resolves the palette. Swap in `inkAlphaIncreasedContrast` for `line` and `grid`. The ghost-card hairline follows `line`, so it gets this for free. The web does the same under `prefers-contrast: more` (generated CSS).
5. Retarget the Graph ink. `gridLine`, `yAxisLabel`, `levelText` and `levelTextSecondary` are repaired against `Graph.base*` today (`ThemeManager.swift:191-200`); repair them against paper instead. They become `grid`, `ylab`, ink and muted.
6. Leave `Graph.baseDark/baseMid/baseTop/topGlow/rightGlow` in place until H1 deletes their only consumer (`HomeGradientBackground`). Then delete them. `curveRose/curveMid/curveLavender` and the `dot*` set have no callers and can go now.
7. Tokens:
   - Add `"app": "appBackground"` to `recipes.paper` and `"app": "cardSurface"` to `recipes.card`.
   - Extend the generator so `IsoclineTokenExpectations` covers them.
   - Add `"app": "error"` to `recipes.safety` once `safety` is a palette field.
   - Expected values come from the generated `IsoclineTokenExpectations.swift`; nothing is typed by hand.
   - Light paper and card are the same at *every* seed; add a hue-sweep assertion for that.

**Crossroads**
- X3: hairline width.
- X4 (**decided**): cream, absolute hue.

**Verify**
- `IsoclineTokenParityTests` passes with the paper and card fields added.
- In `ThemeEngineTests`, add `textPrimary` vs paper ≥ 4.5:1 (7:1 with increased contrast) across the 15° hue sweep.

### F4 · Retire the brand gradient as a ground

**Today.** `Theme.Gradients.brand` / `brandColors` is used at 11 sites:

| Site | Use | Replacement |
|---|---|---|
| `ContentView.swift:19` | Root background behind `MainTabView` | `Theme.Colors.paper.ignoresSafeArea()` |
| `OnboardingView.swift:101`, `CloudSyncChoiceView.swift:16` | Full-screen ground | Paper (O1) |
| `AuthenticationManager.swift:276` (`AuthenticationView`), `AppLockSettingsView.swift:255` (`TestBiometricSheet`) | Lock screen ground | Paper plus the embossed "I." (O2) |
| `SettingsView+Header.swift:25` | Avatar placeholder disc | `AvatarView` placeholder (S8) |
| `JournalView.swift:151` | Gradient "Journal" title | Ink `Theme.Fonts.hero` (J1) |
| `JournalView.swift:236` | Selected scrubber capsule | Removed with the scrubber (J2) |
| `Pill.swift:58` | `.gradient` pill style | Style deleted (S5) |
| `SelectableOptionRow.swift:136` | Selected state | Accent hairline border (S5) |
| `UnifiedStackView.swift:48` | Overlay accent | Removed with the glass card (H10) |

**Keep** `brandColors` for the app-icon gradient (I1) and the hue-picker preview. Its stops are light-only, which is fine for an icon.

**Verify:** `grep -rn "Gradients.brand" xT` returns only the icon and picker uses.

### F5 · Seed-hue persistence and reset hygiene

**Today**
- The hue is stored in `UserDefaults.standard["theme.seedHue"]` and isn't registered in `register(defaults:)`.
- There's no iCloud KVS, although `xT.entitlements` declares `com.apple.developer.ubiquity-kvstore-identifier`.
- Reset App Data wipes UserDefaults (`SettingsView.swift:205`) but never tells the live `ThemeManager`, so the palette keeps the old hue until relaunch.
- The `darkerSystemColorsStatusDidChangeNotification` observer token is never removed.

**Steps**
1. After a reset, call `ThemeManager.shared.resetToDefault()`.
2. Keep the observer token and remove it in `deinit`. That's harmless for a singleton but correct.
3. Optional (X6): mirror `seedHue` to `NSUbiquitousKeyValueStore` when `icloudSyncEnabled` is on, so a second device opens in the same hue.

### F6 · Accessibility floors

**Today**
- Reduce Transparency isn't handled anywhere.
- Reduce Motion is missing in `CelebrationGlowModifier`, `PressableButtonStyle` and `Theme.Motion.pulse` (`NextDoseRowView.swift:92, 98`).
- `@ScaledMetric` is used only at `HomeView.swift:34-35`.
- `@Environment(\.dynamicTypeSize)` is declared but unused (`HomeView.swift:14`).

**Steps**
1. **Reduce Transparency** fallbacks for the effects this redesign adds:
   - emboss → ink hairline (S9);
   - the paper fade under floating pills → a solid paper band (J8);
   - the now-point halo → solid at 30%.
2. **Reduce Motion:**
   - the pressable scale → opacity;
   - the pulse → static;
   - dose-card height change → crossfade;
   - curve morph → crossfade. `FlatGraphView.swift:148` already handles the morph.
3. **Home at accessibility sizes** (`dynamicTypeSize.isAccessibilitySize`) switches to a scrolling layout (H1).
4. **Differentiate Without Color:**
   - week-strip dots differ by shape, not only by color (J2);
   - the safety pill carries a glyph (X10).

### F7 · Mark shapes in Swift

**Today.** The wordmark and "I." exist only as SVG, PGF and JS (`docs/design/brand/`). The app can't draw the logo without live text, and live text is forbidden because the shape never changes.

**Supports.** Extend `tools/scripts/build_isocline_marks.py` to also emit `xT/Theme/IsoclineMarkPaths.swift`. It holds two `Shape`s, `IsoclineWordmark` and `IsoclineMark`, built from the **same** path data.
- Emit `Path` commands from the outline. fontTools' `RecordingPen` gives you moveTo/lineTo/curveTo/qCurveTo.
- Expose each mark's `viewBox` so callers can scale with `aspectRatio`.

The renderings are views over those shapes (S9).

**Verify.** A snapshot of `IsoclineMark().fill()` next to `isocline-mark-ink.svg` matches. Re-running the script produces byte-identical output.

### F8 · Acknowledgements and version

**Today**
- There's no acknowledgements screen.
- The About "Version" value is hard-coded `"0.9"` (`SettingsView+Sections.swift:568`).

**Target**
- A new `AcknowledgementsView` under About. It lists IBM Plex (SIL OFL 1.1, reserved font name "Plex") and Atkinson Hyperlegible Next (SIL OFL 1.1, Google Fonts release), each with its full license text from `Resources/Licenses/`.
- The version reads from `CFBundleShortVersionString` plus `CFBundleVersion`.

### F9 · Theme lint

**Supports.** A new `tools/scripts/lint_theme.sh`, run before each phase PR. It counts:
- `.font(.system(` sites;
- `.font(.<textStyle>)` sites without `Theme.Fonts`;
- `Color(hex:` and `"#RRGGBB"` literals outside `Theme/` and `TimeContentTypes.swift`;
- `.glassEffect(` calls outside system-chrome helpers;
- `Theme.Gradients.brand` uses;
- `Color(.system…)` calls.

It prints the counts per file and fails if a count **rises** against a committed baseline (`tools/scripts/theme_lint_baseline.txt`). There is no CI today (`docs/notes/CODEBASE_REVIEW_2026-10-08.md`), so this is a local gate. Add it to CI when CI arrives.

**Per-phase targets.** The lint also checks for retired symbols, so no separate grep gates are needed:

| After PR | Must be absent |
|---|---|
| 4 | `asGlassCard`, `timeCard`, `settingsCard`. `.glassEffect(` is allowed only in `TimeRegionDetailView` until T3. |
| 6 | `HomeGradientBackground`, `HomeConfettiBurst`, `dashedLine`, `therapeuticReferenceLines` |
| 7 | `RecordDoseView` |
| 10 | Any `.glassEffect(` on content. `Gradients.brand` is allowed only in icon and picker code. |

**Baseline today:**
- 112 `.font(.system`
- 156 bare text-style fonts
- 55 hex literals (36 of them in `TimeContentTypes.swift`)
- 2 `.glassEffect` plus 2 `.asGlassCard`
- 11 brand-gradient uses

### F10 · Shadows and glow

**Today**
- `Theme.Shadows.floating` and `accentFab` (`Theme.swift:290-308`).
- 11 raw `.shadow(` calls, 4 of them in `NextDoseRowView`.
- `.celebrationGlow` (`Motion.swift:163-182`).

**Target.** No shadows on paper: depth is read from the hairline. Glow is allowed only for the curve on night paper (H4).

**Steps**
- Delete `accentFab` when J8 lands.
- Delete `floating` when the Journal dose button goes (J8 / X21).
- Remove `celebrationGlow` together with X19.
- Sweep the raw shadows per screen.

---

## Phase 2 · Surfaces and primitives

### S1 · `.paperCard()` replaces three card modifiers

**Today**

| Modifier | Location | Callers |
|---|---|---|
| `asGlassCard` | `Theme.swift:315-334, 370` | `UnifiedStackView.swift:37` (the Home overlay), `QuickDoseSheet.swift:445` (a button inside a sheet, so glass on glass) |
| `timeCard` | `Theme.swift:337-349, 375` | `ThemePickerView.swift:87` only |
| `settingsCard` | `SettingsRowKit.swift:141-152` | none in production |

The card is also hand-written 9 times: `DoseScheduleSettingsView.swift` at 120, 174, 207, 245, 496, 556 and 602, and `ProfileEditorView.swift` at 128 and 177.

**Target.** Card fill, a `line` hairline at `Theme.Line.hairline` drawn with `strokeBorder` so it stays inside the shape, radius `Theme.Radius.lg`, no shadow.

```swift
struct PaperCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.card
    var radius: CGFloat = Theme.Radius.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.card, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Theme.Colors.line, lineWidth: Theme.Line.hairline))
    }
}
extension View { func paperCard(padding: CGFloat = Theme.Spacing.card,
                                radius: CGFloat = Theme.Radius.lg) -> some View { … } }
```

**Steps**
1. Add the modifier.
2. Migrate the 9 hand-written cards.
3. Migrate `ThemePickerView`'s swatches.
4. Delete `settingsCard`, `timeCard`, `GlassCardModifier`/`asGlassCard` and the dead `#available` branch. `UnifiedStackView` moves in H10.
5. Inside sheets, use **no** fill: the sheet's glass is the surface. Use `ghostCard()` (S2) or flush rows with hairlines instead.

### S2 · `.ghostCard()`

**Target.** The same shape and hairline as `paperCard`, with **no fill**. It isn't a control and never takes a tap target.

**Uses**
- the Journal "nothing yet today" slot (J3);
- the composer text area inside its sheet (J9);
- engraved empty states (H15).

`accessibilityElement(children: .combine)`, with no button trait.

### S3 · Hairline dividers

**Today**
- `HairlineDivider` exists (`Shared/Components/HairlineDivider.swift`: border × .35, 0.5pt), but most screens use `Divider().opacity(0.5)`:
  - Journal: `JournalView.swift:190-204`
  - Settings: `SettingsView.swift:61`, `SettingsRowKit.swift:111-119`
- `SettingsSection` wraps its content in two system `Divider`s.

**Target.** One `HairlineDivider(inset:)` in `Theme.Colors.line` at `Theme.Line.hairline`. Replace the system `Divider`s as each screen is touched.

### S4 · `ActionPill` (Log Dose, New entry)

**Today.** `AccentActionButton` (`Shared/Components/AccentButton.swift:16-39`):
- a full-width rounded rectangle (`Radius.md`) filled with accent × 0.8;
- raw `.white` text and `.headline.weight(.medium)`.

`AccentButtonModifier` (`Theme.swift:352-362`) duplicates it.

**Target**
- A filled seed-accent capsule, minimum height `components.actionPill.minHeight`.
- Icon plus label in `Theme.Colors.OnAccent.primary`, Atkinson Bold (headline alias).
- Two variants:
  - `.inline`: inside cards;
  - `.floating`: a centered capsule that rests on a paper fade (J8).

**Steps**
1. Rewrite `AccentActionButton` as `ActionPill(title:systemImage:variant:action:)`.
2. Keep `AccentActionButton` as a deprecated typealias until every caller migrates.
3. Delete `AccentButtonModifier` once its callers move.

### S5 · `Pill` / chip

**Today.** `Pill.swift`:
- styles `.tinted`, `.material` (`.ultraThinMaterial`) and `.gradient` (brand);
- previews show "optimal" in success green and "3 days late" in error red;
- its header comment claims Journal uses it, which isn't true.

**Target**
- Mono 11 (`pill` role, +0.08em), hairline border, full radius.
- Active state = an accent **border**, not a fill.

**Steps**
1. Collapse the styles to `.neutral` and `.active`.
2. Delete `.material` and `.gradient`.
3. Fix the preview copy ("Within set trough", "Next dose in 2d").
4. Fix the header comment.

`SelectableOptionRow` gets the same active-border treatment.

### S6 · Eyebrow and `SectionHeader`

**Today.** `SectionHeader` (`Shared/Components/SectionHeader.swift`):
- caption2, `text.uppercased()`, tracking 0.5;
- it takes a `String`, so the text is rendered verbatim and never localized.

**Target**
- Mono 11, +0.18em, `.textCase(.uppercase)`, muted.
- An optional serif title.
- The text parameter takes `LocalizedStringResource` (X31).

### S7 · `SettingsIconTile`: one accent

**Today**
- `SettingsRowKit.swift:89-106`: 32pt, `Radius.control`, and the caller passes the colors.
- There are 8 distinct treatments across Settings: Time.cycle/mind/body/skin, accent@.13, warning@.13, neutral, error@.1.
- Separately, `InjectionSite.swift:119` maps `.patch` to `Theme.Colors.warning`. That's a data color, not a tile; review it in H13.

**Target**
- The tile follows `components.tile`: accent fill at `fillOpacity`, accent glyph, `size`, `radius`.
- It takes no color parameters. Remove `iconBackground`/`iconColor` from `SettingsRow`.

**Steps.** Delete the parameters and let the compiler list every call site. The destructive Reset row is X27.

### S8 · `AvatarView`

**Today**
- `ProfileManager.renderPlaceholder` (`ProfileManager.swift:121-134`) renders a 200×200 `UIImage` on **every call**, with no cache.
- That image doesn't follow hue changes until it's re-rendered, and the Settings header doesn't use it anyway: it shows a brand-gradient disc (`SettingsView+Header.swift:17-27`).
- Rings differ everywhere: none in Settings, a 3pt accent ring in the editor, a 2pt OnAccent ring in onboarding.

**Target**
- A circle with a 1pt ink hairline ring. No gradient ring, no glow.
- It shows the user's photo, or the seed-tinted placeholder: an accent disc with `person.fill` in OnAccent.
- Sizes: `components.avatar.row` / `.header` / `.editor` (rows, the Settings header, the editor).

**Supports.** A SwiftUI `AvatarView(size:)` reading `profileManager.profilePhoto`. The placeholder is drawn **in SwiftUI**, so it tracks the hue live.
- Keep `getDefaultProfileImage()` only where a `UIImage` is truly needed, and cache it by hue.
- Use the avatar inside the app only: never on the icon, in notifications or in widgets.

**Callers**
- `SettingsView+Header.swift:17-27`
- `ProfileEditorView.swift:87-99`
- `OnboardingView+StepsLate.swift:283-290`
- `UnifiedScheduleView.swift:31-34`

### S9 · Mark renderings

**Supports**, built over F7's shapes:
- `IsoclineMarkView(rendering: .ink | .hairline | .emboss, …)`:
  - **ink**: fill in `currentColor`, accent or ink;
  - **hairline**: stroke of `Theme.Line.engrave` in ink;
  - **emboss**: a paper face, a white copy offset up-left at .85 opacity and a dark copy offset down-right at .16 opacity, matching `build_isocline_marks.py`.
- Under Reduce Transparency, emboss falls back to hairline.

**Uses**
- lock screen (O2);
- onboarding welcome (O1);
- About / Acknowledgements header (F8);
- the stealth icon artwork (I3).

### S10 · Sheet surfaces

**Today**
- `JournalComposerView` paints an opaque `appBackground` (`JournalComposerView.swift:184`) and a `.regularMaterial` bottom bar (163, 182).
- `QuickDoseSheet` has `.asGlassCard` on a button (445), an `.ultraThinMaterial` overlay forced dark (608-609) and a `.regularMaterial` popover (764).
- `TypeMethodSettingsView` and `DoseScheduleSettingsView` paint `systemGroupedBackground`.

**Target**
- Sheets show the system glass.
- Content inside is flush, with hairline rows, `ghostCard` outlines and accent controls.
- Cancel/confirm live in `ToolbarItem(placement: .cancellationAction / .confirmationAction)`, which iOS 26 renders as glass buttons natively.

**Steps.** Remove the opaque backgrounds, the material bars and the in-sheet glass as each sheet is touched (J9, H13, ST4).

### S11 · `ThemeSpecimenView` (the hue specimen)

**Target.** §08 "Appearance: the hue specimen". A near-square preview built from the **real** components at their real sizes, filled with **sample data**.

**Supports**
- `ThemeSpecimenView(preview: ColorScheme?)`. It uses the real primitives and draws with the live palette:
  - `paperCard`, `Pill`, `ActionPill`, `IsoclineMarkView`;
  - the curve shapes from `Shared/CurveLayout.swift`.
- `SpecimenSample`: one static fixture with curve points, readout, phase markers, dose card and chips. **Never** read user data: the screen may be screenshotted, and onboarding shows it before setup.
- **Day/Night preview** is `.environment(\.colorScheme, preview)` on the specimen subtree only. Palette colors are dynamic (`Color(light:dark:)`), so this works with no second palette.
- **Live hue.** `ThemeManager.seedHue` already re-resolves the palette on every drag tick and commits on end. The specimen just observes it.
  - If profiling shows `ThemePalette.resolve` is too slow per tick, resolve a *preview* palette for the specimen only and leave the app palette alone until the commit.
- **Shape.** `RoundedRectangle(cornerRadius: Theme.Radius.specimen, style: .continuous)`, aspect `components.specimen.aspect`, with a `line` hairline.
- **Accessibility.**
  - The specimen is `accessibilityElement(children: .ignore)` with one label ("Preview of the app in the chosen hue").
  - Dynamic Type is capped at `.large` inside it, since it's a preview; the band outside it stays fully scalable.
- **No `scaleEffect`.** Scaling a real screen down would blur text and break hit areas.

---

## Phase 3a · Home data supports (logic only, fully tested)

These add derived state to `MedicationManager`/`JournalManager` with no UI, so Phase 3b is purely presentational. All of them read existing state; none needs a schema change.

### H-D0 · Named constants (behavior, not design)

These thresholds are product behavior, not visual tokens. They live once in Swift as named constants, beside the code that uses them, and tests reference the names. The rest of this plan uses the names, not the numbers:

| Constant | Value | Used by |
|---|---|---|
| `PhaseStrip.weekdayMaxIntervalDays` | 14 | H-D2, H9 (weekday vs date labels) |
| `PhaseStrip.minIntervalDays` | 2 | H-D2 (no strip for daily routes) |
| `Provenance.ageBuckets` | days below 14 · weeks below 60 · months | H-D3 |
| `DayPeriod` hour ranges | morning 5–11 · afternoon 12–16 · evening 17–20 · night 21–4 | J5 |
| `DoseSection.adjustScheduleAfterDays` | 3 (today's literal in `NextDoseRowView`) | H11 overdue state |
| `DoseSection.countdownRefresh` | 60 s | H11 `TimelineView` |
| `HomeLayout.accessibilityCurveFraction` | 0.4 | H1 AX layout |
| `NotificationLayout.ownWordsMaxLength` | 40 | NT1 |

The safety thresholds are **not** restated anywhere in this plan. `SafetyFlag` in code is their only source.

### H-D1 · `DoseDayState`, which also fixes "Today"

**Today.** `NextDoseRowView.swift:30-56`:
- `isToday = completedDays >= cycleDays`, where `completedDays = min(daysSinceLastDose + 1, cycleDays)`;
- `cycleDays = effectiveFrequencyDays`, the method-based display tier;
- `nextDoseDate` and missed detection use `effectiveDueIntervalDays` (`+Derived.swift:52-62`), so the two disagree;
- "Today" therefore shows a day early, always for daily routes, and from day 6 for TU.

**Supports.** In `MedicationManager+Schedule.swift`:

```swift
enum DoseDayState: Equatable {
    case unscheduled                 // !isFullyConfigured or no nextDoseDate
    case upcoming(Date)              // nextDoseDate after end of today → compact "Next dose"
    case dueToday(Date)              // nextDoseDate within today, not yet passed
    case overdue(Date)               // now ≥ nextDoseDate (inside or past grace) → see X14
}
func doseDayState(now: Date = .now, calendar: Calendar = .current) -> DoseDayState
```

**Rules**
- Use only `nextDoseDate` (`MedicationManager.swift:132`), `hasMissedDose` and the calendar.
- After a dose is logged, `addDose` advances `nextDoseDate`, so the state becomes `.upcoming` with no special case.

**Tests** (new `DoseDayStateTests.swift`). Each case uses the `effectiveDueIntervalDays` it names:
- EV every 7 days: day 6 → `.upcoming`, day 7 → `.dueToday`;
- TU every 70 days;
- oral daily, before and after logging;
- a dose logged early;
- grace boundary ±1 minute;
- a DST transition;
- `nextDoseDate == nil`.

### H-D2 · Cycle phase markers

**Today**
- `currentCyclePosition` (`+Pharmacokinetics.swift:124-196`) gives `.nearPeak/.midCycle/.trough/.unknown` for *now* only, and only for injectables.
- There is no per-date phase function.
- Forward doses aren't projected (commit 4955f54), so after now the curve is pure decay.

**Supports**

```swift
struct PhaseMarker: Identifiable, Equatable {
    enum Kind { case dose, peak, trough, today }
    let id: Kind; let date: Date; let kind: Kind
}
func cyclePhaseMarkers(now: Date = .now) -> [PhaseMarker]
```

**Rules**
- `dose` = `lastDoseDate`.
- `peak` = `lastDoseDate + tmax(ester)`. Omit it when `isTmaxCalibrated` is false (TP, transdermal; `PharmacokineticConstants.swift:144-149, 478-483`). That's the honesty rule.
- `trough` = `nextDoseDate`, the lowest point before the next dose under no-projection.
- `today` = now.
- When two markers fall on the same day, `today` absorbs the other one as its subtitle ("FRI · PEAK").
- Not produced when `effectiveDueIntervalDays < PhaseStrip.minIntervalDays` (daily routes), so the strip hides (X11).

**Tests:** EV 7-day; EC; TU 70-day, where markers are weeks apart; TP with no peak; oral returns empty; dose today returns `today`+`dose` collapsed.

### H-D3 · `LevelProvenance`

**Today**
- `calibrationFactor` comes from the latest calibrated lab for `selectedMedication` (`MedicationManager.swift:279-294`).
- `BloodTestRecord.isCalibrated`, `drawDate` and the private `mostRecentRelevantBloodTest` (75-day relevance window, `+Schedule.swift:178-185`) all exist.

**Supports**

```swift
struct LevelProvenance: Equatable {
    enum Basis { case noLabs, calibrated(lastLab: Date), labNotUsable(lastLab: Date) }
    let basis: Basis
    let labsOnFile: Int        // selected hormone only
}
var levelProvenance: LevelProvenance { get }
```

**Copy grammar.** Mono, caps through `textCase`, localized with plural inflection:

| Basis | Line |
|---|---|
| `.noLabs` | `MODELED · NO LABS YET` |
| `.calibrated` | `MODELED · CALIBRATED TO YOUR LAB OF 4 MAR` or `… · 14 D AGO`; ages bucketed by `Provenance.ageBuckets` (H-D0) |
| `.labNotUsable` | `MODELED · LAST LAB NOT USED FOR CALIBRATION`. This is where `calibrationAlpha` returned nil because the draw couldn't be reconciled. |
| while scrubbing | `MODELED · FRI 14:00`. The time replaces the lab clause; the readout already shows the value. |

Never write "CALIBRATED TO N LABS" (X13 / U3). The curve is drawn in full in every basis, including `.noLabs` (X8, decided).

**Tests:**
- no labs;
- a lab for the other hormone only, which gives `.noLabs`;
- a calibrated lab;
- an unreconcilable lab;
- two labs, where the newest wins;
- age formatting at the bucket edges.

### H-D4 · `RangeBand`

**Today**
- `TherapeuticTarget { troughMin, troughMax, peakCeiling }` (`MedicationManager.swift:369-377`), stored as `userTherapeuticTarget`, which is nil when unset.
- `contextualRange` marks only the trough pair as `.userSet` (`+Pharmacokinetics.swift:396-428`).

**Supports.** `struct RangeBand { let low: Double; let high: Double; let unit: HormoneUnit }` and `var rangeBand: RangeBand?`.
- It is **nil when `userTherapeuticTarget` is nil.** Clinical defaults aren't "your range", and that matches the presentation layer's existing rule (`HormoneLevelPresentation.swift:122-131`).
- **Bounds (X9, decided):** `low = troughMin` and `high = peakCeiling`, labeled `YOUR RANGE {low}–{high}`. `troughMax` stays in the readout comparison ("Within set trough").

### H-D5 · Lab points in a window

**Supports.** `func labPoints(in window: ClosedRange<Date>) -> [LabPoint]`, where `LabPoint` is `{ date, measured }`.
- It covers the selected hormone only and reads `bloodTestHistory`, which is sorted by draw date descending.
- It plots **measured** values, not calibrated ones.

### H-D6 · Next-site suggestion

**Today**
- `lastInjectionSites(for:)` and `lastInjectionSiteDoseDate` (`+Sites.swift:24-38`) have no callers.
- `QuickDoseSheet.recentlyUsedZones` (82, 787) is computed and never read.
- Preferred, avoid and recommended zones come from `ZoneCentroidStore` (`QuickDoseSheet.swift:85-92`).

**Supports**

```swift
struct SiteSuggestion { let last: [InjectionSite]; let lastDate: Date?; let suggested: InjectionSite? }
func siteSuggestion(routeClass: RouteClass) -> SiteSuggestion
```

**Rule.** Pick the least recently used zone in (preferred ∪ recommended) − avoid, using the same `heatMapWindowDays` window the picker uses (injection: 30 d). On ties, take the opposite side from the last site.

Return `nil` for oral, and for cream/patch when no zones are configured.

**Tests:** rotation across 4 preferred zones, with an avoid list, an empty history, and a tie broken by side.

### H-D7 · `JournalManager` gaps that Home also needs

`lastEntry` is `entries.first` (`JournalManager.swift:43-45`), which already means the newest entry, so Home's journal section can use it directly.

The cache doesn't refresh on CloudKit remote changes. It only reloads through `CloudSyncService.swift:84,120,139`.

**Steps.** Observe `NSPersistentStoreRemoteChange` (or `ModelContext.didSave` for local saves) and call `loadEntries()`. The same applies to `MedicationManager.refreshState()` if remote doses or labs should move the curve live. J10 has the edit and delete APIs.

---

## Phase 3b–3c · Home UI and the record-dose sheet

### H1 · Canvas and layout

**Today** (`HomeView.swift`)
- Structure: `NavigationStack → GeometryReader → ZStack`, with no ScrollView.
- `HomeGradientBackground` (222-254) uses `Graph.base*` and two glows.
- A black veil fades from .25 to 0 (50-52).
- The curve occupies the top 55% (`dataRegionFraction: 0.55`).
- `LevelOverlayView` floats as a material card that dodges the now dot (37-66).
- `UnifiedStackView` is docked at the bottom.

**Target**
- A flat paper ground, top to bottom:
  1. eyebrow, readout and provenance, flush;
  2. the curve filling the middle and running under the card;
  3. the phase strip;
  4. one overlay card docked above the tab bar.

**Supports**
- Preference keys `ReadoutBlockHeightKey` and `OverlayCardHeightKey`.
- `FlatGraphView(plotInsets: EdgeInsets)` replaces `dataRegionFraction`:
  - **top** = readout block + 12;
  - **bottom** = card height + phase strip + 12.

  The y-mapping in `FlatGraphView.swift:35-45` and `CurveLayout` uses these insets.
- **The fill** still closes at the bottom of the screen, behind the card.
- **The plateau** stays visible above the card because the bottom inset tracks the card's live height, which changes with the dose state (H11).

**Steps**
1. Delete `HomeGradientBackground` and the veil.
2. Use `.background(Theme.Colors.paper)`.
3. Restructure the views into `VStack(readout) + FlatGraphView + VStack(phaseStrip, card)` over the paper.
4. **Accessibility sizes.** When `dynamicTypeSize.isAccessibilitySize`, wrap everything in a `ScrollView`:
   - the curve gets a fixed height of `HomeLayout.accessibilityCurveFraction` of the screen;
   - the card flows below it rather than overlaying.

   This also puts the unused `@Environment(\.dynamicTypeSize)` at `HomeView.swift:14` to work.

**Verify.** Render with the SpoofProfile personas at default size and at AX3, in light and dark, at hues 0°/90°/180°/270°.

### H2 · Readout (flush)

**Today.** `LevelOverlayView.swift:68-157`:
- an "Estimated" caption;
- `AnimatedCounter` in `.system(size: 52)` with tracking −2.08;
- a unit and medication line;
- `RangePill`;
- an `.ultraThinMaterial` background at .65 with dodge logic;
- `.celebrationGlow` plus `.entranceScale`.

`AnimatedCounter` (`Motion.swift:111-136`) formats with `Int(value.rounded())`, so there's no grouping ("1200").

**Target**
- No card, no material, no dodge.
- Contents:
  - eyebrow: `ESTRADIOL · DAY 3`, built from the hormone base word plus cycle day on the **due** tier, and omitted for daily routes (ester name and interval total moved off the eyebrow — they live on the dose card's medication line and the phase strip; see the 2026-10-12 Home tidy-up decision);
  - readout: mono 500 at 52, `218`, with the unit `pg/mL` in muted mono;
  - provenance line (H-D3);
  - an optional status line (X18);
  - the **safety pill**, when a `SafetyFlag` applies. It uses `Theme.Colors.error` (the `safety` recipe) as outline, text and an `exclamationmark.circle` glyph, with no fill. The clinical note opens on tap. It's never gated (X10, decided).
- While scrubbing, the readout shows the scrub value in accent and the provenance line shows the scrub time.

**Steps**
1. Rebuild `LevelOverlayView` as `HomeReadout`.
2. Give `AnimatedCounter` a `formatter` parameter, defaulting to `AppNumberFormatters.hormoneLevel` (`AppFormatters.swift:105`).
3. Keep `minimumScaleFactor` for 4-digit testosterone values.
4. Remove the celebration modifiers (X19).

**Supports.** `MedicationDisplayFormatter`:
- "Estrogen" + "Valerate (EV)" → "Estradiol valerate";
- testosterone esters likewise;
- strip the parenthetical codes.

### H3 · Provenance line

Render the copy from H-D3 with `.font(Theme.Fonts.label)` and `.monoLabel()`, in muted color. It isn't interactive. Optionally, tapping it could later deep-link to Labs; leave that out of v1 because "what is" shouldn't be a control.

### H4 · Curve: fill and stroke

**Today** (`FlatGraphView.swift`)
- The fill is `levelTint` at .42 → 0 (268-298).
- The stroke is a solid `levelTint` at 1.8pt (283-307).
- `levelTint` = lerp(levelLow, levelHigh, level/ceiling), with the ceiling hard-coded at 1200 for T and 600 for E (56-64).

**Target**
- Fill: `levelTint` at `curve.fill.topOpacity` → 0, vertical.
- Stroke: `Theme.Line.curveHero`, sweeping levelLow → levelHigh, with no dash anywhere.
- Night paper only: a faint glow.

**Steps**
1. Read the fill top opacity from `curve.fill.topOpacity` (generated if X7 is adopted; otherwise one named constant).
2. Stroke with `LinearGradient([levelLow, levelHigh], .leading → .trailing)` at `Theme.Line.curveHero`. On a function graph, x is time and monotonic, so a horizontal gradient *is* the along-the-line sweep (U11).
3. Add the glow per `curve.glow` (dark appearance only, never under Reduce Transparency): a `levelTint` shadow at its `opacity` and `radius`, on the stroke layer only.
4. Remove `therapeuticReferenceLines` and `dashedLine` (341-378); H5 replaces them.
5. Delete the no-op `onChange(of: userTherapeuticTarget?.peakCeiling)` at 169.
6. Fix the stale header comment at 10-11: the chart *is* interactive (scrubbing).

### H5 · Range band

**Today**
- Three dashed `successBrand` lines labeled "Peak ceiling …" and "Trough …–…" (350, 364).
- They are unclamped, so they can sit off-screen.

**Target**
- A soft band from `rangeBand.low` to `rangeBand.high`, filled with accent at .05 and no border.
- Gridline values at the edge.
- Label: `YOUR RANGE 100–600` in `statLabel` mono, muted, at the band's top-left inside the plot.

**Steps**
1. Draw the band from `rangeBand` (H-D4) only.
2. **Y-scale.** When a band is present, `CurveLayout.valueBounds` uses the union of the data and the band. Cap that union at `curve.rangeBand.maxSpanRatio` × the data span so the curve doesn't flatten; when the band is clipped, its label still shows the true numbers.
3. Retire `successBrand` from the chart. If `Theme.Colors.successBrand` has no remaining callers, delete it and update the tokens' `fixed.success.role`.

**Decided.** X9 (bounds: trough floor to peak ceiling), X10 (safety pill is the only red).

### H6 · Lab rings

**Target**
- A hollow ring for each lab draw inside the window, at its **measured** value.
- Ink stroke at `Theme.Line.labRing`, paper fill, `curve.labPoint.diameter`.
- If the model and the draw disagree, the visible gap is the point; don't snap the ring to the curve.

**Steps**
1. Draw `labPoints(in: window)` (H-D5) between the fill and the now point.
2. Each ring gets the a11y label "Lab, 4 March, 212 pg/mL".
3. With the ~3-day window, rings will be rare on Home. The provenance line carries the lab story, and the full history lives in the Labs chart (ST9). See X12 / U4.

### H7 · Now point

**Today**
- `currentDot` (382-425): a 26pt `levelTint` halo at .22 with blur 6, plus a 12pt dot.
- It slides in from the right.

**Target.** A concentric point per `curve.nowPoint`: an accent halo (`haloDiameter`, `haloOpacity`, no blur) around a solid `levelTint` dot (`dotDiameter`). It's the same perfect circle as the "I." mark.

**Steps.** Remove the blur and recolor the halo. Keep the `dotSlide` entrance, which already honors Reduce Motion.

### H8 · Dose markers on the curve

**Today**
- `lastDoseDot` (429-460): accentSecondary dots labeled "dose" in 7pt.
- `nextDoseDot` (464-497): a **hollow ring** labeled "next dose".

**Target.** Retire both.
- A hollow ring now means "a lab draw", so a hollow next-dose ring would read as a measurement.
- Dose timing is carried by the phase strip (H9) and the dose section (H11).
- If a dose cue is wanted on the curve later, use a short engraved tick on the baseline, never a ring.

### H9 · Phase strip

**Today.** None. The nearest thing is the cycle dot track inside `NextDoseRowView.swift:162-208`, which retires with H11.

**Target**
- Up to four mono chips under the curve, e.g. `MON Dose · WED Peak · FRI Today · SUN Trough`.
- Today's chip has an accent hairline ring.
- They are labels, not buttons.

**Supports.** `cyclePhaseMarkers()` (H-D2) and `AppDateFormatters`:
- `weekdayShort` (`AppFormatters.swift:45`) when the interval is at most `PhaseStrip.weekdayMaxIntervalDays`;
- `monthDay` (`AppFormatters.swift:33`) above that, e.g. TU: `MAR 4 Dose · APR 2 Peak · …`.

**Steps**
1. Build `PhaseStrip(markers:)` from `Pill` with the `.neutral` / `.active` styles.
2. Hide it when `markers.isEmpty` (daily routes).
3. It is **not x-aligned** to the chart, because the chart window covers about 3 days and the strip covers one dosing interval (X11 / U5).
4. Phase words are positional names, never goals: PEAK, TROUGH, DOSE, TODAY. "STEADY" is reserved for the mid-cycle readout status (X18).

### H10 · Overlay card

**Today.** `UnifiedStackView.swift:16-48`:
- `InsightRowView → MoodRowView → NextDoseRowView → ActionBarView`, separated by `HairlineDivider`;
- wrapped in `.asGlassCard(cornerRadius: 20)` plus a brand accent at line 48.

**Target**
- One `paperCard` (radius 20) docked above the tab bar.
- Two sections, split by a hairline: the dose section (H11) and the latest journal entry (H12).
- It is only as tall as its content.

**Steps**
1. Replace the glass with `.paperCard()`.
2. Retire `ActionBarView`: Log Dose moves into the dose section, and the Journal button is covered by H12.
3. Retire `InsightRowView`. Its sentence becomes the readout status line (X18).
4. Animate height changes with `Theme.Motion.settle`, or a crossfade under Reduce Motion.
5. Report the height through `OverlayCardHeightKey` (H1).

### H11 · Dose section (two states)

**Today.** `NextDoseRowView.swift`:
- the "Today" / "Next <weekday>" label (buggy, see H-D1);
- a dot track;
- a missed state with an **error-red** badge (215-218), "Missed dose", "Record";
- an expanded overdue prompt after 3 days, with "Record dose" / "Adjust schedule";
- a `NavigationLink` to `UnifiedScheduleView` (279).

**Target**

| `DoseDayState` | Layout |
|---|---|
| `.dueToday(t)` | Full height. Serif `Today 6:00 PM` + a mono countdown chip `IN 6H 42M`. Mono medication line `ESTRADIOL VALERATE 4 MG · INJECTION`. Filled **Log Dose** `ActionPill`. |
| `.upcoming(t)` | One row: mono `NEXT DOSE`, serif `Fri 6:00 PM`, chip `IN 2D` pushed right. No pill. Tapping the row opens the record-dose sheet for early or off-schedule logging. |
| `.overdue(t)` | Full height, laid out like `.dueToday` (X14). Serif `Due Sun 6:00 PM`, neutral chip `2D AGO` in ink, not red, and Log Dose. After `DoseSection.adjustScheduleAfterDays`, a secondary text button "Adjust schedule" opens `DoseScheduleSettingsView`. |
| `.unscheduled` | The unconfigured card (H15). |

**Supports**
- `TimelineView(.periodic(from: .now, by: DoseSection.countdownRefresh))` around the chip, so the countdown advances. `refreshState()` isn't time-based.
- `CountdownFormatter`: `IN 6H 42M`, `IN 2D`, `2D AGO`, localized.
- Medication line built from `resolvedDoseDefaults` / `lastLoggedDose`: ester, amount and method word.
- The time shown is decided by X16.

**Steps**
1. Rewrite `NextDoseRowView` as `DoseSection(state:)`.
2. Delete the dot track, the pulse, the red badge and the raw shadows.
3. Delete `RecordDoseView` (H13 / X15).
4. Move `UnifiedScheduleView`'s entry point to Settings → Medication & Dose → Schedule (ST1).
5. Accessibility:
   - the whole row is one element: "Next dose Friday 6 PM, in 2 days";
   - Log Dose is a separate button.

### H12 · Latest journal entry section

**Today.** `MoodRowView.swift`:
- shows **today's** entry only; otherwise "Add mood" / "Tap to journal", which are unlocalized `String`s;
- mood icon tinted by the `JournalTheme` valence palette;
- tapping opens the composer.

**Target**
- Serif label `Journal`, then mono time and relative day (`08:30 TODAY`, `YESTERDAY`, `SUN`).
- A one-line quote of the entry in Atkinson, then a chevron.
- Latest entry, not today-only (X17).

**Steps**
1. Rebuild `MoodRowView` as `JournalSection`, reading `journalManager.lastEntry`.
2. Show the empty copy when there are no entries ever: `No entries yet` in muted.
3. Tapping switches to the Journal tab, scrolled to the top where the top card or ghost card lives. This needs a router (N2).
4. Drop the valence tint (X23).

### H13 · One record-dose sheet, with last and suggested site

**Today.** Two flows:
- `QuickDoseSheet`:
  - opened from `ActionBarView`;
  - a full summary and edit screen, then the step-2 3D site picker (`BodyModel3DView`) with heat map, avoid/preferred/recommended zones and multi-site;
  - `asGlassCard` on a button (445), a forced-dark material overlay (608-609) and a material popover (764).
- `RecordDoseView`:
  - opened from `NextDoseRowView`;
  - a date-only graphical picker in a **`.height(300)`** sheet (`NextDoseRowView.swift:72-75`), so it's likely clipped;
  - no site, with defaults from the last dose.

**Target**
- Log Dose always opens **`QuickDoseSheet`**.
- Its summary step shows `LAST SITE · LEFT THIGH · SUN` and `SUGGESTED · RIGHT THIGH`, both mono, using H-D6.
- In step 2 the suggested zone is *highlighted*, never preselected. The user confirms.

**Steps**
1. Route every record-dose entry to `QuickDoseSheet`:
   - the dose section, in every state;
   - the notification action (N2);
   - the missed-state prompt.
2. Delete `RecordDoseView`. Its date choice already exists as "Change date…" in `QuickDoseSheet`.
3. Restyle the sheet:
   - remove `asGlassCard` and the materials (S10);
   - fonts: QuickDoseSheet has 33 bare text-style fonts plus 5 `.system` calls, the largest single sweep;
   - concentration chips → `Pill`;
   - "Record Dose" → `ActionPill`.
4. Review `InjectionSite.swift:119`, which tints `.patch` with `warning`. Use accent instead; route classes aren't statuses.
5. Wire `recentlyUsedZones` into H-D6 or delete it.
6. **Haptics.** Use `.sensoryFeedback(.success, trigger: medicationManager.doseRecordedCount)` on Home. This replaces confetti (X19).

**Verify**
- Log a dose in each state.
- After an early log, the dose section reads `.upcoming`.
- The suggestion rotates across the SpoofProfile histories.

### H14 · Retire celebrations on Home

**Today**
- `HomeConfettiBurst` (`HomeView.swift:69-74`), driven by `onChange(doseRecordedCount)` (122-141) with `celebrationDelay` (0.55 s / 1.2 s).
- `.celebrationGlow` on the readout.

**Target.** The feedback for logging a dose is the curve morphing to include it (already animated, `FlatGraphView.swift:163-168`), the dose section changing state, and a success haptic. Nothing more (X19).

**Steps**
1. Delete `HomeConfettiBurst` and the `celebrationDelay` plumbing, if nothing else uses it.
2. Delete `CelebrationGlowModifier` after T4.

### H15 · Unconfigured and empty states

**Today**
- Not configured: a text placeholder card, "Set up your medication" (`HomeView.swift:77-104`).
- No doses: "Log a dose to see your curve" (`FlatGraphView.swift:180`).

**Target.** The engraved-hairline rendering for empty instruments:
- an illustrative curve drawn as a single ink hairline at `Theme.Line.engrave`, with no fill, no numbers and no grid values;
- copy in muted Atkinson.

The card is a `paperCard` with an `ActionPill`:
- "Set up medication" opens the `TypeMethodSettingsView` sheet;
- "Log first dose" opens `QuickDoseSheet`.

There is no separate uncalibrated rendering. X8 decided the full curve is always shown, and the provenance line carries `MODELED · NO LABS YET`.

---

## Phase 3d · Journal

### J1 · Header

**Today.** `JournalView.swift:144-168`:
- `Text("Journal")` in `.system(size: 52, weight: .bold)` with a brand gradient;
- an entry count `^[N entry](inflect: true)`, whose catalog comment wrongly says "Tenure badge…".

**Target**
- `Text("Journal")` in `Theme.Fonts.hero`, ink.
- **No count**: the spec forbids counts.

**Steps.** Remove the count and mark its catalog key stale.

### J2 · Week strip (replaces `TimelineScrubber`)

**Today.** `TimelineScrubber` (`JournalView.swift:212-262`):
- capsules only for days that have entries;
- the selected capsule uses a brand gradient;
- `selectedDateKey` is never synced to the scroll position.

**Target**
- Seven mono day numbers, from the week's `Calendar.current.firstWeekday`.
- Today has an accent hairline ring.
- Under each day:
  - a **dose dot**, filled accent, if a taken dose was recorded that day;
  - an **entry dot**, hollow and ink-muted, if an entry exists.

**Supports**
- `doseDays(in: DateInterval) -> Set<Date>` over `medicationManager.doseHistory`, counting taken only and excluding soft-deleted records (`MedicationManager+Persistence.swift:235-241`).
- `entryDays(in:)` over `journalManager.entries`.

**Steps**
1. Build a horizontal paged `ScrollView` (`.scrollTargetBehavior(.paging)`) of week pages. It starts on the current week and is bounded by the first dose or entry date.
2. Tapping a day that has entries scrolls to that day's group through the existing `ScrollViewReader` and `.id(group.key)`. Days without entries are inert.
3. Accessibility:
   - each day reads "Thursday 17, dose recorded, 2 entries";
   - dots differ by shape (filled vs hollow), not only by color (F6).

### J3 · Top slot: card or ghost card

**Today**
- Every entry is a flat row.
- `EmptyJournalView` (`JournalView.swift:322-343`) appears only when no entries exist at all: "Tap the + button to create your first entry".

**Target**

```swift
enum JournalTopSlot { case card(JournalEntry), ghost }
// card iff entries.first exists and Calendar.current.isDateInToday(entries.first!.date)
```

**Card** (`paperCard`, the one place on the screen that's "now"):
- the time-of-day glyph in an icon tile;
- serif `Sunday` + muted ` morning`;
- mono meta `08:30 · ESTRADIOL VALERATE 2.0 MG` (J6);
- the quote in Atkinson;
- mood and symptom chips (`Pill`).

**Ghost** (`ghostCard`): `Tap "New entry" below to write in your journal.` in muted Atkinson, centered. It isn't a button.

**Steps**
1. Compute `topSlot` in the view, or as a `JournalManager` helper with a unit test.
2. The rows list = entries minus the card's entry.
3. **Delete `EmptyJournalView`**: with zero entries the screen shows the ghost card and nothing below it. That is the empty state.
4. If there are several entries today, only the newest is a card (X20).

### J4 · Flush rows

**Today.** `JournalEntryRow` (`JournalView.swift:266-318`):
- an 8pt mood dot in the valence color;
- `previewText` in `.system(.body, design: .serif)`, 2 lines;
- the mood name tinted, plus the first symptom;
- `Text(date, style: .time)` and a chevron.

**Target**
- No surface.
- The time-of-day glyph with no tile.
- Serif day, a one-line quote in Atkinson, and mono time at the right.
- Rows are separated by `HairlineDivider(inset:)`.

**Steps**
1. Restyle the row.
2. Drop the mood dot and its tint (X23).
3. Keep the chevron for rows that open detail, or drop it for calm; this is a design taste call.
4. Day group headers become `.eyebrow()` (`SUNDAY 12 OCT`), with `journalDateLabel` localized (J11).

### J5 · Time-of-day helper

**Supports.** `enum DayPeriod { morning, afternoon, evening, night }`, from the hour ranges in H-D0.

It provides:
- a glyph: SF Symbols `sunrise`, `sun.max`, `sunset`, `moon` by default, or the sketch's half-circle family as a design call;
- a localized period word ("morning").

The phrase "Sunday morning" is assembled by a localized format (`"%1$@ %2$@"`), so locales can reorder or replace it (U9).

### J6 · Dose meta line on the card

**Today.** There's no link between entries and doses. Only `JournalEntry.hormoneLevel`, a level snapshot taken at save time, exists.

**Supports.** `medicationManager.dose(onSameDayAs: entry.date) -> DoseRecord?`, the taken dose on the entry's calendar day.

The meta line is `08:30` alone when there's no dose that day, or `08:30 · ESTRADIOL VALERATE 2.0 MG` when there is one (U8).

### J7 · Mood presentation

**Today.** `JournalTheme.palette(for:)` (`JournalTheme.swift:20-51`) maps seven moods onto three palettes:
- happy/energetic → accent
- calm/neutral → secondary
- tired/sad/anxious → fixed grey

**Target.** Mood appears as a chip (glyph plus word) on the card and in detail, with no valence color. Coloring "sad" grey and "happy" accent is a quiet verdict (X23).

**Steps**
1. Retire the palette mapping.
2. `MoodChip` in the composer uses `Pill` `.active` for the selection.
3. Delete the four `lightHex`/`darkHex` pairs at `JournalTheme.swift:44-47`.

### J8 · Floating "New entry" pill, and the dose-history button

**Today**
- A 56pt accent circle FAB with `accentFab` shadow, bottom-trailing (98-112), with no a11y label.
- A 50pt `.regularMaterial` dose-history circle, bottom-leading (114-129), that opens `DoseHistoryView` full-screen.

**Target**
- One centered `ActionPill(.floating)`, "New entry", above the tab bar.
- It rests on a short paper fade so rows scroll beneath it.

**Steps**
1. Replace the FAB.
2. For the fade, try iOS 26's `safeAreaBar(edge: .bottom)` first, so the system scroll-edge effect handles content beneath. If that renders as glass over the paper, fall back to a `components.floatingFade.height` `LinearGradient(paper.opacity(0) → paper)`, which becomes a solid band under Reduce Transparency (U15).
3. Remove the dose-history button (X21). Dose history stays at Settings → Labs & Records.
4. Remove `Theme.Shadows.accentFab` and `floating` if nothing else uses them (F10).

### J9 · Composer

**Today.** `JournalComposerView.swift` (487 lines):
- an accent "New Entry." title at 36 bold;
- `TextEditor` in serif footnote, colored by `journalText` hex #72243E/#F4A8C0;
- a `Time.cycle.surface` card for the text area;
- symptom and mood chips;
- a `.regularMaterial` bottom bar with xmark/checkmark buttons;
- an opaque `appBackground`.

The discard dialog and `SheetDismissAttemptObserver` are new, uncommitted and correct; keep them. Presentation differs by entry point: `[.medium, .large]` from Journal, no detents from Home.

**Target**
- Sheet glass as the surface.
- Title `New entry` in `Theme.Fonts.serifTitle`, ink.
- The text area is a `ghostCard` outline with `Theme.Fonts.body` (Atkinson) and ink text.
- Chips are `Pill`s.
- Cancel and Save are toolbar items.

**Steps**
1. Wrap the content in a `NavigationStack` for its toolbar.
2. Delete the bottom bar and the opaque background.
3. Delete the hex colors at 223, 250 and 385; the 223 and 385 swatches move to accent/ink.
4. Use `[.medium, .large]` from every entry point.
5. The level row (`compactLevelRow`, 214-240) shows mono value plus unit, with the band label from `levelBandLabel` (473-486). Check its copy against the voice rules: "above 500 pg/mL" is positional, so it's fine.
6. Keep the `canSave` rule that requires text. Whether mood-only entries should be allowed is a product question, outside this transition.

### J10 · Edit and delete

**Today**
- `JournalManager` has no update or delete.
- `JournalDetailSheet` is read-only.
- There are no swipe actions or context menus.
- The spec calls the top card "still open to you: recent, editable" (U7).

**Supports**
- `JournalManager.update(_:)` and `delete(_:)`, both of which save and refresh the cache.
- A composer `mode: .new | .edit(JournalEntry)`.
- Symptom matching **by name**. `Symptom.commonSymptoms` regenerates UUIDs every launch (`JournalModels.swift:102-111`), so equality by `id` breaks across launches.

**Steps**
1. Tapping the top card opens the composer in edit mode.
2. Tapping a row opens `JournalDetailSheet`, with Edit in the toolbar.
3. Add swipe-to-delete on rows, plus a confirmation.
4. In the detail sheet:
   - remove its inner card (`palette.surface`, `.cornerRadius(16)` at 22-49);
   - show the level **with unit**, since numbers always carry units;
   - replace the deprecated `.cornerRadius()`.

**Tests.** New `JournalManagerTests`:
- add, update and delete round trips on an in-memory `ModelContainer`;
- symptom name matching;
- `topSlot` rules.

### J11 · Strings

**Today**
- Not localized: "Today" and "Yesterday" (`JournalTheme.swift:105-109`, `JournalView.swift:252-253`), `mood.rawValue`, symptom names, and MoodRowView "Add mood" / "Tap to journal".
- Present but empty: the four discard-dialog keys.

**Steps.** Add these keys:
- `New entry`
- `Tap "New entry" below to write in your journal.`
- the period words
- the "%1$@ %2$@" day-period format
- the mood display names

Mood raw values stay as storage keys. Fill in the empty discard keys.

### J12 · Seed data and tests

**Today**
- `SpoofProfile.populateJournal` (`SpoofProfile.swift:634-657`) dates every entry at midnight, so all show 12:00 AM.
- Its Title-case symptom names never match the lowercase `symptomMap`, so seeded entries have no symptoms.
- `xTTests/JournalLayoutTest.swift` is a preview, not a test.

**Steps**
1. Give seed entries realistic times so every period is represented.
2. Fix the symptom-name casing.
3. Convert `JournalLayoutTest` to a real `XCTestCase`, or delete it.

**Personas for QA**
- With a today entry, so the top card shows: maya, sam, rowan, nadia.
- Without one, so the ghost card shows: jan, devon, priya, jules.

---

## Phase 3e · Settings

### ST1 · Information architecture: four gateway cards (X24, decided)

**Today.** `ScrollView` with:
- the profile header;
- a 2×2 quick-card grid;
- five inline sections (`SettingsView+Sections.swift`):
  - Medication & Body (6 rows)
  - Health & history (7)
  - App settings (6)
  - About (2)
  - Reset (1)

**Target.** The spec sketch and the Stitch Settings mockup show four gateway cards, each a `paperCard` with:
- an accent tile;
- a sans title;
- a mono subtitle carrying live values;
- a chevron, pushing to a sub-screen.

**Proposed mapping.** Every current row has a home:

| Gateway | Contains (current row → location) |
|---|---|
| **Medication & Dose** · `ESTRADIOL VALERATE · 4.0 MG Q7D` | Type & method (sheet); Dose & frequency (sheet); Schedule overview (`UnifiedScheduleView`, which moves here from H11); HRT start date; Reminders (dose and journal times, **notification layout**, X25); Body silhouette; Preferred zones; Avoid zones; Re-show recommended zones |
| **Labs & Records** · `2 LABS · LAST 14 D AGO` | Blood tests (`BloodTestHistoryView` + Labs chart, ST9); Your range (ST7); Dose history; Dose record (ST11, replaces Adherence); Screenings; Dose intensity insights (toggle) |
| **Appearance** · `HUE 2° · DEFAULT ICON` | Theme hue (`ThemePickerView`); App icon (I4) |
| **Privacy & Data** · `FACE ID · ICLOUD ON` | App lock; iCloud Sync (+ Restore, Sync now); Export data; Reset app data (X27) |
| Footer (flush) | `ISOCLINE · VERSION 1.0 (42)` · Acknowledgements link · `SHAPED PROTOCOL.` |

**Steps**
1. Create `SettingsMedicationView`, `SettingsLabsView`, `SettingsAppearanceView` (renamed from `ThemeSettingsView`) and `SettingsPrivacyView`.
2. **Move** the row builders out of `SettingsView+Sections.swift`; don't rewrite them. The `@State` that backs toggles moves with the rows.
3. Keep the alerts and sheets owned by the screen that triggers them. Today `SettingsView.swift` owns 5 sheets and 6 alerts, and they should split along with the rows.
4. Delete the quick cards (ST3).

### ST2 · Profile header, flush

**Today.** `SettingsView+Header.swift:15-60`:
- a 56pt avatar: photo or brand disc, with no ring;
- the name in `headline`, where the `isEmpty` fallback is redundant;
- `tenureLabel` in footnote beside a 5pt accent dot;
- a `NavigationLink` "Edit Profile" to `ProfileEditorView`, which wraps its **own `NavigationStack`** (22) although it's pushed.

The header already sits flush with no card. Keep that.

**Target** *(updated 2026-10-12 to the screen sketch)*
- `AvatarView(size: .settingsHero / 88)` (S8), centered.
- Serif name (`serifTitle`), centered.
- A mono line in caps: `DAY 412 · 13 MONTHS` (`label` + `.monoLabel()` + `.textCase(.uppercase)`), centered.
- A quiet accent EDIT mono caption beneath; the block itself is not the control (X26).

**Steps**
1. Restyle the header.
2. Present `ProfileEditorView` as a **sheet**. Its own `NavigationStack` with Cancel/Save is then correct.
3. In the editor:
   - delete the 3pt accent ring and the `systemGroupedBackground`;
   - inside the sheet, use flush rows plus a `ghostCard` for the name field.
4. Build the mono line from `tenureLabel` plus the day count, adding a `tenureDays` accessor if one doesn't exist.

### ST3 · Quick cards

Delete the 2×2 grid (`SettingsView+Header.swift:64-112`). All four cards duplicate rows, and the gateways now carry the live values those cards were standing in for.

### ST4 · Row kit rework

**Today** (`SettingsRowKit.swift`)
- `SettingsSection` is a `SectionHeader` plus system dividers, with no card.
- `SettingsRow` has 22pt horizontal and 16pt vertical padding, and caller-chosen tile colors.
- Many rows are hand-built HStacks with 12 or 16pt vertical padding.
- Toggles use `SwitchToggleStyle(tint: accent)`, except iCloud, which has no tint.

**Target.** Gateway cards on the root, and grouped `paperCard`s of rows on sub-screens.

**Supports**
- `SettingsGatewayCard(icon:title:subtitle:destination:)`.
- `SettingsGroup { rows }`: a `paperCard(padding: 0)` with internal `HairlineDivider(inset: Spacing.card + components.tile.size + Spacing.card)`.
- `SettingsRow`: padding `Spacing.card` horizontal / `Spacing.md` vertical *inside* the card. The `Gutter.screen` padding moves to the card's outer edge, so it isn't applied twice.

**Steps**
1. Rebuild the kit.
2. Route every hand-built row through `SettingsRow` using its `trailing:` slot (for the DatePicker, the segmented Picker and the Toggles).
3. Apply one toggle tint everywhere.
4. Fix `privacyLockSubtitle` (`SettingsView+Sections.swift:552-556`), which shows "biometric · timeout" even when the lock is off.

### ST5 · Live mono subtitles

| Gateway | Source | Example |
|---|---|---|
| Medication & Dose | `MedicationDisplayFormatter` + `resolvedDoseDefaults` + `effectiveDueIntervalDays` | `ESTRADIOL VALERATE · 4.0 MG Q7D` |
| Labs & Records | `bloodTestHistory` for the selected hormone, plus the last draw age (`AttributedString` so the `^` directive inflects — `String(localized:)` leaks it raw) | `2 LABS · LAST 14 DAYS AGO` / `NO LABS YET` |
| Appearance & Curve | `seedHue` (rounded) + current icon name | `HUE 2° · DEFAULT ICON` |
| Privacy & Data | `AuthenticationManager.requireAuthentication` / biometric type + `icloudSyncEnabled` | `FACE ID · ICLOUD ON` / `LOCK OFF · ICLOUD OFF` |

Reminder subtitles are built in English with `String(format: "Daily at %02d:%02d")` (`SettingsView+Helpers.swift:133-144`). Switch them to a localized format plus `Date.FormatStyle` time.

### ST6 · Sub-screens: Lists and Forms on paper (X29)

**Today**

| Screen | Built on | Notes |
|---|---|---|
| `AppLockSettingsView` | `Form` with its **own `NavigationStack`** | pushed; persists only on "Done" (92-99, 239-243), so swiping back discards changes |
| `PreferredZonesListView` | `List` | |
| `PreferredZonesEditorView` | `List`, with its **own `NavigationStack`** | pushed |
| `AvoidZonesEditorView` | `List` | |
| `DoseHistoryView`, `BloodTestHistoryView`, `ScreeningHistoryView` | `HistoryListView` (`List`) | |
| `DataExportView` | `.insetGrouped` list | |
| `DeveloperSettingsView` | private clones of the row kit (183-240) | |
| `AdherenceView` | `systemBackground` | |

**Target.** Keep `List`/`Form` where swipe actions and accessibility matter. Apply:

```swift
.scrollContentBackground(.hidden)
.background(Theme.Colors.paper)
.listRowBackground(Theme.Colors.card)
.listRowSeparatorTint(Theme.Colors.line)
```

**Steps**
1. Add a `.paperList()` modifier bundling the four modifiers above.
2. Remove the nested `NavigationStack`s from pushed screens: AppLock, PreferredZonesEditor and ProfileEditor (unless it becomes a sheet, per ST2).
3. Make AppLock persist on change. "Done" then becomes unnecessary when pushed.
4. Point `DeveloperSettingsView` at the shared kit.

### ST7 · "Your range" screen

**Today**
- The "Use personal targets" toggle expands three rows (`SettingsView+Sections.swift:199-265, 349-401`):
  - "Trough lower bound"
  - "Trough upper bound"
  - "Peak ceiling"
- Their descriptions include "Upper safety **limit** near peak", and the summary reads `Trough … · Peak ceiling …`.
- **Bug:** `loadSettings()` never loads `useCustomTargets` or the values, so the toggle always shows off and the fields show 100/200/600.

**Target.** A sub-screen of Labs & Records called "Your range", in neutral language:
- toggle: "Show my range on the curve";
- rows: "Lower edge" (`troughMin`), "Trough upper edge" (`troughMax`), "Upper edge" (`peakCeiling`);
- footer: "Your range is drawn as a band on your curve. It's a reference you set with your clinician, not a goal."

The band these rows draw spans `troughMin…peakCeiling` (X9, decided).

**Steps**
1. Move the screen.
2. Initialize `@State` from `medicationManager.userTherapeuticTarget` on appear. This fixes the bug.
3. Rewrite the copy.
4. Keep the storage (`TherapeuticTarget`, CloudKit-synced JSON) unchanged.

### ST8 · Appearance screen: the hue specimen

**Today**
- `ThemeSettingsView` is titled "Appearance", while its row says "Theme".
- It hosts `ThemePickerView` (shared with onboarding):
  - a custom drag hue band with 36 OKLCH stops;
  - an adjustable action of ±10°;
  - a preview of three `timeSwatch` chips on `.timeCard` plus an accent button (47-88);
  - a commit on drag end.
- "Reset to default" is `Theme.Colors.error` text (41).

**Target.** The spec's design is §08 "Appearance: the hue specimen", with a live sketch. From top to bottom:
1. **Specimen.** A near-square window of the app in miniature:
   - radius `specimen`, `.continuous` corners, aspect `components.specimen.aspect`;
   - paper ground with a `line` hairline;
   - **sample data only**: readout and provenance line, a filled curve (sweep, lab ring, now point, range band), the phase strip, a dose card with Log Dose, chips, an icon tile, a toggle, the "I." app icon.
2. **Day/Night preview.** Two `Pill`s that apply to the specimen only.
3. **Hue band.** The existing control, restyled. The thumb is paper with an ink hairline and an accent core.
4. **Quick stops.** Eight circles from `seed.stops`. The alternate icons (I2) use the same list.
5. **Readout row.** Mono `HUE 2.5° · ACCENT #D4537E`, plus "Default rose" as plain accent text. Resetting a hue isn't destructive.
6. **App icon picker** (I4).

**Supports** → S11 `ThemeSpecimenView`.

**Steps**
1. Replace the swatch preview in `ThemePickerView` with `ThemeSpecimenView`. Onboarding inherits it.
2. Restyle the band thumb. Keep the adjustable action and commit-on-end.
3. Add the quick stops, reading the tokens' stops through generated constants (X7) or one shared array.
4. Change the reset styling.
5. Rename the row to "Appearance" so the row and screen titles match.

**Verify**
- Dragging updates the specimen every frame without dropped frames on device.
- Night preview works while the system is light, and vice versa.
- VoiceOver reads one specimen label, then the adjustable band.

### ST9 · Labs chart

**Today.** `LabsChartView.swift`:
- index-based x;
- a solid measured line with 7pt dots;
- a **dashed `[5, 4]` modeled line** (91);
- a "Measured" / "Modeled" legend.

**Target.** The same vocabulary as Home:
- the modeled series is a continuous curve with no dash;
- measured draws are hollow rings;
- x is **time-proportional**, not index-based, so gaps between draws read honestly.

**Steps**
1. Rewrite the series drawing.
2. Change the legend to "Modeled · ring = lab draw".
3. Keep `labsSeriesPoints` (`+Pharmacokinetics.swift:346-358`) as the data source.

### ST10 · About and footer

**Steps**
1. The version comes from the bundle (F8).
2. Add the Acknowledgements link.
3. The footer line is `ISOCLINE · VERSION 1.0 (42)` plus `SHAPED PROTOCOL.`, in mono at `faint`.
4. Don't claim "ENCRYPTED" (X28).

### ST11 · Dose record (replaces `AdherenceView`) (X30)

**Today.** `AdherenceView.swift` (464 lines):
- a 140pt rate ring with a percentage;
- "N of M scheduled doses recorded";
- stat cards, including "Consecutive on-schedule doses" (`onTimeStreak`) and "Since a missed dose";
- a regimen timeline;
- dose intensity.

The comments already soften the language, but a ring gauge and a consecutive count still read as a score and a streak.

**Target.** "Dose record":
- a month grid of dose dots, reusing the J2 dot vocabulary;
- a plain line, `11 doses recorded in the last 90 days`;
- the regimen timeline, kept;
- dose intensity, kept.

**Steps**
1. Delete the ring and the consecutive or "since missed" cards.
2. Keep `MedicationManager` adherence and streak computations as they are. `PharmacokineticTests` and others may cover them; just stop rendering them.

### ST12 · Reset row (X27)

Make it the last card in Privacy & Data:
- no icon tile;
- the label "Reset app data" in system destructive red. This is a destructive *control*, not data display.

The existing 3-button alert is kept.

### ST13 · Row-title localization (X31)

**Today.** `SettingsRow.title`, `SettingsSection.label`, `SheetSectionLabel.text`, `SelectableOptionRow.title` and `TimePickerSheet.title` take `String`, so they render verbatim and are never extracted. This is known behavior; see memory: *Settings row titles are verbatim*. The confirmed-missing keys include "Type & method", "Medication & Body", "Theme", "iCloud Sync" and others.

**Recommendation.** While the kit is being rebuilt anyway (ST4), switch these parameters to `LocalizedStringResource`. The cost is near zero now and real later.

---

## Phase 3f · Time, onboarding, lock, launch

### T1 · Time type pass

**Today**
- `TimeView.swift` uses raw `.system` sizes:
  - hero 42 bold (147)
  - 20 semibold (154)
  - 13 (162, 171)
  - celebration overlay 32 / 11 / 22 / 13 / 15 (194-214)
- `TimeBodyExplorerView.swift:193` uses 14 medium.
- `TimeRegionDetailView` mostly uses tokens already, so it switches automatically with F2. Its one raw call is `.system(13, .semibold)` at 247.

**Mapping**
- 42 → `hero`
- 20 → `serifTitle`
- 13 → `detail`
- 11 caps → `.eyebrow()`
- 14 → `detail`

Keep the explicit `Color.white` (151-172), because the Time tab is always night.

### T2 · Forced-dark consistency

**Today**
- The Time tab is dark because `NightSkyBackdrop` is black plus accent at .07, with no `preferredColorScheme`.
- `.environment(\.colorScheme, .dark)` covers only the stage sheet (`TimeBodyExplorerView.swift:171`) and the region card (`TimeRegionDetailView.swift:152`).
- The resting hint (`.secondary` on `.ultraThinMaterial`, `TimeBodyExplorerView.swift:189-201`) and `TierCelebrationOverlay` (`.regularMaterial`, `TimeView.swift:219`) follow the system appearance, so they render light on the night sky in light mode.

**Steps**
1. Apply `.environment(\.colorScheme, .dark)` at the `TimeView` root so everything inside is consistently night.
2. Keep the tab bar system-styled. Over a black backdrop, the iOS 26 glass bar adapts on its own.

### T3 · Glass on Time content (X32)

**Today.** `ProfileSurface` (`TimeRegionDetailView.swift:391-404`) applies `.glassEffect(.regular.tint(palette.base.opacity(0.12)))` to the thighs card. That's glass on content.

**Recommendation.** Replace it with a night card:
- `card` dark recipe at 85%;
- a `line` hairline;
- `Radius.xl`.

This keeps the Time tab inside the system rule. The Time tab is the one place the old look could be grandfathered, but no other content glass survives this transition, so don't keep it.

### T4 · Tier celebration (X32)

**Today.** `TierCelebrationOverlay` (`TimeView.swift:182-250`) is a full-screen material overlay with large type.

**Recommendation.** Make it a quiet milestone line inside `TimeHeroHeader`, such as `MONTH 13 · NEW CHAPTER UNLOCKED`. Keep it factual, with no overlay and no glow. Then delete `CelebrationGlowModifier`.

### T5 · Time palettes

`TimeContentPalette` (`Models/TimeContentTypes.swift:115-171`) holds 36 fixed hex values, and `Theme.Colors.Time.*` is seed-derived. **Out of scope:** the Time tab keeps its own palette. Exclude `TimeContentTypes.swift` in the F9 lint baseline.

### O1 · Onboarding

**Today**
- The ground is the brand gradient (`OnboardingView.swift:101`, `CloudSyncChoiceView.swift:16`).
- There are 53 bare text-style fonts and 5 `.system` calls across the step files.
- The avatar is 100pt with a 2pt OnAccent ring and a shadow.
- The hue picker is shared with Settings.

**Steps**
1. Paper ground.
2. A welcome step with the `IsoclineWordmark` in ink (S9). This is the first place the wordmark appears in the app.
3. Map text styles to `Theme.Fonts`. Most map one-to-one once F2 aliases exist; just add the `Theme.Fonts.` prefix.
4. `AvatarView`.
5. Primary buttons become `ActionPill`.

### O2 · Lock screen

**Today.** `AuthenticationView` (`AuthenticationManager.swift:265+`) and `TestBiometricSheet` sit on the brand gradient.

**Target**
- Paper (or night paper), with the **embossed "I."** centered.
- No app name and no color block.

This is the discretion rendering: it's what someone glancing over a shoulder sees.

### O3 · Launch screen (X33)

**Today.** `xTLaunchScreen.storyboard` has a white background (line 30).

**Steps.** Add a static `LaunchPaper` color asset holding the resolved light and dark `paper` from the tokens. Light paper is cream at every seed (X4), so only the dark value is a default-seed approximation. Regenerate it with the tokens: add the asset to the generator's outputs alongside the `theme-color` metas.
- The launch screen can't read the user's seed. Use the default-seed paper, which is close enough for a sub-second flash, or a neutral paper with no hue.
- Leave out the mark, so there's no brand flash on launch.

### O4 · Profile name prompt

`ProfileNamePromptView` is a `.medium` sheet. Restyle it to sheet glass, a `ghostCard` field and an `ActionPill`.

---

## Phase 3g · Navigation, routing, notifications

### N1 · Tab bar

**Today.** `MainTabView.swift`:
- a legacy `.tabItem` `TabView` with no selection binding;
- `.tint(accent)`;
- line 39 has `tabBarMinimizeBehavior` commented out "for compatibility", which no longer applies at iOS 26.0.

**Steps**
1. Migrate to `Tab("Home", systemImage: "house", value: .home) { … }` with `TabView(selection: $router.tab)`.
2. Keep the four tabs in their current order with regular-weight symbols.
3. Accept the system label font (U1, X34).
4. Leave `tabBarMinimizeBehavior` off for v1. Home doesn't scroll, and on Journal the floating pill would have to track the minimized bar. Revisit after J8 ships.

### N2 · Router and `pendingRoute`

**Today.** `NotificationManager.pendingRoute` is set to `.logDose` (from the "Record dose" action or a dose notification tap) or to `.journal` (`NotificationManager.swift:343-366`). Nothing consumes it.

**Supports.** `@Observable final class AppRouter`, injected at the scene:
- `tab`;
- `presentRecordDose`;
- `journalScrollToTop`.

`ContentView` observes `notificationManager.pendingRoute`:
- `.logDose` → `tab = .home; presentRecordDose = true`;
- `.journal` → `tab = .journal; journalScrollToTop = true`;
- then it clears the route.

Home's journal section (H12) uses the same router.

**Verify.** With the app cold, warm and locked (`AuthenticationView` covering), deliver test notifications. The route applies *after* unlock.

### N3 · Toolbars and navigation bars

Every tab hides or blanks its navigation title today:
- Home: `.toolbar(.hidden)`
- Journal and Settings: `navigationTitle(Text(verbatim: ""))`

Keep the in-content serif titles. Pushed sub-screens use standard inline titles in the system font. Customizing navigation-bar fonts on iOS 26 fights the glass bar, so don't.

### NT1 · Dose notification layout, user-customizable (X35)

**Today** (`Managers/NotificationManager.swift`)
- Dose reminder: title "Dose scheduled", body `getMedicationContext()`, such as "4 mg Estrogen" (282-293, 439-445). That names the medication on the lock screen, and nothing turns it off.
- One `doseReminder` category with a "Record dose" action (455-468). Its hidden-preview placeholder is **"Dose reminder"** (466), so even a phone set to hide previews says "dose".
- Journal reminder: title only (316), with placeholder "Journal reminder".
- The action sets `pendingRoute = .logDose`, which nothing consumes yet (N2).

**Target.** People choose what a dose reminder says. The spec's design is §08 "Dose notification layout", with a live mock.

| Layout | Title | Body | Action |
|---|---|---|---|
| **Discreet** (default) | Reminder | Your scheduled entry is ready. | Open |
| Standard | Dose reminder | `{medication} {amount}` | Log dose |
| Detailed | Dose due | `{medication} {amount} · {route} · due {time} · suggested site: {site}` | Log dose |
| Custom | Reminder / Dose reminder / Isocline / *own words* | any subset of: medication, amount, route, scheduled time, suggested site | Open or Log dose |

**Rules**
- Both actions open the record-dose sheet. Nothing is logged from the lock screen.
- The hidden-preview placeholder is always "Reminder", for dose and journal alike.
- Journal reminders take the chosen title style, and their body never carries health data.
- Own words are stored on this device only (UserDefaults), never synced or exported, and limited to `NotificationLayout.ownWordsMaxLength`.

**Supports**
- `struct NotificationLayout: Codable, Equatable`:
  - `preset`, `title` (enum, or `.own(String)`), `fields: Set<Field>`, `actionLogsDose: Bool`;
  - presets as static values;
  - persisted under one UserDefaults key, default `.discreet`.
- `NotificationContentBuilder.content(for: DoseContext, layout:) -> UNMutableNotificationContent`. It's pure and unit-tested. `DoseContext` is built from `resolvedDoseDefaults`, `nextDoseDate`, the reminder time and `siteSuggestion(routeClass:)` (H-D6).
  - Formatting goes through `MedicationDisplayFormatter` (H2) and the U6 method word.
  - Copy uses `String(localized:)`; own words stay verbatim.
- **Two dose categories** instead of one, `doseReminder.open` and `doseReminder.log`, both registered once at launch. The builder picks one per layout. iOS only knows action titles per category, so this avoids re-registering categories every time the layout changes. The response handler (504) must route both to `.logDose`.
- `NotificationLayoutView`: preset pills, field toggles, title picker with an own-words field, and a **live preview**.
  - The preview renders the builder's actual output with sample data, inside a banner mock.
  - It shows both the unlocked banner and the "previews hidden" placeholder.
  - It notes that iOS always shows the app's name and icon (U19), with a link to the Discreet icon (I3).

**Steps**
1. Add `NotificationLayout` and `NotificationContentBuilder`. Rewrite `scheduleDoseReminder` (181-293) to use the builder.
2. Split the category and set both placeholders to "Reminder".
3. Re-schedule pending reminders whenever the layout changes.
4. Build `NotificationLayoutView`. Its only home is **Settings → Medication & Dose → Reminders**, below the reminder times (X25).
5. Wire both actions through N2's router.

**Tests.** `NotificationContentTests`:
- each preset's title, body and category;
- custom subsets;
- own words, including empty (falls back to "Reminder") and maximum length;
- missing data, e.g. no site suggestion for oral, where the field is dropped rather than left blank;
- the placeholder is "Reminder" for both categories.

---

## Phase 4 · App icon

### I1 · Primary icon

**Today**
- `xT/xTGlassIcon.icon` (Icon Composer) has one layer, `xTlogoLetters.png` (583×395), at scale 1.25.
- `App Icon.appiconset` holds three 1024px "Picsart" PNGs, and two of them are byte-identical.
- `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`, so the unused set probably ships anyway.

**Steps**
1. In Icon Composer, make the background a gradient of the default seed's `brandColors`.
2. Make the foreground the "I." as vector art from `docs/design/brand/isocline-mark-ink.svg`, in OnAccent ink.
3. Let Icon Composer derive the iOS 26 dark, clear and tinted appearances.
4. Delete `xTlogoLetters.png` (and its test-target membership in pbxproj 40-53, after checking the tests don't need it).
5. Delete `App Icon.appiconset`, then set `INCLUDE_ALL_APPICON_ASSETS` to `NO` unless I2 needs it.

### I2 · Hue alternates (X36 / U2)

The free hue dial can't drive the icon, because alternate icons are prebuilt.

**Recommendation**
- One icon per `seed.stops` hue (`resolved.seedStops`), plus the default icon. These are the picker's quick stops too (ST8), so a stop and its icon always match.
- Ship them as additional `.icon` files listed under `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. Verify that Xcode 26 accepts Icon Composer files as alternates; if it doesn't, export the PNG sets.

### I3 · Stealth icon

The embossed "I." on neutral paper (S9 artwork), with no hue. It's offered as "Discreet" in the picker.

### I4 · Icon picker

Under Appearance:
- a grid of the icons, with "Match my hue" selecting the nearest stop to `seedHue`;
- `UIApplication.shared.setAlternateIconName(_:)`, guarded `#if !targetEnvironment(macCatalyst)`.

When the hue changes, don't switch the icon silently; iOS shows an alert on every change. Show a quiet "Update icon to match?" row instead.

---

## Web surfaces

### W1 · Native dark mode in browsers (done 2026-10-11, X4)

**Done**
- `tokens/isocline.css` (generated) sets:
  - `color-scheme: light dark` on `:root`;
  - dark values under `@media (prefers-color-scheme: dark)` for `:root:not([data-theme="light"])`;
  - `color-scheme: light` / `dark` on the forced `[data-theme]` overrides, so scrollbars and form controls match a forced theme too.
- `ISOCLINE_DESIGN_SYSTEM.html`:
  - `<meta name="color-scheme" content="light dark">`, so the browser paints the right canvas before CSS loads;
  - per-scheme `theme-color` metas holding the resolved paper, which tint the browser chrome. **The generator rewrites them** (`THEME_COLOR_PAGES` in `gen_isocline_tokens.py`), so they can't drift;
  - it follows system appearance changes live, and the Night paper button is a manual override that hands back to the system on the next click.

**Rule for every future web surface** (landing page, Isocline Research site):
1. Load `tokens/isocline.css`.
2. Add both metas and list the page in the generator's `THEME_COLOR_PAGES`, which keeps their values in sync.
3. Never set `data-theme` unless the reader asks.
4. Don't hard-code colors outside the tokens.

The app needs nothing equivalent: it already follows iOS appearance, since nothing calls `preferredColorScheme`. The Time tab remains the one intentionally always-night surface (T2).

---

## Crossroads register

**Blocking** means: decide before that phase starts. Everything else has a safe default (the recommendation) that can be revisited. **Decided crossroads leave this register** and live only in the [Decisions log](#decisions-log): X1, X4, X6, X7, X8, X9, X10, X12, X24, X35 and X36.

### Foundations

| # | Question | Options | Recommendation | Blocking |
|---|---|---|---|---|
| X2 | How do the 146 text-style alias call sites change? | **(a)** Repoint the aliases globally to Atkinson and Serif (F2 table): one commit, every screen shifts at once. **(b)** Leave the aliases as SF and migrate call sites to the new roles per screen. | **(a)**: prose is the neutral default, so nothing turns mono unexpectedly. Numbers and labels move to mono roles in the screen passes. | Phase 1 |
| X3 | Hairline width | **(a)** Token value: 1pt at 14% ink (CSS px ≈ pt). **(b)** Keep 0.5pt (1.5px @3x) and raise the alpha to about 22%. | **(a)**, checked on device. If it reads heavy, change **the token** (both platforms) rather than the Swift. | Phase 1 |
| X5 | `appBackground` vs `paper` | **(a)** Re-recipe `appBackground` in place and add a `paper` alias. **(b)** Rename all call sites. | **(a)** now, with the rename as a later mechanical PR. | — |

### Home

| # | Question | Options | Recommendation | Blocking |
|---|---|---|---|---|
| X11 | Phase strip vs a ~3-day chart window | **(a)** The strip shows the current dosing cycle and isn't x-aligned to the chart. **(b)** Widen the Home window to one full interval. **(c)** Place chips at chart x only for events inside the window. | **(a)**. `PKChartWindow` is tuned and tested per ester; widening it flattens the EV peak. Hide the strip for daily routes; use dates for intervals over 14 d. | Phase 3b |
| X13 | "Calibrated to N labs" | **(a)** Rewrite the copy to describe single-lab anchoring (H-D3). **(b)** Implement a multi-lab fit. | **(a)** now. (b) is an Isocline Research item; the PK paper should define the method first. | Phase 3a |
| X14 | The third dose state (overdue/missed) | **(a)** Fold it into the "Today" layout with a neutral past-tense chip and no red. **(b)** Keep a distinct missed card with an error badge (today). | **(a)**. "You missed a dose!" is on the spec's never-write list. | Phase 3b |
| X15 | One record-dose sheet? | **(a)** `QuickDoseSheet` only; delete `RecordDoseView`. **(b)** Keep a fast date-only path. | **(a)**. The fast path is clipped at `.height(300)` and skips sites. `QuickDoseSheet`'s summary step is already one tap to record. | Phase 3c |
| X16 | Which time does the dose section show? | **(a)** The time of `nextDoseDate` (last dose time + interval). **(b)** The dose-reminder time when reminders are on. **(c)** Day only. | **(b)** when reminders are on, otherwise **(c)** with a day-granularity chip (`TODAY`, `IN 2D`). A time derived from whenever the last dose happened to be logged is noise. | Phase 3b |
| X17 | Home journal section: what and where | **(a)** The latest entry, any date, with relative day; tap goes to the Journal tab. **(b)** Today's entry only (today), with tap opening the composer. | **(a)**, matching the spec. Writing happens from the Journal tab's ghost or top card, so there's one place to write. | — |
| X18 | Where do the insight sentence and safety note go? | **(a)** A mono status line under the provenance line (`AT TROUGH · WITHIN YOUR SET TROUGH`), plus the safety pill (X10) whose note shows on tap. **(b)** Keep a sentence row in the card. | **(a)**. The card holds only what you act on; the status describes what *is*. | — |
| X19 | Celebrations | **(a)** Remove confetti, glow and tier overlays, using a haptic plus the curve morph. **(b)** Keep a softened version. | **(a)**. The spec's principles exclude congratulation outright. | — |

### Journal

| # | Question | Options | Recommendation | Blocking |
|---|---|---|---|---|
| X20 | Several entries today | **(a)** Only the newest is a card; the other entries from today are flush. **(b)** All of today's entries are cards. | **(a)**, matching the spec: "the one card on the page is always now". | — |
| X21 | The Journal dose-history button | **(a)** Remove it; dose history lives in Labs & Records. **(b)** Move it to a toolbar icon. | **(a)**. One floating action per screen. | — |
| X22 | Edit support | **(a)** Add update and delete (J10). **(b)** Redefine the top card as "most recent", not editable. | **(a)**. It's small, and deletion is a basic data right. | Phase 3d |
| X23 | Mood colors | **(a)** Presence dots and glyphs only, with no valence color. **(b)** Keep the 3-palette mapping. | **(a)**. Grey for "sad" and accent for "happy" is a verdict. | — |

### Settings

| # | Question | Options | Recommendation | Blocking |
|---|---|---|---|---|
| X25 | Where reminders live | **(a)** Medication & Dose → Reminders: dose and journal times plus the notification layout. **(b)** A fifth gateway, "Reminders". **(c)** Privacy & Data. | **(a)**: one home for everything a reminder says and when. Privacy & Data doesn't duplicate it. | — |
| X26 | How to edit the profile | **(a)** An explicit "Edit" text button; the header itself isn't tappable. **(b)** Tap anywhere on the header (the Stitch chevron). | **(a)**. "What is" shouldn't be a control. | — |
| X27 | Reset row vs the single-accent rule | **(a)** A final card with no tile and a destructive red label. **(b)** An accent tile like the others. | **(a)**. The single-accent rule is about calm, and a destructive control should look different. | — |
| X28 | Footer claims | **(a)** Factual only (`ON-DEVICE`, `ICLOUD ON`). **(b)** The Stitch footer's `ENCRYPTED`. | **(a)**. Only the profile name and image are app-encrypted (`ProfileManager` + `SecurityManager`); the SwiftData store relies on iOS data protection. "Encrypted" would overclaim. | — |
| X29 | Lists and Forms on paper | **(a)** Restyle `List`/`Form` with `.paperList()`. **(b)** Rebuild them as ScrollView plus `paperCard`. | **(a)**: it keeps swipe actions, edit mode and VoiceOver behavior. | — |
| X30 | Adherence screen | **(a)** "Dose record": a calendar plus a plain count; drop the ring and the consecutive count. **(b)** Keep it as is. | **(a)**. | — |
| X31 | Row-title localization | **(a)** Switch the kit to `LocalizedStringResource` during ST4. **(b)** Leave titles verbatim (en only). | **(a)**: the cost is near zero while the kit is open. | — |

### Time, launch, navigation, notifications, icon

| # | Question | Options | Recommendation | Blocking |
|---|---|---|---|---|
| X32 | Time-tab glass and celebration | **(a)** Night card instead of glass, and a milestone line instead of the overlay. **(b)** Grandfather Time as-is. | **(a)**. | — |
| X33 | Launch screen color | **(a)** Static default-seed paper (light and dark). **(b)** Neutral paper with no hue. | **(a)**. | — |
| X34 | Mono caps tab labels | **(a)** Accept the system label font and amend spec §09. **(b)** Use `UITabBarAppearance` font overrides, which are fragile under iOS 26 glass. | **(a)**. | — |

---

## Unsupported features and suggested rewrites

These are spec items that the platform, the current data or the current model can't deliver as written. Each has a suggested rewrite.

| # | Spec item | Why it's unsupported | Suggested rewrite |
|---|---|---|---|
| U1 | Tab labels in mono caps (§09) | The iOS 26 tab bar is system-drawn. Label fonts aren't customizable in a supported way, and appearance overrides fight the glass bar. | Use system labels and keep the regular-weight SF Symbols. Amend §09 to "native labels; one icon family". |
| U2 | An icon that follows the live seed hue | Alternate icons must be prebuilt; the dial is continuous. | Eight hue stops plus default plus Discreet, with "Match my hue" picking the nearest stop (I2, X36). |
| U3 | `CALIBRATED TO 2 LABS` | The model applies a single α from the latest lab (`MedicationManager.swift:279-294`). | `CALIBRATED TO YOUR LAB OF 4 MAR` / `· 14 D AGO` (H-D3). A multi-lab fit is a research item. |
| U4 | Lab rings always visible on the Home curve | The Home window is about 3 days (EV), so labs drawn months apart are almost never in view. | In-window rings, with the provenance line naming the last lab, and the full ring history in the Labs chart (ST9). A window control can come later (X12). |
| U5 | A seven-weekday phase strip for everyone | Intervals range from 1 day (oral, cream) to 70 days (TU), and the chart window doesn't span a cycle. | A cycle strip from `cyclePhaseMarkers`: weekdays up to `PhaseStrip.weekdayMaxIntervalDays`, dates above that, hidden for daily routes, PEAK omitted when tmax isn't calibrated (H9). |
| U6 | `· SC` in the medication line | The data has no SC/IM distinction. `AdministrationMethod` is Injectable, Cream or Oral, and doses store the method only. | Use the method word: `· INJECTION`, `· CREAM`, `· ORAL`. If route depth matters later, add an optional `routeDepth` to `DoseRecord`. That's additive, so CloudKit-safe, but it's a schema change, so it's deferred. |
| U7 | The top journal card "editable" | There's no update or delete API, and detail is read-only. | Add `JournalManager.update/delete` and composer edit mode (J10, X22). |
| U8 | The card's meta line `08:30 · ESTRADIOL VALERATE 2.0 MG` | Entries aren't linked to doses. | Derive it from the taken dose on the same calendar day; show time only when there isn't one (J6). |
| U9 | "Sunday morning" | There's no time-of-day helper, and the phrase is English-specific. | `DayPeriod` plus a localized format string so locales can reorder it (J5). |
| U10 | Colored mood dots | The palette maps only 3 colors, and valence color is a verdict anyway. | Presence dots: dose filled, entry hollow; mood as glyph-plus-word chips (J2, J7, X23). |
| U11 | A stroke that sweeps "along its length" | SwiftUI has no path-length gradient. | A horizontal `LinearGradient`. x is time and monotonic, so it's visually identical on a function graph (H4). |
| U12 | A live countdown chip | `refreshState()` isn't time-driven and the view never re-renders on the clock. | A `TimelineView` around the chip (H11). Refresh the curve on `scenePhase` becoming active (H11). |
| U13 | A paper surface inside sheets | iOS 26 sheets are glass, and `presentationBackground(.clear)` is ignored. Painting paper inside fights the system. | Sheet glass *is* the card surface. Content inside is flush with hairlines and ghost outlines (S10). |
| U14 | The `ENCRYPTED` footer (Stitch) | Only the profile name and image are app-encrypted. | A factual footer: version and `SHAPED PROTOCOL.` (X28). |
| U15 | A paper fade under the floating pill | There's no first-class "fade to background" API; iOS 26 scroll-edge effects are system-styled. | Try `safeAreaBar(edge: .bottom)`. Fall back to a paper `LinearGradient`, which becomes a solid band under Reduce Transparency (J8). |
| U16 | The logo drawn in-app with no live text | The masters exist only as SVG, PGF and JS. | The mark generator emits Swift `Shape`s from the same outlines (F7). |
| U17 | "Every role scales with Dynamic Type" on a non-scrolling Home | The fixed ZStack Home collides at accessibility sizes. | An AX layout: Home scrolls, the curve has a fixed height and the card flows below (H1). |
| U18 | Range band with no user-set range | Clinical defaults aren't "yours"; labeling them `YOUR RANGE` would be false. | No band when `userTherapeuticTarget == nil`. If a reference is wanted, it's a separate, explicitly labeled feature (`TYPICAL TROUGH 100–200`), outside this transition. |
| U19 | Hiding the app's name or icon in a notification | iOS always draws the banner header with the app's display name and current icon; content can't change it. | Pair the Discreet layout with the Discreet icon (I3). The layout screen says so beside its preview (NT1). |
| U20 | A rich expanded notification, such as a mini curve on long-press | That needs a Notification Content Extension: a new target and an App Group to share level data. Neither exists. | Out of scope. Text layouts only (NT1). Revisit with widgets, which need the same App Group. |

---

## Required architectural supports (index)

New types and APIs by layer, so they can be scheduled into PRs.

| Layer | Addition | Element |
|---|---|---|
| Theme | `Theme.FontFace`, rewritten `Theme.Fonts`, `.eyebrow()`, `.monoLabel()`, `.statLabel()`, `ThemedFont` (Bold Text) | F2 |
| Theme | `ThemePalette.paper/card/safety/line/grid/inkMuted/inkFaint`, `ColorRecipe` absolute hue, `Theme.Line`, `Theme.Curve`, `Theme.Component`, `Radius.specimen`, increased-contrast alphas | F3 |
| Theme | Generated `IsoclineTokens.swift` (optional), generated `IsoclineMarkPaths.swift` | X7, F7 |
| Theme | `PaperCardModifier`, `GhostCardModifier`, `.paperList()`, `HairlineDivider(inset:)` | S1–S3, ST6 |
| Components | `ActionPill`, restyled `Pill`, `SectionHeader` (localized), `SettingsIconTile` (single accent), `AvatarView`, `IsoclineMarkView` (ink, hairline, emboss), `ThemeSpecimenView` + `SpecimenSample` | S4–S9, S11 |
| Constants | `PhaseStrip`, `Provenance`, `DayPeriod`, `DoseSection`, `HomeLayout`, `NotificationLayout` named constants | H-D0 |
| Medication | `DoseDayState` + `doseDayState()`, `cyclePhaseMarkers()`, `LevelProvenance`, `RangeBand`, `labPoints(in:)`, `siteSuggestion(routeClass:)`, `dose(onSameDayAs:)`, `doseDays(in:)` | H-D1–H-D6, J2, J6 |
| Journal | `JournalManager.update/delete`, remote-change reload, `JournalTopSlot`, `entryDays(in:)`, composer edit mode | H-D7, J3, J10 |
| Formatting | `MedicationDisplayFormatter`, `CountdownFormatter`, `DayPeriod`, provenance age buckets, `AnimatedCounter(formatter:)` | H2, H11, J5, H-D3 |
| Layout | `ReadoutBlockHeightKey`, `OverlayCardHeightKey`, `FlatGraphView(plotInsets:)` | H1 |
| App | `AppRouter` (tab selection, record-dose and journal routes), `Tab` API migration | N1, N2 |
| Settings | Gateway screens, `SettingsGatewayCard`, `SettingsGroup`, `AcknowledgementsView` | ST1, ST4, F8 |
| Notifications | `NotificationLayout`, `NotificationContentBuilder`, two dose categories, `NotificationLayoutView` with live preview | NT1 |
| Tooling | `lint_theme.sh` + baseline, generator extensions (paper/card expectations, Swift outputs) | F9, F3, F7 |

---

## Verification

### Unit tests to add (xTTests, run with `RunSomeTests`)

| Test file | Covers |
|---|---|
| `FontRegistrationTests` | Every `Theme.FontFace` resolves through `UIFont(name:)` |
| `IsoclineTokenParityTests` (extend) | paper, card and safety in light and dark at the default seed; light paper and card identical across the hue sweep |
| `ThemeEngineTests` (extend) | ink vs paper ≥ 4.5:1 (7:1 with increased contrast) across the hue sweep; line alpha with increased contrast |
| `DoseDayStateTests` | H-D1 cases, including TU, daily, DST and grace |
| `CyclePhaseMarkerTests` | H-D2 cases |
| `LevelProvenanceTests` | H-D3 bases and age buckets |
| `RangeBandTests` | nil when unset; bounds per X9 |
| `SiteSuggestionTests` | H-D6 rotation, avoid list, ties |
| `JournalManagerTests` | add, update and delete round trips; symptom name matching; `topSlot` |
| `NotificationContentTests` | every preset, custom subsets, own words (empty and maximum), dropped fields, "Reminder" placeholder |

### Visual checks per screen PR

Use `RenderPreview` plus a simulator pass. For each screen:
- light and dark;
- hues 0°, 90°, 180°, 270° and the default;
- Dynamic Type default, XXXL and AX3;
- Increase Contrast;
- Reduce Motion;
- Reduce Transparency;
- Bold Text;
- the SpoofProfile personas listed in J12;
- an unconfigured profile;
- a profile with no labs and one with labs.

### Lint gate

`tools/scripts/lint_theme.sh` (F9) shows no increase against the baseline, and the counts for each touched file go to zero. The per-phase targets live in F9.

---

## Appendix A · Fix-along defects found during the audit

These are pre-existing bugs that sit on redesign paths. Fix each one in the PR that touches its file.

| Defect | Location | Fixed in |
|---|---|---|
| "Today" a day early, on the wrong interval tier | `NextDoseRowView.swift:30-56` | H-D1 / H11 |
| Personal-target toggle and values never loaded | `SettingsView.swift:151-168` | ST7 |
| `pendingRoute` never consumed | `NotificationManager.swift:66, 343-366` | N2 |
| `RecordDoseView` graphical picker clipped at `.height(300)` | `NextDoseRowView.swift:72-75` | H13 (deleted) |
| Nested `NavigationStack`s in pushed screens | `ProfileEditorView.swift:22`, `AppLockSettingsView.swift:51`, `PreferredZonesEditorView` | ST2, ST6 |
| AppLock settings discarded on swipe-back | `AppLockSettingsView.swift:92-99, 239-243` | ST6 |
| Lock subtitle shown when the lock is off | `SettingsView+Sections.swift:552-556` | ST4 |
| Version hard-coded "0.9" | `SettingsView+Sections.swift:568` | F8 |
| iCloud toggle missing tint | `SettingsView+Sections.swift:471-490` | ST4 |
| Reminder subtitles not localized | `SettingsView+Helpers.swift:133-144` | ST5 |
| Palette not reset after Reset App Data | `SettingsView.swift:205` / `ThemeManager` | F5 |
| Contrast observer never removed | `ThemeManager.swift:369-374` | F5 |
| Journal cache ignores CloudKit remote changes | `JournalManager.swift` | H-D7 |
| `Symptom` UUIDs regenerate per launch | `JournalModels.swift:102-111` | J10 |
| Seeded journal entries at midnight, with no symptoms | `SpoofProfile.swift:634-657, 640-645` | J12 |
| `JournalLayoutTest` isn't a test | `xTTests/JournalLayoutTest.swift` | J12 |
| `AnimatedCounter` not locale-grouped | `Motion.swift:111-136` | H2 |
| `FlatGraphView` header says non-interactive | `FlatGraphView.swift:10-11` | H4 |
| No-op `onChange(peakCeiling)` | `FlatGraphView.swift:169` | H4 |
| `BloodTestRecord.calibrationFactor` documented as transient but persisted | `Models/BloodTestRecord.swift` | Comment fix, or add `@Transient` (would need a migration check) |
| Entry-count string comment says "Tenure badge" | `Localizable.xcstrings` (~L388) | J1 (key retired) |
| Stale `tabBarMinimizeBehavior` comment | `MainTabView.swift:39` | N1 |
| Dead pre-iOS 26 glass fallback | `Theme.swift:321-334` | S1 |
| Duplicate 984 KB icon PNG | `App Icon.appiconset` | I1 |
| Medication named on the lock screen | `NotificationManager.swift:282-293` | NT1 |
| Hidden-preview placeholder says "Dose reminder" | `NotificationManager.swift:466` | NT1 |

## Appendix B · Token to Swift mapping

The "after" column names the Swift home of each token group. Values stay in the tokens: resolved colors in `resolved`, everything else in its group. If X7 is adopted, the numeric groups are generated into Swift.

| Token (`isocline.tokens.json`) | Swift today | Swift after |
|---|---|---|
| `recipes.paper` | `ThemePalette.appBackground` (.985/.008 · .05/.010) | `appBackground` = paper recipe (absolute hue by day); `paper` alias. Needs `absoluteHue` in `ColorRecipe` (F3). |
| `recipes.card` | `cardSurface` (appBackground × .8) | `cardSurface` = card recipe (opaque); `card` alias |
| `recipes.ink` | `textPrimary` (repaired vs appBackground) | `textPrimary` (repaired vs paper) |
| `recipes.safety` | `Theme.Colors.error` = `Color.red` (static) | `safety` palette field; `error` accessor kept |
| `recipes.onAccent` | `OnAccentPalette.primary` (repaired vs brand stops) | Unchanged for now. Reconcile the two recipes later; the web uses the token. |
| `recipes.accent / accent2 / levelLow / levelHigh` | same fields | unchanged (parity-tested) |
| `inkAlpha.*` | `textSecondary` .6, `textTertiary` .3, `border` (.94 L × .2), `Graph.gridLine / yAxisLabel` | `muted`, `faint`, `line`, `grid`, `ylab` (vs paper) |
| `inkAlphaIncreasedContrast.*` | — | Swapped in when `increasedContrast` is on (F3) |
| `fixed.success` | `successBrand` (reference lines) | retired from the chart (H5); delete if it has no callers |
| `fixed.sage` | — | a secondary series color when one is needed |
| `line.*` | `hairlineWidth` 0.5; stroke 1.8 literal | `Theme.Line.*` |
| `curve.fill / glow / nowPoint / labPoint / rangeBand` | literals in `FlatGraphView.swift` (fill .42; halo .22 with blur; dashed reference lines) | One `Theme.Curve` namespace read by H4–H7 |
| `components.*` (tile, avatar, actionPill, floatingFade, specimen) | literals spread across `SettingsRowKit`, the header, `AccentButton`, `JournalView` | `Theme.Component.*`, read by S4, S7, S8, J8, S11 |
| `type.roles.*`, `type.aliases.*` | `Theme.Fonts.*` (system) | `Font.custom(…, relativeTo:)` per F2 |
| `radius.* / spacing.*` | `Theme.Radius/Spacing` (same values; names differ, e.g. `tiny`=6, `row`=10, `section`=28, `jumbo`=32; no `specimen` yet) | Add `Radius.specimen`; otherwise unchanged; optionally generated (X7) |
| `seed.stops` → `resolved.seedStops` | — | The picker's quick stops (ST8) and the alternate icons (I2) |
| `logo.*` (incl. `logo.emboss`) | — | `IsoclineMarkPaths.swift` and `IsoclineMarkView` (F7, S9). The mark builder and the spec page already read `logo.emboss`. Minimums are enforced by callers. |
