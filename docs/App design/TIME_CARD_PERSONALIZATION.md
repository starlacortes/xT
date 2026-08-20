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

## 4. Phase — present tense, and two vocabularies

Replace the four `phaseLabel` strings:

```swift
enum RegionPhase {
    case pending      // month < startMonth
    case developing   // month < peakMonth
    case refining     // month < completeMonth
    case matured      // month >= completeMonth
}
```

Peak language is removed. The label describes the region's present state
and nothing else. `peakMonth` stays in the model — it still drives change
rate (§5) — it just stops being shown to the reader.

### Two vocabularies

A brain region does not *settle*; it adapts, and adaptation is an ongoing
process rather than a finished one. The phase enum is shared, but the
words it renders are not:

```swift
enum PhaseVocabulary { case tissue, neural }
```

| Phase | `.tissue` | `.neural` | Was |
|-------|-----------|-----------|-----|
| `pending` | `Begins month 3` | `Begins month 3` | `Begins month 3` |
| `developing` | `Developing` | `Adapting` | `Active · peak ahead` |
| `refining` | `Refining` | `Tuning` | `Maturing · peak passed` |
| `matured` | `Settled` | `Adapted` | `Established month 61+` |

The neural column is not invented for this spec — it is the vocabulary
the mind copy already uses. `TimeBodyRegions.mindRegions` currently
contains *"the amygdala is recalibrating"*, *"the PFC's adaptation"*,
*"hippocampal adaptation is in its later phase"*, *"fully adapted to the
estrogen-dominant neurochemical environment"* and *"subtle circuit-level
tuning"*. The labels now agree with the prose underneath them.

`Adapting → Adapted` deliberately shares a root: it reads as one process
at two stages, which is what neural adaptation is. The two states are 6
to 24 months apart depending on region, so no user sees both in a
session.

`vocabulary` is a stored property on `BodyRegion`, set once per array —
`.neural` for `mindRegions` and `mindRegionsT`, `.tissue` for
`bodyRegions` and `bodyRegionsT` — not derived at the call site.

### Why `settled` is not the enum case name either

`TenureTier.t5Settled` already has the rawValue `"Settled"`, and it
labels the *user's global tenure* at 24-59 months. A region phase
rendering the identical word next to it on the same card is precisely
the two-clocks confusion §1 identifies. The enum case is `matured`; only
the `.tissue` vocabulary renders the word "Settled", and it never
appears in the same view as a tier label.

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
| `phase == .matured` | `.steady` |

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
  different chemical messengers."* Drafted against the phase texts
  and the 1,005 unrendered `scienceText` words, which were already written
  in this voice. (The phase texts are gone as of Phase F; `scienceText`
  remains, still unrendered.)

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
static func select(from pool: [InsightEntry], month: Int, seed: Int) -> String? {
    let eligible = pool.filter { $0.months.contains(month) }
    guard !eligible.isEmpty else { return nil }
    return eligible[(max(0, month) &+ seed) % eligible.count].text
}
```

`seed` is a stable FNV-1a hash over the region identifier (`"e.abdomen"`,
`"t.chest"`) — **not** `hashValue`, which is randomly seeded per process in
Swift and would reshuffle the card on every launch. A test pins two seeds to
literal constants so that substitution fails loudly rather than silently.

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
@Test func consecutiveMonthsNeverMatch()     // all 18 regions × months 0...240
@Test func everyPoolHasFourEntries()         // all 18 regions × months 0...240
@Test func selectionIsStableWithinAMonth()   // reopening never reshuffles
@Test func seedIsProcessIndependent()        // seeds pinned to constants
```

Both hold on the shipped data: the eligible pool is five entries at every
month for every region, and no region's card repeats across any month
boundary in 0...240.

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

NEXT is suppressed when `phase == .matured` or when the nearest marker
is more than 24 months out. A card with nothing ahead of it says nothing
about what is ahead of it.

---

## 8. The 60+ build-out

Months 60-240 currently hold 5 bands per region. Replace with 8, and
change what they are *about*: past `completeMonth` the subject is
**maintenance biology** — what the hormone is doing in this tissue right
now, what depends on it, and what the follow-up literature covers.

### Maintenance is work, not the absence of work

