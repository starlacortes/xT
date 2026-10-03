# Time Tab — Implementation Plan

Companion to `TIME_TIERS_DESIGN.md` (the spec). This document is the
sequenced change inventory: every concrete thing that needs to change,
grouped into phases so foundational and interdependent work is built
together.

The plan assumes the rename happens first as a pure no-op pass, then
logic is layered on top of renamed types.

> Phase 2 (Developer Area) is inserted before the tier rework because
> it fixes an active data-safety bug (`SpoofProfile.applyIfNeeded()`
> destroys real user data on every DEBUG launch — see 2.1) and enables
> safe multi-tenure testing for every subsequent phase.

---

## Phase 0 — Pure rename: Bloom -> Time

Goal: every `Bloom*` symbol/file in the HRT feature becomes `Time*`,
with zero behavior change. Build must pass and the app must look
identical after this phase. This phase is committed as one reviewable
unit.

### 0.1 Rename owner files (three new files, three deletions)

Source of truth for what each file owns: `TIME_TIERS_DESIGN.md` and the
exhaustive audit (see "Files to rename" below).

| Old file | New file |
|----------|----------|
| `xT/Models/BloomContent.swift` | `xT/Models/TimeContent.swift` |
| `xT/Elements/Home/BloomView.swift` | `xT/Elements/Home/TimeView.swift` |
| `xT/Elements/Home/BloomBodyDetailView.swift` | `xT/Elements/Home/TimeBodyDetailView.swift` |

Xcode project uses synthesized file references (verified: `project.pbxproj`
contains zero `Bloom` entries), so moving/renaming these files on disk
and updating the `import`/type references is sufficient — no pbxproj
surgery required.

### 0.2 Rename types (in `TimeContent.swift`, formerly `BloomContent.swift`)

Pure identifier renames. Behavior unchanged. Do NOT alter tier logic
here (that is Phase 3).

| Old | New |
|-----|-----|
| `TenureTier` | `TenureTier` (keep name — it is the right concept) |
| `BloomBodySystem` | `TimeBodySystem` |
| `BloomBodySystemDetail` | `TimeBodySystemDetail` |
| `BloomMilestone` | `TimeMilestone` |
| `BloomChange` | `TimeChange` |
| `BloomHormoneInsight` | `TimeHormoneInsight` |
| `BloomPalette` (the local struct at `:118`) | `TimePalette` |
| `BloomContentEngine` | `TimeContentEngine` |

Note: `TenureTier` keeps its name. It is correct and decoupled from the
Bloom naming. Its *values* (early/established/mature) stay until Phase 3.

### 0.3 Rename palette + card modifier (in `xT/Theme/Theme.swift`)

| Old | New |
|-----|-----|
| `Theme.Colors.BloomPalette` | `Theme.Colors.TimePalette` |
| `Theme.Colors.Bloom` (namespace struct) | `Theme.Colors.Time` |
| `Theme.Colors.Bloom.mind/skin/body/cycle` | `Theme.Colors.Time.mind/skin/body/cycle` |
| `BloomCardModifier` | `TimeCardModifier` |
| `View.bloomCard(_:)` | `View.timeCard(_:)` |

Comment strings at `Theme.swift:42, 164, 200` updated to say "Time".

### 0.4 Rename views (in `TimeView.swift`, formerly `BloomView.swift`)

| Old | New |
|-----|-----|
| `BloomView` | `TimeView` |
| `BloomHeroHeader` | `TimeHeroHeader` |
| `BloomHormoneRow` | `TimeHormoneRow` |
| `BloomChangesRow` | `TimeChangesRow` |
| `CollapsibleChangesRow` | `CollapsibleChangesRow` (keep — already neutral) |
| `BloomBodySection` | `TimeBodySection` |
| `BloomBodySystemRow` | `TimeBodySystemRow` |
| `BloomMilestonesSection` | `TimeMilestonesSection` |
| `BloomMilestoneRow` | `TimeMilestoneRow` |
| `BloomRegimenTimelineRow` | `TimeRegimenTimelineRow` |

### 0.5 Rename detail view (in `TimeBodyDetailView.swift`)

| Old | New |
|-----|-----|
| `BloomBodyDetailView` | `TimeBodyDetailView` |

### 0.6 Update `bloomProgress` API (in `ResearchInsightsManager.swift`)

