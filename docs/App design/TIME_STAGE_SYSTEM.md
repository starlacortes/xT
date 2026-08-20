# Time — The Stage System

**Status:** built and pushed. Not yet compiled — see *Verification* at the end.
**Companions:** `TIME_CARD_PERSONALIZATION.md` (what the card says and how it
reads), `TIME_TIERS_DESIGN.md` (tenure tiers), `TIME_REGION_COPY.md` (the
corpus, pending clinical re-review).

This document specifies three changes that landed together, because they are
one change: the Time feature now has **one content model, one tenure number,
and one place where a named clinical scale is defined**.

1. [Stages](#1-stages) — binding named clinical scales to the copy the reader sees
2. [One tenure number](#2-one-tenure-number) — `activeMonthsOnHRT` everywhere
3. [The retired system cards](#3-the-retired-system-cards) — what left and why

---

## 1. Stages

### 1.1 The problem

`RegionMarker` and `BodyRegion.monthFocus` were two independently authored
lists describing the same timeline, with nothing checking that they agreed.

They did not agree. In the one region with a real clinical scale:

| | Marker said | Band copy said |
|---|---|---|
| Tanner stage 4 | arrives month 18 | "typically reached across this window" — months 14–17 |
| Tanner stage 5 | arrives month 48 | "the named endpoint" — months 84–95 |

A reader at month 16 was told by NOW that stage 4 typically arrives now, and
by NEXT that stage 4 typically arrives in two months. Both sentences shipped.
Neither list could see the other, so nothing could have caught it.

This is the §7 gap stated plainly: markers were specified to do three jobs —
populate NEXT, anchor the NOW copy in the band containing them, and give the
long tail named endpoints — and only the first was built.

### 1.2 The distinction: marker vs stage

A **marker** is a landmark: a named month on a region's own clock.
`"Visceral floor"`, `"First fat-cell cycle"`, `"Training ceiling"`. Its name is
a UI label — the eyebrow above the NEXT slot — not a phrase from the
literature. Nothing outside the card refers to it.

A **stage** is a landmark that belongs to an ordered, externally defined scale.
`"Tanner stage 4"` means something *relative to stage 3*, the sequence has to
be complete, and the phrase appears in clinical prose the reader may meet
elsewhere. That is a stronger claim, and it earns a stronger guarantee.

**Only stages are bound to the copy.** Plain markers keep their freedom,
because requiring the band to quote `"Held baseline"` would push UI labels into
prose that reads worse for it. This is a deliberate limit, not an oversight —
see [1.6](#16-what-this-deliberately-does-not-do).

### 1.3 The model

```swift
enum StageScale: String {
    case tanner

    /// How a step on this scale is written, everywhere it is written.
    func phrase(ordinal: Int) -> String        // "Tanner stage 4"

    /// The steps this scale defines. Stage 1 is the untreated baseline,
    /// so a region's sequence starts at 2.
    var ordinals: ClosedRange<Int>             // 2...5
}

struct StageRef: Equatable {
    let scale: StageScale
    let ordinal: Int
}

struct RegionMarker {
    let month: Int
    let name: String
    let note: String
    var stage: StageRef?      // nil for a plain marker
}
```

Staged markers are never constructed by hand. The factory derives the name
from the scale, so the eyebrow, the band copy and the test all read one
spelling of one stage:

```swift
static func stage(_ scale: StageScale, _ ordinal: Int,
                  month: Int, note: String) -> RegionMarker
```

```swift
"chest": [
    .stage(.tanner, 2, month: 3,  note: "Typically establishes around month 3."),
    .stage(.tanner, 3, month: 9,  note: "Typically arrives around month 9."),
    .stage(.tanner, 4, month: 14, note: "Typically arrives around month 14."),
    .stage(.tanner, 5, month: 48, note: "Where it is reached, typically arrives around month 48."),
],
```

### 1.4 The mechanism: `band(at:)`

Nothing could connect a marker to a sentence, because `focusText(at:)` returned
the text and discarded the range that produced it. A marker knew its month and
had no way to ask which sentence the reader sees in that month.

```swift
/// The band the NOW copy is drawn from, with its range, or nil below startMonth.
func band(at months: Int) -> (range: ClosedRange<Int>, text: String)?
```

`focusText(at:)` is now `band(at:)?.text`. One lookup, two callers, and the
band is addressable from outside for the first time.

### 1.5 The two bindings

**Forward — a stage's arrival month must land in a band that names it.**

This is what turns the NOW slot into the reader's current-stage readout without
the card claiming anything about them personally. The band copy is already
hedged in the house voice ("typically reached here"), and it is now also
guaranteed correct.

**Reverse — no region's copy may name a stage the model does not hold.**

Checked across the region's overview, every band, every insight entry and every
marker note, by regex, so `"Tanner 2"` and `"Tanner stage 2"` both count. This
is the direction that catches prose inventing a stage, which is exactly how the
chest ended up describing a stage 5 arrival two years after the marker placed
one.

Enforced by `xTTests/RegionStageTests.swift`, eight tests:

| Test | Holds |
|---|---|
| `everyMarkerResolvesToABand` | all 72 markers, staged or not, land inside a band |
| `bandAndFocusTextAgree` | the two accessors never disagree, months 0–240 |
| `stageNamesComeFromTheScale` | a staged marker's name is `scale.phrase(ordinal:)` |
| `stageSequencesAreCompleteAndAscending` | ordinals equal the scale's full range, in month order, one scale per region |
| `everyStageArrivalIsNamedByItsBand` | forward binding |
| `noCopyNamesAStageThatIsNotModelled` | reverse binding |
| `currentStageIsPresentTense` | never claims a stage before it arrives; the last stage stays current at long tenure |
| `currentAndNextDoNotCollide` | current and NEXT are never the same step, and never out of order |

### 1.6 What this deliberately does not do

- **No new UI.** The stage system's output is guaranteed-consistent copy in the
  slots that already exist. `currentStage(track:key:month:)` is available and
  unused by the view: a "Tanner stage 3" chip on the chest card and nothing
  equivalent on the other seventeen regions would read as a missing feature
  everywhere else.
- **No stage claim about the reader.** `currentStage` returns where the *median*
  sits. Rendering it as "you are at stage 3" would be the one promise this
  whole content system has avoided making. The hedged band copy is the honest
  form of the same information, which is why the forward binding targets it.
- **Plain markers are not anchored.** 45 of 72 marker names do not appear in the
  band containing them, and that is mostly correct: `"Steadier week to week"`
  is a label, not a sentence. Requiring it in prose would damage the copy to
  satisfy a test.
- **One scale.** Tanner is the only ordered scale the shipped regions actually
  use. `StageScale` is an enum with one case so that adding a second is a
  data change, not a redesign.

### 1.7 Copy changed

| Region | Before | After |
|---|---|---|
| E chest, marker | Tanner stage 4 at month 18 | month 14, matching the band that describes its arrival |
| E chest, band 46–59 | "Maturation is approaching completion. Full development can take the whole 60 months." | "Tanner stage 5, where it is reached, typically arrives across this window. Full ductal-lobular maturation can take the whole sixty months." |

The new band is 2 sentences / 21 words / 1 hedge per sentence — inside the §9
NOW caps. The corpus is still 700 strings, so the pinned count in
`RegionStyleTests.styleLintCoversEverything` is unchanged.

### 1.8 Adding a scale later

1. Add a case to `StageScale` with its `phrase(ordinal:)` and `ordinals`.
2. Author the region's markers with `.stage(...)`.
3. Make the band containing each arrival month name the stage.

Step 3 is not optional and not a convention — `everyStageArrivalIsNamedByItsBand`
fails until it is done, naming the band and quoting its text.

---

## 2. One tenure number

### 2.1 The problem

`MedicationManager` exposes two counts:

- **`monthsOnHRT`** — calendar months since the declared start date.
- **`activeMonthsOnHRT`** — gap-aware. The span before the first logged dose is
  trusted as active therapy; from there, only calendar months containing a
  taken dose count.

The Time screen header read the first. The region card underneath it reads the
second. For anyone with a three-month gap the header said **Month 14** directly
above a card computing its phase, band, insight and stage from **month 11**.

The card design pass made this visible rather than latent: the card now prints
its own month in its header, so the two numbers sit one above the other.

### 2.2 The rule

**`activeMonthsOnHRT` is the tenure number.** Everywhere a single figure answers
"how long have I been doing this", it is this one — the Time header, the region
card, the tier ladder, the profile badge.

`monthsOnHRT` survives in exactly one place: the Settings HRT-start row, where
it is paired with the start date. A calendar span is the right answer next to a
calendar date, and it is labelled as one.

### 2.3 The profile badge

```
●  2 years
```

Under the profile name in Settings: a 5pt accent dot, then the tenure. Whole
years at twelve months and over, months below that, nothing at all below one
month — "0 months" is not a milestone.

One formatter, `MedicationManager.tenureLabel`, so the badge cannot drift from
the header. It returns `LocalizedStringResource` with `inflect: true`, so
"1 year" and "2 years" are the string catalog's problem rather than a branch.

Whole years is a deliberate flattening: at 23 months the badge says "1 year".
The exact month count is one row away, and a badge that reads "1 year 11
months" is a readout, not a badge.

---

## 3. The retired system cards

### 3.1 What left

`TimeBodySystem`, `TimeBodySystemDetail` and `BodySystemKey`, plus the 37
engine members that existed only to fill them — roughly 900 lines across
`TimeContentData.swift` and `TimeContentTypes.swift`.

This was the tier-keyed content model the region card replaced: seven
`BodySystemKey` cases (mood, skin, body shape, cycle, voice, hair, muscle),
each with a row and a deep-dive page of `scienceText` / `timelineText` /
`whatToExpect` / `maintenanceNote` / `deepeningNote`.

### 3.2 Why

**It was unreachable.** No view constructed it. Its only non-model references
were eight assertions in `TenureTierTests.swift` checking that its strings were
not empty.

**It was keyed to the wrong thing.** Content selected by tenure tier rather than
by region is the exact problem `TIME_CARD_PERSONALIZATION.md` §1 measured: four
different body regions rendering one identical paragraph.

**It carried the voice this system removed.** Fifteen of its strings used
terminus framing, verbatim:

> "Pitch has been stable for half a decade. No further biological change is expected."
> "Hair and skin patterns are stable and testosterone-driven change is complete."
> "Lean mass has plateaued: testosterone alone no longer drives further growth…"

The region lint in `RegionStyleTests` and `RegionCopyRulesTests` reads the
region corpus and deliberately does not read this file. Unreachable code that
is also unlinted is a loaded gun: anything that wired a view to
`engine.bodySystems` would have shipped all fifteen without a test failing.

### 3.3 The tests

Six deleted outright: `bodyDetailNoCrashEstrogen`,
`bodyDetailNoCrashTestosterone`, `gapAwareMuscleLabel`,
`detailReachabilityEMind`, `detailReachabilityEHips`,
`detailReachabilityTChest`. They asserted that deleted code returned non-empty
strings.

One narrowed: `gapAwareConsistencyRegression` kept its real subject — 50
calendar months with 10 active must read as T3, not T5 — and dropped the half
that inspected a `progressLabel` that no longer exists. Renamed to say what it
now tests.

Nothing that survives references the retired family; a repo-wide grep for
`TimeBodySystem`, `BodySystemKey`, `bodySystems`, `bodySystemDetail` and
`bodySystemFocus` returns nothing.

### 3.4 What was kept

`TimeContentPalette` stays — milestones and the hormone-level insight still use
it. So do `unlockedChanges`, `upcomingMilestones`, the hormone band copy and
the tier ladder. Only the system-card family and its exclusive helpers left.

---

## Verification

**Nothing here was compiled or tested.** There is no Swift toolchain in the
authoring environment.

What was done instead:

- The eight assertions in `RegionStageTests` were re-implemented in Python
  against the parsed Swift and run over the real data: 18 regions, 72 markers,
  270 insight entries, 340 bands. **0 failures.** Both bindings hold in both
  directions; 8 stage references across the corpus all resolve to modelled
  ordinals.
- The new 46–59 band was checked against the §9 NOW caps: 2 sentences, 21
  words, ≤24 per sentence, one hedge per sentence, no banned punctuation, no
  terminus phrase.
- The renderable corpus is still 700 strings (18 overviews / 340 bands / 270
  insights / 72 marker notes), so the pinned count in
  `RegionStyleTests.styleLintCoversEverything` is unchanged.
- Every edited Swift file passed a brace/paren/bracket balance check with
  string literals and comments stripped.
- A repo-wide grep confirmed no dangling references to the retired family.

This is evidence that the data and the rules are right. It is not evidence that
the code compiles. **Build in Xcode.**
