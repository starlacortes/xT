# Time Tab — Card Personalization System

Status: Spec (draft, pending review). Defines how the region card
selects what to say for a given user at a given month.

Companion documents: `TIME_TIERS_DESIGN.md` (tenure model),
`TIME_REGION_COPY.md` (authored copy + clinical sign-off),
`TIME_IMPLEMENTATION_PLAN.md` (sequencing).

Surfaces affected: `TimeRegionDetailView`, `TimeBodyExplorerView`,
`TimeBodyRegions`, `TimeContentData`.

---

## 1. The problem, measured

Take the card an estrogen user sees at month 10 when they tap Abdomen.
It renders five blocks:

| Block | Source | Words | Specific to this month? | Specific to this region? |
|-------|--------|-------|-------------------------|--------------------------|
| Phase label | `phaseLabel(at:)` | 4 | no | no |
| Hero | `monthFocus[9...11]` | 19 | band-level | yes |
| About this region | `overview` | 52 | no | yes |
| Your timeline | `timelineTextForBody(tier:)` | 24 | tier-level | no |
| What to expect | `whatToExpectForBody(tier:)` | 26 | tier-level | no |

**121 words, of which 19 are specific to month 10.** The other 102 are
identical at month 9, month 11, and — for the bottom 50 — identical on
the Hips, Thighs and Glutes cards too.

Four structural faults produce this:

1. **The band grid is global, not regional.** All 18 regions share the
   same `monthFocus` boundaries (`1-2, 3-5, 6-8, 9-11, 12-17, 18-23,
   24-35, ...`) even though their `startMonth`/`peakMonth`/`completeMonth`
   differ by years. The copy cadence was authored on a calendar, not on
   each region's biology.

2. **One deep dive serves four regions.** `bodySystemKey(for:)` maps
   E hips, thighs, glutes and abdomen all to `.bodyShape`, and T chest,
   thighs, hips and glutes all to `.muscleStrength`. Four cards, one
   bottom half. E chest, T abdomen and the T mind card map to `nil` and
   get no bottom half at all — so the breast-tissue card, arguably the
   most-opened card in the app, is the shortest one.

3. **Two clocks are stacked without reconciliation.** The header, phase
   label and hero run on the *region's* clock. Everything below runs on
   the user's global `TenureTier`. Nothing tells the reader these are
   different measurements.

4. **The long tail is thin.** Months 60-240 — fifteen years, and the
   fastest-growing segment of the user base — get 5 authored bands.
   Months 0-59 get 9.

Two further observations:

- `phaseLabel` says `Active · peak ahead` and `Maturing · peak passed`.
  Both orient the reader to a moment that is not now. The fourth state,
  `Established month 61+`, interpolates the user's *current* month, so it
  reads "month 62+" next month — restating where they are, not when the
  region settled. The header already shows tenure; this is duplication
  wearing a clinical label.

- `TimeBodySystemDetail.scienceText` holds **1,005 words** of
  pathway-level prose across 8 blocks. It is authored, it is asserted
  non-empty in `TenureTierTests`, and it is never rendered.

---

## 2. Principle

> The card answers one question: **what is my body doing right now?**
> When the honest answer is "the same as last month," it answers with
> something the reader did not already know rather than repeating
> itself.

Three rules follow:

- **General context is not standing content.** A region's `overview`
  earns space once — before that region has started. After that, the
  reader knows what their chest is.
- **Every slot on the card is specific to this region.** Nothing shared
  across four cards.
- **No two consecutive months render the same card.** This is a testable
  invariant, not an aspiration. See §6.

---

## 3. One context object

Today the card is a pure function of `(medication, activeMonthsOnHRT)`.
Every other signal the engine computes — `currentLevel`, `adherenceRate`,
`cyclePosition`, `screeningLog` — is dropped before rendering, and
`TimeBodyExplorerView` builds a throwaway `minimalEngine` with those
fields set to `nil` purely to reach `bodySystemDetail`.

Replace both with one value threaded from the explorer:

