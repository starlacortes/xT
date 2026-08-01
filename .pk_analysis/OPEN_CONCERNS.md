# PK Model — Open Concerns

**Status as of 2026-07-31 (second pass)** · Commits `8a50db9` → `9abf8b2` → the
testosterone calibration pass described below.

This note records what is *unresolved* in the pharmacokinetic engine, and why each
item was left alone rather than fixed. It is written so nobody has to re-derive the
reasoning.

The derivations live in `.pk_analysis/`: `fit_constants.py` (estrogen),
`fit_testosterone.py` (testosterone), `verify_constants.py` (independent check that
the shipped constants reproduce their sources), `personas.py` (end-to-end user
scenarios). The full write-up is `docs/pk-validation-dossier.tex`.

---

## TL;DR

| # | Concern | Severity | Status |
|---|---|---|---|
| 1 | PK test suite has a test-isolation defect; results are unreliable | High | **Resolved 2026-07-31** |
| 2 | The TC Tmax target encoded in our own harness is probably wrong | High | **Resolved 2026-07-31** — the encoded window was right |
| 3 | Testosterone esters are uncalibrated (Tmax off by 3–13×) | Medium | **Partly resolved** — magnitude fixed for all four; TC shape fixed; TE/TP/TU shape still open |
| 4 | TU cannot be modeled correctly by a 2-parameter Bateman | Medium | Open — modeling decision, deliberately deferred |
| 5 | Predicted levels change substantially for existing users | Medium | Open — product / comms |
| 6 | Amplitude re-anchoring was an engineering call, not a clinical one | Medium | Open — clinical sign-off |
| 7 | Oral estradiol Tmax is ~12.7 h against a published 4–8 h | Medium | **New 2026-07-31** — open |
| 8 | Transdermal intraday ripple is structurally under-modeled | Low | **New 2026-07-31** — documented, not fixable in this model |
| 9 | Transdermal dose-response is anchored to the 50 mg arm only | Low | **New 2026-07-31** — documented |

---

## 1. ~~The PK test suite is not trustworthy~~ — **Resolved 2026-07-31**

The suite is a reliable safety net for PK work. Two entangled causes were fixed: a
singleton race (`MedicationManager.shared` → `MedicationManager()` at 62 sites, since
Swift Testing runs in parallel), and a real production bug in forward-fill that
generated ~12 phantom historical doses from a single old dose. Details are preserved
in the git history of this file.

---

## 2. ~~Our own TC Tmax target is probably wrong~~ — **Resolved 2026-07-31**

**The encoded 1.0–2.0 d window was correct. The day 4–5 claim was not.**

Bi et al. 2018 (*CPT: Pharmacometrics & Systems Pharmacology*, doi
10.1002/psp4.12287) Table 2 gives Ka = 1.22 /day against a disposition rate CL/V =
2.6/14.4 = 0.1806 /day. Therefore

    Tmax = ln(ka/ke)/(ka − ke) = 1.84 d

which sits inside the encoded window. Propagating the published 95% CI on Ka
(0.785–2.67) gives a Tmax band of 1.08–2.43 d, which never reaches day 4–5.

The suspicion recorded here was that "24–48 h" in secondary sources described when
levels rise into the supraphysiologic range rather than time-to-peak. That reading was
reasonable but wrong: the primary source supports the shorter window directly.

Read TC Tmax as **1.84 d ± ~0.7 d**. Bi's own limitations section explains the
imprecision — 1–2 absorption-phase samples per subject, Ka RSE 44.9%.

Guarded by `cypionateTPeakTime` in `xTTests/PharmacokineticTests.swift`.

---

## 3. Testosterone esters — magnitude now fixed, shape still open for TE/TP/TU

### What was resolved

**TC is fully calibrated** from the primary source that §2 and the old §3 were both
blocked on. Bi et al. 2018 Table 2 gives everything needed:

| | Before | After | Derivation |
|---|---|---|---|
| `halfLifeDays` | 8.0 | 3.839 | ln2 / (CL/V), CL/F 2.6 kL/d ÷ V/F 14.4 kL |
| `eliminationHalfLifeHours` | 2.0 | 13.64 | ln2 / Ka, Ka = 1.22 /d |
| `scalingConstant` | 1081.0 | 67.13 | closed form 1e5·Ka / (V_L · EDF · ke) |

