# Time Tab — Tenure Tier Design

Status: Spec (post-review). This document defines the required content
and structure for users at different points on HRT, with particular
focus on multi-year users who currently collapse into a single "mature"
bucket.

Companion document: `TIME_IMPLEMENTATION_PLAN.md` (sequencing + change
inventory for the refactor).

---

## 1. The problem

`TenureTier` (in `xT/Models/TimeContent.swift:15`) currently has three
buckets:

| Tier        | Months    | Emoji | Role |
|-------------|-----------|-------|------|
| early       | 0 - 11    | seed  | "changes unlocking" |
| established | 12 - 23   | herb  | "settling" |
| mature      | 24+       | tree  | "maintenance" |

Two structural flaws:

1. **"Established" at 12 months is wrong.** Physiologically and
   experientially, nobody is established at one year. Fat redistribution
   runs a 2-3 year cell-turnover cycle; breast tissue continues
   developing for 5+ years on estrogen; voice continues settling into
   year 2-3 on T. Calling a 12-month user "established" sets a false
   expectation and flattens the most active period of change.

2. **"Mature" is a monolith.** Everything >= 24 months gets identical
   content. A 2-year user and a 10-year user see the same timeline text
   ("Year 2+"), the same milestones, the same body-system labels, and
   the same hormone-insight copy. There is no progression, no
   anniversary framing, and no long-term health monitoring that tracks
   actual elapsed time.

Principles for the redesign:
- Months 0-24 should have **more frequent updates** (this is the active
  discovery phase).
- 24+ should be split into **reasonable timeframes** rather than one
  bucket.
- Granularity is preferred over simplicity.
- 7 distinct emoji glyphs.

---

## 2. Tier structure (resolved)

Seven tiers. The active phase (0-24 months) gets four fine-grained tiers;
the long tail (24+ months) gets three year-banded tiers.

### 2a. Active phase (0-24 months) — frequent, change-focused

| Tier | Months  | Name       | Emoji   | Role |
|------|---------|------------|---------|------|
| T1   | 0-2     | Beginning  | seed    | First reactions; body is reacting, not yet adapting |
| T2   | 3-5     | Emerging   | sprout  | First visible/physical changes |
| T3   | 6-11    | In motion  | leaf    | Changes stacking; most rapid visible shift |
| T4   | 12-23   | Deepening  | herb    | Still changing, NOT established; slower, subtler shifts |

Notes:
- 12 months stays inside the "active" track. Renamed from "Established"
  to "Deepening" to avoid the false "you're done" signal.
- T1-T3 get distinct per-month-range timeline strings. T4 keeps a
  single 12-23 band.

### 2b. Long-term phase (24+ months) — banded, maintenance/health-focused

| Tier | Months   | Name     | Emoji | Role |
|------|----------|----------|-------|------|
| T5   | 24-59    | Settled  | tree  | Changes largely complete; shift from "what's changing" to "maintain + first long-term screenings" |
| T6   | 60-119   | Rooted   | tree-ring | 5-10 year: established maintenance, richer health surveillance |
| T7   | 120+     | Veteran  | mountain | 10+ year: long-term health is the whole story; anniversary/retrospective framing |

Notes:
- T5 absorbs the current "mature" tier but now has an end.
- T6/T7 are genuinely new tiers requiring authored content.
- 60 months (5 years) aligns with the existing breast-screening
  milestone (`TimeContent.swift:603`). 120 (10 years) is a natural
  decade marker.

### 2c. Layout decision (resolved)

T5-T7 share the mature **layout** (status dots, collapsed changes) and
differ only in copy + milestones. This keeps the view simple.

**Additional layout change: the progress bar is removed entirely.**
The progress bar concept is inappropriate for the Time tab across all
tiers. Body-system rows use status dots for every tier, not just mature.

---

## 3. What each section should show, by tier

