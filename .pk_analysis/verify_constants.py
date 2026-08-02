#!/usr/bin/env python3
"""
verify_constants.py -- independent check that the constants shipped in
PharmacokineticConstants.swift, driven through the engine replica, reproduce the
published anchors they were fit to.

This is deliberately NOT the fitting code. fit_constants.py / fit_testosterone.py
solve for the constants; this file takes the shipped numbers at face value and runs
them through simulate_fixed(), the same code path the app uses, then compares against
the source figures. A fit that agrees with itself proves nothing; this closes the loop.

Run:  python3 .pk_analysis/verify_constants.py
"""

import math
import sys

from pk_engine_replica import (
    DoseEvent, E2_ESTERS, T_ESTERS, OLD_T_ESTERS, OLD_T_ROUTE_FALLBACK_S,
    simulate_fixed, effective_ester_name, effective_dose_factor, ka_ke,
    expected_time_to_peak, bateman,
)

FAILS = []


def check(label, got, target, tol_pct, note=""):
    """Record a comparison. tol_pct is the tolerance as a percentage of target."""
    err = (got - target) / target * 100.0 if target else float("inf")
    ok = abs(err) <= tol_pct
    mark = "PASS" if ok else "FAIL"
    print(f"  [{mark}] {label:<46} got {got:>10.1f}   target {target:>8.1f}"
          f"   ({err:+6.1f}%, tol +-{tol_pct:.0f}%)")
    if note:
        print(f"         {note}")
    if not ok:
        FAILS.append(f"{label}: got {got:.1f}, target {target:.1f} ({err:+.1f}%)")
    return ok


def steady_state(medication, ester, route, dose_mg, tau_days, n_doses=400,
                 samples_per_interval=400):
    """Run the engine replica to steady state; return (cmax, cmin, cavg) over the
    final dosing interval. Uses the app's own summation, not a closed form."""
    doses = [DoseEvent(t_days=i * tau_days, ester=ester, medication=medication,
                       route=route, dose_mg=dose_mg) for i in range(n_doses)]
    t0 = (n_doses - 1) * tau_days
    grid = [t0 + tau_days * k / samples_per_interval
            for k in range(samples_per_interval + 1)]
    ys = simulate_fixed(doses, grid)
    cavg = sum(ys[:-1]) / len(ys[:-1])   # left-Riemann over one full interval
    return max(ys), min(ys), cavg


def single_dose(medication, ester, route, dose_mg, horizon_days, npts=4000):
    doses = [DoseEvent(t_days=0.0, ester=ester, medication=medication,
                       route=route, dose_mg=dose_mg)]
    grid = [horizon_days * k / npts for k in range(npts + 1)]
    ys = simulate_fixed(doses, grid)
    cmax = max(ys)
    tmax = grid[ys.index(cmax)]
    return cmax, tmax


# ======================================================================
print("=" * 96)
print("1. TESTOSTERONE CYPIONATE (IM depot)")
print("   source: Bi et al. 2018, CPT Pharmacometrics Syst Pharmacol, doi 10.1002/psp4.12287")
print("=" * 96)

tc = T_ESTERS["Cypionate (TC)"]
ka, ke = ka_ke(tc)
print(f"  encoded: t1/2(slow) {tc['half_life_days']:.3f} d -> ka {ka:.4f} /d")
print(f"           t1/2(fast) {tc['elim_h']:.2f} h    -> ke {ke:.4f} /d")
print(f"           EWF {tc['ewf']}, F {tc['F']}, S {tc['S']}")
print()

# Bi Table 2: Ka 1.22 /day, CL/F 2.6 kL/day, V/F 14.4 kL.
# The engine's ka corresponds to Bi's disposition rate CL/V and its ke to Bi's Ka
# (or vice versa -- the Bateman is symmetric under the swap; see the Swift comment).
check("disposition rate CL/V (/day)", ka, 2.6 / 14.4, 1.0,
      "Bi Table 2: CL/F 2.6 kL/day over V/F 14.4 kL")
check("absorption rate Ka (/day)", ke, 1.22, 1.0, "Bi Table 2 point estimate")

_, tmax = single_dose("Testosterone", "Cypionate (TC)", "Injectable", 100.0, 20.0)
check("single-dose Tmax (days)", tmax, 1.84, 5.0,
      "ln(ka/ke)/(ka-ke) from Bi's own parameters; 95% CI on Ka gives 1.08-2.43 d")