`bloomProgress` is a parameter name in `ResearchInsightsManager` at
lines 226, 322, 408 (function signatures) plus local consumers at
270-288, 422, and the `TrendPoint` construction at 444.

| Old | New |
|-----|-----|
| `bloomProgress: [String: Double]` (all params) | `timeProgress: [String: Double]` |

`TrendPoint.monthsOnHRT` and `InsightVariable.monthsOnHRT` keep their
names — they are correct, tenure-accurate, and not Bloom-specific.

### 0.7 Update `MainTabView.swift`

- `BloomView()` -> `TimeView()` at line 25. The tab label is already
  `"Time"` (line 27); no string change.

### 0.8 Update palette consumers (18 files)

These files reference `Theme.Colors.Bloom.*` only. Pure find/replace of
`Theme.Colors.Bloom` -> `Theme.Colors.Time` and (where applicable)
`.bloomCard(` -> `.timeCard(`. No logic change.

| File | Lines (approx) |
|------|-----------------|
| `xT/Elements/Home/GraphView.swift` | 218, 219, 228, 229, 398, 400, 439, 441 |
| `xT/Elements/Home/AdherenceView.swift` | 199, 207, 452 (palette only) |
| `xT/Elements/Home/UnifiedScheduleView.swift` | 151 |
| `xT/Elements/Home/Components/MainContentView.swift` | 98, 99, 111, 112, 296, 316 |
| `xT/Elements/Home/Components/LevelTrendCard.swift` | 41, 46, 107, 109 |
| `xT/Elements/Home/Components/DoseStreakCard.swift` | 33, 36, 38, 51 |
| `xT/Elements/Home/Components/MissedDosePrompt.swift` | 23, 27, 63, 67, 78, 82, 86, 103 |
| `xT/Elements/Journal/JournalView.swift` | 316, 321, 325, 329 |
| `xT/Elements/Journal/Components/JournalComposerView.swift` | 110, 114, 188, 193, 198, 218, 221, 226, 263, 264, 271, 272, 284, 286, 292, 314, 318 |
| `xT/Elements/Journal/Components/JournalCardView.swift` | 50 |
| `xT/Elements/Insights/LongitudinalTrendView.swift` | 23 (comment), 191-194, 254 (`bloomProgress` var), 265 |
| `xT/Elements/Insights/Components/TrendLineChart.swift` | 233, 244 |
| `xT/Elements/Insights/AuditSafetyView.swift` | 173 |
| `xT/Elements/Insights/CorrelationView.swift` | 181 (comment), 182-188, 202 |
| `xT/Elements/Settings/SettingsView.swift` | 182, 183, 198, 199, 212, 213, 231, 364, 389, 440, 441 |
| `xT/Elements/Settings/AppLockSettingsView.swift` | 117, 121, 154, 158, 300 |
| `xT/Elements/Onboarding/OnboardingView.swift` | 956 |
| `design-files/MainContentView.swift` | 82, 83, 95, 96, 280, 300 (not compiled; update for consistency) |

`bloomProgress` local var in `LongitudinalTrendView.swift:254` and
`CorrelationView.swift:182` is renamed `timeProgress` to match the
`ResearchInsightsManager` API change in 0.6.

### 0.9 Update file-header comments

The header comments in the three renamed files (`TimeContent.swift`,
`TimeView.swift`, `TimeBodyDetailView.swift`) and `Theme.swift` say
"Bloom". Update to "Time". No code change.

### 0.10 Namesake: leave `BloomEffect.swift` alone

`xT/Elements/Home/BloomEffect.swift` is a sparkle animation for
task-completion feedback. It is unrelated to the HRT feature. It
defines `BloomEffect`, `BloomEffectModifier`, `SparkleParticle`, and the
`View.bloomEffect(trigger:position:)` extension (which has zero call
sites). Do NOT rename it in this pass — it is a separate decision
whether to later rename it (e.g. to `SparkleBurstEffect.swift`) to avoid
future confusion.

### 0.11 Update non-source docs

- `TIME_TIERS_DESIGN.md`: update all `Bloom*` file/line references to
  `Time*` (post-rename line numbers may shift; re-verify).
- `xT-interactive-flow/index.html`: lines 353, 398, 499, 556 reference
  "Bloom" as the tab name. Update the user-facing strings to "Time".
  Line 463 references `BloomEffect` — leave (it refers to the namesake
  sparkle, which is unchanged).