The Time tab has these sections (current file `TimeView.swift`):
Hero header, Hormone row, Regimen timeline, Changes, Body systems,
Milestones. This matrix specifies what each section should surface per
tier. "Current" = what the code does today; "Gap" = what's missing.

### 3.1 Hero header (`TimeView.swift:137`)

| Tier | `timelineTitle` (current) | `timelineTitle` (proposed) |
|------|---------------------------|---------------------------|
| T1 (0-2) | "Day one - welcome" / "Early days" | keep |
| T2 (3-5) | "Things are shifting" | "You are shifting." |
| T3 (6-11) | "You're in full swing" | keep |
| T4 (12-23) | "A year and counting" | "Changes are deepening" |
| T5 (24-59) | "Deeply rooted" | "Deeper Changes" |
| T6 (60-119) | "Deeply rooted" (same) | "Maturity approaching" |
| T7 (120+) | "Deeply rooted" (same) | "Matured." |

Gap: `timelineTitle` (`TimeContent.swift:203`) saturates at month 24
with one `default` case. Needs per-tier strings for T5/T6/T7.
Gap: `timelineSubtitle` (`:214`) emits "Mature" for everything >= 24.
Needs T5/T6/T7 labels (e.g. "Settled", "Rooted", "Veteran").

**Subtitle addition:** add a small greyed-out parenthetical showing the
current time band, e.g. `Month 42 on HRT · 🌳 Settled (Year 2-5)`. This
gives the user continuous context about where they are in the arc
without crowding the title.

### 3.2 Hormone row (`TimeView.swift:252`, engine `TimeContent.swift:282`)

The `estrogenInsight`/`testosteroneInsight` functions
(`TimeContent.swift:306`, `:321`) accept a `months` parameter but **never
use it**. The `bodyDescription` is identical for a 3-month and a 10-year
user at the same level.

| Tier | What the insight should convey |
|------|---------------------------------|
| T1-T3 | "Levels are building; this is expected early on" framing for non-optimal ranges |
| T4 | "Levels should be stable by now; if not, check timing/dose" |
| T5 | "Maintenance range - no action needed" |
| T6 | "Long-term maintenance; your baseline is well known" |
| T7 | "Veteran range - trust your baseline; flag only meaningful drift" |

Gap: author tenure-aware `bodyDescription` strings per range x tier. This
is the single most condescending gap for long-term users today.

### 3.3 Changes (`TimeView.swift:316`, `:387`; engine `TimeContent.swift:250`)

`unlockedChanges` plateaus early: estrogen at month 9
(`TimeContent.swift:258`), testosterone at month 4 (`:269`). After
that, mature users see "All 6 active" forever.

| Tier | What changes should show |
|------|--------------------------|
| T1-T3 | Current unlock cadence (per-month). Keep. |
| T4 | All unlocked, but framed "still maturing" (e.g. breast tissue, voice) |
| T5 | "All established" + a short list of changes that *continue* past 2 years (breast dev yr 3-5, bone remodeling, voice final settle yr 3) |
| T6 | Drop the changes section or collapse to a single "All established" badge; the section stops being useful at 5 years |
| T7 | Replace with a retrospective "X changes over Y years" summary |

