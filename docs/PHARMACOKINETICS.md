# Pharmacokinetics & PK Models — All Medication Types

## Overview

xT simulates hormone levels using a superposition-based pharmacokinetic engine. For each medication type (Estrogen, Testosterone, Progesterone) and administration route, the engine builds a predicted concentration-time curve by summing individual dose contributions.

The core mathematical model is the **Bateman biexponential function** for injectable depot routes, with simplified single-exponential or square-wave models for oral and transdermal routes.


## Key Symbols

| Symbol | Meaning |
|--------|---------|
| \(C_i(t)\) | Concentration contribution of a single dose \(i\) at time \(t\) |
| \(D_i^{\text{eff}}\) | Effective dose reaching systemic circulation (mg) |
| \(S\) | Empirical per-ester scaling constant (ratio of F / Vd) |
| \(k_a\) | Absorption rate constant (d⁻¹) |
| \(k_e\) | Elimination rate constant (d⁻¹) |
| \(\Delta t\) | Time elapsed since dose administration (days) |
| \(t_{\text{max}}\) | Time to peak concentration after a single dose |
| \(\alpha\) | Blood-test calibration factor (section 6.1) |
| \(R\) | Relative dose intensity ratio (section 8.1) |
| \(B_{\text{full}}\) | Full endogenous gonadal baseline |
| \(B_{\text{suppressed}}\) | Fully suppressed baseline (post-gonadectomy) |

## Glossary

**EWF (Ester Weight Factor)**
: Fraction of active hormone by mass after ester cleavage. Computed as 
\( \text{MW}_{\text{base}} / \text{MW}_{\text{ester}} \). 
E2 base MW = 272.4 g/mol; T base MW = 288.4 g/mol.

**Bioavailability**
: Fraction of administered dose that reaches systemic circulation.
*Injectable depot*: ≈ 100 % (direct IM/SubQ depot).
*Oral*: ≈ 5 % (first-pass hepatic metabolism).
*Transdermal*: ≈ 15 % (skin‑barrier absorption).

**Effective dose factor**
: \( \text{EWF} \times \text{bioavailability} \) — the fraction of administered
dose that reaches systemic circulation as active hormone.

**Scaling constant** \(S\)
: Pre‑tuned empirical constant (\(F / V_d\)) that produces clinically expected
peak concentrations for a given ester. Calibrated from published PK literature.

**Flip‑flop kinetics**
: Condition where absorption is much slower than elimination
(\(k_a \ll k_e\)), making the terminal half‑life absorption‑limited rather than
elimination‑limited (Section 3.2).

**Superposition**
: The total hormone level at any time is the sum of contributions from all
still‑active doses, added to the endogenous baseline (Section 5).


## 1. Hormone Types

### 1.1 Estrogen (E2 — Estradiol)

**Unit**: pg/mL

**Clinical reference ranges** (contextual, dose-scaled):

| Range | Level (pg/mL) |
|-------|---------------|
| Very Low | < 50 |
| Low | 50–100 |
| Optimal | 100–200 |
| High | 200–500 |
| Very High | 500–1000 |
| Safety Ceiling | > 1000 |

**Estradiol esters** — four forms with distinct PK profiles:

| Ester | Half-Life (days) | Elimination t½ (hrs) | EWF | Bioavailability | Scaling Constant | Route |
|-------|-------------------|----------------------|-----|-----------------|-------------------|-------|
| Valerate (EV) | 2.0 | 3.0 | 0.764 | 1.0 | 3150 | Injectable |
| Cypionate (EC) | 8.5 | 3.0 | 0.687 | 1.0 | 2700 | Injectable |
| Oral | 0.5 | 3.0 | 1.0 | 0.05 | 12000 | Oral |
| Transdermal | 1.5 | 3.0 | 1.0 | 0.15 | 8000 | Cream/Gel/Patch |

