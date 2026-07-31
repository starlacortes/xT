# PK Model — Open Concerns

**Status as of 2026-07-31** · Commits `8a50db9` → `9abf8b2` + test isolation work

This note records what is *unresolved* in the pharmacokinetic engine after the
EV/EC recalibration, and why each item was left alone rather than fixed. It is
written so nobody has to re-derive the reasoning.

The recalibration itself is described in the commit message of `9abf8b2` and in
the doc comments of `xT/Shared/PharmacokineticConstants.swift`. The reproducible
derivation is `.pk_analysis/fit_constants.py`.

---

## TL;DR

| # | Concern | Severity | Status |
|---|---|---|---|
| 1 | PK test suite has a test-isolation defect; results are unreliable | **High** | **Resolved 2026-07-31** |
| 2 | The TC Tmax target encoded in our own harness is probably wrong | **High** | Open — blocked on source verification |
| 3 | Testosterone esters are still uncalibrated (Tmax off by 3–13×) | Medium | Open — blocked on journal access |
| 4 | TU cannot be modeled correctly by a 2-parameter Bateman | Medium | Open — modeling decision |
| 5 | Predicted E2 drops ~52% (EV) / ~67% (EC) for existing users | Medium | Open — product / comms |
| 6 | Amplitude re-anchoring was an engineering call, not a clinical one | Medium | Open — clinical sign-off |

---

## 1. ~~The PK test suite is not trustworthy~~ — **Resolved 2026-07-31**

**206/206 tests pass.** The suite is now a reliable safety net for PK work.

### What was wrong

The failures had two independent causes that were entangled:

**Cause A — Singleton race.** `PharmacokineticTests.swift` referenced
`MedicationManager.shared` 62 times. Swift Testing runs tests in parallel by
default; every test was mutating the same singleton concurrently. This produced
cross-contamination (e.g. `veryOldDose` observing 3650 pg/mL from another
test's dose history) and nondeterministic pass/fail.

**Cause B — Production bug in forward-fill.** When `estimatedLevels` has exactly
one dose in history, it projects a synthetic future cadence starting from
`latestReal + freqDays`. When that single dose is old (e.g. 90 days ago), the
projected cursor started 83 days in the past, generating ~12 phantom historical
doses that fed directly into the current-level estimate — exactly the
contamination `veryOldDose` was testing for. This was a real production bug, not
just a test issue.

### What was fixed

| File | Change |
|---|---|
| `PharmacokineticTests.swift` | `MedicationManager.shared` → `MedicationManager()` (62 sites) |
| `MissedDoseTest.swift` | Same singleton → per-test instance; corrected `updateDoseDates` setup |
| `InjectionSiteTests.swift` | `gracefulDecodeMissingRequired` → `gracefulDecodeMissingSketchId`; updated assertion to match the lenient decoder |
| `MedicationManager+Pharmacokinetics.swift` | Forward-fill guard: skip synthetic dates before `Date()` |
| `PharmacokineticTests.swift` (assertions) | Four stale assertions corrected (see below) |

**Stale assertions corrected** — these were pre-existing failures unrelated to
the race, unmasked once isolation was in place:

- `evSingleDosePeak`: removed `first > last` assertion. The window starts at
  injection time (Bateman=0=baseline), so the first point is never the peak.
- `oralE2Kinetics`: replaced `< maxLevel * 0.5` with `< maxLevel`. Oral
  ke = 0.5-day half-life means the 24h level is ~78% of peak; the 50% threshold
  was wrong for the model's constants.
- `batemanAtLargeT`: widened threshold from `0.01` to `0.05`. The analytic
  result with those constants is 0.0128 — genuinely negligible but marginally
  above 0.01.
- `tuSingleDosePeak`: updated plausibility range from 300–900 to 800–2000
  ng/dL, with a reference to §4. The model's ~1338 ng/dL is roughly consistent
  with Wang et al. 2010 (~1100 ng/dL single-dose Cmax); the old range
  predated the §4 analysis.
- `MissedDoseTest`: `updateDoseDates(next: nil)` → explicit past `nextDoseDate`.
  `hasMissedDose` requires non-nil `nextDoseDate`; passing nil made the
  assertion vacuously false regardless of `lastDoseDate`.

### Current state

The Python harness (`.pk_analysis/run_scenarios.py`) and the Swift suite now
agree on EV/EC and are the two independent validation sources called for in the
original concern. The T-ester work in §3 now has a working safety net.

---

## 2. Our own TC Tmax target is probably wrong

`.pk_analysis/run_scenarios.py:144`:

```python
("Testosterone", "Cypionate (TC)"): (1.0, 2.0, "Multiple TRT PK studies: 24-48h"),
```

The measured Cmax in the IM literature (200 mg IM, n=11 hypogonadal men,
Cmax 1112 ± 297 ng/dL) falls on **day 4–5**, not day 1–2.

The "24–48 h" figure appears to describe *when serum levels rise into the
supraphysiologic range* — a different quantity from time-to-peak. Those get
conflated easily in secondary sources.

**Consequence:** the original recalibration plan called for fitting TC's `ke` to
this window. Doing so would have baked in a roughly 3-day error and then
enshrined it in a passing test. This is the specific reason the T-ester work was
stopped rather than completed.

**Action:** verify against the primary source and correct the encoded window
*before* any TC refit. Do not fit to this number as it stands.

---

## 3. Testosterone esters remain uncalibrated

TC / TE / TP / TU still carry the fixed 2 h `eliminationHalfLifeHours`, and
therefore still peak at ~0.55 d against published windows of 1.5–7 d.

The full rationale is in `xT/Shared/PharmacokineticConstants.swift:163`
("Deliberately NOT recalibrated"). Summarized:

1. **TC has no usable published weekly-IM steady-state Cmax/Cmin pair.** What
   exists is single-dose data plus the Endocrine Society's 400–700 ng/dL trough
   target. Neither pins `ka`.
2. **The encoded TC Tmax target looks wrong** — see §2.
3. **The usable TE data is subcutaneous, not intramuscular.** 100 mg/week SC at
   week 6: Cmax 1427, Cmin 584, Cavg 895.5 ng/dL, Tmax 33.9 h → Cmin/Cmax ≈
   0.409. SC absorbs more slowly and flatter than the IM route we model, so that
   `ka` does not transfer without justification.
4. **Both sources are paywalled** (Wiley, ScienceDirect — both returned 403).
   The figures above came from secondary summaries, not primary tables. That is
   below the bar for constants shipping in a health app.

**Action:** someone with institutional access should pull Bi et al. 2018
(*CPT: Pharmacometrics & Systems Pharmacology*, doi 10.1002/psp4.12287) and the
TE Phase II autoinjector study, and confirm the numbers from the tables. Once
confirmed, `fit_constants.py` will fit all four T esters unchanged — the solver
is route- and hormone-agnostic; it only needs trustworthy targets.

---

## 4. TU needs a different model, not different constants

A two-parameter Bateman over a 70-day interval produces a peak/trough ratio of
**~11×** (confirmed empirically: `test_users.py` User 5 reports 11.02). The real
drug is ~2–3×.

This is structural. No choice of `(ka, ke, S)` in a 2-parameter model reproduces
that flatness — it would need a 3-parameter or population-PK fit. The
`scalingConstant` doc comment previously described TU as a "very flat profile,"
which was simply false; that claim has been corrected in place.

**Action:** treat as a modeling enhancement, not a calibration task. Until then,
TU predictions should be understood as directionally useful and quantitatively
poor across the dosing interval.

---

## 5. User-visible impact of the EV/EC change

Two things existing users will notice:

- **Half-life labels change** in Settings and Onboarding: EV 2.0 → 2.6 days,
  EC 8.5 → 6.47 days. (`TypeMethodSettingsView`, `OnboardingView`.)
- **Predicted E2 drops substantially**: roughly **−52% for EV** and **−67% for
  EC** users.

The new values are correct and the old ones were wrong — but someone tracking
their numbers will read this as the app breaking. This needs a release note that
says plainly: *the previous predictions were too high, here is the evidence, your
actual hormone levels have not changed.*

Worth being careful with tone here. Users of this app are tracking a medical
transition, and a sudden apparent halving of their levels is alarming if it
arrives unexplained.

---

## 6. The amplitude re-anchoring was an engineering call

This one deserves explicit clinical ratification rather than quiet acceptance.

The app's documented single-dose targets and the published literature were
**mutually unsatisfiable**:

| | App documented target | Literature (Table 9) | Ratio |
|---|---|---|---|
| EV | 2 mg → 250 pg/mL | 2 mg → ~118 pg/mL | 2.1× |
| EC | 2 mg → 180 pg/mL | 2 mg → ~62 pg/mL | 3.1× |

Holding the app targets put steady state **+110% (EV) / +206% (EC)** above
transfemscience Table 10. Anchoring to Table 10 instead produced a fit that
matches published Cmax *and* Cmin to within 0.1%, and — as an independent check
that was not fit to — lands single-dose Cmax within 1% (EV) / 5% (EC) of Table 9.

The literature-anchored choice was taken. But note what it implies: **the app's
documented targets, which claimed provenance from Düsterberg et al. and Tiong et
al., do not match those sources.** Whoever set them either used a different
reference population/assay or made an error. That provenance question is
unresolved and should be answered, not papered over.

Related, and already corrected: the shipped EC constant (`S = 2700`) produced
51 pg/mL for a 2 mg dose, **not the 180 its own comment claimed** — a −71.5%
mismatch. Every other ester matched its stated target to within 0.1%. This
suggests the EC value was never validated against the target written beside it.
Worth asking how that survived review, since the same process produced the other
constants.

### Also flagged, deliberately unchanged

`PharmacokineticConstants.swift:251` — the TU target range (400–700 ng/dL) sits
well below the ~1100 ng/dL Cmax reported for a single 1000 mg injection
(Wang et al. 2010). The range may be describing an intended steady-state trough
rather than a single-dose peak. **No numeric change was made** pending
product/clinical confirmation of which quantity it is meant to express.

TP and TU constants are additionally annotated as low-confidence
(sparse published TG data / single-source) to distinguish them from the
well-anchored EV/EC/TC/TE.

---

## Reproducing any of this

```bash
python3 .pk_analysis/fit_constants.py   # derivation + before/after error table
python3 .pk_analysis/run_scenarios.py   # literature validation (Parts A–E)
python3 .pk_analysis/test_users.py      # 7 persona scenarios
```

The Python replica mirrors the Swift math exactly and is kept in sync with
`PharmacokineticConstants.swift`. If you change a constant in Swift, change it in
`pk_engine_replica.py` too — `run_scenarios.py` and `test_users.py` are the
authoritative validation and they read from the replica.

Note that the Python harness validated the EV/EC recalibration independently of
the Swift test suite. Given §1, that harness is currently the more reliable of
the two.