```swift
struct JourneyContext {
    let track: HormoneTrack        // .estrogen | .testosterone
    let month: Int                 // activeMonthsOnHRT
    let tier: TenureTier           // derived, not stored separately
    let method: String?            // "Injectable", "Oral", ...
    let ageAtStart: Int?           // MedicationManager.ageAtHRTStart
    let adherence: Double?         // 0...1
    let hasLabs: Bool              // any recorded level
}
```

`minimalEngine` is deleted. Any future signal has exactly one place to
enter, and the card's inputs become visible in one type instead of
inferred from six call sites.

**Note on `months`:** `TimeHeroHeader` reads `monthsOnHRT` while the
explorer reads `activeMonthsOnHRT`. These disagree for any user with a
dosing gap. `JourneyContext.month` is `activeMonthsOnHRT`; the header
must be moved onto the same value or the two numbers will keep
contradicting each other on screen.

---

## 4. Phase — present tense only

Replace the four `phaseLabel` strings:

```swift
enum RegionPhase {
    case pending      // month < startMonth
    case developing   // month < peakMonth
    case refining     // month < completeMonth
    case settled      // month >= completeMonth
}
```

| Phase | Label | Was |
|-------|-------|-----|
| `pending` | `Begins month 3` | `Begins month 3` |
| `developing` | `Developing` | `Active · peak ahead` |
| `refining` | `Refining` | `Maturing · peak passed` |
| `settled` | `Settled` | `Established month 61+` |

Peak language is removed. The label now describes the tissue's present
state and nothing else. `peakMonth` stays in the model — it still drives
change rate (§5) — it just stops being shown to the reader.

---

## 5. Change rate drives what the card says

```swift
enum ChangeRate { case fast, moderate, slow, steady }
```

Authored per band where the biology warrants it, with this derivation as
the default:

| Condition | Rate |
|-----------|------|
| `phase == .pending` | `.slow` |
| within ±25% of `peakMonth` | `.fast` |
| `phase == .developing` | `.moderate` |
| `phase == .refining` | `.slow` |
| `phase == .settled` | `.steady` |

Rate does not appear on the card. It selects **which bank the second
slot draws from** — the mechanism that answers the brief.

---

## 6. Card slots

Four slots. One is unconditional.

| Slot | Shown when | Cap | Content |
|------|-----------|-----|---------|
| **NOW** | always | 2 sentences / 34 words | What this tissue is doing this month |
| **INSIGHT** | always | 2 sentences / 30 words | Mechanism when moving, fact when not |
| **NEXT** | a marker lies within 24 months | 1 sentence / 20 words | The next named landmark and roughly when |
| **ABOUT** | `phase == .pending` only | 2 sentences / 40 words | The region's `overview` |

`Your timeline`, `What to expect` and `Long-term` are **removed**. They
are the source of the duplicated bottom halves and the unreconciled
second clock. Their genuinely useful content — bone density at 5+ years,
DEXA, resistance training, screening cadence — migrates into
region-specific NOW and FACT bands at the months where it applies.

### NOW — banded, on the region's own clock

`monthFocus` stays, but the band grid is **re-cut per region** against
that region's `startMonth`/`peakMonth`/`completeMonth`: dense where the
region is moving, coarse where it is not. E Abdomen (3/12/24) gets bands
at `3, 4-5, 6-7, 8-9, 10-11, 12-13, 14-17, 18-23, 24-35, ...`. E Chest
(1/18/60), which moves for five years, gets a different grid entirely.

### INSIGHT — the variance mechanism

Two banks, one slot:

```swift
enum InsightBank { case mechanism, fact }

// rate .fast / .moderate  → .mechanism
// rate .slow / .steady    → .fact
```

- **MECHANISM** — the pathway producing the visible change. Receptors,
  enzymes, signal cascades. This is the register the user described:
  *"what the cells are doing, how the muscle is responding to the
  different chemical messengers."* Largely a re-cut of the existing
  `earlyText`/`midText`/`lateText` and the 1,005 unrendered `scienceText`
  words, which are already written in exactly this voice.

- **FACT** — a concrete, surprising, true thing about this region under
  this hormone. Comparative, historical, measured. Set in the same type
  at the same weight as every other slot, in reading order — **not** a
  callout, not a "Did you know", not an aside. It is the card's normal
  content for a month when the progression line has not moved.