The long-tail card's failure mode is not inaccuracy. It is writing
"development is complete" and leaving the reader with the sense that the
interesting part is behind them. That framing is also imprecise:
maintained tissue is not tissue that stopped. Adipose distribution, bone
mineral density, breast tissue and neural adaptation are each held in
place by a signal the body is reading continuously, and each would move
without it. The copy's job at year six is to say what that ongoing work
*is*, not to certify that an earlier phase ended.

So the long tail is written in the **present active**: what the hormone
is doing, what depends on it, what is being measured. See the two rules
this adds in §9 — no terminus framing, and shared-physiology facts.

| Band | Frame |
|------|-------|
| 60-71 | What holds this tissue now — maintenance as continuous signalling |
| 72-83 | The daily work: what the hormone is doing in this tissue every day |
| 84-95 | What the signal is load-bearing for, and over what timescale |
| 96-119 | The measures and screening that become the relevant ones at this tenure |
| 120-143 | A decade in: what the longitudinal cohorts show |
| 144-179 | Bone, metabolic and cardiovascular picture at 12-15 years |
| 180-239 | 15-20 years — the edge of published follow-up |
| 240+ | Past the literature: what is known, what is not, what is being studied |

Because rate is `.steady` throughout this range, the INSIGHT slot draws
from the fact bank nearly every month. **The long-tail user is the
heaviest consumer of the fact bank** — which sets its sizing (§10) and
makes the fact bank, not the NOW band, the main reason a six-year user
opens the card at all.

Content owed, by region:

- **E Chest** — Tanner stage 5 as a named endpoint; that a documented
  minority plateau at stage 3-4 and that this is a recognised outcome
  rather than a failure; mammographic density and how it reads across
  the decades; that the tissue is estrogen-dependent, which is a
  statement about what estradiol is doing rather than about what it
  stopped doing.
- **E body regions** — bone mineral density as the clinically primary
  measure past 5 years; estrogen as its principal regulator; how the
  remodelling cycle works and where estradiol sets its balance point;
  DEXA cadence.
- **E mind regions** — the longitudinal cognitive cohorts and what they
  do and do not establish; ongoing BDNF signalling as an active process.
- **T chest / body** — terminal hair density, still progressing past 60
  months; the muscle-mass ceiling and its training-dependence;
  hematocrit at long tenure and why it is watched.
- **T mind regions** — the adapted amygdala/PFC state and what the
  shorter follow-up window permits saying.

---

## 9. Voice rules

Enforceable, and enforced: the mechanical rules below ship as
`RegionStyleTests`, and the two in the subsections as `RegionCopyRulesTests`.
Both run over every string the card can render.

- ≤2 sentences per slot. ≤34 words per slot. ≤24 words per sentence.
- ≤1 em-dash per slot. One approximator per sentence, on the same logic:
  "roughly ten years, and about 8% annually" hedges the arithmetic twice.
- Lead with the tissue, not the reader. "Ductal tissue is branching,"
  not "You may notice your breasts changing."
- One hedge per sentence. `typically` **or** `may`, never both.
- `many people report` is never the opening clause. It appears second,
  and only where the experience genuinely varies between people.
- Present tense in NOW, MECHANISM and FACT. Future tense only in NEXT.
- No exclamation marks, no "fun fact", no parenthetical asides.

### No terminus framing

Banned as a framing of the long tail: *complete*, *finished*, *no
further*, *nothing more*, *stopped*, *no longer changes*. Where a
developmental phase genuinely has an endpoint, say **what is being held**
rather than what has stopped.

> Development here finished years ago. Estradiol is maintaining the
> distribution rather than driving it.

> Estradiol is holding this distribution in place. Adipose tissue reads
> the signal continuously — the pattern is maintained, not memorised.

Both sentences describe the same biology. The second does not leave the
reader with nothing.

This is not an instruction to obscure. "Breast development typically
plateaus around year five" is a true and useful thing to tell someone,
and it stays. What goes is the *editorial* verdict layered on top of it —
`no further development is expected`, `requires no further adjustment`,
`no further biological change is expected`.

Cleared in the region corpus by Phase E — 15 strings rewritten — and held
there by test. The nine that remain are in `TimeContentData`'s `scienceText`
and `timelineText`, which the card does not render.

### Shared-physiology facts

The fact bank draws on the much larger literature about estrogen- and
androgen-maintained bodies. Write those facts in terms of the **tissue
state**, never the population.

> In any estrogen-maintained skeleton, osteoclasts resorb bone and
> osteoblasts rebuild it. Estradiol sets where that balance lands.

