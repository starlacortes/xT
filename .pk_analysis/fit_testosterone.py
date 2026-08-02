#!/usr/bin/env python3
"""
fit_testosterone.py  --  Derivation of xT's testosterone PK constants.

Companion to fit_constants.py (which derived the EV/EC estradiol constants on
2026-07-29). This script covers the testosterone side, which OPEN_CONCERNS.md
sections 2-3 left uncalibrated pending primary-source access.

Everything here is derived from PRIMARY sources:

  [Bi2018]   Bi Y, Perry PJ, Ellerby M, Murry DJ. "Population Pharmacokinetic/
             Pharmacodynamic Modeling of Depot Testosterone Cypionate in Healthy
             Male Subjects." CPT Pharmacometrics Syst Pharmacol. 2018;7(4):259-268.
             doi:10.1002/psp4.12287.
             Table 2 (population PK parameter estimates, n=31):
                 CL/F = 2.6 kL/day    (RSE 4.53%,  95% CI 2.42-2.8)
                 V/F  = 14.4 kL       (RSE 12.1%,  95% CI 11.9-17.6)
                 Ka   = 1.22 /day     (RSE 44.9%,  95% CI 0.785-2.67)
             Median post hoc terminal half-life 4.05 d.

  [AndroGel] AndroGel (testosterone gel) 1% FDA prescribing information,
             NDA 021015/S-036 (rev. 05/2013), Section 12.3 + Table 5.
             "Approximately 10% of the testosterone dose applied on the skin
              surface from AndroGel is absorbed into systemic circulation."
             Table 5, Day 180 steady state, hypogonadal men:
                 50 mg/d : Cavg 555+-225, Cmax 830+-347, Cmin 371+-165 ng/dL
                 75 mg/d : Cavg 601+-309, Cmax 901+-471, Cmin 406+-220 ng/dL
                100 mg/d : Cavg 713+-209, Cmax 1083+-434, Cmin 485+-156 ng/dL

  [Jatenzo]  Swerdloff RS et al. "A New Oral Testosterone Undecanoate
             Formulation Restores Testosterone to Normal Concentrations in
             Hypogonadal Men." J Clin Endocrinol Metab. 2020;105(8):2515-2531.
             PMC7282712. 237 mg TU BID (= 150 mg unesterified T equivalents):
                 Cavg 488.7 +- 154.5 ng/dL (serum equivalent)
                 Cmax 1008.3 +- 581.0 ng/dL
                 Tmax 2-4 h

--------------------------------------------------------------------------
THE APP'S PARAMETRIZATION (see MedicationManager+Pharmacokinetics.swift)
--------------------------------------------------------------------------
The engine evaluates, per dose, for injectable and oral routes:

    contribution(dt) = A * EDF * S * (ka/(ka-ke)) * (exp(-ke*dt) - exp(-ka*dt))

where  ka = ln2 / halfLifeDays              <- the SLOW constant
       ke = ln2 / (eliminationHalfLifeHours/24)   <- the FAST constant
       EDF = esterWeightFactor * bioavailability
       S  = scalingConstant

NOTE the app's names are the reverse of PK convention: its `ka` is the slow
(terminal) constant and its `ke` is the fast one. The Bateman is symmetric in
Tmax under that swap, and the amplitude difference is absorbed into S, so this
is only a naming hazard -- but it means S is NOT interpretable as F/Vd.

For the transdermal route the engine instead emits 24 hourly micro-doses of
A*EDF/24, each decaying as a single exponential exp(-ka*dt) with ka from
halfLifeDays, scaled by S.
"""

import math

LN2 = math.log(2)


# ======================================================================
# Shared helpers -- ONE definition of the app's math, used by every fit,
# so EDF placement can never silently drift between esters.
# ======================================================================

def bateman_shape(lam_slow, lam_fast, t):
    """The app's Bateman shape factor, excluding A*EDF*S."""
    denom = lam_slow - lam_fast
    if abs(denom) < 1e-9:
        return lam_slow * t * math.exp(-lam_slow * t)
    return (lam_slow / denom) * (math.exp(-lam_fast * t) - math.exp(-lam_slow * t))


def tmax_bateman(lam_slow, lam_fast):
    """Time of peak. Symmetric under slow<->fast swap."""
    if abs(lam_slow - lam_fast) < 1e-9:
        return 1.0 / lam_slow
    return math.log(lam_fast / lam_slow) / (lam_fast - lam_slow)


