# Pharmacokinetic review — 25 August 2026

A full re-derivation of xT's pharmacokinetic model from its sources, and a
reconciliation of the three papers against the shipped implementation.

Every numeric claim in `pk-research-paper.tex` — the steady-state table, the accuracy
table, the out-of-sample table, the t_max table and the eight-persona suite — was
recomputed from the constants in `PharmacokineticConstants.swift`, twice: once by
forward simulation to steady state, and once, where a closed form exists, by the
analytic sum `Σ_{k≥1} C(kτ)`. All but one reproduced.

**What changed:** three `.tex` files, three rebuilt PDFs, and one patch against two
Swift files. The patch is **not applied** — see [Applying the patch](#applying-the-patch).

---

## The short version

| # | Finding | Where | Severity |
|---|---------|-------|----------|
| 1 | Endogenous baseline is keyed to the tracked hormone, not the user's gonads | code + PK paper | **major** |
| 2 | Comparison band's floor exceeds what the model can predict; band inverts at high dose | code + persona paper | **major** |
| 3 | `relativeDoseIntensity` ignores the dosing interval | code | **major** |
| 4 | α is derived against total but applied to exogenous only — doesn't round-trip | code + PK paper | moderate |
| 5 | Nadia's α trend was misread; it is a signal about her, not the model | persona paper | moderate |
| 6 | Spironolactone clearance factor is unsourced and mechanically misplaced | code + PK paper | moderate |
| 7 | Baseline taper plateaus at 92%, then steps at week 104 | code + PK paper | minor |
| 8 | Baseline is evaluated once and applied flat across the whole series | code + PK paper | minor |
| 9 | Aromatization equation in the PK paper dropped a factor of 10 | PK paper | minor |
| 10 | TP steady-state trough printed as 760; it is 580 | PK paper | minor |
| 11 | Maya's "published single-dose peak 400–500 pg/mL" contradicts its own citation | persona paper | minor |
| 12 | The 240 ng/dL basal used in the testosterone tables was never defined | PK paper | minor |
| 13 | TE's k_a is a censored mean | PK paper | disclosure |
| 14 | `CloudSyncService` is undocumented; memory paper's sync claims are dated | memory paper | **major gap** |

Nothing in the Bateman core, the clearance identity, the ester weight factors, the
scaling constants, or the t_max derivations was found to be wrong. Those all check out
exactly. The defects are in the layers *around* the PK model — the baseline, the
calibration, and the comparison bands.

---

## The three that matter

### 1. The endogenous baseline is keyed to the wrong variable

`MedicationType.baselineValue` supplies one intact-gonad figure per **hormone** — 100
pg/mL for estradiol, 600 ng/dL for testosterone — and the engine selects between them by
asking which hormone is being tracked. But the intact baseline is a property of the
gonads the user has, not of the hormone they are watching. The two constants don't even
describe the same person: 600 ng/dL is an intact eugonadal male value, 100 pg/mL a
mid-follicular ovulatory one.

| User | Given | Actual | Verdict |
|---|---|---|---|
| Transfeminine, tracking E2 | 100 pg/mL | ~20–30 pg/mL | ~4× too high |
| Transmasculine, tracking T | 600 ng/dL | ~15–50 ng/dL | >10× too high |
| Transfeminine, tracking T (suppression) | 600 → 15 | 600 → 15 | correct |

Right for one case of three.

**Magnitude.** At the default 4-week timescale the phantom testosterone baseline is
328 ng/dL at week 1 and 183 at week 2. Against a TC 100 mg q7d regimen still
accumulating over the same fortnight, that roughly **doubles** a new transmasculine
user's predicted level — during exactly the period when he's checking the number most
and has no blood test to contradict it. The estradiol error is smaller in ratio but
lands on a smaller quantity: 92 pg/mL of phantom baseline at week 1, against a 4 mg EV
dose whose own peak is 238.

It also narrates the decay as "gonadal suppression," which is not what testosterone
therapy does to a trans man.

**Not fixed, deliberately.** The fix needs a therapy-direction or gonadal-starting-point
field on the profile, and the tracked hormone is not a proxy for it — the third row above
is the counterexample. I could not read `BodyType.swift`, `UserPreferences.swift`, or the
onboarding flow (device staging went down mid-session), so I don't know whether such a
field already exists under another name. Guessing at an API I couldn't see, in the
component that decides what number a user reads about their own body, seemed the wrong
call. **This one needs your decision.** The patch documents it in place at
`dynamicBaseline` with the full reasoning.

### 2 & 3. The comparison band is unreachable, and sometimes inverted

Three of the seven validation personas are flagged low. The persona paper's first
revision called this a vocabulary problem — correct numbers, alarming words. It isn't.
In all three cases the level is compared against a bound the PK model cannot reach:

| Persona | Intensity | Band floor | Model C_max | Level | Status |
|---|---|---|---|---|---|
| Maya (EV 4 mg q7d) | 2.0 | 400 | 338 | 323 | `slightlyBelow` |
| Devon (TC 200 mg q14d) | 4.0 | 1350 | 1162 | 317 | `criticallyLow` |
| Nadia (EC 5 mg q10d) | 2.5 | 300 | 256 | 135 | `criticallyLow` |

Devon's is worse than unreachable — it's **inverted**. At mid-cycle:

```
midMin = (troughMin + scaledPeakMin)/2 = (300 + 600×4.0)/2 = 1350
midMax = (troughMax + peakCeiling)/2   = (1000 + 1500)/2   = 1250
```

`inRange` requires `min ≤ actual ≤ max`. With 1350 > 1250, **no level satisfies it** —
the classification collapses to "critically low" or "slightly above" with nothing
between. At `.nearPeak` his band is `(2400, 1500)`: floor 900 ng/dL above ceiling, and
both above the 1099 his regimen actually peaks at.

The root cause is `relativeDoseIntensity`. It divides the mean dose *amount* by a fixed
reference dose, with no term for how often the dose is taken. Both references are weekly
figures (2 mg EV/week, 50 mg TC/week), so comparing a per-administration amount to them
is a units error that cancels only when the user's interval happens to be 7 days. Devon
moving from 100 mg q7d to 200 mg q14d has **identical exposure** — the model itself holds
C_avg at 549.5 ng/dL across the change — but his intensity reads 2.0 then 4.0. Every
derived target doubles because he changed his calendar.

**Fixed in the patch**, both of them: intensity now compares rates
(`D̄/τ_user` ÷ `D_ref/τ_ref`, returning 2.0 on both sides of Devon's change and dropping
his mid-cycle floor from 1350 to 750), and `contextualRange` now guarantees `lo ≤ hi`.
The remaining half — intersecting model-derived bounds with the predicted
`[C_min, C_max]` envelope, which would eliminate all three rows above — is left as a
`TODO` in the patch, because it needs the predicted envelope at the call site and that's
a larger refactor than I'd land unreviewed.

This class of defect will recur for anyone who splits or consolidates doses — twice-weekly
estradiol, ten-weekly undecanoate — which is a large share of the regimens xT supports.

---

## The rest

### 4. α doesn't round-trip

`computeCalibrationFactor` derives α as `measured / (base + exogenous)` but
`estimatedLevels` applies it as `base + exogenous × α`. Re-evaluating the model at the
draw instant therefore returns `measured + (1−α)·base`, not `measured`.

Negligible for a suppressed user (base 5 pg/mL or 15 ng/dL, under 1%). Not negligible
early in therapy: at base 328 and exogenous 400 ng/dL, a measured 500 gives α = 0.687 and
a post-calibration prediction of **603 — +20.5%**. And the error always resists the
correction: a user whose true levels run below the population model stays over-predicted.
It's worst in the same regime as finding 1, and pushes the same direction.

Scaling the exogenous term alone is the physiologically defensible reading — α corrects
the drug model, not the user's adrenal output — so **the patch moves the derivation to
match the application**, with a guard for the case where the measurement sits at or below
the modeled endogenous floor (no positive α reconciles those; declining to calibrate
beats clamping to 0.2 and asserting a correction that doesn't exist).

### 5. Nadia's α trend was misread

The persona paper read her declining α (0.669 → 0.587 → 0.554 over 12 months) as the
single-scalar calibration failing to absorb a non-standard interval, "increasingly
diverging" as she accumulated time on q10d.

Recomputing: EC at 5 mg q10d reaches steady state within three months. The predicted
trough is **157.4 pg/mL at month 3, at month 6, and at month 12** — identical to four
significant figures. Nothing diverges, because nothing moves. With the denominator fixed
at 170.2, the declining α can only mean a declining numerator: her measured troughs were
approximately 113.9 → 99.9 → 94.3 pg/mL. **A 17% fall in her own levels on an unchanged
regimen.**

That inverts the finding. A monotone α drift on a fixed regimen, after steady state, is
the *most* informative thing the calibration engine can produce — it's the one case where
α measures the user rather than absorbing the model's error. The engine keeps only the
latest α and discards the sequence; Jules's single 1.326 and Nadia's three-point decline
are stored and presented identically. Rewritten in the persona paper, with a design
implication.

### 6. Spironolactone

`spiroClearanceFactor = 1.15`, justified in both code and paper as CYP3A4 induction
accelerating E2 clearance by "10–20%". Two problems:

- **No source.** I could not find a primary human PK study establishing it. The one study
  that measured estradiol PK directly in transfeminine people on spironolactone — Cattani
  et al., *Clin Pharmacokinet* 2023 (PMID 37261664) — reports estradiol exposure
  unaffected by the interaction it tested (AUC GMR 0.89, 90% CI 0.76–1.04; trough ratio
  1.06, 0.94–1.20) and identifies no spironolactone-driven effect.
- **Wrong exponential.** Under the paper's own flip-flop convention, `ke` for a depot
  ester is the *fast* rate — absorption from the oil vehicle, not hepatic clearance.
  Clearance governs the slow exponential in `halfLifeDays`. Scaling `ke` does lower AUC in
  roughly the right direction, but by speeding the depot release while leaving the
  terminal slope untouched. A real clearance increase would steepen the terminal decay and
  deepen the trough. This does neither.

Kept — removing a shipped toggle is your call, not mine — but demoted to the bottom tier
of the source hierarchy alongside TP, and documented at length in both places. It's opt-in
and defaults off, which is the position the evidence supports. It should not be presented
in the UI as a fact about spironolactone.

### 7 & 8. Two smaller baseline problems

**The 92% plateau.** `progress` was clamped at 1.0, freezing the taper at
`1 − e^−2.5 = 91.8%` once the timescale elapsed — 63 ng/dL of modeled endogenous
testosterone held constant for the rest of the first two years — and then the 104-week
rule drops it to 15 in a single step. A user carries a fixed 48 ng/dL of phantom hormone
for two years and loses it overnight on their anniversary. **Fixed** (uncapped the
exponential; the 104-week rule becomes a no-op, since `e^(−2.5·26) ≈ 0`).

**The flat baseline.** `estimatedLevels` evaluates `dynamicBaseline` *once*, as of now,
and applies that value to every point in the series including historical ones. A six-month
chart draws a horizontal endogenous floor at today's suppressed value rather than the
decaying curve. **Not fixed** — changing it silently re-scales every stored α, which needs
a migration. The patch adds the date-aware `dynamicBaseline(for:asOf:)` overload the fix
will need, and a `TODO` at the call site.

### 9–12. Documentation corrections

- **Aromatization.** The paper stated `E2 = 0.002 × T_ng/dL`. The code computes
  `0.002 × 10 × T_ng/dL`, and the code is right — 1 ng/dL = 10 pg/mL. The paper dropped
  the unit conversion, understating the implemented estimate tenfold. Paper corrected; no
  code change. (Sanity: 600 ng/dL → 12 pg/mL, low end of the 10–40 male range. The real
  serum E2/T mass ratio is nearer 0.5%, so 0.002 is conservative by ~2× — retained, since
  a low estimate fails safe for telling a trans man whether his E2 is running *high*.)
- **TP steady-state trough.** Table 5 printed **760**; both simulation and the analytic
  sum give **580**. Corrected. TP's peak/trough ratio moves
  from 2.29× to 3.00×.
- **Maya's single-dose peak.** The persona paper cited the PK paper for "EV's published
  single-dose peak of approximately 400–500 pg/mL" at 4 mg. The PK paper says 119 pg/mL
  for 2 mg, validated against TFS Table 9 to within 1% — so 238 at 4 mg, not 400–500. The
  citation contradicted its source. Corrected.
- **The 240 ng/dL basal.** Several testosterone rows add a flat 240 to exogenous output
  and never say so. It's the residual endogenous T of Bi's healthy-male cohort — correct
  for the Bi comparison, and *not* a level xT would ever display for a trans man. Now
  defined in its own subsection and flagged wherever used.

### 13. TE's absorption rate is a censored mean

Ichihara reported k_a for only the 4 of 10 subjects where it was estimable (2.82, 3.16,
0.49, 1.38 d⁻¹, mean 1.9625). The other **six exceeded 10 d⁻¹** — which is precisely why
they weren't estimable. Averaging the estimable four selects the slow tail and biases k_a
downward by an unquantifiable amount.

Kept anyway, for a reason now stated in the paper rather than left implicit: k_a = 10 d⁻¹
with the reported 6.6 d terminal half-life puts t_max at 0.46 d, and no subject peaked
that early (observed mean 1.7 ± 0.9 d across all ten). Ichihara's censored fits and
Ichihara's own observed t_max can't both be right — a source-internal conflict of the same
species as the TU one — and the constant is chosen to match the observable.

### 14. The memory paper has a hole where `CloudSyncService` should be

`Managers/` now contains eight types; the paper documents six. `ThemeManager` is a scope
decision and harmless. `CloudSyncService.swift` is not: added 23 Aug 2026, alongside
`CloudSyncChoiceView.swift` (onboarding) and `SettingsView+CloudSync.swift` (settings) —
i.e. a user-facing choice about cloud sync. That's in direct tension with two claims the
paper makes: that the container is configured `cloudKitDatabase: .automatic`
unconditionally, and that "all SwiftData models participate in CloudKit sync" with no
selective-sync mechanism.

I couldn't read the file (staging was down), so I have not described what it does —
guessing at the behaviour of the component that decides what leaves the device would be
worse than admitting the gap. The paper now states the coverage boundary explicitly, dates
its analysis to 20 Aug 2026, and makes documenting `CloudSyncService` the first item of
future work. **This is the largest outstanding piece of work across the three papers.**

Also fixed: five citations to `Persistence.swift`, which doesn't exist — normalised to
`MedicationManager+Persistence.swift`.

---

## Applying the patch

`pk-review-2026-08-25.patch` touches two files:
`xT/Shared/PharmacokineticConstants.swift` and
`xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift`.

```
cd ~/Documents/dxto/xT
git checkout -b pk-review-2026-08-25
patch -p1 --dry-run < docs/pk-review-2026-08-25.patch   # verify
patch -p1 < docs/pk-review-2026-08-25.patch
```

It applies cleanly against the files as of 24 Aug 2026 01:55 UTC (verified with
`patch --dry-run`).

**It has not been compiled.** There's no Swift toolchain in this environment, so the
changes are reviewed-by-eye only. Build and run `xTTests/PharmacokineticTests.swift`
before committing.

Two of the four changes will move numbers that existing tests may assert on:

- **`relativeDoseIntensity`** now returns dose *rate* relative to the reference rate. Any
  test asserting the old per-dose ratio will fail, and should.
- **`computeCalibrationFactor`** now derives α from the exogenous term. **Every stored α
  changes**, by `(1−α)·base / exogenous`. For suppressed users this is under 1%; for users
  early in therapy it is up to ~20%. Consider whether stored `BloodTestRecord`s need
  recomputation on next launch — `recomputeCalibrationFactors()` already exists and is
  called on init, so this may be handled, but it's worth confirming rather than assuming.

The taper and band-guard changes are strictly narrowing and shouldn't move anything that
was previously correct.

---

## What I'd do next, in order

1. **Decide the therapy-direction question** (finding 1). Everything else in the baseline
   is downstream of it, and it's the one defect with a user-visible clinical magnitude.
2. **Build and test the patch**, then commit. Watch the two α/intensity test surfaces.
3. **Finish the band clamp** (the `TODO` in `contextualRange`) — it closes findings 2 and
   3 completely rather than partially.
4. **Read and document `CloudSyncService`**, then re-verify the memory paper's encryption
   and sync claims against it.
5. **Surface the α trend** in the UI rather than only the latest value (finding 5). Cheap,
   and it's the app's best signal about a user whose body has changed.