# Closed-form population prediction: a 100 mg IM dose in a one-compartment model with
# Bi's V/F should peak at Dose/V * shape(tmax), independent of the app's parametrization.
V_L = 14400.0
shape = (ke / (ke - ka)) * (math.exp(-ka * tmax) - math.exp(-ke * tmax))
pop_cmax = 100.0 / V_L * shape * 1e5   # mg/L -> ng/dL
cmax_100, _ = single_dose("Testosterone", "Cypionate (TC)", "Injectable", 100.0, 20.0)
check("single 100 mg Cmax vs Bi population model", cmax_100, pop_cmax, 1.0,
      "the app's S is the analytic solution, so this must agree to rounding")

# Out-of-sample: literature single-dose 200 mg IM peaks near ~1112 ng/dL total, of
# which roughly 240 ng/dL is basal secretion (Bi b_base 6.24 mg/day / CL).
cmax_200, _ = single_dose("Testosterone", "Cypionate (TC)", "Injectable", 200.0, 20.0)
check("single 200 mg Cmax, exogenous only", cmax_200, 1112.0 - 240.0, 15.0,
      "NOT used in the fit -- independent check against the 200 mg IM literature figure")

cmax_w, cmin_w, cavg_w = steady_state("Testosterone", "Cypionate (TC)", "Injectable", 100.0, 7.0)
print(f"\n  weekly 100 mg steady state, exogenous only:"
      f" Cmax {cmax_w:.0f}  Cmin {cmin_w:.0f}  Cavg {cavg_w:.0f} ng/dL")
print(f"  + basal 240 ng/dL (xT models this separately as baseLevel):"
      f" Cmax {cmax_w + 240:.0f}  Cmin {cmin_w + 240:.0f} ng/dL")
check("weekly 100 mg Cmax incl. basal", cmax_w + 240.0, 1150.0, 20.0,
      "Bi Figure 2, 100 mg intensive-sampling panel reads ~1100-1200 ng/dL at peak")

# Cavg at steady state is an identity in a one-compartment model: Dose/(CL*tau).
# It does not depend on ka, ke or Tmax, so this is the sharpest available test that
# S carries the right absolute magnitude rather than merely the right shape.
CL_L_PER_DAY = 2600.0   # Bi Table 2: CL/F 2.6 kL/day
check("weekly 100 mg Cavg = Dose/(CL*tau)", cavg_w,
      100.0 / (CL_L_PER_DAY * 7.0) * 1e5, 1.0,
      "steady-state identity, independent of the absorption parametrization")
total_cavg = cavg_w + 240.0
inside = 300.0 <= total_cavg <= 1000.0
print(f"  [{'PASS' if inside else 'FAIL'}] weekly 100 mg total Cavg inside the eugonadal band"
      f"        got {total_cavg:>10.1f}   band 300-1000 ng/dL")
if not inside:
    FAILS.append(f"weekly 100 mg total Cavg {total_cavg:.1f} outside 300-1000 ng/dL")

# Regression guard on the defect that motivated the refit. The shipped constant has
# been through two revisions; both predecessors are recorded so neither can drift back.
print(f"\n  regression guard, TC scaling constant: {OLD_T_ESTERS['Cypionate (TC)']['S']:.0f}"
      f" (as-found, 2026-07-28 QA) -> 1081 (numeric curve-fit, 2026-07-28)"
      f" -> {tc['S']:.2f} (analytic, from Bi)")


# ======================================================================
print()
print("=" * 96)
print("1b. TE / TP / TU -- steady-state magnitude by conservation of mass")
print("=" * 96)
print("""  These three have no primary source of their own, but their scaling constants are
  not free. Integrating the app's expression over a dosing interval gives exactly
  Cavg = Dose*EDF*S/(tau*ke), and the true Cavg is (mg testosterone/day)/CL_T. CL_T
  belongs to testosterone, not to the ester, so it is already pinned by the TC refit.
  Equating the two, EWF cancels and S = 1e5*ke/(CL_T*F). Every ester must satisfy it.
""")
CL_T = 2600.0 * T_ESTERS["Cypionate (TC)"]["ewf"]   # Bi CL/F is per mg of cypionate
print(f"  CL_T = 2600 L/day x EWF_TC {T_ESTERS['Cypionate (TC)']['ewf']}"
      f" = {CL_T:.1f} L/day ({CL_T/1440:.2f} L/min)")