def steady_state_curve(lam_slow, lam_fast, tau, n_doses=400, npts=2000):
    """Superpose n_doses at interval tau; return (t_grid, shape) over the final
    interval. Uses explicit superposition rather than the closed form so it
    matches what the engine actually does (finite dose history)."""
    ts, ys = [], []
    for i in range(npts + 1):
        t = tau * i / npts
        tot = 0.0
        for d in range(n_doses):
            dt = t + d * tau
            tot += bateman_shape(lam_slow, lam_fast, dt)
        ts.append(t)
        ys.append(tot)
    return ts, ys


def transdermal_ss_curve(lam, tau=1.0, n_days=200, npts=2400):
    """The app's transdermal model at steady state: 24 hourly micro-doses per
    application, each a bare decaying exponential. Returns shape per unit
    (A*EDF/24)*S."""
    ts, ys = [], []
    for i in range(npts + 1):
        t = tau * i / npts
        tot = 0.0
        for d in range(n_days):
            for h in range(24):
                dt = t + d * tau - h / 24.0
                if dt >= 0:
                    tot += math.exp(-lam * dt)
        ts.append(t)
        ys.append(tot)
    return ts, ys


def summarize(ts, ys):
    cmax, cmin = max(ys), min(ys)
    # trapezoidal mean over the interval
    area = sum((ys[i] + ys[i + 1]) / 2 * (ts[i + 1] - ts[i]) for i in range(len(ts) - 1))
    cavg = area / (ts[-1] - ts[0])
    tmax = ts[ys.index(cmax)]
    return dict(cmax=cmax, cmin=cmin, cavg=cavg, tmax=tmax)


def find_bracket(f, lo, hi, n=200):
    """Scan a log-spaced grid for a sign change; return a bracketing pair.
    Guards against the silent-failure mode where a hand-picked bracket happens
    to miss the root entirely."""
    prev_x = lo
    prev_f = f(lo)
    for i in range(1, n + 1):
        x = lo * (hi / lo) ** (i / n)
        try:
            fx = f(x)
        except ValueError:
            continue
        if prev_f * fx <= 0:
            return prev_x, x
        prev_x, prev_f = x, fx
    raise ValueError(f"no sign change anywhere on [{lo},{hi}]")


def bisect(f, lo, hi, tol=1e-10, iters=300):
    flo, fhi = f(lo), f(hi)
    if flo * fhi > 0:
        raise ValueError(f"no sign change on [{lo},{hi}]: f={flo:.4g},{fhi:.4g}")
    for _ in range(iters):
        mid = (lo + hi) / 2
        fm = f(mid)
        if abs(fm) < tol:
            return mid
        if flo * fm < 0:
            hi, fhi = mid, fm
        else:
            lo, flo = mid, fm
    return (lo + hi) / 2


# ======================================================================
# 1. TESTOSTERONE CYPIONATE  --  derived analytically from Bi 2018 Table 2
# ======================================================================

