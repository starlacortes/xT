# Testosterone Ester Pharmacokinetics — Research Memo

**Purpose:** answer three questions raised by the `fix/pk-clinical-accuracy` work: (1) what does the published literature actually say about the shape (Tmax, half-life) of each testosterone ester's curve, (2) does closing the remaining gaps (TE/TP/TU "shape," per `OPEN_CONCERNS.md` §3) require a bigger PK-model rewrite, and (3) are the two loose ends the last session flagged (the `tuSingleDosePeak` failure and the transdermal `NaN`) real product bugs or test artifacts.

**Bottom line up front:** the codebase's own `OPEN_CONCERNS.md` §4 assumes TU's flat peak/trough profile needs "a 3-parameter or population-PK model." The published population-PK literature on injectable testosterone undecanoate contradicts that — every population PK analysis found (Pastuszak 2021, the 2022 Journal of Clinical Pharmacology 8-week-interval study) fits TU with a **1-compartment, first-order-absorption/first-order-elimination model** — structurally the same 2-rate-constant Bateman the app already uses. The flatness is a **calibration problem** (the placeholder 2-hour "fast" rate constant is off by roughly two orders of magnitude for TU), not a structural one. A full 3-compartment rewrite is not indicated by the evidence. What *is* indicated: refit TE's and TU's absorption constants against real IM data (found below), and accept that TP stays flagged as uncalibrated because the literature genuinely doesn't support a confident fit.

---

## 1. What the literature says, ester by ester