3.839 d is deliberately **not** the ~7–8 d figure commonly quoted for TC. Bi addresses
that discrepancy directly: noncompartmental analysis yields 6.9 d and their own model
yields 6.87 d *when endogenous secretion is assumed zero*, but 4.05 d once endogenous
production is accounted for. xT models endogenous production separately as
`baseLevel`, so the exogenous-only figure is the one that belongs here. Bi's own
median post hoc estimate is 4.05 d — 5.2% from our 3.839.

**TE / TP / TU magnitudes are fixed too**, without needing a source for any of them.
Integrating the app's own expression over a dosing interval gives exactly

    Cavg = Dose · EDF · S / (τ · ke)

because ∫₀^∞ (ka/(ka−ke))(e^(−ke·t) − e^(−ka·t)) dt = 1/ke. The true steady-state
average is (mg testosterone per day) / CL, and clearance is a property of
*testosterone*, not of the ester carrying it — so it is already pinned by the TC
refit. Equating the two, the ester weight factor cancels:

    S = 1e5 · ke / (CL_T · F),   CL_T = 2600 × EWF_TC = 1817.4 L/day

TC satisfies this identity to 0.03% *without having been fit to it* — its S came from
Bi's V/F and Ka analytically — which is the independent check that makes it
trustworthy. TE, TP and TU did not:

| | S before | S implied | Ratio | Steady-state Cavg before → after |
|---|---|---|---|---|
| TE | 923.0 | 457.67 | 2.02× high | 100 mg q7d: 1141 → 566 ng/dL |
| TP | 359.0 | 457.67 | 0.78× low | 50 mg q2d: 903 → 1151 ng/dL |
| TU | 214.0 | 457.67 | 0.47× low | 1000 mg q70d: 232 → 496 ng/dL |

They were also mutually inconsistent, so the app told users on different esters
different things about the same clearance. TE is the clearest gain: it contradicted
its primary-sourced sibling TC by 2× despite the two being clinically
near-interchangeable, and would have shown a standard 100 mg/week regimen at
Cmax 1753 ng/dL — a level that reads as clearly supraphysiological.

All four now share one S wherever they share a `ke`, which is not a copy-paste
artifact: S depends only on `ke` and clearance.

Guarded by `testosteroneScalingSatisfiesClearanceIdentity` and
`cypionateScalingMatchesAnalyticForm`.

### What is still open

**TE, TP and TU keep the placeholder 2 h `eliminationHalfLifeHours`.** Their magnitude
is now right; their *shape* is not. Tmax lands at 0.3–0.7 d against published windows
of 1.5–7 d, so the peak arrives days early and the curvature between peak and trough
is wrong.

Why they were not fitted:

1. **TE's usable steady-state profile is subcutaneous** (100 mg/week, week 6:
   Cmax 1427, Cmin 584, Cavg 895.5 ng/dL, Tmax 33.9 h). SC absorbs more slowly and
   flatter than the IM route modeled here, so its `ka` does not transfer without
   justification. That figure also comes from a secondary summary, not a primary table.
2. **TP has sparse published PK data.**
3. **TU needs a structurally different model** — see §4 — not merely a different `ka`.

A visible consequence, deliberately left in place and asserted by a test
(`undecanoatePeakTimeIsUncalibrated`): TU's modeled Tmax (0.66 d) is now *earlier* than
TC's (1.84 d), inverting the clinical ordering. That test passed before this pass only
because TC was also wrong, in the same direction, by more. It now documents the
inversion rather than hiding it, and instructs whoever fixes TU's `ka` to delete it and
restore the clinical assertion.

**Action:** someone with institutional access should pull the TE Phase II autoinjector
study (IM arm) and any primary TP source. `fit_testosterone.py` will fit them unchanged
once the targets are trustworthy.

---

## 4. TU needs a different model, not different constants

A two-parameter Bateman over a 70-day interval produces a peak/trough ratio of **~11×**.
The real drug is ~2–3×.

This is structural. No choice of (ka, ke, S) in a 2-parameter model reproduces that
flatness — it needs a 3-parameter or population-PK fit.

The §3 magnitude correction improves TU's Cavg (232 → 496 ng/dL exogenous, against a
published ~500–600 total) but makes its Cmax overshoot, because correcting magnitude
cannot correct shape. That trade was taken knowingly: Cavg is what clinicians titrate on
and what a user lives at, and the peak was already wrong before.

**Action:** treat as a modeling enhancement. Explicitly deferred — a 3-parameter engine
is out of scope for a calibration pass. Until then TU predictions are directionally
useful and quantitatively poor across the dosing interval.

---

## 5. User-visible impact