print()
for name in ("Cypionate (TC)", "Enanthate (TE)", "Propionate (TP)", "Undecanoate (TU)"):
    c = T_ESTERS[name]
    _, ke_i = ka_ke(c)
    implied = 1e5 * ke_i / (CL_T * c["F"])
    check(f"{name} S satisfies the identity", c["S"], implied, 0.5)
print("""
  TC is the load-bearing check here: its S was derived analytically from Bi's V/F and
  Ka without reference to this identity, so the two agreeing to 0.03% is independent
  confirmation that both derivations are right.

  Until 2026-08-02 all three of TE/TP/TU took the SAME S, because all three shared the
  placeholder 2 h ke. TE and TU now carry sourced absorption rates, so their S values
  moved with them (identity, not refit) and only TP still sits at 457.67. Magnitude is
  unchanged for all three -- Cavg = Dose*EDF*S/(tau*ke) holds S/ke fixed. Sections 1c
  and 1d below check the shape that actually moved.
""")

# The refit's central claim is that it moved shape without moving magnitude. Cavg is
# the invariant that must survive it, so assert that directly rather than by algebra.
print("  Magnitude invariance across the 2026-08-02 refit (Cavg must not have moved):")
for name, dose, tau, cavg_before in (("Enanthate (TE)", 100.0, 7.0, 566.0),
                                     ("Undecanoate (TU)", 1000.0, 70.0, 496.0)):
    _, _, cavg_i = steady_state("Testosterone", name, "Injectable", dose, tau)
    check(f"{name} {dose:.0f} mg q{tau:.0f}d Cavg unchanged", cavg_i, cavg_before, 1.0,
          "pre-refit value; S and ke moved together so this is required to hold")


# ======================================================================
print()
print("=" * 96)
print("1c. TESTOSTERONE ENANTHATE (IM depot)")
print("    source: Ichihara et al. 2020, Androgens Clin Res Ther, doi 10.1089/andro.2020.0002")
print("            n=10 transgender men, single 250 mg IM -- the app's own population")
print("=" * 96)

te = T_ESTERS["Enanthate (TE)"]
ka_te, ke_te = ka_ke(te)
print(f"  encoded: t1/2(slow) {te['half_life_days']:.3f} d -> ka {ka_te:.4f} /d")
print(f"           t1/2(fast) {te['elim_h']:.4f} h -> ke {ke_te:.4f} /d")
print(f"           EWF {te['ewf']}, F {te['F']}, S {te['S']}")
print()

check("terminal half-life (days)", math.log(2) / ka_te, 6.6, 1.0,
      "Ichihara reported 6.6 +- 1.9 d for total testosterone")
# The paper could estimate ka in 4 of 10 subjects: 2.82, 3.16, 0.49, 1.38 /day.
check("absorption rate ka (/day)", ke_te, sum([2.82, 3.16, 0.49, 1.38]) / 4.0, 1.0,
      "mean of the four per-subject estimates the paper reports")
print("  note ka (1.96 /d) >> the elimination rate implied by 6.6 d (0.105 /d), so this")
print("  is the ordinary non-flip-flop case: elimination is rate-limiting, as the paper")
print("  states. The app's slow/fast slots therefore hold terminal/absorption here, the")
print("  same assignment TC uses.")
print()

cmax_te_sd, tmax_te = single_dose("Testosterone", "Enanthate (TE)", "Injectable", 250.0, 40.0)
check("single 250 mg Tmax (days)", tmax_te, 1.7, 30.0,
      "observed 1.7 +- 0.9 d; NOT fit to -- ka came from the paper's own estimates")

# Magnitude is deliberately NOT taken from Ichihara. Record the size of the gap rather
# than fitting it away, and show where it comes from.
print(f"\n  single 250 mg Cmax, exogenous only: {cmax_te_sd:.0f} ng/dL"
      f"  vs Ichihara's observed {2940:.0f} +- 1710")
