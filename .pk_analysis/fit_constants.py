#!/usr/bin/env python3
"""
fit_constants.py -- derive (ka, ke, S) per injectable ester from published PK data.

WHY THIS EXISTS
---------------
The shipped constants were fit as if `eliminationHalfLifeHours` were the
physiological free-hormone clearance (3 h for E2, 2 h for T). Under flip-flop
kinetics that choice is unidentifiable from the data: with ke ~ 5.5-8.3/day and
ka ~ 0.09-0.35/day, the exp(-ke*t) term is gone within ~2 h, so

    C(t) ~ const * exp(-ka*t)                      for essentially all t > 0

Two consequences follow, and they map onto the two open defects:

  * The whole inter-dose peak->trough decay is governed by **ka**, i.e. by
    `halfLifeDays`. Trough undershoot is a ka problem, NOT a ke problem.
  * **ke** only controls how fast the curve climbs, i.e. Tmax. Pinning it to a
    physiological 2-3 h forces Tmax to ~0.5 d for every depot ester, which is
    why the model underestimates every published Tmax window.

So the fit here treats ka and ke as *apparent* (empirical curve-fit) constants
and solves them against two independent observables:

    Tmax          = ln(ka/ke) / (ka - ke)            -> pins ke (given ka)
    Cmin/Cmax     at steady state                     -> pins ka (shape only,
                                                         independent of S)

Amplitude is then a third, separable parameter: S scales C(t) linearly, so it
is solved last against a single-dose Cmax target and cannot disturb the shape.

METHOD
------
Cmin/Cmax at steady state is invariant under S (both scale together), so the
shape fit is a clean 2-eq / 2-unknown system. It is solved by nested bisection:
outer on ka (monotone: slower ka -> higher trough -> higher ratio), inner on ke
to hold Tmax fixed at the literature value.

Stdlib only, Python 3.9 compatible -- no numpy/scipy.
"""

import math

LN2 = math.log(2)

# ----------------------------------------------------------------------
# Shipped constants (mirrors PharmacokineticConstants.swift as of 8a50db9)
# ----------------------------------------------------------------------

CURRENT = {
    "Valerate (EV)":    dict(t_half=2.0,  elim_h=3.0, ewf=0.764, F=1.00, S=3150.0),
    "Cypionate (EC)":   dict(t_half=8.5,  elim_h=3.0, ewf=0.687, F=1.00, S=2700.0),
    "Cypionate (TC)":   dict(t_half=8.0,  elim_h=2.0, ewf=0.699, F=1.00, S=1081.0),
    "Enanthate (TE)":   dict(t_half=7.0,  elim_h=2.0, ewf=0.720, F=1.00, S=923.0),
    "Propionate (TP)":  dict(t_half=1.0,  elim_h=2.0, ewf=0.837, F=1.00, S=359.0),
    "Undecanoate (TU)": dict(t_half=20.0, elim_h=2.0, ewf=0.631, F=1.00, S=214.0),
}

# ----------------------------------------------------------------------
# Literature targets
#
#   tmax_d   : published time-to-peak (days)
#   ratio    : published steady-state Cmin/Cmax at (ref_dose, interval).
#              None -> no trough data; keep the shipped terminal half-life.
#   ref_dose / interval : the regimen the ratio was measured under
#   amp_dose / amp_cmax : the app's DOCUMENTED single-dose Cmax target
#   lit_amp             : the same quantity per literature, for comparison
# ----------------------------------------------------------------------