def fit_tc():
    print("=" * 74)
    print("1. TESTOSTERONE CYPIONATE (TC)  --  source: Bi et al. 2018, Table 2")
    print("=" * 74)

    CL = 2.6            # kL/day
    V = 14.4            # kL
    Ka = 1.22           # /day
    V_L = V * 1000.0    # litres
    EWF = 0.699         # T base 288.4 / TC 412.6
    F = 1.0             # depot IM, near-complete absorption
    EDF = EWF * F

    ke_bi = CL / V                       # /day, the disposition constant
    t_half_terminal = LN2 / ke_bi
    t_half_abs_h = LN2 / Ka * 24.0

    print(f"  CL/F = {CL} kL/day, V/F = {V} kL, Ka = {Ka} /day")
    print(f"  -> disposition rate      ke = CL/V = {ke_bi:.6f} /day")
    print(f"  -> terminal half-life       = {t_half_terminal:.4f} d"
          f"   (paper's post hoc median: 4.05 d, agreement {100*abs(t_half_terminal-4.05)/4.05:.1f}% )")
    print(f"  -> absorption half-life     = {t_half_abs_h:.3f} h")

    tmax = tmax_bateman(ke_bi, Ka)
    print(f"  -> Tmax = ln(ka/ke)/(ka-ke) = {tmax:.4f} d")

    # Uncertainty band on Tmax from the published 95% CI on Ka.
    tmax_lo = tmax_bateman(ke_bi, 2.67)
    tmax_hi = tmax_bateman(ke_bi, 0.785)
    print(f"     95% CI on Ka (0.785-2.67) -> Tmax in [{tmax_lo:.2f}, {tmax_hi:.2f}] d")

    # S follows in closed form. Matching the app's expression to the true
    # one-compartment model:
    #     A*EDF*S*(lam_slow/(lam_fast-lam_slow)) == (D*1e5/V_L)*(lam_fast/(lam_fast-lam_slow))
    # (1e5 converts mg/L -> ng/dL).  The D cancels; EDF appears because the app
    # multiplies the dose by it while Bi's V/F already absorbs ester conversion.
    S = (1e5 * Ka) / (V_L * EDF * ke_bi)
    print(f"  -> S = 1e5*Ka / (V_L * EDF * ke) = {S:.2f}   (was 1081.0)")

    # Forward check: single 100 mg dose.
    D = 100.0
    A = D * EDF
    cmax_single = A * S * bateman_shape(ke_bi, Ka, tmax)
    print(f"\n  Single 100 mg dose  -> Cmax {cmax_single:.1f} ng/dL at t={tmax:.2f} d")

    # Independent cross-check NOT used in the fit: MacIndoe/secondary report of
    # 200 mg IM -> Cmax 1112 +- 297 ng/dL. Linear PK -> halve for 100 mg.
    print(f"     cross-check vs 200 mg -> 1112 ng/dL scaled to 100 mg = 556 ng/dL"
          f"  (model {cmax_single:.0f}, {100*(cmax_single-556)/556:+.1f}%)")

    # Steady state, weekly 100 mg.
    ts, ys = steady_state_curve(ke_bi, Ka, tau=7.0)
    ss = summarize(ts, ys)
    print(f"\n  Weekly 100 mg at steady state (exogenous contribution only):")
    print(f"     Cmax {A*S*ss['cmax']:7.1f} ng/dL at t={ss['tmax']:.2f} d")
    print(f"     Cmin {A*S*ss['cmin']:7.1f} ng/dL")
    print(f"     Cavg {A*S*ss['cavg']:7.1f} ng/dL")
    print(f"     peak/trough ratio {ss['cmax']/ss['cmin']:.2f}")

    # Bi's own basal secretion term gives the endogenous floor the app models
    # separately as baseLevel. b_base = 6.24 mg/day, CL = 2.6 kL/day.
    endo = 6.24 / CL * 100.0   # mg/day / (kL/day) = mg/kL = ug/L = ng/mL -> *100 = ng/dL
    print(f"\n  Bi basal secretion b_base=6.24 mg/d / CL -> endogenous floor {endo:.0f} ng/dL")
    print(f"     total predicted = {A*S*ss['cmax']+endo:.0f} peak / {A*S*ss['cmin']+endo:.0f} trough")
    print(f"     Figure 2 (100 mg intensive panel) observed ~1100-1200 peak / ~400-500 late")

    return dict(half_life_days=t_half_terminal, elim_h=t_half_abs_h,
                ewf=EWF, F=F, S=S)


# ======================================================================
# 2. TESTOSTERONE TRANSDERMAL (gel)  --  source: AndroGel 1% FDA label
# ======================================================================