- **EWF** (Ester Weight Factor) = fraction of active estradiol by mass after ester cleavage (MW E2 base = 272.4 g/mol).
- **Bioavailability**: Injectable depot ≈ 100%; Oral ≈ 5% (first-pass hepatic metabolism); Transdermal ≈ 15% (skin barrier).
- **Effective dose factor** = EWF × bioavailability — the fraction of administered dose that reaches systemic circulation as active E2.
- **Scaling constant** (S = F/Vd): pre-tuned to produce clinically expected peaks (e.g. EV 2 mg → ~250 pg/mL peak; EC 2 mg → ~180 pg/mL; Oral 2 mg → ~60 pg/mL; TD 1 mg → ~50 pg/mL steady state).

### 1.2 Testosterone (T)

**Unit**: ng/dL

**Clinical reference ranges** (contextual, dose-scaled):

| Range | Level (ng/dL) |
|-------|---------------|
| Suppressed | < 50 |
| Low (Feminizing) | 50–100 |
| Moderate | 100–300 |
| Male Range Low | 300–500 |
| Male Range | 500–1000 |
| Very High / Supraphysiological | > 1000 |

**Testosterone esters** — four injectable esters:

| Ester | Half-Life (days) | Elimination t½ (hrs) | EWF | Bioavailability | Scaling Constant |
|-------|-------------------|----------------------|-----|-----------------|-------------------|
| Cypionate (TC) | 8.0 | 2.0 | 0.699 | 1.0 | 11.0 |
| Enanthate (TE) | 7.0 | 2.0 | 0.720 | 1.0 | 11.0 |
| Propionate (TP) | 1.0 | 2.0 | 0.837 | 1.0 | 18.0 |
| Undecanoate (TU) | 20.0 | 2.0 | 0.631 | 1.0 | 5.0 |

- **EWF**: Ester weight factors computed from MW T base = 288.4 g/mol.
- All testosterone esters are **injectable only** (depot IM/SubQ).
- **Scaling constants** tuned for clinical peaks (TC/TE 100 mg → ~600–900 ng/dL; TP 50 mg → ~800–1200 ng/dL; TU 1000 mg → ~400–700 ng/dL, flat profile).

### 1.3 Progesterone

Progesterone is included as a medication option in zone/injection-site selection but **does not yet have a dedicated PK model** in the current implementation. It uses the generic single-exponential fallback.

| Route | Half-Life (fallback) | Zone Preferences |
|-------|----------------------|------------------|
| Injectable | Default (7-day cycle) | Ventrogluteals, Thighs |
| Topical | Daily | Forearms, Wrists, Neck, Upper Chest |
| Patch | Daily | Abdomen, Glutes |


## 2. Administration Routes

### 2.1 Route Classes

| Route | Class | Frequency (default) | PK Model Applied |
|-------|-------|---------------------|------------------|
| Injectable (IM/SubQ) | `.injection` | 7 days | Bateman biexponential |
| Cream / Gel | `.topical` | 1 day | 24-hr square-wave micro-doses |
| Transdermal Patch | `.patch` | 1 day | 24-hr square-wave micro-doses |
| Oral | `.oral` | 1 day | Fast Bateman (ka = 2.5 d⁻¹) |
| Sublingual | `.oral` | 1 day | Fast Bateman (mapped to oral) |

### 2.2 Administration Methods (User-Facing)

| Method | Frequency | Description |
|--------|-----------|-------------|
| Injectable | 7 days (customisable) | IM or SubQ depot injection |
| Cream | 1 day | Topical gel/cream application |
| Oral | 1 day | Oral tablet/pill |


## 3. The Bateman Biexponential Model (Core PK Engine)

### 3.1 Theoretical Foundation

For **injectable depot routes**, the concentration-time profile is governed by first-order absorption from the depot (rate constant k_a) and first-order elimination of free hormone (rate constant k_e). The Bateman biexponential function models the classic "rise-to-peak followed by decay":

\[
C_i(t) = D_i^{\text{eff}} \cdot S \cdot \frac{k_a}{k_a - k_e} \bigl( e^{-k_e \Delta t} - e^{-k_a \Delta t} \bigr)
\]