> Breast density falls with age in estrogen-maintained tissue, which is
> why mammogram readings change across the decades.

Never name a comparison group — not to soften anything, but because
naming one makes the reader the exception to it. "The same as in
cisgender women" and "unlike cisgender women" are both out; so is any
construction that positions the reader relative to another group. The
physiology is stated once, and it applies to the body reading it.

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
| NOW bands, re-cut 0-59 | 196 | **written** — 10-12 per region, on each region's own clock |
| NOW bands, 60-240 | 144 | **written** — 8 per region on the frame table below |
| Mechanism entries | 90 | **written** — 5 per region, eligible at every month |
| Fact entries | 180 | **written** — 10 per region, 8 of them eligible past month 60 |
| Markers | 72 | **written** — 4 per region: Tanner stages, adipocyte cycles, training ceilings |
| Terminus rewrites | 15 strings | **cleared** in the region corpus, and held there by test |
| Style rewrites | 20 strings | **cleared** — 16 overviews, 3 bands, 4 insight entries, 1 tense fix |
| De-duplication rewrites | 40 strings | **cleared** — fact entries that restated a mechanism entry |
| Renderable corpus | 700 strings | 18 ABOUT, 340 NOW, 270 INSIGHT, 72 NEXT — pinned by test |

Fact-bank sizing is set by the long-tail user, not the new one. Past
`completeMonth` the rate is `.steady`, so the fact slot fires nearly
every month — a six-year user sees the fact bank more often than any
other content on the card.

Ten entries per region, of which **at least eight must be eligible past
month 60** (`months` ranges are per-entry, so an entry can be scoped to
the early phase, the long tail, or both). That gives an eight-month
non-repeat cycle to someone opening the card monthly at year six, and a
test asserts the 60+ pool size directly rather than the global count:

```swift
@Test func longTailFactPoolIsDeep()  // every region, months 60...240, pool ≥ 8
```

Shipped as eight entries scoped `0...600` and two scoped `0...59`. The
long-tail pool is exactly eight, which is the eight-month cycle §10 asks
for; a reader in their first five years sees ten.

---

## 11. Migration

| Phase | Work | New copy? | Status |
|-------|------|-----------|--------|
| A | `JourneyContext`, `RegionPhase` + `PhaseVocabulary`, present-tense labels, four slots, delete `minimalEngine`, drop the deep-dive section, gate `overview` on `.pending` | none | **landed** |
| B | Mechanism bank + selector + invariant tests | 90 entries | **landed** |
| C | Re-cut NOW bands onto per-region grids | 196 bands | **landed** |
| D | Fact bank | 180 strings | **landed** |
| E | 60+ bands and markers | 216 strings | **landed** |
| F | Style lint test; retire the unreachable phase texts; de-duplicate the insight banks; regenerate `TIME_REGION_COPY.md` | 60 rewrites | **landed** |

Phases B and C make consecutive months differ. D and E are the writing.

### What Phase A landed

The standing month-10 estrogen Abdomen card went from five blocks and 121
words to two blocks and 52: the banded month sentence in NOW, the region's
phase copy in INSIGHT, and nothing else. `overview` now appears only while
the region's clock has not started, where it is the only thing worth saying.

The three tier-keyed blocks are gone from the card, which is where the four
identical estrogen bottom halves went with them. `Active · peak ahead` and
`Maturing · peak passed` are gone from the string catalog.

`RegionCardSlots` is the seam Phase B needs: it resolves NOW, INSIGHT and
ABOUT from a region and a `JourneyContext`, and swapping INSIGHT's source
for the mechanism and fact banks does not change the view.

`ChangeRate` ships unused. It is the input Phase B's bank selection reads,
and the tests already pin its behaviour at the peak and past `completeMonth`.

### What Phase A did not do

`TimeBodySystem`, `TimeBodySystemDetail` and `BodySystemKey` are no longer
reachable from the region card, but `TimeContentEngine.bodySystems` still
builds them and `TenureTierTests` still asserts against them. They are dead
to the UI and alive to the test suite — retire them once `scienceText` has
been harvested for Phase B, not before.

The month mismatch between `TimeHeroHeader` and the card is also still open.
The header reads `monthsOnHRT`, the card reads `activeMonthsOnHRT`, and for
anyone with a dosing gap they disagree — the header can say month 14 over a
card computing phase from month 11. The distinction looks deliberate
(`months` is commented "for display" and drives the change-unlock lists), so
collapsing it changes more than the card. It needs a decision, not a patch.