### 0.12 Phase 0 verification

- `build_run_sim` succeeds.
- App launches; Time tab shows identical content to pre-rename.
- `grep -rn "Bloom" xT/` returns only: `BloomEffect.swift` (namesake),
  and any leftover in `design-files/` if not updated.
- `grep -rn "Theme.Colors.Bloom\|bloomCard\|bloomProgress\|BloomContentEngine\|BloomView" xT/` returns zero matches.

---

## Phase 1 — Verification checkpoint

No code changes. Run the app at a few tenures (use the onboarding
HRT-duration stepper or a SpoofProfile variant) to confirm the rename
didn't drift behavior. Screenshots at 0m, 8m, 18m, 30m, 70m if a spoof
profile supports it. Then proceed to Phase 2.

---

## Phase 2 — Developer Area (Settings)

Goal: add a Developer area to Settings with three controls — Developer
Mode (master gate), Sample (Jan test profile), and Research (Insights
tab visibility). This phase fixes an active data-safety bug and makes
multi-tenure testing safe for every later phase.

Context: today `SpoofProfile.applyIfNeeded()` runs unconditionally at
every DEBUG launch (`xTApp.swift:106`) and calls `resetAllManagers()`
(`SpoofProfile.swift:63`) which **deletes real user data** from
SwiftData and UserDefaults. This is the "developer functions bleeding
into the standard interface" problem. Phase 2 makes the spoof profile
opt-in, preserves user data while it is active, and restores it on
toggle-off.

All developer state is stored in **UserDefaults** (not SwiftData) so it
never syncs to iCloud or pollutes the production data model. All
developer UI is gated behind `#if DEBUG`.

### 2.1 Stop auto-applying SpoofProfile

- `xTApp.swift:104-107`: remove the unconditional
  `SpoofProfile.applyIfNeeded()` call from `init()`.
- The spoof profile only applies when the user explicitly enables the
  Sample toggle (see 2.4). This is the core fix for the data-loss bug.

### 2.2 Developer state (UserDefaults keys)

New helper `xT/Shared/DeveloperSettings.swift` (DEBUG-only) that owns
three UserDefaults-backed `@Published` flags:

| Key | Default | Purpose |
|-----|---------|---------|
| `dev.developerModeEnabled` | `false` | Master gate. When off, the two toggles below are visible but greyed out. |
| `dev.sampleProfileEnabled` | `false` | When on, Jan's test profile is loaded on next launch; user data is snapshotted and preserved. |
| `dev.researchTabVisible` | `false` | When on, the Insights tab appears in `MainTabView`. |

Expose as an `ObservableObject` (`DeveloperSettings`) with `@Published`
Bool properties and UserDefaults persistence. Inject via environment or
singleton (match the existing `MedicationManager.shared` pattern). Read
access is non-DEBUG-safe (returns `false` in RELEASE) so consumers like
`MainTabView` don't need `#if DEBUG`.

### 2.3 Data snapshot/restore for the Sample toggle

New `xT/Shared/ProfileSnapshot.swift` (DEBUG-only) that snapshots and
restores user data so enabling Jan does not destroy it:

- `static func snapshot()` — before loading Jan, save the user's real
  state: all SwiftData records (`DoseRecord`, `BloodTestRecord`,
  `JournalEntry`), the relevant `UserDefaults` keys (dose dates,
  medication selection, reminders, onboarding flag), and
  `ProfileManager` fields. Store to a side UserDefaults domain or a
  separate SwiftData store (decision at implementation time; recommend
  a side UserDefaults dictionary keyed under `dev.userSnapshot.*` plus a
  SwiftData snapshot container, since the main container is CloudKit-
  backed and shouldn't hold dev snapshots).
- `static func restore()` — on Sample toggle-off, clear Jan's data and
  rehydrate the user's snapshot into the live managers + SwiftData.
- Idempotency: if a snapshot already exists (Sample already enabled),
  do not re-snapshot; if no snapshot exists on restore, no-op (user
  had no data to preserve).

This is the "unload/reload" the user described — symbolic swap of the
active dataset, not a literal memory operation.

### 2.4 Sample toggle behavior (Jan test profile)

When the user turns the Sample toggle **on**:
1. If a user-data snapshot does not yet exist, call
   `ProfileSnapshot.snapshot()`.
2. Set `dev.sampleProfileEnabled = true`.
3. Show a confirmation alert: "Switch to the Jan test profile? Your
   data is preserved and will be restored when you turn this off. The
   app will quit." with "Cancel" / "Quit & Switch" buttons.
4. On "Quit & Switch": `ProfileSnapshot.snapshot()` (if needed),
   then `SpoofProfile.forceApply()` to populate Jan, then exit the app
   via `exit(0)` (or `UIApplication.shared.terminate` — note iOS
   doesn't cleanly support programmatic quit; `exit(0)` from a
   foreground app is the standard approach and the user explicitly
   asked for "quit the app").
5. On next launch, `xTApp.init()` checks
   `dev.sampleProfileEnabled`; if true, ensure Jan is loaded (idempotent
   — Jan was applied before quit, so this is a guard, not a re-apply).

When the user turns the Sample toggle **off**:
1. Call `ProfileSnapshot.restore()` to rehydrate the user's data.
2. Set `dev.sampleProfileEnabled = false`.
3. Clear Jan's data from the live managers + SwiftData (the restore
   overwrites it).
4. No app quit needed — the live managers update and SwiftUI
   re-renders. (If restore proves unreliable without a relaunch, fall
   back to the quit-and-relaunch pattern; decide at implementation
   time.)

### 2.5 Research toggle behavior (Insights tab visibility)

- `MainTabView.swift`: conditionally include `InsightsDashboardView`
  (tag 3) only when `DeveloperSettings.shared.researchTabVisible == true`.
  In RELEASE, the tab is always hidden (the flag defaults `false` and
  there is no UI to set it to `true` outside DEBUG).
- When the toggle flips, the tab appears/disappears on next render. No
  relaunch needed.

### 2.6 Developer Area UI in Settings

Add a new `settingsDeveloperSection` to `SettingsView.swift`, placed
after the About section (or as the final section). Structure:

```
Developer
  [Developer mode toggle]      <- master gate
  ---
  [Sample (Jan) toggle]         <- greyed out unless dev mode on
  ---
  [Research (Insights tab) toggle] <- greyed out unless dev mode on
```

Behavior:
- **Developer Mode toggle**: when the user flips it on, show a
  confirmation alert: "Would you like to enable developer mode?" with
  "Cancel" / "Enable" buttons. Only on "Enable" does
  `dev.developerModeEnabled` become `true`. Flipping off requires no
  confirmation (but should also turn off the two child toggles and, if
  Sample is on, trigger restore).
- **Sample and Research toggles**: always visible (so the user can see
  they exist), but `disabled(!developerModeEnabled)` — greyed out
  when Developer Mode is off. This matches the user's spec: "if
  developer mode is off, the user can still see the two toggles on that
  page, but the toggles are greyed out."
- Use `#if DEBUG` around the entire section so it does not ship in
  RELEASE. In RELEASE, none of this UI exists and the flags are
  hardwired `false`.

Use the existing `settingsSection` / `settingsRowContent` /
`settingsIconView` helpers for visual consistency. Icons: developer
mode = `wrench.and.screwdriver`, sample = `person.crop.circle.badge`
(or `person.fill.viewfinder`), research = `chart.xyaxis.line`.

### 2.7 Prevent dev-state bleed into standard UI

Audit every place a developer feature could leak into the standard
interface in RELEASE:
- `SpoofProfile` is already `#if DEBUG` (verified). Good.
- `DeveloperSettings` flags default `false` and have no RELEASE setter
  path (the Settings UI is `#if DEBUG`). Good.
- `MainTabView` reads `researchTabVisible` which is `false` in RELEASE.
  Good.
- The only residual risk is a stale `dev.sampleProfileEnabled = true`
  from a DEBUG build carrying over if the user installs a RELEASE build
  over it. Mitigate: `xTApp.init()` in RELEASE explicitly clears all
  `dev.*` keys and, if `dev.sampleProfileEnabled` was true, the
  RELEASE build has no `ProfileSnapshot` to restore from — so it
  should just reset to onboarding. Document this edge case.

### 2.8 Phase 2 verification

- RELEASE build: Developer section absent; Insights tab absent;
  `SpoofProfile` never runs; no `dev.*` keys persist.