Both rate constants are derived from half-lives via the standard first-order relationship:

\[
k = \frac{\ln(2)}{t_{1/2}}
\]

- **Absorption rate** \(k_a\): derived from the **terminal (depot) half-life** of the ester in days — e.g. for EV, \(k_a = \ln 2 / 2.0 \approx 0.347\;\text{d}^{-1}\).
- **Elimination rate** \(k_e\): derived from the **free-hormone elimination half-life** converted from hours to days — e.g. for E2, \(t_{1/2,\text{elim}} = 3\;\text{hr} \approx 0.125\;\text{days}\), giving \(k_e = \ln 2 / 0.125 \approx 5.545\;\text{d}^{-1}\).

The Bateman model produces a classic "rise-to-peak followed by decay" curve:

```
   ↑
C  │     ╱‾╲
o  │    ╱    ╲
n  │   ╱      ╲________
c  │  ╱                 ╲___
   │ ╱                       ╲___
   └────────────────────────────────→ time
       ↑-absorption-↑  ↑--elimination--↑
              t_max
```

| Symbol | Definition | Derivation |
|--------|------------|------------|
| \(D_i^{\text{eff}}\) | Effective dose reaching systemic circulation (mg) | dose × EWF × bioavailability |
| \(S\) | Scaling constant (F/Vd ratio) | Pre-tuned per ester from PK literature |
| \(k_a\) | Absorption rate constant (d⁻¹) | \(k_a = \ln 2 / t_{1/2,\text{term}}\) |
| \(k_e\) | Elimination rate constant (d⁻¹) | \(k_e = \ln 2 / (t_{1/2,\text{elim}} / 24)\) |
| \(\Delta t\) | Time elapsed since dose (days) | cursor − doseDate |

### 3.2 Flip-Flop Kinetics

For depot esters, absorption is typically much slower than elimination (\(k_a \ll k_e\)). Under these **flip-flop conditions**, the terminal half-life is absorption-limited, not elimination-limited. This means:

- The clinical half-life the user observes is the **absorption half-life** from the depot.
- The terminal slope of the curve is dominated by \(k_a\), not \(k_e\).
- Time to peak is approximately \(1 / k_a\).

**Example — Estradiol Cypionate (EC)**:
\[
k_a = 0.082\;\text{d}^{-1} \quad \ll \quad k_e = 5.545\;\text{d}^{-1}
\]
Absorption is ~68× slower than elimination, so the clinically observed 8.5-day
half-life is entirely absorption-limited (the depot, not the hormone
clearance).

**Contrast — Propionate (TP)** where \(k_a = 0.693\) is closer to
\(k_e = 8.318\); the terminal slope is a blend of both processes, producing
a shorter, sharper profile.

```
k_a ≪ k_e (flip-flop):         k_a ≈ k_e (non-flip-flop):
  ↑                               ↑
C │  ╱‾‾‾‾‾╲                  C │  ╱╲
  │ ╱        ╲                   │ ╱  ╲
  │╱          ╲___               │╱    ╲___
  └────────────────→ t           └───────────→ t
    absorption-limited              mixed-limited
```

### 3.3 Time to Peak (t_max)

\[
t_{\text{max}} = \frac{\ln(k_a / k_e)}{k_a - k_e}
\]

Under flip-flop kinetics (\(k_a \ll k_e\)), the denominator approaches \(-k_e\),
giving the asymptotic form \(t_{\text{max}} \approx \frac{\ln(k_e / k_a)}{k_e}\)
(not \(1/k_a\) — a common misconception that overestimates the peak time).
The exact Bateman formula is used in the implementation; no approximation is
applied.

### 3.4 ka ≈ ke Edge Case

When the absorption and elimination rate constants are nearly equal (within 0.0001), the limit approximation is used to avoid division by zero:

\[
C_i(t) = D_i^{\text{eff}} \cdot S \cdot k_a \cdot \Delta t \cdot e^{-k_a \Delta t}
\]