Predictions move for a lot of users in this pass. Nothing about anyone's actual hormone
levels has changed; the previous numbers were wrong.

| Who | Change |
|---|---|
| EV / EC injectable (2026-07-29) | −52% (EV), −67% (EC) |
| TE injectable | steady-state Cavg roughly halves |
| TP injectable | roughly +27% |
| TU injectable | Cavg roughly doubles; single-dose projection falls ~2.4× because the projected interval was corrected |
| Testosterone gel | ~1090× reduction — was reading six figures |
| Oral testosterone | ~3600× reduction — was reading seven figures |
| Estradiol cream, onboarded in-app | large reduction — see §6a |
| Estradiol cream / oral, configured from Settings | unchanged |

The testosterone gel and oral testosterone figures are not typos. Those routes fell
through to hardcoded scaling constants; see the `scalingConstant` doc comment in
`PharmacokineticConstants.swift`.

Half-life labels also change in Settings and Onboarding (TC 8.0 → 3.8 days).

**No release note was written for this pass** — the app is not yet deployed, so there
are no existing users to inform. That decision needs revisiting before launch: if any of
these numbers ship and then move again, the tone matters. Users of this app are tracking
a medical transition, and a sudden apparent halving of their levels is alarming if it
arrives unexplained.

---

## 6. The amplitude re-anchoring was an engineering call

This deserves explicit clinical ratification rather than quiet acceptance.

The app's documented single-dose targets and the published literature were **mutually
unsatisfiable**:

| | App documented target | Literature (Table 9) | Ratio |
|---|---|---|---|
| EV | 2 mg → 250 pg/mL | 2 mg → ~118 pg/mL | 2.1× |
| EC | 2 mg → 180 pg/mL | 2 mg → ~62 pg/mL | 3.1× |

Holding the app targets put steady state **+110% (EV) / +206% (EC)** above
transfemscience Table 10. Anchoring to Table 10 instead matches published Cmax *and*
Cmin to within 0.1%, and — as an independent check not fit to — lands single-dose Cmax
within 1% (EV) / 5% (EC) of Table 9.

The literature-anchored choice was taken. But note what it implies: **the app's
documented targets, which claimed provenance from Düsterberg et al. and Tiong et al., do
not match those sources.** Whoever set them either used a different reference
population/assay or made an error. That provenance question is unresolved and should be
answered, not papered over.

The same pattern recurred on 2026-07-31 for testosterone: the TE/TP/TU single-dose peak
targets written in the doc comment are also not simultaneously reachable with correct
steady-state behaviour, and steady state was chosen again for the same reason. Those
single-dose figures are now *derived* values, not enforced targets.

Related, already corrected: the shipped EC constant (S = 2700) produced 51 pg/mL for a
2 mg dose, **not the 180 its own comment claimed** (−71.5%). Every other ester matched
its stated target to within 0.1%, which suggests that one value was never validated
against the target written beside it. Worth asking how that survived review, since the
same process produced the others.

### 6a. Two defects found by running personas rather than by inspection

Both were reachable from the UI and both are fixed.

**Testosterone on a non-injectable route** used hardcoded scaling constants. The lookup
in `estimatedLevels` was guarded on `medication == "Estrogen"`, so a testosterone dose on
the Oral or Cream route fell through to the literals 12000.0 / 8000.0 — the
pre-2026-07-28 *estrogen* values that this codebase already documents as ~9.6× and ~52×
too large even for estrogen. Compounded with the wrong EDF (the stored injectable
ester's, not the route's) and a hardcoded absorption rate, a 50 mg/day testosterone gel
regimen returned ≈605,000 ng/dL against a label value of 555.

Reachable because `administrationMethods` offered every route for every medication while
`availableEsters` returned `[]` for testosterone + Oral/Cream, leaving the injectable
ester silently selected.

**Estradiol cream, onboarded in-app**, stored the ester as the raw method name `"Cream"`,
which matches no case in `MedicationEster`. The lookup failed the same way and used the
hardcoded 8000. Users who configured the identical route from Settings stored
`"Transdermal"` and were unaffected. Both ends are fixed: onboarding now stores the route
pseudo-ester, and `MedicationManager.effectiveEsterName` makes the route — not the stored
string — decide the constants, which also repairs existing records.

### 6b. Forward projection assumed a 7-day interval for every injectable