print("  -> DOCUMENTED, NOT FITTED. Ichihara's own cohort parameters are roughly half")
print("     the Bi-derived values this app is anchored to:")
print(f"       CLtot/F  14.3 L/day/kg x 65 kg = {14.3*65:.0f} L/day   vs CL_T {2600*0.699:.0f}")
print(f"       Vd/F    118.7 L/kg    x 65 kg = {118.7*65:.0f} L        vs V/F  14400")
print("     Adopting their clearance for TE alone would put TE and TC 2x apart on the")
print("     same molecule and break the conservation-of-mass identity checked in 1b.")
print("     Shape is taken from Ichihara; magnitude stays with Bi. Their Cmax CV is")
print("     wide enough (+-1710 on 2940) that this is not a sharp contradiction, and")
print("     the per-user blood-test factor alpha is what absorbs the remainder.")

cmax_te, cmin_te, cavg_te = steady_state("Testosterone", "Enanthate (TE)", "Injectable", 100.0, 7.0)
print(f"\n  weekly 100 mg steady state, exogenous only:"
      f" Cmax {cmax_te:.0f}  Cmin {cmin_te:.0f}  Cavg {cavg_te:.0f} ng/dL"
      f"  (P/T {cmax_te/cmin_te:.2f})")
check("weekly 100 mg Cavg = Dose*EWF/(CL_T*tau)", cavg_te,
      100.0 * te["ewf"] / (2600.0 * 0.699 * 7.0) * 1e5, 1.0,
      "steady-state identity -- must be untouched by an absorption-rate refit")


# ======================================================================
print()
print("=" * 96)
print("1d. TESTOSTERONE UNDECANOATE (IM depot)")
print("    sources: Zhang 1998 (J Androl 19:761-8) terminal t1/2; Aveed clinical")
print("             pharmacology Tmax; Wang 2010 (doi 10.2164/jandrol.109.009597) P/T")
print("=" * 96)

tu = T_ESTERS["Undecanoate (TU)"]
ka_tu, ke_tu = ka_ke(tu)
print(f"  encoded: t1/2(slow) {tu['half_life_days']:.3f} d -> ka {ka_tu:.5f} /d")
print(f"           t1/2(fast) {tu['elim_h']:.4f} h ({tu['elim_h']/24:.3f} d)"
      f" -> ke {ke_tu:.5f} /d")
print(f"           EWF {tu['ewf']}, F {tu['F']}, S {tu['S']}")
print()

hl_tu = math.log(2) / ka_tu
inside_zhang = 18.3 - 2.3 <= hl_tu <= 23.7 + 2.7
print(f"  [{'PASS' if inside_zhang else 'FAIL'}] terminal half-life {hl_tu:.1f} d inside"
      f" Zhang's two dose arms (18.3+-2.3 @500 mg, 23.7+-2.7 @1000 mg)")
if not inside_zhang:
    FAILS.append(f"TU terminal half-life {hl_tu:.1f} d outside Zhang's arms")

cmax_tu_sd, tmax_tu = single_dose("Testosterone", "Undecanoate (TU)", "Injectable", 1000.0, 200.0)
check("single 1000 mg Tmax (days)", tmax_tu, 7.0, 3.0,
      "Aveed 750 mg IM: median 7 d (range 4-42). ke was fit to this, so this is a "
      "round-trip check on the fit, not independent evidence")
print(f"  single 1000 mg Cmax, exogenous only: {cmax_tu_sd:.0f} ng/dL"
      f"  (Wang reports ~1100 total for 1000 mg)")

cmax_tu, cmin_tu, cavg_tu = steady_state("Testosterone", "Undecanoate (TU)", "Injectable", 1000.0, 70.0)
pt = cmax_tu / cmin_tu
print(f"\n  1000 mg q70d steady state, exogenous only:"
      f" Cmax {cmax_tu:.0f}  Cmin {cmin_tu:.0f}  Cavg {cavg_tu:.0f} ng/dL")