def fit_transdermal():
    print()
    print("=" * 74)
    print("2. TESTOSTERONE TRANSDERMAL  --  source: AndroGel 1% label, Table 5")
    print("=" * 74)

    DOSE = 50.0            # mg/day applied
    CAVG, CMAX, CMIN = 555.0, 830.0, 371.0
    EWF = 1.0              # gel delivers unesterified testosterone
    F = 0.10               # "approximately 10% ... is absorbed" [AndroGel 12.3]
    EDF = EWF * F
    micro = DOSE * EDF / 24.0

    target_ratio = CMAX / CMIN
    print(f"  target 50 mg/d: Cavg {CAVG}, Cmax {CMAX}, Cmin {CMIN} ng/dL"
          f"  (Cmax/Cmin = {target_ratio:.3f})")
    print(f"  EWF = {EWF} (unesterified), F = {F} (label), EDF = {EDF}")

    # ------------------------------------------------------------------
    # STRUCTURAL LIMITATION -- documented rather than fitted around.
    #
    # The engine's transdermal model is 24 hourly micro-doses, each a bare
    # decaying exponential with no absorption phase. Its intraday peak/trough
    # ratio is therefore governed entirely by how much decay happens in the
    # one hour between micro-doses. Reproducing the observed Cmax/Cmin of
    # 2.237 would require a terminal half-life near 1 h, which contradicts the
    # label's own washout statement (48-72 h to baseline) by more than an
    # order of magnitude. The two targets are mutually unsatisfiable in this
    # model, exactly as OPEN_CONCERNS section 4 describes for TU.
    #
    # Resolution: anchor the rate constant to the WASHOUT observation (the
    # physically meaningful terminal behaviour, and the one that governs what
    # a user sees after stopping or missing doses), anchor S to Cavg, and
    # report the intraday ripple as a known under-prediction.
    # ------------------------------------------------------------------
    for hl in (0.05, 0.25, 0.5788, 1.0, 1.5):
        ts_, ys_ = transdermal_ss_curve(LN2 / hl, npts=480)
        s_ = summarize(ts_, ys_)
        print(f"     [ratio probe] half-life {hl:.4f} d -> Cmax/Cmin"
              f" {s_['cmax']/s_['cmin']:.3f}")
    print(f"     -> observed {target_ratio:.3f} is unreachable above ~0.05 d;"
          f" anchoring to washout instead")

    # Washout anchor: "serum testosterone concentrations return to approximately
    # baseline concentrations within 48-72 hours after administration of the last
    # dose" [AndroGel 1.62% label, 12.3]. Take the midpoint, 60 h, and read
    # "approximately baseline" as 5% of steady state remaining.
    WASHOUT_H, RESIDUAL = 60.0, 0.05
    lam = -math.log(RESIDUAL) / (WASHOUT_H / 24.0)
    half_life = LN2 / lam
    print(f"  -> washout anchor: {RESIDUAL:.0%} remaining at {WASHOUT_H:.0f} h"
          f" -> lambda {lam:.4f}/d, half-life {half_life:.4f} d ({half_life*24:.2f} h)")
    for wh in (48.0, 72.0):
        l_ = -math.log(RESIDUAL) / (wh / 24.0)
        print(f"     sensitivity: washout {wh:.0f} h -> half-life {LN2/l_*24:.2f} h")

    ts, ys = transdermal_ss_curve(lam, npts=2400)
    shape = summarize(ts, ys)
    print(f"     achieved Cmax/Cmin = {shape['cmax']/shape['cmin']:.3f}"
          f"  vs observed {target_ratio:.3f}  <-- KNOWN UNDER-PREDICTION of ripple")

    # Then S from Cavg.
    S = CAVG / (micro * shape['cavg'])
    print(f"  -> S = {S:.2f}   (previously fell through to the hardcoded 8000.0)")

    print(f"\n  Reproduction check at each label dose (S anchored to 50 mg only):")
    print(f"     {'dose':>6} {'Cavg pred':>10} {'obs':>6} {'err':>8}")
    for dose, oavg in [(50, 555), (75, 601), (100, 713)]:
        m = dose * EDF / 24.0
        pred = m * S * shape['cavg']
        print(f"     {dose:>6} {pred:>10.0f} {oavg:>6} {100*(pred-oavg)/oavg:>+7.1f}%")

    # The label's own dose-response is markedly sublinear: doubling 50 -> 100 mg
    # raises Cavg only 555 -> 713 (1.28x). The same pattern appears in the
    # AndroGel 1.62% label (Table 6), where the 81 mg group has a LOWER Cavg
    # (537) than the 60.75 mg group (643). This is a titration artifact -- dose
    # was escalated in patients who absorbed poorly, so the higher-dose groups
    # are enriched for poor absorbers -- not saturable pharmacokinetics.
    # The engine assumes dose-linearity, so no single constant fits all three.
    # We anchor to 50 mg: it is the standard starting dose and the least
    # selection-confounded group. The least-squares alternative is shown for
    # transparency.
    d_arr, o_arr = [50.0, 75.0, 100.0], [555.0, 601.0, 713.0]
    k_ls = sum(d * o for d, o in zip(d_arr, o_arr)) / sum(d * d for d in d_arr)
    S_ls = k_ls / ((EDF / 24.0) * shape['cavg'])
    print(f"\n     least-squares alternative across all 3 doses: S = {S_ls:.2f}")
    for dose, oavg in zip(d_arr, o_arr):
        pred = dose * (EDF / 24.0) * S_ls * shape['cavg']
        print(f"       {dose:>5.0f} mg -> {pred:>6.0f} (obs {oavg:.0f},"
              f" {100*(pred-oavg)/oavg:+.1f}%)")
    print("     -> anchored to 50 mg; sublinearity is a titration artifact in the")
    print("        source data, documented rather than fitted around.")

    return dict(half_life_days=half_life, elim_h=None, ewf=EWF, F=F, S=S)