Voice check, three drafts:

> Visceral fat carries roughly twice the density of estrogen receptors
> as subcutaneous fat. That is why the belly responds months before the
> hips do.

> Breast tissue is one of the few adult tissues that can still run a
> complete developmental program — the same ductal branching as
> endogenous puberty, on the same signal.

> Testosterone binds its receptor and the pair moves into the nucleus
> and stays for hours. That residence time is why muscle protein
> synthesis stays elevated long after the blood level has peaked.

### Selection — deterministic monthly rotation

Both banks use the same selector:

```swift
func entry(at month: Int, seed: Int) -> String? {
    let pool = entries.filter { $0.months.contains(month) }
    guard !pool.isEmpty else { return nil }
    return pool[abs(month &+ seed) % pool.count].text
}
```

`seed` is a stable FNV-1a hash of the region key computed at build time —
**not** `hashValue`, which is randomly seeded per process in Swift and
would reshuffle the card on every launch.

Properties:

- **Stable within a month.** Reopening the card does not reshuffle.
- **Rotates every month.** Months 10 and 11 draw different entries even
  where the NOW band is shared.
- **No persistence.** Pure function of `(month, region)`. Nothing to
  migrate, nothing to sync, identical on a reinstall.

### The invariant

> For every region and every month *m*, the card at *m* differs from the
> card at *m+1*.

Guaranteed when every eligible pool holds ≥2 entries; enforced at ≥4 by
test, which also gives a 4-month minimum before any entry recurs. Both
are unit-testable against the static data with no view layer involved:

```swift
@Test func consecutiveMonthsNeverMatch() // all 18 regions × months 0...240
@Test func everyPoolHasFourEntries()     // all 18 regions × months 0...240
```

---

## 7. Markers

```swift
struct RegionMarker {
    let month: Int      // typical, not promised
    let name: String    // "Tanner stage 4"
    let note: String    // one sentence
}
```

Markers do three jobs: they populate NEXT, they anchor the NOW copy in
the band that contains them, and they give the long-tail card named
endpoints it currently lacks. Tanner staging is referenced in E Chest
prose today but is not modelled, so nothing can be said about reaching —
or not reaching — stage 5.

NEXT is suppressed when `phase == .settled` or when the nearest marker
is more than 24 months out. A card with nothing ahead of it says nothing
about what is ahead of it.

---

## 8. The 60+ build-out

Months 60-240 currently hold 5 bands per region. Replace with 8, and
change what they are *about*: past `completeMonth` the honest subject is
no longer development but **maintenance biology** — what the hormone is
actively holding, what reverses without it, and what the follow-up
literature actually covers.

| Band | Frame |
|------|-------|
| 60-71 | Development complete — what "complete" means structurally |
| 72-83 | What the hormone is actively maintaining |
| 84-95 | What reverses without it, and over what timescale |
| 96-119 | Screening that becomes age-appropriate at this tenure |
| 120-143 | Decade markers; what the longitudinal cohorts show |
| 144-179 | Bone, metabolic and cardiovascular picture at 12-15 years |
| 180-239 | 15-20 years — the edge of published follow-up |
| 240+ | Beyond the literature: what is known, what is not |

Because rate is `.steady` throughout this range, the INSIGHT slot draws
from the fact bank nearly every month. **The long-tail user is the
heaviest consumer of the fact bank** — which sets its sizing (§10).

Content owed, by region:

- **E Chest** — Tanner stage 5 as a named endpoint; that a documented
  minority plateau at stage 3-4 and that this is a recognised outcome
  rather than a failure; mammographic density; that the tissue is
  estrogen-dependent rather than permanent.
- **E body regions** — bone mineral density as the clinically primary
  measure past 5 years; estrogen as its principal regulator; DEXA
  cadence; that BMD here is *maintained*, not built.
- **E mind regions** — the longitudinal cognitive cohorts and what they
  do and do not establish.