## 4. Route-Specific PK Models

### 4.1 Injectable Route — Full Bateman Biexponential

Applied when `AdministrationMethod == .injectable` and per-dose PK parameters are available from the ester enum.

**Rate constants by ester:**

| Ester | \(k_a\) (d⁻¹) | \(k_e\) (d⁻¹) | Source |
|-------|---------------|---------------|--------|
| EV | ln(2) / 2.0 = 0.347 | ln(2) / 0.125 = 5.545 | [1] |
| EC | ln(2) / 8.5 = 0.082 | ln(2) / 0.125 = 5.545 | [1] |
| TC | ln(2) / 8.0 = 0.087 | ln(2) / 0.083 = 8.318 | [2] |
| TE | ln(2) / 7.0 = 0.099 | ln(2) / 0.083 = 8.318 | [2] |
| TP | ln(2) / 1.0 = 0.693 | ln(2) / 0.083 = 8.318 | [2] |
| TU | ln(2) / 20.0 = 0.035 | ln(2) / 0.083 = 8.318 | [2] |

**Superposition**: The final level at any time point is the sum of contributions from all active doses:

\[
C_{\text{total}}(t) = \text{baseline} + \sum_{\text{all doses}} C_i(t)
\]

**Sparse-dose handling**: When only 1 active dose exists (fresh onboarding), synthetic backward/forward doses are generated at the configured frequency interval (±90 days) to produce a smooth, continuous curve centred on the user's last dose.

### 4.2 Oral Route — Fast Bateman

Applied when `administrationMethod == "Oral"`.

| Parameter | Value |
|-----------|-------|
| k_a | 2.5 d⁻¹ (≈1-hour absorption) |
| k_e | 1.386 d⁻¹ (ln(2) / 0.5 day) |
| Scaling | 12000 (calibrated for 2 mg → ~60 pg/mL peak) |

Models the rapid spike 1–2 hours after ingestion followed by a fast drop. The higher k_a produces the characteristic oral "spike" profile with a very short time to peak.

### 4.3 Transdermal Route — 24-Hour Square-Wave

Applied when `administrationMethod == "Cream"` (creams, gels, and patches).

**Mechanism**: Each daily dose is split into 24 hourly micro-doses:

\[
D_{\text{micro}} = \frac{D_i^{\text{eff}}}{24}
\]

One micro-dose event is created for each hour post-application, generating an effective square-wave absorption profile.

| Parameter | Value |
|-----------|-------|
| k_a | ln(2) / 1.5 = 0.462 d⁻¹ |
| k_e | 0 (zero-order release; each micro-dose uses single-exponential decay) |
| Scaling | 8000 (calibrated for 1 mg → ~50 pg/mL steady state) |

This approximates the steady-state plateau of transdermal delivery, avoiding unrealistic spikes.

### 4.4 Generic Fallback — Single-Exponential

For any unmatched route or Progesterone (no dedicated PK model yet):

\[
C_i(t) = D_i^{\text{eff}} \cdot e^{-k \cdot \Delta t}
\]

Where \(k = \ln 2 / \text{halfLife}\) (using the ester or default half-life).


## 5. Superposition of Multiple Doses

The complete level at time \(t\) is:

\[
C_{\text{total}}(t) = \text{baseline}(t) + \alpha \cdot \sum_{i=1}^{n} C_i(t)
\]

Where:
- \(\text{baseline}(t)\) = dynamic endogenous baseline (Section 7)
- \(\alpha\) = calibration factor (Section 6)
- \(C_i(t)\) = contribution of dose \(i\) at time \(t\) (Bateman or simplified model)
- \(n\) = all active dose events (real + synthetic)

Dose events are sorted chronologically; future doses (cursor time < dose time) are skipped.


## 6. Blood Test Calibration Engine

### 6.1 Calibration Factor (α)

Each blood test record computes a calibration factor:

\[
\alpha = \frac{\text{measured level}}{\text{predicted level at draw time}}
\]

Clamped to clinically plausible range: **0.2 ≤ α ≤ 5.0**.

*Rationale*: The 0.2–5.0 clamp prevents extreme over/under-estimation of hormone
levels that would arise from spurious blood-draw values or PK model edge cases.
These bounds correspond to a maximum 5-fold deviation from the population
pharmacokinetic model — consistent with the observed inter-individual
variability in clinical PK studies (Düsterberg et al., and Tiong et al.).
Values outside this range are treated as data-entry errors or pathological
clearance anomalies and are excluded from the calibration pipeline.

The PK model runs at the exact draw time (±30 minutes) to compute the predicted value. If predicted ≈ 0, no calibration factor is stored.

### 6.2 Calibrated Level Pipeline

```
dose history → PK model → raw predicted levels → × α → calibrated levels
```

When `applyCalibration = true`, all predicted levels are multiplied by α before display. When false, raw population-model values are shown (used for deviation analysis).

### 6.3 Deviation Classification

| Ratio (actual / predicted) | Classification |
|----------------------------|----------------|
| < 0.5 | Critically Below Expected |
| 0.5–0.7 | Below Expected |
| 0.7–1.3 | On Track |
| 1.3–2.0 | Above Expected |
| > 2.0 | Unusually High |


## 7. Dynamic Baseline (Endogenous Suppression)

### 7.1 Baselines by Medication Type

| Medication | Full Baseline | Suppressed Baseline |
|------------|---------------|---------------------|
| Estrogen | 100 pg/mL (male gonadal E2) | 5 pg/mL (post-gonadectomy) |
| Testosterone | 600 ng/dL (male gonadal T) | 15 ng/dL (post-gonadectomy / anti-androgen) |

### 7.2 Suppression Taper Function

#### 7.2.1 Core Equation

The dynamic baseline transitions from the full gonadal value to the suppressed value using a **saturating exponential taper**:

\[
\text{baseline}(t) = B_{\text{full}} + (B_{\text{suppressed}} - B_{\text{full}}) \cdot (1.0 - e^{-2.5 \cdot \text{progress}})
\]

Where:
\[
\text{progress} = \min\left(\frac{\text{weeks on HRT}}{\text{timescale weeks}}, 1.0\right)
\]

#### 7.2.2 Timescale Configuration

**Timescale** (user-configurable via `SuppressionSpeed`):

| Speed | Weeks | Description |
|-------|-------|-------------|
| Fast | 4 | Rapid gonadal suppression |
| Medium | 8 | Standard taper |
| Slow | 12 | Gradual taper |

#### 7.2.3 Long-Term Lock-In

At progress = 1.0, suppression reaches ~92%. After 2 years (104 weeks), baseline is locked at the suppressed value.

### 7.3 Special Cases & Overrides

- **Anti-androgen in use + Testosterone**: **Baseline immediately drops to suppressed (15 ng/dL), overriding all taper functions — regardless of HRT duration.**
- **No HRT start date**: Full gonadal baseline is assumed.
- **Trans men on T**: E2 baseline can be estimated from T aromatization (Section 10).


## 8. Dose Intensity Scaling

### 8.1 Relative Dose Intensity

\[
R = \frac{\text{average dose over last 3 months}}{\text{standard starting dose}}
\]

| Medication | Standard Starting Dose |
|------------|------------------------|
| Estrogen | 2.0 mg |
| Testosterone | 50.0 mg |

### 8.2 Progress Scale

Dose intensity modifies the rate at which clinical changes progress:

- **< 0.5 Intensity** → 20 % slower timeline progression (scale factor 0.8×)
- **0.5–1.5 Intensity** → Standard timelines (scale factor 1.0×)
- **> 1.5 Intensity** → Changes may accelerate ~10 % (scale factor 1.1×)

### 8.3 Contextual Target Ranges

The clinical target ranges scale with dose intensity:

| Medication | Peak Min | Peak Max | Trough Min | Trough Max |
|------------|----------|----------|------------|------------|
| Estrogen | 200 × R | 600 × R | 100 × min(R, 1.5) | 250 × min(R, 1.5) |
| Testosterone | 600 × R | 1200 × R | 400 × min(R, 1.5) | 700 × min(R, 1.5) |

Trough targets are capped at 1.5× the standard to prevent unreasonably high trough recommendations at very high doses. Peak targets scale linearly with dose. A floor at 0.25× prevents pathological low targets.

### 8.4 User Therapeutic Targets

When the user sets personal therapeutic targets (troughMin, troughMax, peakCeiling), those override the dose-scaled clinical defaults for the trough and peak reference range.


## 9. Cycle Position Detection

### 9.1 Cycle Positions

| Position | Description |
|----------|-------------|
| `.nearPeak` | Within 24 hours after the actual curve peak |
| `.midCycle` | Between peak and trough |
| `.trough` | Within 24 hours before next dose OR at actual curve minimum |
| `.unknown` | Non-injectable routes or insufficient data |

### 9.2 Detection Algorithm (Injectable Routes)

1. Search `recentLevels` for the highest value after the last dose → **true peak**.
2. Search `recentLevels` for the lowest value after the last dose → **true trough**.
3. Compare current time against peak and trough coordinates (±24-hour windows).
4. **Fallback** (≤ 3 data points): Use the theoretical \(t_{\text{max}}\) from the Bateman formula with a ±30 % window.
5. Non-injectable routes always return `.unknown` (cycle-position logic is not meaningful for daily administration).

### 9.3 Contextual Target Selection

| Position | Target |
|----------|--------|
| Near Peak | Peak range (scaled peak min → peak ceiling) |
| Trough | Trough range (trough min → trough max) |
| Mid-Cycle | Interpolated midpoint of trough and peak ranges |
| Unknown | Trough range (safety default) |


## 10. Clinical Safety Layer

### 10.1 Safety Overrides

Safety labels take precedence over the standard classification and fire when:

| Condition | Label |
|-----------|-------|
| E2 > 1000 pg/mL | "Very High – Safety Check" (thromboembolic risk) |
| T > 1500 ng/dL | "Supraphysiological" (polycythemia risk) |
| E2 < 50 pg/mL at trough | "Sub-Therapeutic (Trough)" |
| E2 < 80 pg/mL at trough + Spiro | "Low (Spiro May Increase Clearance)" |

### 10.2 Unified Hormone Level Pipeline

The `getCurrentHormoneLevel()` function follows a 4-layer pipeline:

1. **PK Model**: Run at current time with α applied → calibrated level.
2. **Deviation Analysis**: Compare calibrated vs. raw predicted → "On Track" / "Below Expected" / etc.
3. **Contextual Classification**: Compare against dose-scaled, cycle-position-aware targets → "On Target" / "Critically Low" / etc.
4. **Safety Override**: Check clinical safety ceilings → override label if triggered.

### 10.3 Level Status Classification (relative to contextual target)

| Condition | Status |
|-----------|--------|
| actual < minTarget × 0.5 | Critically Low |
| actual < minTarget × 0.8 | Very Low |
| actual < minTarget | Slightly Below Target |
| minTarget ≤ actual ≤ maxTarget | On Target |
| actual ≤ maxTarget × 1.3 | Slightly Above Target |
| actual > maxTarget × 1.3 | High |

### 10.4 Final Label Format

```
"{Status} · {Context Label}{Position Suffix}"
```

With deviation dashboards when applicable:
```
"{Status} · {Context Label} · {Deviation Label}{Position Suffix}"
```


## 11. Aromatization (T → E2 Conversion)

### 11.1 Model

A small fraction of circulating testosterone is converted to estradiol via the aromatase enzyme:

\[
\text{E2}_{\text{arom}} (\text{pg/mL}) = T_{\text{ng/dL}} \times 0.002
\]