# ======================================================================
# 3. ORAL TESTOSTERONE UNDECANOATE  --  source: Jatenzo / Swerdloff 2020
# ======================================================================

def fit_oral():
    print()
    print("=" * 74)
    print("3. ORAL TESTOSTERONE UNDECANOATE  --  source: Swerdloff 2020 (Jatenzo)")
    print("=" * 74)

    DOSE_TU = 237.0        # mg TU per administration
    TAU = 0.5              # BID
    CAVG, CMAX = 488.7, 1008.3
    TMAX_H = 3.0           # median of the reported 2-4 h window
    EWF = 0.631            # T 288.4 / TU 456.7; label states 237 mg TU = 150 mg T
    F = 1.0                # absolute oral bioavailability not established in the
                           # source; folded into S (see note below)
    EDF = EWF * F
    A = DOSE_TU * EDF

    print(f"  237 mg TU BID -> Cavg {CAVG}, Cmax {CMAX} ng/dL, Tmax {TMAX_H} h")
    print(f"  EWF = {EWF}  (label: 237 mg TU = 150 mg T equiv -> {150/237:.3f}, agrees)")

    # Two unknowns (lam_slow, lam_fast); two targets (Tmax, Cmax/Cavg ratio).
    target_tmax = TMAX_H / 24.0
    target_ratio = CMAX / CAVG
    print(f"  targets: Tmax {target_tmax:.4f} d, Cmax/Cavg {target_ratio:.3f}")

    def ratio_for(half_life_days):
        """For a given slow half-life, pick lam_fast so Tmax lands on target,
        then report the resulting steady-state Cmax/Cavg."""
        lam_slow = LN2 / half_life_days

        def tmax_err(lam_fast):
            return tmax_bateman(lam_slow, lam_fast) - target_tmax

        # Tmax is maximised at lam_fast -> lam_slow (value 1/lam_slow) and falls
        # to 0 as lam_fast -> inf, so a root exists only when 1/lam_slow > target.
        if 1.0 / lam_slow <= target_tmax:
            raise ValueError("target Tmax unreachable for this slow half-life")
        lo, hi = find_bracket(tmax_err, lam_slow * 1.000001, 5000.0)
        lam_fast = bisect(tmax_err, lo, hi, tol=1e-12)
        ts, ys = steady_state_curve(lam_slow, lam_fast, tau=TAU, n_doses=200, npts=600)
        s = summarize(ts, ys)
        return s['cmax'] / s['cavg'], lam_fast

    # ------------------------------------------------------------------
    # SECOND STRUCTURAL LIMITATION. With Tmax pinned to the reported 2-4 h
    # window, the largest Cmax/Cavg this model can produce at BID dosing is
    # ~1.61, against the reported 2.063. Probe the feasible set:
    # ------------------------------------------------------------------
    print("     feasible Cmax/Cavg given Tmax = 3 h:")
    feasible = []
    for hl in (0.09, 0.12, 0.15, 0.20, 0.30, 0.50, 1.00):
        try:
            r, lf = ratio_for(hl)
        except ValueError:
            continue
        feasible.append((hl, r, lf))
        print(f"       slow half-life {hl:.2f} d ({hl*24:5.2f} h) -> Cmax/Cavg {r:.3f}")
    print(f"     target {target_ratio:.3f} exceeds the achievable maximum"
          f" {max(r for _, r, _ in feasible):.3f}.")
    print("     The reported ratio is inflated by mean-of-maxima bias: Cmax is the")
    print("     mean of per-subject maxima (E[max] >= max[E]) and carries SD +-581")
    print("     on a mean of 1008. Anchor to Tmax and Cavg -- the label's own")
    print("     primary endpoint and the quantity clinicians titrate on -- and")
    print("     accept a documented under-prediction of peak fluctuation.")

    # Choose the feasible slow half-life whose Cmax/Cavg comes closest to the
    # observed ratio, i.e. best achievable agreement on the secondary target.
    half_life = min(feasible, key=lambda p: abs(p[1] - target_ratio))[0]
    _, lam_fast = ratio_for(half_life)
    lam_slow = LN2 / half_life

    ts, ys = steady_state_curve(lam_slow, lam_fast, tau=TAU, n_doses=200, npts=2000)
    shape = summarize(ts, ys)
    S = CAVG / (A * shape['cavg'])

    print(f"  -> slow half-life = {half_life:.4f} d ({half_life*24:.2f} h)")
    print(f"  -> fast half-life = {LN2/lam_fast*24:.3f} h")
    print(f"  -> Tmax = {tmax_bateman(lam_slow, lam_fast)*24:.2f} h")
    print(f"  -> S = {S:.2f}   (previously fell through to the hardcoded 12000.0)")
    print(f"\n  Steady state 237 mg BID: Cavg {A*S*shape['cavg']:.0f}"
          f" (obs {CAVG}), Cmax {A*S*shape['cmax']:.0f} (obs {CMAX}),"
          f" Cmin {A*S*shape['cmin']:.0f}")
    print("  NOTE: F is set to 1.0 because absolute oral TU bioavailability is not")
    print("        established in the source. F and S are confounded -- only their")
    print("        product is identified by these data.")

    return dict(half_life_days=half_life, elim_h=LN2 / lam_fast * 24.0,
                ewf=EWF, F=F, S=S)


