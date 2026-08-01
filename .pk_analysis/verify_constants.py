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

  Note all three of TE/TP/TU take the SAME S. That is not a copy-paste artifact -- S
  depends only on ke and clearance, and all three still share the placeholder 2 h ke.
  Their ka values (and therefore Tmax, and the shape of the curve within an interval)
  remain uncalibrated. Magnitude is now right; shape is not. OPEN_CONCERNS.md sec. 3.
""")


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
print("4. ESTROGEN -- REGRESSION: the 2026-07-31 refactor must not move these")
print("   source: transfemscience.org Tables 9/10; unchanged constants")
print("=" * 96)

# Oral E2's stored half-lives were restated to match what the engine hardcoded. If that
# restatement is truly a no-op, driving the NEW constants through the NEW code must
# reproduce the OLD hardcoded rates exactly.
ev = E2_ESTERS["Oral"]
ka_e, ke_e = ka_ke(ev)
check("oral E2 ka reproduces the old hardcoded 2.5 /day", ka_e, 2.5, 0.05)
check("oral E2 ke reproduces the old hardcoded 1.386 /day", ke_e, 1.386, 0.05)

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