This is approximately **0.2% conversion** — derived from longitudinal
aromatization studies in trans male populations on exogenous testosterone
(Tiong et al., 2022) [3].

### 11.2 Male Reference Range Assessment

| E2 (pg/mL) | Assessment |
|------------|------------|
| < 10 | Below typical male range — unlikely to cause issues |
| 10–40 | Within typical male reference range |
| > 40 | May exceed male range — monitor for estrogenic effects |

This is relevant for trans men who want to ensure their aromatization-derived E2 stays within the male reference range (10–40 pg/mL).


## 12. Anti-Androgen & Drug Interactions

### 12.1 Spironolactone — CYP3A4 Induction Hypothesis

*Note: The interaction between spironolactone and CYP3A4-mediated estradiol
clearance is a working heuristic, not a clinically validated drug interaction.
Observational data suggest spironolactone use is associated with lower
achievement of target estradiol levels in some patients, and the enzyme
induction hypothesis is one plausible mechanism. However, the exact magnitude
of this effect and the CYP3A4-specific pathway remain areas of active
investigation. The 1.15× multiplier is a conservative estimate pending
stronger evidence.*

| Parameter | Value |
|-----------|-------|
| Clearance multiplier | 1.15 (15% faster k_e) |
| Applied to | Estrogen k_e only |
| Condition | `spironolactoneInUse AND spironolactoneClearanceEnabled` |

The 1.15× factor is applied to k_e in the Bateman model, resulting in faster E2 elimination and lower predicted levels. Users may toggle this off via `spironolactoneClearanceEnabled`.

### 12.2 Other Anti-Androgens

| Drug | PK Effect in Model |
|------|--------------------|
| Cyproterone Acetate | No direct PK interaction modelled; gonadal suppression via dynamic baseline |
| GnRH Agonists | Aggressive gonadal suppression via dynamic baseline (baseline → suppressed) |
| Finasteride | 5α-reductase inhibitor — no serum T/E2 PK interaction; affects DHT conversion only |
| Dutasteride | Same class as Finasteride |

These primarily affect the **dynamic baseline** (Section 7) rather than the PK curve itself. **When `antiAndrogenInUse = true` and the type is Testosterone, the baseline immediately drops to suppressed levels (15 ng/dL), overriding all taper functions.**


## 13. Common Vial Concentrations

### 13.1 Estrogen

| Ester | Available Concentrations (mg/mL) |
|-------|----------------------------------|
| Valerate (EV) | 10, 20, 40 |
| Cypionate (EC) | 5, 10 |

### 13.2 Testosterone

| Ester | Available Concentrations (mg/mL) |
|-------|----------------------------------|
| Cypionate (TC) | 100, 200 |
| Enanthate (TE) | 200, 250 |
| Propionate (TP) | 100 |
| Undecanoate (TU) | 250 |


## 14. Injection Site & Heat Map Tracking

The app tracks injection and application sites with a 3D body model. Zones are mapped to body regions:

| Region | Contains |
|--------|----------|
| Thighs | Upper/Mid/Lower/Outer/Inner Left/Right Thigh, Hamstring |
| Glutes | Ventrogluteal, Upper/Lower Glute |
| Arms | Deltoid, Tricep, Forearm, Upper Arm, Posterior |
| Upper Body | Shoulder, Chest, Abdomen, Periumbilical, Neck, Wrist |

**Preferred zones by medication + route** are defined for Estrogen, Testosterone, and Progesterone across injection, topical, and patch routes. An avoid-zone system tracks areas flagged for rotation rest, with safety checks preventing injection within restricted zones.

### Rotation Safety

The zone store includes rotation safety rules:
- Minimum time before reusing the same zone
- Heat map tracking of site usage frequency
- Avoid zones flagged for rest or complication recovery


## 15. Dosing Schedule & Frequency

### 15.1 Default Frequencies

| Administration Method | Default Frequency (days) |
|-----------------------|--------------------------|
| Injectable | 7 |
| Cream | 1 |
| Oral | 1 |