# ======================================================================
# 4. TESTOSTERONE ENANTHATE and UNDECANOATE  --  shape refit, 2026-08-02
# ======================================================================
#
# These two are structurally simpler than the fits above, because only their
# SHAPE is being solved for. Magnitude is not free: the conservation-of-mass
# identity established by the TC refit fixes S once ke is known.
#
#     Cavg = Dose*EDF*S/(tau*ke)  must equal  (mg testosterone/day)/CL_T
#     =>  S = 1e5*ke/(CL_T*F),     CL_T = 2600 * EWF_TC = 1817.4 L/day
#
# EWF cancels, so S depends on ke and clearance alone. Every ester must satisfy
# it, and `verify_constants.py` section 1b asserts that they do.

CL_T = 2600.0 * 0.699    # L/day, per mg of testosterone -- from Bi via EWF_TC


def s_from_ke(lam_fast, F=1.0):
    """The clearance identity, in one place."""
    return 1e5 * lam_fast / (CL_T * F)


def fit_te():
    print()
    print("=" * 74)
    print("4. TESTOSTERONE ENANTHATE (TE)  --  source: Ichihara et al. 2020")
    print("   doi 10.1089/andro.2020.0002; n=10 transgender men, 250 mg IM")
    print("=" * 74)

    T_HALF_TERMINAL = 6.6                       # d, reported (+- 1.9)
    KA_SUBJECTS = [2.82, 3.16, 0.49, 1.38]      # /day, the 4 estimable subjects
    TMAX_OBS = 1.7                              # d, reported (+- 0.9), all 10 subjects
    EWF, F = 0.720, 1.00

    ka_mean = sum(KA_SUBJECTS) / len(KA_SUBJECTS)
    lam_slow = LN2 / T_HALF_TERMINAL            # app's `ka` slot -- the SLOW constant
    lam_fast = ka_mean                          # app's `ke` slot -- the FAST constant

    print(f"  reported ka per subject: {KA_SUBJECTS}  -> mean {ka_mean:.4f} /day")
    print(f"  reported terminal t1/2:  {T_HALF_TERMINAL} d -> {lam_slow:.5f} /day")
    print()
    print("  NOTE this is NOT a fit -- both rates are taken from the paper directly,")
    print("  the same way TC's came from Bi. Nothing was solved for. The paper models")
    print("  a one-compartment system with first-order absorption, and ka (1.96) far")
    print("  exceeds the rate implied by its own terminal half-life (0.105), so")
    print("  absorption is the fast process: the ordinary non-flip-flop case, and the")
    print("  same slow=terminal / fast=absorption assignment TC uses.")
    print()

    tmax = tmax_bateman(lam_slow, lam_fast)
    S = s_from_ke(lam_fast, F)
    print(f"  -> slow half-life = {T_HALF_TERMINAL:.4f} d       (was 7.0, uncited)")
    print(f"  -> fast half-life = {LN2/lam_fast*24:.4f} h     (was 2.0, placeholder)")
    print(f"  -> S              = {S:.2f}         (was 457.67)")
    print()
    print(f"  CROSS-CHECK, not fit to: Tmax = {tmax:.3f} d against an observed")
    print(f"  {TMAX_OBS} +- 0.9 d ({(tmax-TMAX_OBS)/TMAX_OBS*100:+.0f}%). The constant came")
    print("  from the paper's ka estimates (n=4); the target is its observed Tmax")
    print("  (n=10). Different quantities, different subsets -- so this is a real")
    print("  check rather than a round trip.")
    print()
    print("  DOCUMENTED, NOT FITTED: a single 250 mg dose gives ~881 ng/dL exogenous")
    print("  here against Ichihara's observed Cmax of 2940 +- 1710. Their cohort's")
    print("  CLtot/F (~930 L/day at 65 kg) and Vd/F (~7700 L) are each about half the")
    print("  Bi-derived values the app is anchored to. Taking their clearance for TE")
    print("  alone would put TE and TC 2x apart on the same molecule and break the")
    print("  identity above. Shape from Ichihara, magnitude from Bi.")

    return dict(half_life_days=T_HALF_TERMINAL, elim_h=LN2 / lam_fast * 24.0,
                ewf=EWF, F=F, S=S)