When a user has logged exactly one dose, the chart projects a future cadence. That
interval came from the administration method, which returns 7 days for anything
injectable. For TU — dosed every 10–14 weeks — a single logged 1000 mg dose was projected
as *weekly* 1000 mg injections, reaching ~2850 ng/dL against a single-dose ~1190. TP was
under-projected for the mirror-image reason.

Fixed by `typicalIntervalDays` on both ester enums. A user-set `customFrequencyDays`
still wins.

### Also flagged, deliberately unchanged

The TU target range (400–700 ng/dL) written in the doc comment sits well below the
~1100 ng/dL Cmax reported for a single 1000 mg injection (Wang et al. 2010). It may be
describing an intended steady-state trough rather than a single-dose peak. **No numeric
change made** pending product/clinical confirmation of which quantity it means.

---

## 7. Oral estradiol Tmax is too late — **new 2026-07-31**

The engine's oral rate constants are ka = 2.5 /day and ke = 1.386 /day, giving
Tmax = 12.7 h. Published oral estradiol Tmax is on the order of 4–8 h.

The consequence shows up on a BID schedule: Tmax exceeds the 12 h dosing interval, so
each dose is still rising when the next arrives and the modeled curve flattens to a
peak/trough of ~1.1× across the day. Real oral estradiol swings considerably more. This
is visible in `personas.py` persona 3 (Priya).

Cavg is unaffected — it depends only on dose rate, F and ke — so average and
trough-adjacent numbers remain usable. The intraday peak is under-modeled.

Note also that the engine's own comment described ka = 2.5 as "≈1h absorption", which is
arithmetically wrong: ln2/2.5 d = 6.7 h. That comment is gone along with the hardcoded
literals; the rates now live in `MedicationEster.oral` where they can be seen and changed.

**Action:** refitting `ka` requires re-deriving S against the same source, since the two
are coupled through the peak. Out of scope for this pass; the numbers were restated
exactly (0.5 d → 0.2773 d, 3.0 h → 12.0035 h) so that oral E2 predictions are
bit-identical to before while the constants stop lying about what the engine uses.

---

## 8. Transdermal intraday ripple is structurally under-modeled — **new 2026-07-31**

The transdermal route is modeled as 24 hourly micro-doses, each decaying
single-exponentially, with no absorption phase. That construction tops out at a
Cmax/Cmin of about 1.05 for testosterone gel, against an observed 2.24 in the AndroGel
1% label.

Reproducing 2.24 would require a terminal half-life near 1 h, which contradicts the
label's own 48–72 h washout statement by an order of magnitude. The two cannot be
satisfied together in this model.

Cavg is correct (fit to the label, 0.0% error). Peak-to-trough within a day is flattened.
Same structural class of problem as §4.

---

## 9. Transdermal dose-response is anchored to one arm — **new 2026-07-31**

The AndroGel 1% label's dose-response is markedly sublinear: 50 mg → Cavg 555,
75 mg → 601, 100 mg → 713 ng/dL. The 1.62% label inverts outright — 81 mg Cavg 537 is
*below* 60.75 mg Cavg 643.

That is a titration artifact: higher-dose arms are enriched for poor absorbers, because
subjects were escalated when they responded badly. It is selection confounding, not
saturable pharmacokinetics, and a linear model should not be bent to reproduce it.

S is anchored to the **50 mg arm** — the standard starting dose and the least
selection-confounded. Predictions at 75 and 100 mg therefore run high by roughly 39% and
56% against the label's own numbers. `fit_testosterone.py` prints the least-squares
alternative for comparison.

Gel absorption also varies enormously between individuals; the app's calibration factor
against blood tests is the intended remedy.

---

## Reproducing any of this

```bash
python3 .pk_analysis/fit_constants.py      # estrogen derivation + before/after errors
python3 .pk_analysis/fit_testosterone.py   # testosterone derivation: TC, gel, oral
python3 .pk_analysis/verify_constants.py   # independent check of the SHIPPED constants
python3 .pk_analysis/personas.py           # 8 end-to-end user scenarios
python3 .pk_analysis/run_scenarios.py      # literature validation (Parts A–E)
python3 .pk_analysis/test_users.py         # earlier persona set
```

`verify_constants.py` is the one to run first. It is deliberately *not* the fitting code:
it takes the shipped numbers at face value, drives them through the same summation the
app performs, and compares against the source figures. A fit that agrees with itself
proves nothing.

The Python replica mirrors the Swift math exactly and is kept in sync with
`PharmacokineticConstants.swift`. **If you change a constant in Swift, change it in
`pk_engine_replica.py` too** — the validation scripts read from the replica.