print(f"  peak/trough {pt:.2f}  vs Wang 2010's observed 1.80 (789.8 / 435.6 ng/dL, wk 12)")
print(f"  (pre-refit this was 11.01; the absorption fit closed roughly a third of it)")
print()
print("  -> OPEN, and the reason is a SOURCE CONFLICT, not a missing compartment.")
decay_bound = 2 ** (70.0 / hl_tu)
hl_for_18 = 70.0 * math.log(2) / math.log(1.8)
print(f"     Over a 70 d interval, {hl_tu:.0f} d is {70.0/hl_tu:.1f} half-lives, so pure")
print(f"     decay alone bounds peak/trough at >= {decay_bound:.1f}x. Absorption sustaining")
print(f"     the trough is what brings the model to {pt:.1f}x. Decay alone would not")
print(f"     reach 1.8x until a terminal half-life of {hl_for_18:.1f} d.")
print()
print("     That target IS reachable in this two-rate Bateman: pairing a 73.8 d slow")
print("     rate with a 27.5 h release rate gives Tmax 7.0 d AND peak/trough 1.80x --")
print("     3.7x Zhang's measured half-life. So the pre-2026-08-02 claim that TU")
print("     'needs a 3-parameter or population-PK model' is disproven by construction,")
print("     and separately by Pastuszak 2021, which fits IM TU with one compartment and")
print("     first-order absorption. What is actually needed is Wang's primary sampling")
print("     schedule -- specifically whether that week-12 peak/trough pair spans one")
print("     full inter-dose interval.")

# Assert the constructive claim rather than leaving it in prose. Both halves matter:
# the pair must hit Tmax 7 d AND, run through the app's own superposition, peak/trough
# 1.80. The second is why the counterexample is 73.8 d and not the 82.5 d the pure-decay
# bound suggests -- absorption keeps refilling the trough, so a shorter half-life
# suffices. Simulated, not closed-form, precisely so that distinction cannot be lost.
_ALT_HL, _ALT_FAST_H = 73.8, 27.5
_ka_alt = math.log(2) / _ALT_HL
_ke_alt = math.log(2) / (_ALT_FAST_H / 24.0)
check("the 73.8 d / 27.5 h counterexample gives Tmax 7 d",
      math.log(_ka_alt / _ke_alt) / (_ka_alt - _ke_alt), 7.0, 2.0,
      "half of what makes the 'needs more compartments' claim false")
_alt = dict(half_life_days=_ALT_HL, elim_h=_ALT_FAST_H, ewf=tu["ewf"], F=tu["F"],
            S=tu["S"])
T_ESTERS["__tu_counterexample__"] = _alt
_cmax_alt, _cmin_alt, _ = steady_state("Testosterone", "__tu_counterexample__",
                                       "Injectable", 1000.0, 70.0)
del T_ESTERS["__tu_counterexample__"]
check("...and, simulated, peak/trough 1.80", _cmax_alt / _cmin_alt, 1.80, 3.0,
      "the other half -- and the reason the counterexample is 73.8 d, not the 82.5 d "
      "the pure-decay bound implies")


# ======================================================================
print()
print("=" * 96)
print("2. TRANSDERMAL TESTOSTERONE (gel)")
print("   source: AndroGel 1% prescribing information, Table 5 (Day 180, n=44)")
print("=" * 96)

td = T_ESTERS["Transdermal"]
print(f"  encoded: t1/2 {td['half_life_days']:.4f} d ({td['half_life_days']*24:.1f} h),"
      f" EWF {td['ewf']}, F {td['F']}, S {td['S']}")
print()

cmax_g, cmin_g, cavg_g = steady_state("Testosterone", "Transdermal", "Cream", 50.0, 1.0)
check("50 mg/day gel, steady-state Cavg", cavg_g, 555.0, 5.0,
      "label Table 5; this is the anchor S was fit to")

print(f"  intraday ripple Cmax/Cmin = {cmax_g/cmin_g:.2f}  (observed 2.24)")
print("  -> DOCUMENTED LIMITATION: the 24-hourly-micro-dose model has no absorption")
print("     phase and cannot produce that ripple at any half-life consistent with the")
print("     label's own 48-72 h washout. Cavg is right; peak-to-trough is flattened.")

for d_mg, obs in ((75.0, 601.0), (100.0, 713.0)):
    _, _, cavg_x = steady_state("Testosterone", "Transdermal", "Cream", d_mg, 1.0)
    err = (cavg_x - obs) / obs * 100.0
    print(f"  out-of-sample {d_mg:.0f} mg/day: model Cavg {cavg_x:.0f} vs label {obs:.0f}"
          f"  ({err:+.0f}%)")
print("  -> DOCUMENTED LIMITATION: the label's dose-response is sublinear (a titration")
print("     artifact -- higher-dose arms are enriched for poor absorbers; the 1.62%")
print("     label inverts outright, 81 mg Cavg 537 < 60.75 mg Cavg 643). S is anchored")
print("     to the 50 mg arm, the standard starting dose, so 75/100 mg run high.")