- DEBUG build, dev mode off: toggles visible but greyed out; flipping
  dev mode on shows the confirmation alert; confirming enables the
  child toggles.
- DEBUG build, Sample on: alert offers quit; after quit + relaunch, Jan
  is loaded; user's prior data is in the snapshot.
- DEBUG build, Sample off: user's data is restored; Jan's data gone.
- DEBUG build, Research on: Insights tab appears; off: disappears.
- Toggling dev mode off while Sample is on triggers restore and clears
  the child toggles.

---

## Phase 3 — Tier enum rework + layout changes

Goal: replace the 3-tier `early/established/mature` model with the 7-tier
model, remove the progress bar entirely, and add the greyed time-band to
the subtitle. This phase touches the type system and the layout but
does NOT author new long-term clinical content (that is Phase 5) — it
wires the structure and reuses existing "mature" copy for T5 as a
placeholder.

### 3.1 Rework `TenureTier` enum (`TimeContent.swift:15`)

Replace the 3-case enum with a 7-case enum per the resolved spec:

```
T1 beginning  (0-2)
T2 emerging   (3-5)
T3 inMotion   (6-11)
T4 deepening  (12-23)
T5 settled    (24-59)
T6 rooted     (60-119)
T7 veteran   (120+)
```

- Update `init(months:)` switch.
- Update `statusEmoji` to 7 distinct glyphs (TBD with author; spec uses
  seed/sprout/leaf/herb/tree/tree-ring/mountain — confirm exact SF Symbols
  or emoji).
- Keep `var rawValue`-conformant names as the user-facing labels.

### 3.2 Update every tier switch in `TimeContent.swift`

Every `switch tier` / `switch tenureTier` block (see audit: ~120 lines
across `:217-520`, `:536-626`, `:656-688`, `:724-899`, `:909-1091`) must
be expanded from 3 cases to 7. For Phase 3:
- T1-T4: split the existing `early`/`established` strings across the
  new T1-T4 as appropriate (most existing copy keys on month ranges
  already, so this is mostly remapping the switch arms).
- T5: reuse the existing `mature` copy verbatim as the placeholder.
- T6/T7: temporarily alias to T5's copy with a TODO marker. Phase 5
  authors the real T6/T7 strings.

### 3.3 Remove the progress bar (layout change)

Per spec decision: progress bar is removed from the Time tab entirely.

- `TimeBodySystemRow` (was `BloomBodySystemRow`, `BloomView.swift:502`):
  delete `showProgressBar` (`:509`) and the entire `if showProgressBar {`
  GeometryReader block (`:544-557`). Always render the status dot
  (currently the `if !showProgressBar` branch at `:529`).
- `TimeContentEngine` body-system constructors: remove
  `progressFraction` from all `TimeBodySystem` initializers, or keep the
  field but stop using it for display. (Recommendation: drop the field
  to avoid dead state.)
- `TimeBodySystem` struct (was `BloomBodySystem`, `:39`): remove
  `progressFraction` and `progressLabel`-as-progress; keep
  `progressLabel` as a status label only.
- `TimeBodyDetailView` (was `BloomBodyDetailView`): the tier badge and
  tenure banner stay; no progress bar there to remove.

### 3.4 Add greyed time-band to subtitle

- `TimeContentEngine.timelineSubtitle` (`:214`): append a greyed
  parenthetical with the tier's time band, e.g.
  `"Month 42 on HRT · 🌳 Settled (Year 2-5)"`.
- `TimeHeroHeader` (was `BloomHeroHeader`, `:137`): render the
  parenthetical in `.secondary` opacity to visually subordinate it.

### 3.5 Update `timelineTitle` per the spec table

`TimeContentEngine.timelineTitle` (`:203`): replace the `default ->
"Deeply rooted"` saturation with per-tier strings:
- T2: "You are shifting."
- T4: "Changes are deepening"
- T5: "Deeper Changes"
- T6: "Maturity approaching"
- T7: "Matured."
(T1, T3 keep current strings.)

### 3.6 Update `changesSectionLabel`, `changesDefaultCollapsed`, `milestonesSectionLabel`

- `changesSectionLabel` (`:227`): map T1-T4 to "CHANGES UNLOCKED" /
  "CHANGES UNLOCKED" / "CHANGES UNLOCKED" / "CHANGES UNLOCKED" (keep
  current early/established semantics across the new T1-T4); T5 -> keep
  "ESTABLISHED CHANGES"; T6/T7 -> TBD in Phase 5 (collapse/retrospective).