TARGETS = {
    # transfemscience.org Table 9 (single 5 mg) + Table 10 (5 mg weekly steady state).
    # `ss_cmax` anchors amplitude to the published steady-state peak rather than to
    # the app's legacy documented single-dose target -- see AMPLITUDE ANCHOR below.
    "Valerate (EV)": dict(
        tmax_d=2.1, ratio=142.0 / 384.0, ref_dose=5.0, interval=7.0,
        amp_dose=2.0, amp_cmax=250.0, ss_cmax=384.0,
        lit_amp=(5.0, 295.0), source="transfemscience Table 9/10"),
    "Cypionate (EC)": dict(
        tmax_d=4.3, ratio=262.0 / 339.0, ref_dose=5.0, interval=7.0,
        amp_dose=2.0, amp_cmax=180.0, ss_cmax=339.0,
        lit_amp=(5.0, 155.0), source="transfemscience Table 9/10"),
    # No published trough table -> hold shipped terminal half-life, fit ke to Tmax.
    "Cypionate (TC)": dict(
        tmax_d=1.5, ratio=None, ref_dose=100.0, interval=7.0,
        amp_dose=100.0, amp_cmax=750.0,
        lit_amp=(100.0, 650.0), source="TRT PK studies, Tmax 24-48h"),
    "Enanthate (TE)": dict(
        tmax_d=1.7, ratio=None, ref_dose=100.0, interval=7.0,
        amp_dose=100.0, amp_cmax=750.0,
        lit_amp=(100.0, 740.0), source="Ichihara 2020, mean Tmax 1.7d"),
    "Propionate (TP)": dict(
        tmax_d=0.6, ratio=None, ref_dose=50.0, interval=2.0,
        amp_dose=50.0, amp_cmax=1000.0,
        lit_amp=None, source="sparse published TG data (app-internal target)"),
    "Undecanoate (TU)": dict(
        tmax_d=7.0, ratio=None, ref_dose=1000.0, interval=70.0,
        amp_dose=1000.0, amp_cmax=550.0,
        lit_amp=(1000.0, 1100.0), source="Wang 2010, Tmax ~7d, Cmax ~1100 ng/dL"),
}


# ----------------------------------------------------------------------
# Core math (mirrors the Swift Bateman exactly)
# ----------------------------------------------------------------------

def bateman(amount, S, ka, ke, t):
    if t < 0:
        return 0.0
    denom = ka - ke
    if abs(denom) < 1e-4:
        return amount * S * ka * t * math.exp(-ka * t)
    return amount * S * (ka / denom) * (math.exp(-ke * t) - math.exp(-ka * t))


def tmax_of(ka, ke):
    """Analytic time-to-peak. Symmetric in ka/ke."""
    if abs(ka - ke) < 1e-9:
        return 1.0 / ka
    return math.log(ka / ke) / (ka - ke)


def steady_state(ka, ke, S, eff_amount, interval, n_cycles=40, step=0.01):
    """Cmax/Cmin over the final dosing interval at steady state."""
    dose_times = [i * interval for i in range(n_cycles)]
    t0 = dose_times[-1]
    vals = []
    t = t0
    while t <= t0 + interval:
        vals.append(sum(bateman(eff_amount, S, ka, ke, t - d)
                        for d in dose_times if t >= d))
        t += step
    return max(vals), min(vals)


def single_dose_cmax(ka, ke, S, eff_amount):
    return bateman(eff_amount, S, ka, ke, tmax_of(ka, ke))


# ----------------------------------------------------------------------
# Solvers
# ----------------------------------------------------------------------

def solve_ke_for_tmax(ka, tmax_target):
    """Given ka (slow constant), find ke > ka reproducing tmax_target.

    tmax_of is monotone decreasing in ke for ke > ka, so bisect.
    """
    lo, hi = ka * 1.0000001, ka * 1e6
    if tmax_of(ka, hi) > tmax_target:
        return None                      # unreachable: ka itself too slow
    for _ in range(300):
        mid = math.sqrt(lo * hi)         # geometric bisection: ke spans decades
        if tmax_of(ka, mid) > tmax_target:
            lo = mid
        else:
            hi = mid
    return math.sqrt(lo * hi)