### Cypionate (TC) — already fixed, no action needed
Confirmed against the primary source already cited in `PharmacokineticConstants.swift`: **Bi et al. 2018**, *CPT: Pharmacometrics & Systems Pharmacology*, doi [10.1002/psp4.12287](https://doi.org/10.1002/psp4.12287). Population PK, Ka = 1.22/day, CL/F = 2.6 kL/day, V/F = 14.4 kL → terminal t½ 3.84 d (exogenous-only), Tmax 1.84 d. This is the one ester in the app with a real primary-source fit, and the code's derivation checks out.

### Enanthate (TE) — a usable IM primary source exists; the code doesn't have it yet
`OPEN_CONCERNS.md` §3 says TE's only usable steady-state data is *subcutaneous* and explicitly asks: "someone with institutional access should pull the TE Phase II autoinjector study (IM arm)." That paper exists, is open access, and — better than what was being searched for — was run in the app's own population:

**Ichihara K, Masumori N, Fujii S, Toda T (2020).** "Pharmacokinetics of Testosterone Enanthate After Intramuscular Injection for Transgender Men." *Androgens: Clinical Research and Therapeutics.* DOI: [10.1089/andro.2020.0002](https://doi.org/10.1089/andro.2020.0002). Open access, n=10 Japanese transgender men, single 250 mg IM dose (Enarmon Depot).

Key reported values:
- **Total testosterone Tmax: 1.7 ± 0.9 days** (all subjects peaked within 3 days)
- **Total testosterone terminal half-life: 6.6 ± 1.9 days**
- Cmax 29.4 ± 17.1 ng/mL (2940 ng/dL) after a 250 mg dose
- Absorption rate constant (ka), calculable in 4/10 subjects: 2.82, 3.16, 0.49, 1.38 /day
- CLtot/F 14.3 ± 6.5 L/day/kg; Vd/F 118.7 ± 68.3 L/kg (large inter-individual spread — CV 0.58 on Vd/F)
- Explicitly modeled as **"a one-compartment model with first-order absorption"** — not two- or three-compartment
- No mention of "flip-flop" kinetics in the paper; the reported ka values (mean ≈ 2/day) are well above the elimination rate implied by the 6.6-day half-life (≈0.105/day), meaning absorption is the fast process and elimination is what's actually rate-limiting the terminal decline — the normal (non-flip-flop) case

This is directly actionable. The app's current `halfLifeDays = 7.0` for TE (the "slow, terminal" slot in its parameterization) is already close to Ichihara's 6.6-day terminal half-life — that part was accidentally almost right. What's wrong is `eliminationHalfLifeHours = 2.0` (the placeholder "fast" slot), which should represent absorption and currently forces Tmax to ~0.5 days. Using Ichihara's mean ka (≈2/day → absorption half-life ≈8 hours) instead of the 2-hour placeholder would move modeled Tmax from ~0.5 days to something in the 1–2 day range, in line with the observed 1.7 days — closing the gap flagged in `OPEN_CONCERNS.md` §3 for TE specifically, with a source that's actually a better match for this app's population than the SC data that was previously rejected.

### Undecanoate (TU) — the model family is fine; the rate constants are two orders of magnitude off
Three sources triangulate here:

**Zhang GY, Gu YQ, Wang XH, Cui YG, Bremner WJ (1998).** "A pharmacokinetic study of injectable testosterone undecanoate in hypogonadal men." *J Androl* 19(6):761-8. [PubMed 9876028](https://pubmed.ncbi.nlm.nih.gov/9876028/). 500/1000 mg IM in 8 Klinefelter patients: peak T at end of week 1 (day 7), **terminal elimination half-life 18.3 ± 2.3 days (500 mg) / 23.7 ± 2.7 days (1000 mg)**, mean residence time ~21–23 days.

**Wang C et al. (2010).** "Pharmacokinetics and Safety of Long-Acting Testosterone Undecanoate Injections in Hypogonadal Men: An 84-Week Phase III Clinical Trial." *J Androl*, [doi 10.2164/jandrol.109.009597](https://onlinelibrary.wiley.com/doi/full/10.2164/jandrol.109.009597) — already the source the app cites for its TU Cmax target. At week 12 steady state: peak 27.4 ± 7.5 nmol/L (789.8 ± 215.4 ng/dL), trough 15.1 ± 3.8 nmol/L (435.6 ± 109.2 ng/dL) — **a peak/trough ratio of 1.8**, consistent with the "real drug is ~2–3×" figure already in `OPEN_CONCERNS.md`.

**Pastuszak AW et al. (2021).** "Population Pharmacokinetic Modeling and Simulations to Evaluate a Potential Dose Regimen of Testosterone Undecanoate in Hypogonadal Males." *J Clin Pharmacol.* [PubMed 34269421](https://pubmed.ncbi.nlm.nih.gov/34269421/) — this is the direct answer to the "what model type does TU need" question. Quoting the abstract: **"A 1-compartment model with first-order absorption into the central compartment and first-order elimination from the central compartment"** best described IM TU pharmacokinetics, with body weight and SHBG as significant covariates. Aveed's own Phase 3 data (750 mg IM) shows Tmax at a **median of 7 days** (range 4–42 days).

Putting this together: TU's flat curve is not evidence that the 2-rate-constant Bateman is structurally inadequate — the literature's own best-fit model *is* a 2-rate-constant Bateman. It's evidence that the app's TU rate constants are wrong in a specific, correctable way. Currently `halfLifeDays = 20.0` (already a reasonable match to Zhang's 18–24 day terminal half-life) paired with the same placeholder `eliminationHalfLifeHours = 2.0` used for TE/TP — which forces Tmax to ~0.66 days against an observed ~7 days. Because both the terminal half-life (~20 d) and the true absorption half-life (needed to hit Tmax ≈ 7 d) are slow and much closer in magnitude than the current 20-day/2-hour split, refitting `ka` alone should substantially flatten the modeled peak/trough ratio toward the observed ~1.8–3×, without touching the model's structure.

### Propionate (TP) — genuinely sparse; recommend leaving flagged, not fabricating a fit
The best available source remains what the code's comments already point to: **Behre HM, Wang C, Handelsman DJ, Nieschlag E (2004),** "Pharmacology of testosterone preparations," in *Testosterone: Action, Deficiency, Substitution* (Cambridge Univ. Press) — a textbook chapter, not a primary PK study, showing a simulated curve for 50 mg twice-weekly dosing rather than reporting fitted ka/ke or raw single-dose concentration-time data. A 1974 case series (3 men, 20 mg TP + 115.7 mg TE combined) is the only other figure surfaced, and it's confounded by being a mixed-ester injection. This confirms rather than resolves `OPEN_CONCERNS.md`'s existing assessment — TP should stay marked `isTmaxCalibrated = false` rather than being given a fabricated-precision fit. If a real fit is wanted later, the actionable path is the same one `OPEN_CONCERNS.md` already names: find a primary single-dose IM TP PK study (none surfaced here), not a structural model change.

### Transdermal — no change indicated
Nothing found contradicts the app's existing AndroGel-label-anchored constants or its documented structural limitation (§8/§9 of `OPEN_CONCERNS.md`: the 24-hourly-microdose model can't simultaneously match the label's 2.24 Cmax/Cmin ripple and its 48–72 h washout). That's a separately-flagged, already-understood limitation, not part of this ask.

---

## 2. PK model trade-offs: when does a testosterone ester actually need more than 2 rate constants?

The app's current architecture — one absorption rate `ka`, one elimination rate `ke`, superposed across doses — is a **one-compartment model with first-order absorption**, solved analytically as the Bateman function. This is the same model family the FDA-facing population PK literature above uses for every injectable testosterone ester examined (Bi 2018 for TC, Ichihara 2020 for TE, Pastuszak 2021 for TU). That's worth sitting with: the trade-off question isn't really "1 vs 2 vs 3 compartments" for *this* class of drug, because the published answer for all three calibrated esters is the same 2-rate-constant structure. The three-compartment framing in `OPEN_CONCERNS.md` §4 appears to have been a reasonable engineering hypothesis (a 2-parameter curve with grossly mismatched rate constants can't reproduce a flat curve, therefore add parameters) that the literature doesn't actually support once you go looking — the fix is recalibration, not restructuring.

Where a genuinely more complex model *would* be justified, for calibration:

- **A second absorption pathway (dual/parallel first-order absorption).** This is a real, distinct architecture change — not "three compartments" in the classical PK sense, but two parallel `ka` values feeding one central compartment, used when a depot releases drug in two physically distinct ways (e.g., a fast-dissolving fraction plus a slow-release oily fraction). Searching for this specifically for TU turned up no published evidence that it's used or needed — the Pastuszak and Aveed FDA-facing models are single-pathway first-order absorption. If a future TU refit still can't hit both Tmax and the 1.8× peak/trough ratio simultaneously with one `ka`, this is the next thing to try, not a full compartmental rewrite.
- **A true peripheral compartment (classical 2- or 3-compartment PK).** This matters when a drug redistributes into a slow-equilibrating tissue depot *after* reaching the central compartment, producing a multi-phase (not single-exponential) terminal decline visible in log-concentration-vs-time data. None of the sources reviewed report a non-single-exponential terminal phase for any injected testosterone ester — the terminal slope is consistently described as one straight line on a semi-log plot, which is what justifies the 1-compartment fits used throughout this literature. This is the strongest reason not to add compartments here: nobody who has fit real concentration-time data to these drugs found a need to.
- **Population PK with inter-individual variability (IIV) terms.** This is the axis where the literature genuinely goes further than the app: Bi 2018, Ichihara 2020, and Pastuszak 2021 all report between-subject variance on clearance and volume (e.g., Ichihara's Vd/F CV of 0.58 — an 8-fold individual range). The app's existing blood-test calibration factor (α, clamped 0.2–5.0×) is a pragmatic per-user analog of this, applied post hoc rather than as a formal mixed-effects model. That's a reasonable engineering trade-off for a consumer app (no institutional access to raw data, no need to report population confidence intervals) rather than a gap that needs a rewrite.

**Recommendation:** don't rewrite the engine to a 3-compartment model. The 2-rate-constant Bateman is the right structural choice, matches the published pharmacometrics for this drug class, and the actual defects are calibration (wrong `ka` for TE and TU) plus one genuinely open data gap (TP). Reserve the dual-absorption-pathway idea as a fallback only if refitting TU's single `ka` against Wang 2010's 1.8× peak/trough target fails to converge — worth a quick check in `.pk_analysis/fit_testosterone.py` before assuming it's needed.

---

## 3. The two loose ends from the last session

### `tuSingleDosePeak` — confirmed test-isolation defect, not a PK regression
The transcript's diagnosis checks out against the actual code. `MedicationManager.loadUserPreferences()` (`MedicationManager+Persistence.swift:85-93`) sets `customFrequencyDays` from a SwiftData-backed `UserPreferences` fetch, and `loadTransientPreferences()` (lines 34-46) additionally hydrates it from `UserDefaults`. Neither is reset by `clearSelection()`. Since `MedicationManager()` runs this on init and Swift Testing executes in parallel, a `customFrequencyDays` value left over from another test (or a real on-device default) leaks into `tuSingleDosePeak`, and the projection logic then uses `freqDays = 7` instead of TU's correct 70-day interval — reproducing almost exactly the superposition arithmetic in the transcript (three weekly 1000 mg doses ≈ 2846 ng/dL). This is the same class of defect `OPEN_CONCERNS.md` §1 already recorded as "resolved" for the singleton race; this is a second, narrower instance (state leak, not a race) that the resolution didn't cover. The one-line test fix (`mgr.customFrequencyDays = nil`) is correct as a patch, but given this is the second time state-leak-via-persistence has broken a PK test, it's worth a follow-up ticket for a shared `MedicationManager.makeIsolated()` test helper that clears both the UserDefaults keys and the SwiftData `UserPreferences` row, rather than relying on every new test to remember it.

### Transdermal `timeToPeakDays` returning `NaN` — working as designed, guard was the right call
This isn't a bug so much as an honest answer surfacing somewhere it hadn't before. `TestosteroneEster.transdermal.eliminationHalfLifeHours = 0` by design (the route is modeled as 24 hourly micro-doses with `ke = 0`, no absorption phase — see `PharmacokineticConstants.swift:363` and the doc comment on `timeToPeakDays` at line 375, which already states "Returns NaN for `.transdermal`... NaN is the honest answer"). `ke = 0` makes `ka/ke` infinite, and `log(∞)` is `NaN` — mathematically there is no time-to-peak for a route with no elimination phase in this model, so `NaN` is correct, not a defect. The real risk was `Int(Double.nan)` trapping in Swift once the value became reachable from a picker; gating the UI on `.isFinite` (matching the existing `isTmaxCalibrated` pattern already used to keep TE/TP/TU's uncalibrated Tmax out of user-facing copy) is the right fix and needed no numeric change.

---

## 4. Suggested priority order

1. Refit TE's absorption constant against Ichihara 2020 (real IM data, real population match) — closes `OPEN_CONCERNS.md` §3 for TE specifically.
2. Refit TU's absorption constant against Zhang 1998 (Tmax ≈7 d, terminal t½ 18–24 d) and validate against Wang 2010's 1.8× peak/trough — likely closes most of §4 without a model change; fall back to dual-absorption-pathway only if a single `ka` can't hit both targets.
3. Leave TP flagged uncalibrated; the literature doesn't support more precision than that.
4. Land the `tuSingleDosePeak` one-line fix, and open a follow-up ticket for a shared test-isolation helper that resets persisted PK state (UserDefaults + SwiftData `UserPreferences`) rather than patching this test alone.
5. Keep the `.isFinite` guard for transdermal as shipped — no further change needed there.

---

## Sources

- Bi P, et al. (2018). Population PK of testosterone cypionate. *CPT Pharmacometrics Syst Pharmacol.* doi: [10.1002/psp4.12287](https://doi.org/10.1002/psp4.12287)
- Ichihara K, Masumori N, Fujii S, Toda T (2020). Pharmacokinetics of Testosterone Enanthate After Intramuscular Injection for Transgender Men. *Androgens: Clinical Research and Therapeutics.* doi: [10.1089/andro.2020.0002](https://doi.org/10.1089/andro.2020.0002)
- Zhang GY, Gu YQ, Wang XH, Cui YG, Bremner WJ (1998). A pharmacokinetic study of injectable testosterone undecanoate in hypogonadal men. *J Androl* 19(6):761-8. [PMID 9876028](https://pubmed.ncbi.nlm.nih.gov/9876028/)
- Wang C, et al. (2010). Pharmacokinetics and Safety of Long-Acting Testosterone Undecanoate Injections in Hypogonadal Men: An 84-Week Phase III Clinical Trial. *J Androl.* doi: [10.2164/jandrol.109.009597](https://onlinelibrary.wiley.com/doi/full/10.2164/jandrol.109.009597)
- Pastuszak AW, Gittelman M, Tursi JP, Jaffe JS, Miner MM (2021). Population Pharmacokinetic Modeling and Simulations to Evaluate a Potential Dose Regimen of Testosterone Undecanoate in Hypogonadal Males. *J Clin Pharmacol.* [PMID 34269421](https://pubmed.ncbi.nlm.nih.gov/34269421/)
- Behre HM, Wang C, Handelsman DJ, Nieschlag E (2004). Pharmacology of testosterone preparations. In *Testosterone: Action, Deficiency, Substitution*, Cambridge University Press.
- Aveed (testosterone undecanoate injection) prescribing information / FDA clinical pharmacology review — 750 mg IM Tmax median 7 days (range 4–42).
- In-repo: `docs/research/PHARMACOKINETICS.md`, `.pk_analysis/OPEN_CONCERNS.md`, `xT/Shared/PharmacokineticConstants.swift`, `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift`, `xT/Managers/Medication/MedicationManager+Persistence.swift`.
