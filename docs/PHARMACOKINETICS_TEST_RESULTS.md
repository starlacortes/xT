# Pharmacokinetic Model — Test Results

**Date**: 2026-07-26
**Framework**: Swift Testing
**Target**: `xTTests/PharmacokineticTests`
**Status**: 75 passed / 0 failed (100%)

---

## Suite Results

### Ester Constants — Physical Plausibility
**12 tests passed**

Validates all `MedicationEster` and `TestosteroneEster` enum constants against known clinical values:
- Half-lives match documented values (EV=2.0d, EC=8.5d, Oral=0.5d, TD=1.5d, TC=8.0d, TE=7.0d, TP=1.0d, TU=20.0d)
- Elimination half-lives consistent (E2=3h, T=2h)
- Ester weight factors match molecular-weight calculations (E2 base=272.4, T base=288.4 g/mol)
- Bioavailability matches route (injectable=1.0, oral=0.05, transdermal=0.15)
- Effective dose factor = EWF x bioavailability
- Scaling constants within clinical ranges (E2: 1000-15000, T: 3-25)
- Relative ordering correct (TP scaling > TC scaling; TU scaling < TC scaling)
- Half-life ordering correct (EV < EC; TU longest)

### Bateman Biexponential — Mathematical Correctness
**6 tests passed**

Verifies the core Bateman function against key mathematical properties:
- `C(0) = 0` (no dose contribution the instant of injection)
- `C(∞) = 0` (concentration approaches zero as t → ∞)
- Positive values for all positive t
- Single-peak, unimodal curve (strictly rising before peak, strictly falling after)
- `ka ≈ ke` limit approximation is continuous and matches analytical form

### Flip-Flop Kinetics — Physiological Correctness
**2 tests passed**

Confirms depot ester absorption is absorption-limited:
- Depot esters (EV, EC, TC, TP) all satisfy `ka ≪ ke` (flip-flop condition)
- EV: `ka/ke ≈ 0.063`, EC: `ka/ke ≈ 0.015`, TC: `ka/ke ≈ 0.010`, TP: `ka/ke ≈ 0.083`
- Oral route: `ka > ke` (absorption faster than elimination — NOT flip-flop)

### Time to Peak — Pharmacodynamic Accuracy
**6 tests passed**

Validates `expectedTimeToPeak()` against published clinical PK data:
- EV t_max ≈ 0.3–0.8d (~12 hours, matches clinical observations)
- EC t_max ≈ 0.5–3.0d (slower depot absorption)
- TC t_max ≈ 0.5–3.0d
- TP t_max ≈ 0.1–0.6d (rapid peak, ~8 hours)
- TU t_max > TC t_max (longer half-life → later peak, confirms ordering)

### Dynamic Baseline — Endogenous Suppression
**6 tests passed**

Tests the saturating exponential taper model:
- Anti-androgen use immediately returns suppressed baseline (15 ng/dL for T)
- No HRT start date returns full baseline (100 pg/mL E2, 600 ng/dL T)
- >2 years HRT returns fully suppressed baseline (5 pg/mL E2)
- Baseline decreases monotonically over time during suppression phase
- Fast suppression (4wk) produces lower baseline than slow suppression (12wk) at the same time point
- Baseline always bounded between suppressed and full values across entire timeline

### Deviation Classification — Calibration Ratio Binning
**9 tests passed**

Verifies the ratio-based deviation classifier:
- 1.0x → "On Track"
- <0.5x → "Critically Below Expected"
- 0.5–0.7x → "Below Expected"
- 0.7–1.3x → "On Track" (verified at boundaries 0.7, 0.85, 1.0, 1.15, 1.29)
- 1.3–2.0x → "Above Expected"
- >2.0x → "Unusually High"
- Low predicted value (<1.0) → "Unable to Compare"
- Boundary values at exactly 0.5, 0.7, 1.3, 2.0 match expected bins

### Safety Overrides — Clinical Safety Flags
**6 tests passed**

Validates safety override logic for high-risk clinical scenarios:
- E2 > 1000 pg/mL → "Very High – Safety Check"
- E2 exactly 1000 → no flag (boundary non-inclusive)
- T > 1500 ng/dL → "Supraphysiological"
- E2 < 50 at trough → "Sub-Therapeutic (Trough)"
- E2 < 50 NOT at trough → no flag (context-sensitive)
- Normal levels (E2=200, T=600) → no overrides

### Aromatization — T→E2 Conversion
**5 tests passed**

Tests the 0.2% aromatization estimator:
- 1000 ng/dL T → 2.0 pg/mL E2 (correct conversion factor)
- Zero T → zero E2
- Elevated assessment: E2 > 40 pg/mL from aromatization triggers warning
- Normal assessment: E2 10–40 pg/mL reports "within male reference range"
- Linear scaling: 0.002 multiplier holds across full range (100–10,000 ng/dL)

### Dose Intensity — Dose Scaling Computation
**4 tests passed**

Tests `relativeDoseIntensity` computation:
- No doses → defaults to 1.0
- Standard 2mg E2 dose → intensity ≈ 1.0
- Double standard dose (4mg E2) → intensity > 1.5
- Half standard T dose (25mg) → intensity < 1.0

### PK Engine — Nominal Dosing Scenarios
**5 tests passed**

End-to-end validation of the full PK pipeline:
- Single 2mg EV dose produces clinically plausible peak (150–400 pg/mL) with proper decay
- Single 100mg TC dose produces clinically plausible peak (400–1200 ng/dL)
- Oral E2 (2mg) produces rapid spike and fast decay (24h level << peak)
- Calibration factor (α=1.5) proportionally scales all output levels
- Zero-dose scenario produces baseline-only levels (~5 pg/mL suppressed)

### PK Engine — Edge Cases & Robustness
**6 tests passed**

Boundary-condition and robustness testing:
- Empty dose history returns empty array
- No medication selected returns empty array
- Zero dose amount produces near-baseline-only levels
- Start=end produces exactly one data point
- Start after end produces empty array (no reverse traversal)
- Finer stepDays produces more data points than coarse
- 90-day-old dose contributes negligible amounts (<10 pg/mL above baseline)

### Superposition — Multi-Dose Contributions
**1 test passed**

- Two-dose scenario: dual-dose level ≥ single-dose level (additive superposition)

### Calibration Factor — Alpha Computation & Clamping
**2 tests passed**

- Alpha clamps to clinical range [0.2, 5.0] for both extremely low and extremely high measured values
- No blood tests → calibration factor is nil

### Testosterone Ester — PK Validation
**2 tests passed**

- TU (undecanoate) produces measurable profile with proper peak detection
- TP (propionate) t_max < TC (cypionate) t_max (confirms faster absorption)

### Contextual Range — Dose-Scaled Targets
**3 tests passed**

- Peak range ceiling exceeds trough max (correct clinical ordering)
- Higher dose intensity shifts targets upward
- Unknown cycle position uses trough min for safety (conservative fallback)

---

## Summary

| Metric | Value |
|--------|-------|
| Total test suites | 15 |
| Total test cases | 75 |
| Passed | 75 |
| Failed | 0 |
| Pass rate | 100% |

All ester constants, Bateman mathematics, flip-flop kinetics, time-to-peak, dynamic baseline, calibration clamping, safety overrides, aromatization, dose intensity, nominal scenarios, edge cases, superposition, and contextual ranges are validated and consistent with the PK model specification in `PHARMACOKINETICS.md`.