def solve_shape(tmax_target, ratio_target, eff_amount, interval):
    """Solve (ka, ke) against Tmax and the steady-state Cmin/Cmax ratio.

    The ratio is independent of S, so this is pure shape fitting. Slower ka
    (longer terminal half-life) -> higher trough -> higher ratio, so the outer
    bisection on terminal half-life is monotone.
    """
    def ratio_at(t_half):
        ka = LN2 / t_half
        ke = solve_ke_for_tmax(ka, tmax_target)
        if ke is None:
            return None, ka, None
        cmax, cmin = steady_state(ka, ke, 1.0, eff_amount, interval)
        return (cmin / cmax if cmax > 0 else 0.0), ka, ke

    lo, hi = 0.3, 60.0                   # terminal half-life search window (days)
    best = None
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        r, ka, ke = ratio_at(mid)
        if r is None:
            lo = mid
            continue
        best = (mid, ka, ke, r)
        if r < ratio_target:
            lo = mid                     # trough too low -> slow ka down
        else:
            hi = mid
    return best


def fit(name):
    tgt = TARGETS[name]
    cur = CURRENT[name]
    eff = tgt["ref_dose"] * cur["ewf"] * cur["F"]

    if tgt["ratio"] is not None:
        t_half, ka, ke, ratio = solve_shape(
            tgt["tmax_d"], tgt["ratio"], eff, tgt["interval"])
    else:
        # No trough data: hold the shipped terminal half-life, fit ke to Tmax.
        t_half = cur["t_half"]
        ka = LN2 / t_half
        ke = solve_ke_for_tmax(ka, tgt["tmax_d"])
        cmax, cmin = steady_state(ka, ke, 1.0, eff, tgt["interval"])
        ratio = cmin / cmax if cmax > 0 else 0.0

    # AMPLITUDE ANCHOR (last step -- S scales C(t) linearly and cannot perturb shape).
    #
    # Where a published steady-state peak exists (`ss_cmax`), anchor to that. The
    # app's legacy `amp_cmax` targets are NOT usable as an anchor: EV 2mg->250 is
    # 2.1x and EC 2mg->180 is 3.1x the corresponding transfemscience figures, so
    # holding them forces steady state ~+110% / ~+206% above Table 10. Anchoring to
    # the published steady state instead makes single-dose Cmax a derived value.
    if tgt.get("ss_cmax") is not None:
        ref_eff = tgt["ref_dose"] * cur["ewf"] * cur["F"]
        unit_ss, _ = steady_state(ka, ke, 1.0, ref_eff, tgt["interval"])
        S = tgt["ss_cmax"] / unit_ss
    else:
        amp_eff = tgt["amp_dose"] * cur["ewf"] * cur["F"]
        S = tgt["amp_cmax"] / single_dose_cmax(ka, ke, 1.0, amp_eff)

    derived_single = single_dose_cmax(
        ka, ke, S, tgt["amp_dose"] * cur["ewf"] * cur["F"])

    return dict(name=name, t_half=t_half, ka=ka, ke=ke, S=S,
                elim_h=LN2 / ke * 24.0, ratio=ratio,
                tmax=tmax_of(ka, ke), derived_single=derived_single)


# ----------------------------------------------------------------------
# Report
# ----------------------------------------------------------------------

def current_metrics(name):
    cur = CURRENT[name]
    tgt = TARGETS[name]
    ka = LN2 / cur["t_half"]
    ke = LN2 / (cur["elim_h"] / 24.0)
    amp_eff = tgt["amp_dose"] * cur["ewf"] * cur["F"]
    ref_eff = tgt["ref_dose"] * cur["ewf"] * cur["F"]
    cmax, cmin = steady_state(ka, ke, cur["S"], ref_eff, tgt["interval"])
    return dict(ka=ka, ke=ke, tmax=tmax_of(ka, ke),
                cmax_single=single_dose_cmax(ka, ke, cur["S"], amp_eff),
                ss_cmax=cmax, ss_cmin=cmin,
                ratio=(cmin / cmax if cmax > 0 else 0.0))