### What Phases B and C landed

The invariant holds. For all eighteen regions across months 0-240, the card at
*m* differs from the card at *m+1* — verified by test, not by inspection. NOW
holds still for a band at a time; INSIGHT rotates every month underneath it.
Month 10 and month 11 on E Abdomen share a NOW sentence and draw different
INSIGHT copy, which is the case this system was built to answer.

**Phase B** is `TimeRegionInsights`: 90 mechanism entries, five per region, and
the deterministic selector. Two decisions are worth recording because neither is
in §6 as written.

Mechanism entries carry `0...240` rather than phase-scoped ranges. The register
is the pathway, not the calendar — receptors, enzymes, residence times — and
that copy is as true at month 200 as at month 2. It keeps the two slots in
different registers (NOW is the timeline, INSIGHT is the biology), and it keeps
the eligible pool at full depth for a ten-year user rather than draining as the
regions mature. The cost is a five-month rotation cycle; Phase D's fact bank is
what lengthens it.

`ChangeRate` now steers bank selection, but the fact banks are empty, so every
card resolves to mechanism copy through the fall-through. The rate machinery is
live and tested; it has one bank to choose from until Phase D fills the other.

**Phase C** re-cut all 196 pre-60 bands onto per-region grids derived from
`startMonth`/`peakMonth`/`completeMonth`. E Abdomen (3/12/24) lands on exactly
the grid §6 specifies: `3, 4-5, 6-7, 8-9, 10-11, 12-13, 14-17, 18-23, 24-35,
36-47, 48-59`. The old grid was one calendar shape stamped on all eighteen
regions, so E Chest — which develops for five years — got the same 24-35 and
36-47 bands as E Amygdala, which finished at 24. Three properties are now tested
rather than assumed: bands cover `startMonth...240` with no gap or overlap, no
band before the peak runs wider than six months, and no developing band is
wider than any matured one in the same region.

The grid starting at `startMonth` is what keeps ABOUT working: a region whose
clock hasn't started has no band, falls through to the pending sentence, and
shows its `overview`.

### What Phases B and C did not do

Neither phase was "re-cut only", as the table above claimed before they ran.
Moving band boundaries means rewriting the sentences inside them, and mechanism
copy in a pathway register is not a re-slicing of timeline copy. All 286 bands
and all 90 entries are authored text held to the §6 caps (34 words for NOW, 30
for INSIGHT), enforced by test.

The 60+ bands are untouched — still five per region, carried through verbatim.
Phase E replaces them with eight and changes what they are about. They are
inside the caps and inside the coverage guarantee, so they are correct as they
stand; they are just not yet the maintenance-biology copy §8 asks for.

`earlyText`/`midText`/`lateText` survive this phase, described here as "the NOW
fallback for pending months". That was wrong, and Phase F found it: `phaseText`
returned the pending sentence for every month below `startMonth`, and every
month at or above it resolved to a band, so the three fields were unreachable
from the moment the grid became contiguous. Phase F deletes them.

### What Phases D and E landed

**Phase D** is the fact bank: 180 entries, ten per region, eight of them
eligible at every month. Past `completeMonth` the rate is `.steady`, so this is
the bank the card draws from nearly every month — the long-tail reader sees more
of it than of anything else on the card, and now gets eight months before
anything recurs.

The facts are written as tissue state, never as a population comparison, per §9.
"In any estrogen-maintained skeleton, the pelvis is a primary site of bone
remodelling" says the thing without making the reader the exception to it.

**Phase E** replaced all 144 long-tail bands on the §8 frame table and added 72
markers. The 60+ card is now about maintenance biology in the present active:
what holds this tissue, what the hormone does in it daily, what the signal is
load-bearing for, what gets measured, what the cohorts show, and where the
published follow-up runs out. The last band is honest about that edge rather
than trailing off.

The terminus worklist is cleared. Fifteen strings carried `complete`,
`plateaued`, `finished` or `no further` as an editorial verdict; all fifteen are
rewritten, and `RegionCopyRulesTests` now holds the whole region
corpus to both that rule and the comparison-group rule. What survives is the
factual use §9 explicitly protects: "breast growth typically plateaus" stays,
because it is information rather than a verdict.