def fit_tu():
    print()
    print("=" * 74)
    print("5. TESTOSTERONE UNDECANOATE (TU)  --  Aveed Tmax over Zhang 1998 t1/2")
    print("=" * 74)

    T_HALF_TERMINAL = 20.0     # d; Zhang 1998: 18.3+-2.3 @500 mg, 23.7+-2.7 @1000 mg
    TMAX_TARGET = 7.0          # d; Aveed 750 mg IM, median 7 (range 4-42)
    TAU = 70.0                 # d, the label's 10-week interval
    PT_OBSERVED = 1.80         # Wang 2010 wk 12: 789.8 / 435.6 ng/dL
    EWF, F = 0.631, 1.00

    lam_slow = LN2 / T_HALF_TERMINAL
    print(f"  terminal t1/2 {T_HALF_TERMINAL} d held fixed (inside both Zhang arms)")
    print(f"  solving for the release rate that puts Tmax at {TMAX_TARGET} d...")

    # tmax_bateman is symmetric in its two arguments, so the root must be
    # bracketed on the fast > slow branch or bisection can land on the mirror.
    f = lambda x: tmax_bateman(lam_slow, x) - TMAX_TARGET
    lam_fast = bisect(f, *find_bracket(f, lam_slow * 1.000001, 50.0))

    S = s_from_ke(lam_fast, F)
    print(f"  -> slow half-life = {T_HALF_TERMINAL:.4f} d      (unchanged)")
    print(f"  -> fast half-life = {LN2/lam_fast*24:.4f} h    (was 2.0, placeholder)")
    print(f"  -> S              = {S:.2f}         (was 457.67)")
    print(f"  -> Tmax           = {tmax_bateman(lam_slow, lam_fast):.4f} d")
    print()

    ts, ys = steady_state_curve(lam_slow, lam_fast, tau=TAU, n_doses=200, npts=2000)
    sh = summarize(ts, ys)
    print(f"  steady state, 1000 mg q{TAU:.0f}d: peak/trough {sh['cmax']/sh['cmin']:.2f}"
          f"  against Wang's observed {PT_OBSERVED:.2f}")
    print()
    print("  THE REMAINING GAP IS A SOURCE CONFLICT, NOT A MODEL LIMITATION.")
    decay_bound = 2 ** (TAU / T_HALF_TERMINAL)
    hl_needed = TAU * LN2 / math.log(PT_OBSERVED)
    print(f"    Over {TAU:.0f} d, a {T_HALF_TERMINAL:.0f} d half-life is"
          f" {TAU/T_HALF_TERMINAL:.1f} half-lives, so decay alone")
    print(f"    bounds peak/trough at >= {decay_bound:.1f}x. Absorption sustaining the")
    print(f"    trough is what brings the model to {sh['cmax']/sh['cmin']:.1f}x.")
    print(f"    Decay alone would hit {PT_OBSERVED:.1f}x at a terminal half-life of"
          f" {hl_needed:.1f} d.")
    print()

    # The constructive refutation of the retired "TU needs 3 parameters" claim.
    # Solve for the half-life whose *simulated* peak/trough is the observed one --
    # not the pure-decay bound above, which ignores that absorption keeps refilling
    # the trough and so overshoots the required half-life by ~12%.
    def pt_at(hl):
        ls = LN2 / hl
        g = lambda x: tmax_bateman(ls, x) - TMAX_TARGET
        lf = bisect(g, *find_bracket(g, ls * 1.000001, 50.0))
        s = summarize(*steady_state_curve(ls, lf, tau=TAU, n_doses=200, npts=2000))
        return s['cmax'] / s['cmin'], lf

    h = lambda hl: pt_at(hl)[0] - PT_OBSERVED
    hl_alt = bisect(h, *find_bracket(h, 30.0, 200.0))
    pt_alt, lam_fast_alt = pt_at(hl_alt)
    print(f"    And BOTH targets are jointly reachable in this 2-rate model: pairing")
    print(f"    {hl_alt:.1f} d with {LN2/lam_fast_alt*24:.1f} h gives"
          f" Tmax {tmax_bateman(LN2/hl_alt, lam_fast_alt):.2f} d AND peak/trough"
          f" {pt_alt:.2f}.")
    print(f"    That half-life is {hl_alt/T_HALF_TERMINAL:.1f}x Zhang's measurement.")
    print("    That is the constructive disproof of the retired claim that TU needs a")
    print("    3-parameter or population-PK model (OPEN_CONCERNS.md section 4). It is")
    print("    not adopted, because a 74 d terminal half-life contradicts the only")
    print("    direct measurement anyone has published. See section 4a for the action:")
    print("    read Wang 2010's sampling schedule before touching the engine.")

    return dict(half_life_days=T_HALF_TERMINAL, elim_h=LN2 / lam_fast * 24.0,
                ewf=EWF, F=F, S=S)