Users can set custom frequencies via `customFrequencyDays`.

### 15.2 Regimen Segments

The engine tracks contiguous segments of identical ester/dose/method combinations through time. When the user changes their regimen, a new segment begins. This enables:

- Tracking of regimen transitions
- Computing adherence rate within each segment
- Showing dose history trajectory across different protocols

### 15.3 Adherence & Streak Tracking

- **Adherence rate**: Ratio of doses taken vs. scheduled over the observation period.
- **On-time streak**: Consecutive doses taken within the scheduled tolerance window.
- **Dose status**: Each dose record is marked as `taken`, `skipped`, or `missed`.


## 16. Summary: Model Selection Matrix

| Medication | Route | Ester | PK Model | \(k_a\) (d⁻¹) | \(k_e\) (d⁻¹) | Notes | Ref |
|------------|-------|-------|----------|---------------|---------------|-------|-----|
| Estrogen | Injectable | Valerate (EV) | Bateman | 0.347 | 5.545 | Spiro: k_e × 1.15 | [1] |
| Estrogen | Injectable | Cypionate (EC) | Bateman | 0.082 | 5.545 | Spiro: k_e × 1.15 | [1] |
| Estrogen | Oral | Oral | Fast Bateman | 2.5 | 1.386 | Rapid spike ~1–2 hrs | [1] |
| Estrogen | Cream/Patch | Transdermal | 24-hr square-wave | 0.462 | 0.0 (zero-order) | 24 micro-doses/day | [1] |
| Testosterone | Injectable | Cypionate (TC) | Bateman | 0.087 | 8.318 | — | [2] |
| Testosterone | Injectable | Enanthate (TE) | Bateman | 0.099 | 8.318 | — | [2] |
| Testosterone | Injectable | Propionate (TP) | Bateman | 0.693 | 8.318 | Fast rise, short duration | [2] |
| Testosterone | Injectable | Undecanoate (TU) | Bateman | 0.035 | 8.318 | Very flat, 20-day t½ | [2] |
| Progesterone | Injectable | — | Single-exp fallback | ln(2)/t½ | — | No dedicated PK model yet | — |
| Progesterone | Topical | — | Single-exp fallback | ln(2)/t½ | — | No dedicated PK model yet | — |
| Progesterone | Patch | — | Single-exp fallback | ln(2)/t½ | — | No dedicated PK model yet | — |


## 17. References

1. **Düsterberg, B. et al.** — Pharmacokinetic profiles and terminal half-lives
   of estradiol valerate and cypionate injectable depots. *Data incorporated
   into EV, EC, and transdermal rate constants.*
2. **Tiong, S. et al.** (2022). Comparative pharmacokinetics of injectable
   testosterone esters (cypionate, enanthate, propionate, undecanoate).
   *Journal of Clinical Endocrinology & Metabolism.*
3. **Tiong, S. et al.** (2022). Longitudinal aromatization of exogenous
   testosterone to estradiol in trans male populations.
   *Derivation of the 0.2 % T → E2 conversion factor (Section 11.1).*
4. **Bateman, H.** (1910). "The solution of a system of differential equations
   occurring in the theory of radioactive transformations."
   *Proceedings of the Cambridge Philosophical Society*, Vol. 15, pp. 423–427.
   DOI: [10.1017/S0305004100001374](https://doi.org/10.1017/S0305004100001374)
   (The original Bateman biexponential model.)
 5. **Spironolactone-estradiol interaction** — The 1.15× clearance multiplier is a
    working hypothesis based on observational evidence and proposed CYP3A4 induction.
    This interaction has not been validated in controlled PK studies and should be
    treated as a heuristic. Users may toggle the adjustment off in settings
    (Section 12.1).
6. **Gonadal suppression model** — Derivation of saturating exponential
   taper from gonadotropin suppression data (FSH/LH decline rates under
   exogenous sex-hormone administration). Provides the basis for the dynamic
   baseline in Section 7.2.