# ---- The defect this closes, simulated rather than estimated from the S ratio ----
# Three things were wrong at once, and they compound: the scaling constant fell through
# to a hardcoded 8000, the EDF came from the stored injectable ester (0.699 x 1.0 rather
# than the gel's 1.0 x 0.10), and ka came from a hardcoded ln2/1.5 rather than the gel's
# own 13.9 h half-life -- the last of which also changes how much accumulates day to day.
def old_cream_steady_state(dose_mg, stored_ester, n_days=400, samples=400):
    """The Cream path exactly as it behaved before 2026-07-31, for testosterone."""
    S = OLD_T_ROUTE_FALLBACK_S["Cream"]                    # medication != "Estrogen"
    edf = effective_dose_factor(OLD_T_ESTERS[stored_ester])  # stored ester, not the route
    ka = math.log(2) / 1.5                                  # hardcoded tdKa
    micro = dose_mg * edf / 24.0
    t0 = float(n_days - 1)
    ys = []
    for k in range(samples + 1):
        t = t0 + k / samples
        total = 0.0
        for day in range(n_days):
            for h in range(24):
                dt = t - (day + h / 24.0)
                if dt < 0:
                    continue
                total += micro * S * math.exp(-ka * dt)
        ys.append(total)
    return max(ys), min(ys), sum(ys[:-1]) / len(ys[:-1])

old_cmax_g, _, old_cavg_g = old_cream_steady_state(50.0, "Cypionate (TC)", n_days=60)
print(f"\n  regression guard: 50 mg/day gel, testosterone, as the code behaved before")
print(f"  2026-07-31 -> Cavg {old_cavg_g:,.0f} ng/dL against a label value of 555.")
print(f"  Overprediction factor {old_cavg_g / cavg_g:,.0f}x. Contributing causes:")
print(f"    scaling constant  {OLD_T_ROUTE_FALLBACK_S['Cream']:.0f} (hardcoded)"
      f" vs {td['S']:.2f} (calibrated)")
print(f"    effective dose    {effective_dose_factor(T_ESTERS['Cypionate (TC)']):.3f}"
      f" (stored ester) vs {effective_dose_factor(td):.3f} (route)")
print(f"    absorption ka     {math.log(2)/1.5:.3f} (hardcoded)"
      f" vs {math.log(2)/td['half_life_days']:.3f} /day (calibrated)")
check("gel Cavg is now within 5% of the label", cavg_g, 555.0, 5.0,
      "the same scenario that previously returned six figures")


# ======================================================================
print()
print("=" * 96)
print("3. ORAL TESTOSTERONE UNDECANOATE")
print("   source: Swerdloff et al. 2020 (Jatenzo), 237 mg BID")
print("=" * 96)

orl = T_ESTERS["Oral"]
ka_o, ke_o = ka_ke(orl)
print(f"  encoded: t1/2(slow) {orl['half_life_days']:.3f} d, t1/2(fast) {orl['elim_h']:.3f} h,"
      f" EWF {orl['ewf']}, F {orl['F']}, S {orl['S']}")
print()

cmax_o, cmin_o, cavg_o = steady_state("Testosterone", "Oral", "Oral", 237.0, 0.5)
check("237 mg BID steady-state Cavg", cavg_o, 488.7, 5.0, "primary endpoint; S fit to this")
_, tmax_o = single_dose("Testosterone", "Oral", "Oral", 237.0, 1.0)
check("Tmax (hours)", tmax_o * 24.0, 3.0, 15.0, "reported window 2-4 h")
print(f"  Cmax {cmax_o:.0f} vs reported 1008 ({(cmax_o-1008.3)/1008.3*100:+.0f}%)")
print("  -> DOCUMENTED LIMITATION: with Tmax pinned to 2-4 h the model's achievable")
print("     Cmax/Cavg tops out at ~1.61 against a reported 2.06. The reported ratio is")
print("     itself inflated by mean-of-maxima bias (E[max] >= max[E]; Cmax SD +-581 on")
print("     a mean of 1008).")


# ======================================================================
print()
print("=" * 96)
print("4. ESTROGEN -- oral Tmax refit (2026-08-01), and what it must NOT move")
print("   source: transfemscience.org Tables 9/10; oral Tmax window from secondary sources")
print("=" * 96)