- `changesDefaultCollapsed` (`:248`): `tier >= .settled` (T5+)
  collapses; T1-T4 expanded. Update the comparison for the new enum
  ordering (T5 and above).
- `milestonesSectionLabel` (`:534`): T1-T4 -> "COMING UP"; T5+ ->
  "LONG-TERM HEALTH".

### 3.7 Phase 3 verification

- Build passes.
- Spoof profile at 0m, 8m, 18m, 30m, 70m, 130m: each lands in the
  correct tier; subtitle shows correct time band; no progress bars
  render anywhere; T6/T7 display T5 placeholder copy (acceptable for
  this phase).
- No crash on the new switch arms (exhaustiveness).

---

## Phase 4 — Data foundation

Goal: build the inputs the engine needs for multi-year content. These
are interdependent with Phase 5 (content authoring) and must come first
because the content references them.

### 4.1 Health screening log (new model)

New file `xT/Models/ScreeningRecord.swift`:
- `struct ScreeningRecord: Identifiable, Codable` with `id`, `date`,
  `type: ScreeningType`, `notes: String?`.
- `enum ScreeningType: String, Codable` with cases: `bloodPanel`,
  `dexaScan`, `breastScreening`, `cardioCheck`, `liverPanel`, `cbc`,
  `other`.
- Persistence via the same mechanism as `BloodTestRecord` (check
  `MedicationManager` or a dedicated manager — confirm storage pattern
  during implementation).

New manager (or extend an existing one) to store/retrieve
`ScreeningRecord`s. Mirror the `BloodTestRecord` access pattern in
`MedicationManager` so the engine can read "last DEXA date" etc.

### 4.2 Gap-aware duration (`MedicationManager.swift:438`)

Replace `monthsOnHRT` (single start-date diff) with a gap-aware
computation. Options:
- Track explicit pause/resume dates (new model `TherapyGap`).
- Derive from dose history: count months with at least one active
  dose record.

Decision needed at implementation time: do we trust dose history for
gap inference, or add explicit pause/resume UX? The spec says gaps are
in scope; the capture method is an implementation decision. Recommend
dose-history inference first (no new UX), with explicit pause/resume as
a later enhancement if inference proves unreliable.

Expose both: `monthsOnHRT` (calendar span, for context) and
`activeMonthsOnHRT` (gap-aware, for tiering and content). Tier uses
`activeMonthsOnHRT`.

### 4.3 Age at HRT start

- Add `dateOfBirth: Date?` to the profile manager (check
  `ProfileManager` for an existing field; if absent, add it and a
  capture step in onboarding/settings).
- Compute `ageAtHRTStart: Int?` in `MedicationManager` from DOB +
  `hrtStartDate`.
- Surface to `TimeContentEngine` so milestones can branch on age.

### 4.4 Dose-intensity settings toggle

- Add a `UserPreferences` flag: `showDoseIntensityInsights: Bool`
  (default `false`).
- Settings UI: add a toggle under the Time/medication section. Not in
  onboarding.
- `TimeContentEngine` only surfaces `relativeDoseIntensity`-derived
  copy when the flag is on. For T5+, the toggle gates whether the
  metric appears at all (per spec: not forced on long-term users).

### 4.5 Wire new inputs into `TimeContentEngine`

Update the engine's initializer (`TimeContent.swift:178`) to accept:
- `activeMonthsOnHRT: Int` (replaces `months` for tiering)
- `ageAtStart: Int?`
- `screeningLog: ScreeningLog` (or a lightweight protocol the engine
  queries for "last done date" by type)
- `showDoseIntensity: Bool`

Keep `months` (calendar) available for display ("Month N on HRT").

### 4.6 Phase 4 verification