**NEXT** is built. `RegionMarker` carries a month, a name and a sentence; the
slot renders the name as its eyebrow and the sentence as its body, at the same
weight as NOW and INSIGHT. It is suppressed once a region has matured and
suppressed when the nearest landmark is more than 24 months out.

This is the one slot that looks forward, which is worth being careful about
given that `peak ahead` and `peak passed` were removed for exactly that reason.
The difference is that a marker names something concrete — "Tanner stage 4",
"First fat-cell cycle" — rather than reporting the reader's position on a curve,
and it disappears entirely when there is nothing concrete within reach. A test
asserts no marker name or note contains the word "peak".

### What Phases D and E did not do

`TimeContentData` still carries nine terminus strings of its own, in
`scienceText` and `timelineText`. None are reachable from the region card, and
the lint deliberately does not read them — the §9 count of 39 was taken across
both corpora. They come out with the `TimeBodySystem` family, which is still
test-referenced and still holds the `scienceText` prose.

`RegionMarker` does one of the three jobs §7 gives it. It populates NEXT; it
does not yet anchor the NOW copy in the band that contains it, and the long-tail
bands do not yet reference markers by name.

### What Phase F landed

The style lint ships as `RegionStyleTests`, holding all 700 renderable strings
to the mechanical half of §9: per-slot sentence and word caps, one em-dash, one
hedge and one approximator per sentence, no parentheses, no exclamation marks,
no `fun fact`, future tense only in NEXT, and no slot opening on the reader
rather than the tissue. The corpus is built once, in `CardCopy.all`, and both
lint files read it, so they cannot drift apart on what "every string the card
can render" means.

Twenty strings had to be rewritten to pass — sixteen `overview` strings over the
40-word cap, three bands running to three sentences, one band in the future
tense, and four insight entries that hedged twice in one sentence. Two of those
four were mine from Phase D: "roughly ten years, and the population turns over
about 8% annually" approximates the arithmetic twice in one breath.

**The phase texts are gone.** `earlyText`, `midText` and `lateText` accounted for
21 of the 23 length violations, and none of them could render: `monthFocus`
covers every month from `startMonth` onward, so `focusText` only returns nil
below `startMonth`, where `phaseText` returned the pending sentence and never
reached the three authored fields. The lint would have been guarding 54 strings
no reader can see. They are deleted, `phaseText(at:)` is now the `pendingText`
property that was its only reachable branch, and each region's final band runs
to month 1200 so the nil case stays exactly "before this region starts".

A lint is only as honest as the corpus it reads, so two of its assertions are
about itself: the pinned count of 700 with a per-slot breakdown, so a silent
drop in coverage fails rather than passes; and a check that the corpus contains
no abbreviations or decimals, which is the assumption that lets the sentence
splitter break on every period and be exact rather than approximate.

**A defect Phase F found on the way.** `banksDoNotOverlap` had been asserting
that no entry appears in both banks — by exact string match, which is the
weakest possible reading of that intent. Measuring properly found **39 of the
180 fact entries were paraphrases of a mechanism entry in the same region**, one
of them word-for-word identical, and two entries repeated verbatim across
regions.

That defeats what the two banks are for. A reader draws from the mechanism bank
while a region is moving and from the fact bank once it has settled, so the
long-tenure reader — who sees the fact slot nearly every month — was the one
being served reworded copy they had already read years earlier. All 40 are
rewritten, and the test now measures subject-matter overlap and shared word runs
instead of string equality. The shipped corpus's worst pair now overlaps 0.42
against a 0.50 threshold, and no two entries share a seven-word run.

`TIME_REGION_COPY.md` is regenerated from the three source files. The previous
revision signed off a corpus that no longer ships — Phases C and E replaced
every band in it — so it is marked **pending re-review** rather than carried
forward, and it now covers all four slots instead of overviews and long-tail
bands alone.

### What Phase F did not do

The judgement half of §9 stays prose: whether a hedge is the right hedge,
whether a mechanism is stated correctly, whether a fact is worth the slot. The
lint checks that copy is shaped like the house style, not that it is true —
`TIME_REGION_COPY.md` and clinical review are what check that.

### Slot inventory, as shipped

All four slots in §6 are built. NOW and INSIGHT render unconditionally, NEXT
when a landmark is within the horizon, ABOUT while the region's clock has not
started. A card therefore runs two blocks at its thinnest and four at its
fullest, and the two that are always present are the two the brief asked for.