# Oral E2, refit 2026-08-01 (concern #7). Until then this block pinned ka to the 2.5 /day
# the engine used to hardcode, to prove the 07-31 restatement was a no-op. That pin has
# done its job and is now retired -- keeping it would have made this script fail by
# construction on any Tmax fix. What replaces it is a probe, not a pin: Tmax against the
# published window, plus the ke and Cavg invariants the refit was required NOT to move.
ev = E2_ESTERS["Oral"]
ka_e, ke_e = ka_ke(ev)
_, tmax_e = single_dose("Estrogen", "Oral", "Oral", 2.0, 1.0)
check("oral E2 Tmax (hours)", tmax_e * 24.0, 6.0, 33.0,
      "published window 4-8 h; pinned to the 6 h midpoint (no principle picks a point inside it)")
check("oral E2 ke unchanged by the Tmax refit", ke_e, 1.386, 0.05,
      "the refit moved ka only -- ke is the elimination side")

# The whole case for holding S = 1250 through the refit is that AUC/dose = amount*S/ke
# carries no ka term, so Cavg cannot move. Assert that rather than trusting the algebra.
_, _, cavg_e2_qd = steady_state("Estrogen", "Oral", "Oral", 2.0, 1.0)
check("oral E2 2 mg daily steady-state Cavg", cavg_e2_qd, 90.2, 2.0,
      "ka-invariant -- this is the real regression guard on the refit")
cmax_e2_sd, _ = single_dose("Estrogen", "Oral", "Oral", 2.0, 1.0)
print(f"  Cmax {cmax_e2_sd:.0f} pg/mL for a single 2 mg dose, up from 60 before the refit.")
print("  -> ACCEPTED CONSEQUENCE, not a regression: S and ka are coupled through the peak")
print("     but not the average, so pinning Tmax and holding Cavg necessarily moves Cmax.")
print("     Holding Cmax at 60 instead would need S = 848.5 and would drop Cavg to 61.")

td_e2 = E2_ESTERS["Transdermal"]
check("transdermal E2 ka reproduces the old hardcoded ln2/1.5",
      math.log(2) / td_e2["half_life_days"], math.log(2) / 1.5, 0.01)

for ester, cmax_t, cmin_t in (("Valerate (EV)", 384.0, None), ("Cypionate (EC)", 339.0, None)):
    cmax_e, cmin_e, _ = steady_state("Estrogen", ester, "Injectable", 5.0, 7.0)
    check(f"{ester} 5 mg weekly steady-state Cmax (pg/mL)", cmax_e, cmax_t, 5.0,
          "transfemscience Table 10 -- unchanged by this refactor")

# Route normalization must be a no-op for estrogen, whose doses already stored the
# matching pseudo-ester. Confirm the resolver agrees for every combination in use.
for ester, route, expect in (("Oral", "Oral", "Oral"),
                             ("Transdermal", "Cream", "Transdermal"),
                             ("Valerate (EV)", "Injectable", "Valerate (EV)"),
                             ("Cypionate (EC)", "Injectable", "Cypionate (EC)")):
    got = effective_ester_name(ester, route)
    ok = got == expect
    print(f"  [{'PASS' if ok else 'FAIL'}] resolver {ester!r:>18} + {route!r:<12} -> {got!r}")
    if not ok:
        FAILS.append(f"resolver {ester}/{route} -> {got}, expected {expect}")

# And the new behaviour: a stale injectable ester on a non-injectable route.
for ester, route, expect in (("Cypionate (TC)", "Cream", "Transdermal"),
                             ("Cypionate (TC)", "Oral", "Oral"),
                             ("Cream", "Cream", "Transdermal")):
    got = effective_ester_name(ester, route)
    ok = got == expect
    print(f"  [{'PASS' if ok else 'FAIL'}] resolver {ester!r:>18} + {route!r:<12} -> {got!r}"
          f"   (was: unresolvable -> hardcoded fallback)")
    if not ok:
        FAILS.append(f"resolver {ester}/{route} -> {got}, expected {expect}")


# ======================================================================
print()
print("=" * 96)
if FAILS:
    print(f"{len(FAILS)} CHECK(S) FAILED")
    for f in FAILS:
        print(f"  - {f}")
    sys.exit(1)
print("ALL CHECKS PASSED")
print("=" * 96)