- Build passes.
- Onboarding still works; new fields persist.
- Engine reads the new inputs without crashing when they are nil
  (early users won't have screening logs).

---

## Phase 5 — Content authoring

Goal: replace T5/T6/T7 placeholder copy with real per-tier clinical
content, and author the long-term-specific sections. This is the largest
writing phase. Each sub-phase is independently reviewable.

### 5.1 Hormone insight, tenure-aware (`TimeContent.swift:306`, `:321`)

Author `bodyDescription` strings per hormone-range x tier. Use the
`months` parameter that is already passed but ignored today. Matrix
from spec section 3.2.

### 5.2 Body-system detail timeline/what-to-expect/maintenance

Split every `case .mature` (currently aliased to T5 in Phase 3) into
real T5/T6/T7 variants across all helpers:
- `timelineTextForMood/Skin/Body`, `cycleTimelineText`
  (`:909-953`)
- `whatToExpectForMood/Skin/Body`, `cycleWhatToExpect` (`:957-999`)
- `tVoiceTimeline`, `tSkinTimeline`, `tMuscleTimeline`,
  `cycleTimelineTextForT` (`:1003-1045`)
- `tVoiceWhatToExpect`, `tSkinWhatToExpect`, `tMuscleWhatToExpect`,
  `cycleWhatToExpectForT` (`:1049-1091`)
- `maintenanceNote` / `establishedNote` in `estrogenDetail` /
  `testosteroneDetail` (`:705-907`)

`establishedNote` (the T4-specific field at `:84`) may need renaming or
generalizing to `deepeningNote` to match the new tier name. Decide
during implementation.

### 5.3 Long-term changes list

Add `longTermChanges` to the engine. New changes unlocked at 24/36/60
months (breast maturation continues, bone remodeling, voice final
settle). Surface in the changes section for T5; collapse for T6;
retrospective summary for T7.

### 5.4 Milestones per tier with completion tracking

- T5: keep current mature set; wire DEXA/cardio/breast badges to the
  screening log from Phase 4.1 so they flip "due" -> "done" based on
  last-done date.
- T6: add 5-year reassessment, DEXA rescan (every 2y from baseline),
  10-year CVD risk re-score. Drop "After year 5" badges (now in past).
- T7: add 10-year comprehensive review, age-appropriate cancer
  screenings (uses `ageAtStart`), bone-density trend review, anniversary
  milestone.

### 5.5 Clinical copy review

Per open question in the spec, T6/T7 clinical copy (DEXA cadence, CVD
re-scoring, cancer screening) needs a medical review step before
shipping. Flag this as a blocking checkpoint at the end of 5.4.

### 5.6 Phase 5 verification

- Build passes.
- Spoof profile at 30m/70m/130m: each shows distinct, correct copy.
- Milestone badges flip correctly when a `ScreeningRecord` is added.
- No placeholder TODOs remain in shipped T6/T7 strings.

---

## Phase 6 — Long-term UX polish

Goal: the cross-cutting long-term UX that isn't clinical content.

### 6.1 Regimen compaction (`TimeView.swift:680`)

`TimeRegimenTimelineRow`: for T5+, collapse to a summary line ("X
changes over Y years") with an expand-to-detail. T1-T4 keep the full
list.

### 6.2 Adherence framing for veterans (`TimeView.swift:198`)

For T5+, replace/augment the raw adherence percent with "X-month streak"
or "veteran consistency" framing. T1-T4 keep current.

### 6.3 Anniversary / retrospective

Add an anniversary milestone and optional retrospective summary for
year milestones (especially T7's 10-year marker). May surface as a
hero-header flourish or a dedicated milestone card.

### 6.4 Phase 6 verification

- Build passes.
- Long-tenure spoof profile: regimen row is compact, adherence framing
  reads as veteran-appropriate, anniversary appears at year boundaries.

---

## Cross-cutting concerns

### Testing

There are no existing tests for Bloom/Time logic (verified: `xTTests/`
and `xTUITests/` have zero Bloom references). Consider adding:
- Unit tests for `TenureTier(months:)` boundary correctness (every tier
  boundary: 0, 3, 6, 12, 24, 60, 120 and the off-by-one cases).
- Unit tests for `TimeContentEngine` at representative tenures (0, 5,
  9, 18, 42, 70, 130 months) asserting tier, title, subtitle, and
  that no section crashes.
- A UI snapshot test at 3 tenures if the project has snapshot testing
  set up (check during Phase 3).

Tests can be added incrementally starting in Phase 3.

### Localization

All tenure-tied strings ("CHANGES UNLOCKED", "Year 2+", etc.) are
hardcoded string literals in `TimeContent.swift` and
`TimeBodyDetailView.swift` (verified: no `Localizable.strings` exists;
`xTLaunchScreen.xcstrings` has no Bloom refs). If localization is
planned, Phase 5 is the natural point to extract strings into a
catalog. Out of scope for this plan unless requested.

### `BloomEffect.swift` namesake

Left alone in Phase 0. Separate decision: rename to
`SparkleBurstEffect.swift` to avoid future confusion. Not required for
the Time refactor.

### Git history compaction

Per the user's request to compact history without data loss: the
design doc and this plan capture every change exhaustively. Each phase
is intended as one commit (or a small number). After Phase 0 and Phase 3
land, the intermediate "Bloom" history can be squashed if desired,
since the spec + plan preserve the rationale.

---

## File change summary (all phases)

### Files renamed (Phase 0)
- `xT/Models/BloomContent.swift` -> `xT/Models/TimeContent.swift`
- `xT/Elements/Home/BloomView.swift` -> `xT/Elements/Home/TimeView.swift`
- `xT/Elements/Home/BloomBodyDetailView.swift` -> `xT/Elements/Home/TimeBodyDetailView.swift`

### Files edited (Phase 0)
- `xT/Theme/Theme.swift`
- `xT/Elements/Home/MainTabView.swift`
- `xT/Managers/MedicationManager.swift` (header comment only at L31; internal consumer L1658)
- `xT/Managers/ResearchInsightsManager.swift` (`bloomProgress` -> `timeProgress`)
- 18 palette-consumer files (listed in 0.8)
- `design-files/MainContentView.swift` (non-compiled)
- `xT-interactive-flow/index.html` (non-compiled)
- `TIME_TIERS_DESIGN.md` (reference updates)

### Files created (Phase 2 — Developer Area)
- `xT/Shared/DeveloperSettings.swift` (DEBUG-only UserDefaults flags)
- `xT/Shared/ProfileSnapshot.swift` (DEBUG-only snapshot/restore)

### Files edited (Phase 2 — Developer Area)
- `xT/xTApp.swift` (remove unconditional `SpoofProfile.applyIfNeeded()`)
- `xT/Elements/Home/MainTabView.swift` (conditional Insights tab)
- `xT/Elements/Settings/SettingsView.swift` (Developer section UI)

### Files created (Phase 4 — Data foundation)
- `xT/Models/ScreeningRecord.swift`
- Possibly `xT/Managers/ScreeningManager.swift` (or extend existing manager)

### Files edited (Phase 3-6)
- `xT/Models/TimeContent.swift` (tier enum, all switches, content)
- `xT/Elements/Home/TimeView.swift` (progress bar removal, subtitle, regimen compaction, adherence framing)
- `xT/Elements/Home/TimeBodyDetailView.swift` (tier-aware display)
- `xT/Managers/MedicationManager.swift` (gap-aware duration, ageAtStart)
- `xT/Managers/ProfileManager.swift` (DOB, if missing) — verify field exists
- `xT/Models/UserPreferences.swift` (dose-intensity toggle)
- `xT/Elements/Settings/SettingsView.swift` (dose-intensity toggle UI)
- Onboarding (DOB capture, if missing) — verify

### Files left alone
- `xT/Elements/Home/BloomEffect.swift` (namesake sparkle animation)
- `xT/Elements/Timeline/TimelineView.swift` (separate photo-grid feature)

---

## Phase ordering and dependencies

```
Phase 0 (rename)
  |
  v
Phase 1 (verify rename) -- no code
  |
  v
Phase 2 (developer area) -- fixes data-safety bug; enables safe testing
  |
  v
Phase 3 (tier enum + layout) -- structure only, T6/T7 aliased
  |
  v
Phase 4 (data foundation) -- screening log, gaps, age, dose toggle
  |
  v
Phase 5 (content authoring) -- depends on Phase 4 inputs
  |
  v
Phase 6 (long-term UX polish) -- depends on Phase 5 content
```

Phase 2 must precede Phase 3+ because it fixes the active data-loss bug
(unconditional `SpoofProfile.applyIfNeeded()` in `xTApp.init`) and
provides the safe multi-tenure testing path (Jan profile toggle) that
every later phase relies on for verification. Phase 3 and Phase 4 are
largely independent and could partially overlap, but keeping them
sequential makes review easier. Phase 5 strictly depends on Phase 4
(content references the new inputs). Phase 6 depends on Phase 5 (it
polishes content-driven sections).