- **T chest / body** — terminal hair density, the one change still
  progressing past 60 months; the muscle-mass ceiling and its
  training-dependence; hematocrit at long tenure.
- **T mind regions** — the settled amygdala/PFC state and what the
  short follow-up window permits saying.

---

## 9. Voice rules

Enforceable, and enforced — see the lint test in §10.

- ≤2 sentences per slot. ≤34 words per slot. ≤24 words per sentence.
- ≤1 em-dash per slot. (Current corpus: 120 across 360 strings.)
- Lead with the tissue, not the reader. "Ductal tissue is branching,"
  not "You may notice your breasts changing."
- One hedge per sentence. `typically` **or** `may`, never both.
- `many people report` is never the opening clause. It appears second,
  and only where the experience genuinely varies between people.
- Present tense in NOW, MECHANISM and FACT. Future tense only in NEXT.
- No exclamation marks, no "fun fact", no parenthetical asides.

Net effect on the month-10 Abdomen card:

**Before — 121 words, 19 of them specific to this month**

> ABDOMEN · ACTIVE · PEAK AHEAD
> The android-to-gynoid shift in abdominal fat is well underway. Combined with hip gains, the waist-to-hip ratio is changing noticeably.
> ABOUT THIS REGION — While estrogen builds fat at the hips and thighs, it simultaneously draws down androgenic visceral fat around the abdominal organs — reversing the android fat pattern. This belly softening is often one of the earliest externally visible changes because visceral fat responds more quickly than the slower gynoid deposition at the hips.
> YOUR TIMELINE — Months 6-12: Waist-to-hip ratio begins shifting noticeably. Upper body muscle loss contributes to a narrower shoulder appearance.
> WHAT TO EXPECT — Fat redistribution is among the slowest changes, typically measured in years rather than months. Weight cycling can accelerate it, but redistribution proceeds without it.

**After — 52 words, all specific to this region and month**

> ABDOMEN · DEVELOPING
> The android-to-gynoid shift is well underway. Your waist-to-hip ratio is moving faster this month than it will at any later point.
> Lipoprotein lipase activity is falling in visceral fat and rising in gluteofemoral depots. That enzyme switch is the change, at the cellular level.
> Visceral reduction is largely complete around month 12.

At month 11 the first block is unchanged — the biology has not moved —
and the second draws the next mechanism entry. Different card, honestly
so.

---

## 10. Content inventory owed

| Item | Count | Notes |
|------|-------|-------|
| NOW bands, re-cut 0-59 | 18 regions × ~9 | Re-cut and trimmed from existing `monthFocus` |
| NOW bands, 60-240 | 18 × 8 = 144 | 90 net new (replaces 5 per region) |
| Mechanism entries | 18 × 4 = 72 | Largely re-cut from `earlyText`/`midText`/`lateText` + 1,005 words of unrendered `scienceText` |
| Fact entries | 18 × 8 = 144 | Net new. The real writing job. |
| Markers | ~4 per region = 72 | Tanner stages, receptor saturation, ductal-lobular completion, BMD plateau |

Fact-bank sizing is set by the long-tail user: at `.steady` the fact
slot fires every month, so 8 entries per region gives an 8-month
non-repeat cycle for someone who opens the card monthly at year 6+.

---

## 11. Migration

| Phase | Work | New copy? |
|-------|------|-----------|
| A | `JourneyContext`, `RegionPhase`, delete `minimalEngine`, drop the deep-dive section, gate `overview` on `.pending` | none |
| B | Mechanism bank + selector + invariant tests | re-cut only |
| C | Re-cut NOW bands onto per-region grids | re-cut only |
| D | Fact bank | 144 strings |
| E | 60+ bands and markers | ~160 strings |
| F | Style lint test; extend `TIME_REGION_COPY.md` for clinical sign-off | none |

Phase A alone drops the standing card from 121 words to ~71 and removes
the duplicated bottom halves. Phases B and C make consecutive months
differ. D and E are the writing.

`TimeBodySystem`, `TimeBodySystemDetail`, `BodySystemKey` and
`bodySystemKey(for:)` are retired at the end of Phase A. `scienceText`
is harvested for Phase B before its type is deleted.