Gap: no later-emerging long-term changes are modeled. Need a
`longTermChanges` list (e.g. "Breast maturation continues", "Bone density
remodeling", "Voice final settling") unlocked at 24/36/60 months.

### 3.4 Body systems (`TimeView.swift:470`, detail `TimeBodyDetailView.swift`)

**The progress bar is removed entirely.** Every tier uses status dots
instead of progress bars. Today the progress bar only exists for
early/established (`showProgressBar: tenureTier != .mature` at
`TimeView.swift:509`); this change extends the dot treatment to all
tiers and deletes the progress-bar code path.

Every `*Timeline` / `*WhatToExpect` / `maintenanceNote` helper
(`TimeContent.swift:909-1091`) has one `case .mature` string that says
"Year 2+" generically.

| Tier | Body-system row | Detail page |
|------|-----------------|-------------|
| T1-T4 | Status dot (was: progress bar). | Timeline/what-to-expect (current, keep per-tier) |
| T5 | Status dot + "maintained for X months" sub-label. | "Year 2-5" copy |
| T6 | Status dot + "maintained X years" sub-label. | "Year 5-10" copy; add long-term screening note |
| T7 | Status dot + "X years established". | "10+ years" copy; health-monitoring is the primary content |

Gap: every `case .mature` in the timeline/what-to-expect/maintenance
helpers needs splitting into T5/T6/T7 variants.
Gap: no "maintained for X years" signal on the body-system row
(`TimeBodySystemRow` `:502`).

### 3.5 Milestones (`TimeView.swift:593`; engine `TimeContent.swift:541`)

Mature milestones are static (`TimeContent.swift:584-617` estrogen,
`:656-688` T). Same list at month 25 and month 120. Only the
breast-screening badge flips at month 60 (`:607`).

| Tier | Milestones |
|------|------------|
| T1-T4 | Current "COMING UP" milestones (12-mo, 24-mo, next blood test). Keep. |
| T5 | Current mature set (annual panel, DEXA q2y, breast screen after yr5, cardio annual). Keep but make DEXA/cardio track *actual last-scan date* when available. |
| T6 | Add: 5-year reassessment with provider; DEXA rescan due (every 2y from baseline); 10-year CVD risk re-score. Drop "After year 5" badges (they're now in the past). |
| T7 | Add: 10-year comprehensive review; consider age-appropriate cancer screenings (age x tenure); bone-density trend review. Anniversary milestone ("10 years on HRT"). |

Gap: milestones don't track *completion* or *last-done date*. Today only
the blood-test milestone uses dynamic scheduling (`bloodTestSchedulingText`).
DEXA/cardio/breast are static badges. Need a per-milestone "last done"
date (from a health-screening log) to flip badges from "due" to "done".
Gap: no anniversary / retrospective milestone. Long-term users lose the
narrative arc.

### 3.6 Regimen timeline (`TimeView.swift:680`)

`BloomRegimenTimelineRow` dumps every segment as a wall of text. A
5-year user with 12 regimen changes gets 12 lines.

| Tier | Regimen row |
|------|-------------|
| T1-T4 | Full segment list (current). Keep. |
| T5+ | Collapse to a summary ("X changes over Y years") with an expand-to-detail. Stop showing every segment inline. |

Gap: no compaction for long regimen histories.

### 3.7 Cross-cutting: adherence & cycle compass (`TimeView.swift:198`, `:222`)

Adherence and cycle-compass messaging is tenure-agnostic. A 5-year 95%
streak reads the same as 3-month 95%.

| Tier | Adherence framing |
|------|-------------------|
| T1-T4 | Current ("Adherence", percent). Keep. |
| T5+ | Add "X-month streak" or "veteran consistency" framing; the raw percent stops being informative after years. |

---

## 4. Data the engine needs but does not have

These are inputs the engine would need to support the multi-year content.
Some require new persistence; others already exist in `MedicationManager`
but aren't surfaced.

1. **Health screening log.** (In scope.) To flip milestones from "due"
   to "done", we need a record of when the user last had: blood panel,
   DEXA, breast screening, cardiovascular check, liver panel, CBC.
   Today only blood tests are tracked (`BloodTestRecord`). New model +
   capture flow needed.

2. **Therapy gaps.** (In scope.) `monthsOnHRT`
   (`MedicationManager.swift:438`) is a single `hrtStartDate` diff. A
   user who paused 6 months is counted as continuous. Long-term users
   are the most likely to have gaps. Need a gap-aware duration (total
   months on active therapy).

3. **Age at HRT start.** Milestones hedge with "especially if you
   started after age 30" (`TimeContent.swift:596`) but no age data
   drives it. Starting HRT at 20 vs 45 changes bone/cardio guidance
   materially. Need `ageAtStart` (derivable from DOB + hrtStartDate).

4. **`relativeDoseIntensity` for mature users.** Passed in
   (`TimeContent.swift:191`) but has zero effect on mature-tier
   content. Rather than forcing this on long-term users, make it a
   **user-facing settings toggle** (not in onboarding; in Settings).
   Users who want dose-intensity insights can enable them; others
   default to off. This respects that the metric stops being useful for
   veterans.

---

## 5. Inventory of missing multi-year logic (file refs)

Consolidated list of gaps, with file:line, for the implementation pass
that follows the rename.

| # | Gap | Location |
|---|-----|----------|
| 1 | `estrogenInsight`/`testosteroneInsight` ignore `months` param | `TimeContent.swift:306`, `:321` |
| 2 | `timelineTitle` saturates at month 24 | `TimeContent.swift:203` |
| 3 | `unlockedChanges` plateaus at month 9 (E) / 4 (T); no long-term changes | `TimeContent.swift:258`, `:269` |
| 4 | Body-system progress hard-caps at 1.0 for all mature; progress bar to be removed entirely | `TimeContent.swift:357`, `:366`, `:375`, `:400`, `:409`, `:418`; `TimeView.swift:509`, `:544-557` |
| 5 | Every `case .mature` timeline/what-to-expect/maintenance string is one "Year 2+" blob | `TimeContent.swift:909-1091` |
| 6 | Mature milestones static past month 60 (only breast badge flips) | `TimeContent.swift:584-617`, `:656-688` |
| 7 | No anniversary / retrospective content | (none) |
| 8 | Regimen timeline doesn't compact for long histories | `TimeView.swift:680` |
| 9 | Adherence/cycle messaging tenure-agnostic | `TimeView.swift:198`, `:222` |
| 10 | No age x tenure interaction; "after age 30" copy is hardcoded | `TimeContent.swift:596` |
| 11 | `monthsOnHRT` is single start-date diff; no gap handling | `MedicationManager.swift:438` |
| 12 | `relativeDoseIntensity` has no effect on mature content; make optional via settings | `TimeContent.swift:191` |
| 13 | No health-screening log; milestones can't flip to "done" | (new model needed) |
| 14 | `establishedNote` field and all its conditional display logic tied to old 3-tier model | `TimeContent.swift:84`; `TimeBodyDetailView.swift:67` |

---

## 6. Resolved decisions

| Question | Decision |
|----------|----------|
| Tier count | 7 (granular). |
| T6/T7 split | Keep both (60m and 120m boundaries). |
| Emoji strategy | 7 distinct glyphs. |
| T5-T7 layout | Share mature layout; differ only in copy + milestones. |
| Progress bar | Removed entirely from Time tab (all tiers use status dots). |
| Health screening log | In scope. |
| Therapy gaps | In scope. |
| Dose intensity for long-term | Optional, settings toggle (not onboarding). |

---

## 7. Open questions for the author

1. For T6/T7, who authors the clinical copy (DEXA cadence, CVD
   re-scoring, cancer screening)? Needs a review step before shipping.

---

## 8. Sequencing (summary — full detail in `TIME_IMPLEMENTATION_PLAN.md`)

1. Rename pass: `Bloom*` -> `Time*` (pure rename, no logic change).
2. Developer Area in Settings: Developer Mode gate, Sample (Jan test
   profile) toggle with data snapshot/restore, Research (Insights tab)
   toggle. Fixes the active data-safety bug where `SpoofProfile`
   auto-applies and destroys user data on every DEBUG launch.
3. Tier enum rework + layout changes (remove progress bar, add greyed
   time band in subtitle).
4. Data foundation: screening log, gap-aware duration, age at start,
   dose-intensity settings toggle.
5. Content authoring: per-tier strings for hero, hormones, changes,
   body systems.
6. Milestone completion tracking (depends on screening log).
7. Long-term UX: regimen compaction, adherence framing, anniversary.