# ======================================================================

def main():
    tc = fit_tc()
    td = fit_transdermal()
    orl = fit_oral()
    te = fit_te()
    tu = fit_tu()

    print()
    print("=" * 74)
    print("SWIFT CONSTANTS")
    print("=" * 74)
    print(f"  TestosteroneEster.cypionate:")
    print(f"      halfLifeDays              {tc['half_life_days']:.3f}   (was 8.0)")
    print(f"      eliminationHalfLifeHours  {tc['elim_h']:.2f}   (was 2.0)")
    print(f"      scalingConstant           {tc['S']:.2f}   (was 1081.0)")
    print(f"  TestosteroneEster.transdermal (NEW):")
    print(f"      halfLifeDays              {td['half_life_days']:.4f}")
    print(f"      esterWeightFactor         {td['ewf']}")
    print(f"      bioavailability           {td['F']}")
    print(f"      scalingConstant           {td['S']:.2f}")
    print(f"  TestosteroneEster.oral (NEW):")
    print(f"      halfLifeDays              {orl['half_life_days']:.4f}")
    print(f"      eliminationHalfLifeHours  {orl['elim_h']:.3f}")
    print(f"      esterWeightFactor         {orl['ewf']}")
    print(f"      bioavailability           {orl['F']}")
    print(f"      scalingConstant           {orl['S']:.2f}")
    print(f"  TestosteroneEster.enanthate (refit 2026-08-02):")
    print(f"      halfLifeDays              {te['half_life_days']:.4f}   (was 7.0)")
    print(f"      eliminationHalfLifeHours  {te['elim_h']:.4f}   (was 2.0)")
    print(f"      scalingConstant           {te['S']:.2f}   (was 457.67)")
    print(f"  TestosteroneEster.undecanoate (refit 2026-08-02):")
    print(f"      halfLifeDays              {tu['half_life_days']:.4f}   (unchanged)")
    print(f"      eliminationHalfLifeHours  {tu['elim_h']:.4f}   (was 2.0)")
    print(f"      scalingConstant           {tu['S']:.2f}   (was 457.67)")
    print()
    print("  TP injectable: UNCHANGED, still on the 2.0 h placeholder and S = 457.67.")
    print("  No primary-quality source was reached for it; see OPEN_CONCERNS.md 3.")


if __name__ == "__main__":
    main()