def main():
    order = ["Valerate (EV)", "Cypionate (EC)",
             "Cypionate (TC)", "Enanthate (TE)",
             "Propionate (TP)", "Undecanoate (TU)"]

    print("=" * 100)
    print("SHIPPED CONSTANTS vs. THEIR OWN DOCUMENTED TARGETS")
    print("=" * 100)
    print(f"{'Ester':<18}{'RefDose':>9}{'DocTarget':>11}{'Actual':>10}{'Error':>10}   {'Tmax':>6} {'LitTmax':>8}")
    for n in order:
        c, t = current_metrics(n), TARGETS[n]
        err = (c["cmax_single"] - t["amp_cmax"]) / t["amp_cmax"] * 100
        flag = "  <-- MISMATCH" if abs(err) > 25 else ""
        print(f"{n:<18}{t['amp_dose']:>9.0f}{t['amp_cmax']:>11.0f}"
              f"{c['cmax_single']:>10.1f}{err:>+9.1f}%   {c['tmax']:>6.2f} {t['tmax_d']:>8.2f}{flag}")

    print()
    print("=" * 100)
    print("FITTED CONSTANTS")
    print("=" * 100)
    print(f"{'Ester':<18}{'halfLifeDays':>14}{'elimHours':>11}{'S':>11}   "
          f"{'(was)':>22}")
    fits = {}
    for n in order:
        f = fit(n)
        fits[n] = f
        cur = CURRENT[n]
        was = f"{cur['t_half']:.1f}d/{cur['elim_h']:.0f}h/S={cur['S']:.0f}"
        print(f"{n:<18}{f['t_half']:>14.2f}{f['elim_h']:>11.1f}{f['S']:>11.1f}   {was:>22}")

    print()
    print("=" * 100)
    print("VERIFICATION -- Tmax and steady-state trough, before vs. after")
    print("=" * 100)
    print(f"{'Ester':<18}{'Tmax old':>10}{'Tmax new':>10}{'LitTmax':>9}{'  ':>3}"
          f"{'Ratio old':>11}{'Ratio new':>11}{'LitRatio':>10}")
    for n in order:
        c, f, t = current_metrics(n), fits[n], TARGETS[n]
        lit_r = f"{t['ratio']:.3f}" if t["ratio"] is not None else "   n/a"
        print(f"{n:<18}{c['tmax']:>10.2f}{f['tmax']:>10.2f}{t['tmax_d']:>9.2f}{'  ':>3}"
              f"{c['ratio']:>11.3f}{f['ratio']:>11.3f}{lit_r:>10}")

    print()
    print("=" * 100)
    print("DERIVED CHECK -- steady-state Cmax drift (NOT a fit target)")
    print("=" * 100)
    lit_ss = {"Valerate (EV)": (384.0, 142.0), "Cypionate (EC)": (339.0, 262.0)}
    for n in order:
        f, t, cur = fits[n], TARGETS[n], CURRENT[n]
        eff = t["ref_dose"] * cur["ewf"] * cur["F"]
        cmax, cmin = steady_state(f["ka"], f["ke"], f["S"], eff, t["interval"])
        if n in lit_ss:
            lc, lm = lit_ss[n]
            print(f"{n:<18} ss_Cmax={cmax:>7.1f} (lit {lc:.0f}, {(cmax-lc)/lc*100:+.1f}%)   "
                  f"ss_Cmin={cmin:>6.1f} (lit {lm:.0f}, {(cmin-lm)/lm*100:+.1f}%)")
        else:
            ratio = cmax / cmin if cmin > 0 else float("inf")
            print(f"{n:<18} ss_Cmax={cmax:>7.1f}   ss_Cmin={cmin:>6.1f}   peak/trough={ratio:>5.1f}x")

    print()
    print("=" * 100)
    print("SWIFT CONSTANTS")
    print("=" * 100)
    for n in order:
        f = fits[n]
        print(f"// {n:<18} halfLife={f['t_half']:.2f}d  elim={f['elim_h']:.1f}h  S={f['S']:.1f}")


if __name__ == "__main__":
    main()
