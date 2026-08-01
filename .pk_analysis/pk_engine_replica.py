#!/usr/bin/env python3
"""
pk_engine_replica.py

Faithful Python re-implementation of xT's Swift PK engine, in two forms:

  * OLD_* / simulate_buggy()  -- the code exactly as found during QA (before
    any fixes), including all three bugs identified:
      (1) oral/transdermal dose events routed through an unscaled,
          non-Bateman branch (main superposition loop bug)
      (2) DoseEvent construction gated on the global selected route rather
          than each dose's own administrationMethod
      (3) skipped doses (doseStatus == .skipped) still contributing to the
          PK curve
    plus the pre-existing testosterone `scalingConstant` miscalibration.

  * E2_ESTERS / T_ESTERS / simulate_fixed() -- the code AFTER the fixes
    applied to MedicationManager+Pharmacokinetics.swift and
    PharmacokineticConstants.swift on 2026-07-28.

Both share the same underlying Bateman/exponential math (never in question);
only the constants and the event-routing logic differ.
"""

import math
from dataclasses import dataclass

# ----------------------------------------------------------------------
# CURRENT (fixed) constants -- mirrors PharmacokineticConstants.swift
# ----------------------------------------------------------------------

E2_ESTERS = {
    # EV/EC recalibrated 2026-07-29 -- see fit_constants.py. ka fit to the Table 10
    # trough, ke fit to the published Tmax, S anchored to the Table 10 steady-state peak.
    "Valerate (EV)":    dict(half_life_days=2.60, elim_h=21.5, ewf=0.764, F=1.00, S=396.4),
    "Cypionate (EC)":   dict(half_life_days=6.47, elim_h=38.6, ewf=0.687, F=1.00, S=273.0),
    # Oral restated 2026-07-31 from (0.5 d, 3.0 h) to (0.2773 d, 12.0035 h). NOT a
    # recalibration: the engine never read those fields for oral doses, it hardcoded
    # ka = 2.5 and ke = 1.386 inline, and S = 1250 was fit against those. The stored
    # values now reproduce exactly what the engine used. Predictions are unchanged.
    "Oral":             dict(half_life_days=0.2773, elim_h=12.0035, ewf=1.000, F=0.05, S=1250.0),
    "Transdermal":      dict(half_life_days=1.5, elim_h=3.0, ewf=1.000, F=0.15, S=155.0),
}

T_ESTERS = {
    # TC refit 2026-07-31 from the primary population-PK source (Bi et al. 2018,
    # doi 10.1002/psp4.12287, Table 2): CL/F 2.6 kL/d, V/F 14.4 kL, Ka 1.22 /d.
    #   half_life_days 8.0 -> 3.839  (= ln2 / (CL/V), exogenous-only; xT models
    #                                 endogenous secretion separately as baseLevel)
    #   elim_h         2.0 -> 13.64  (= ln2 / Ka)
    #   S           1081.0 -> 67.13  (closed form: 1e5*Ka / (V_L * EDF * ke))
    # TE / TP / TU scaling corrected 2026-07-31 to 457.67 by conservation of mass:
    # Cavg = Dose*EDF*S/(tau*ke) must equal (mg T/day)/CL_T, and CL_T is a property of
    # testosterone, not of the ester -- so S = 1e5*ke/(CL_T*F) with CL_T = 1817.4 L/day.
    # EWF cancels, so all three share one S while ke is shared. Their `ka` (and hence
    # Tmax) remain UNCALIBRATED. See OPEN_CONCERNS.md section 3 and fit_testosterone.py.
    "Cypionate (TC)":   dict(half_life_days=3.839, elim_h=13.64, ewf=0.699, F=1.00, S=67.13),
    "Enanthate (TE)":   dict(half_life_days=7.0,   elim_h=2.0,   ewf=0.720, F=1.00, S=457.67),
    "Propionate (TP)":  dict(half_life_days=1.0,   elim_h=2.0,   ewf=0.837, F=1.00, S=457.67),
    "Undecanoate (TU)": dict(half_life_days=20.0,  elim_h=2.0,   ewf=0.631, F=1.00, S=457.67),
    # Route pseudo-esters added 2026-07-31. Before this, testosterone on the Oral or
    # Cream route had no entry at all: the engine's scaling lookup was guarded on
    # `medication == "Estrogen"` and fell through to the hardcoded 12000.0 / 8000.0,
    # overpredicting by ~1100x. See fit_testosterone.py.
    "Oral":             dict(half_life_days=0.09,   elim_h=2.003, ewf=0.631, F=1.00, S=13.57),
    "Transdermal":      dict(half_life_days=0.5784, elim_h=0.0,   ewf=1.000, F=0.10, S=132.98),
}


def effective_ester_name(ester, route):
    """Mirrors MedicationManager.effectiveEsterName.

    Non-injectable routes are governed by their route pseudo-ester, not by whatever
    injectable ester happens to be stored on the dose record.
    """
    if route == "Oral":
        return "Oral"
    if route == "Cream":
        return "Transdermal"
    return ester

# ----------------------------------------------------------------------
# ORIGINAL (pre-fix) constants, exactly as found during QA
# ----------------------------------------------------------------------

OLD_E2_ESTERS = {k: dict(v) for k, v in E2_ESTERS.items()}
OLD_E2_ESTERS["Oral"]["S"] = 12000.0
OLD_E2_ESTERS["Transdermal"]["S"] = 8000.0

OLD_E2_ESTERS["Oral"]["half_life_days"] = 0.5
OLD_E2_ESTERS["Oral"]["elim_h"] = 3.0

OLD_T_ESTERS = {k: dict(v) for k, v in T_ESTERS.items()}
OLD_T_ESTERS["Cypionate (TC)"].update(half_life_days=8.0, elim_h=2.0, S=11.0)
OLD_T_ESTERS["Enanthate (TE)"]["S"] = 11.0   # -> 923.0 (2026-07-28) -> 457.67
OLD_T_ESTERS["Propionate (TP)"]["S"] = 18.0  # -> 359.0 (2026-07-28) -> 457.67
OLD_T_ESTERS["Undecanoate (TU)"]["S"] = 5.0  # -> 214.0 (2026-07-28) -> 457.67

# TestosteroneEster had no .oral / .transdermal cases before 2026-07-31.
del OLD_T_ESTERS["Oral"]
del OLD_T_ESTERS["Transdermal"]

# With no entry to find, both non-injectable branches used these hardcoded literals.
OLD_T_ROUTE_FALLBACK_S = {"Oral": 12000.0, "Cream": 8000.0}


def effective_dose_factor(const):
    return const["ewf"] * const["F"]

def ka_ke(const):
    ka = math.log(2) / const["half_life_days"]
    ke = math.log(2) / (const["elim_h"] / 24.0)
    return ka, ke

def expected_time_to_peak(const):
    ka, ke = ka_ke(const)
    if abs(ka - ke) < 1e-4:
        return 1.0 / ka
    return math.log(ka / ke) / (ka - ke)

def bateman(amount, scaling, ka, ke, t):
    if t < 0:
        return 0.0
    denom = ka - ke
    if abs(denom) < 1e-4:
        return amount * scaling * ka * t * math.exp(-ka * t)
    return amount * scaling * (ka / denom) * (math.exp(-ke * t) - math.exp(-ka * t))


@dataclass
class DoseEvent:
    t_days: float
    ester: str
    medication: str          # "Estrogen" | "Testosterone"
    route: str                # "Injectable" | "Oral" | "Cream"
    dose_mg: float
    status: str = "taken"     # "taken" | "skipped" | "missed"


def _tables(old):
    return (OLD_E2_ESTERS, OLD_T_ESTERS) if old else (E2_ESTERS, T_ESTERS)


def simulate_buggy(doses, global_route, t_grid, use_old_constants=True):
    """Reproduces the CODE AS FOUND, bugs and all."""
    e2, t_ = _tables(use_old_constants)
    is_injectable_global = (global_route == "Injectable")
    points = []
    for t in t_grid:
        total = 0.0
        for d in doses:
            # BUG: skipped doses were NOT filtered out.
            dt = t - d.t_days
            if dt < 0:
                continue
            table = e2 if d.medication == "Estrogen" else t_
            const = table[d.ester]
            eff_amount = d.dose_mg * effective_dose_factor(const)

            # BUG: event construction gated on the GLOBAL route, not d.route.
            if is_injectable_global:
                ka, ke = ka_ke(const)
                total += bateman(eff_amount, const["S"], ka, ke, dt)
            elif d.route == "Oral":
                oral_ka, oral_ke = 2.5, 1.386
                S = e2.get(d.ester, e2["Oral"])["S"]
                # BUG: main loop's `isInjectable && event.ke>0` is false here
                # (global route isn't Injectable), so this NEVER actually used
                # Bateman or S in the original code -- just amount*exp(-ka*dt).
                total += eff_amount * math.exp(-oral_ka * dt)
            elif d.route == "Cream":
                td_ka = math.log(2) / 1.5
                micro = eff_amount / 24.0
                for h in range(24):
                    micro_dt = t - (d.t_days + h / 24.0)
                    if micro_dt < 0:
                        continue
                    # BUG: scaling constant never applied in the single-exp branch.
                    total += micro * math.exp(-td_ka * micro_dt)
            else:
                ka, _ = ka_ke(const)
                total += eff_amount * math.exp(-ka * dt)
        points.append(total)
    return points


def simulate_pre_20260731(doses, t_grid):
    """The engine as it stood between the 2026-07-28 QA fixes and 2026-07-31.

    Route branching and the skipped-dose filter are already correct here; what is not
    is the constant lookup. Both non-injectable branches resolved their scaling constant
    behind `medication == "Estrogen"` and otherwise used a hardcoded literal, the
    absorption rate for those routes was hardcoded, and EDF came from the dose's stored
    ester regardless of route. Kept so persona scenarios can be diffed against it rather
    than described in prose.
    """
    points = []
    taken = [d for d in doses if d.status == "taken"]
    for t in t_grid:
        total = 0.0
        for d in taken:
            dt = t - d.t_days
            if dt < 0:
                continue
            table = OLD_E2_ESTERS if d.medication == "Estrogen" else OLD_T_ESTERS
            const = table.get(d.ester)

            # `dosePotencyFactor` resolved EDF from the stored ester alone. When that
            # string matched no case -- e.g. onboarding stored ester "Cream" -- the
            # lookup returned nil and the function fell through to `return 1.0`, so the
            # dose was modeled at full strength with no bioavailability applied at all.
            eff_amount = d.dose_mg * (effective_dose_factor(const) if const else 1.0)

            if d.route == "Injectable":
                if const is None:
                    continue
                ka, ke = ka_ke(const)
                total += bateman(eff_amount, const["S"], ka, ke, dt)
            elif d.route == "Oral":
                # `if medication == "Estrogen", let e = MedicationEster(rawValue:)`
                S = (OLD_E2_ESTERS[d.ester]["S"]
                     if d.medication == "Estrogen" and d.ester in OLD_E2_ESTERS
                     else OLD_T_ROUTE_FALLBACK_S["Oral"])
                total += bateman(eff_amount, S, 2.5, 1.386, dt)     # hardcoded rates
            elif d.route == "Cream":
                S = (OLD_E2_ESTERS[d.ester]["S"]
                     if d.medication == "Estrogen" and d.ester in OLD_E2_ESTERS
                     else OLD_T_ROUTE_FALLBACK_S["Cream"])
                td_ka = math.log(2) / 1.5                            # hardcoded rate
                micro = eff_amount / 24.0
                for h in range(24):
                    micro_dt = t - (d.t_days + h / 24.0)
                    if micro_dt < 0:
                        continue
                    total += micro * S * math.exp(-td_ka * micro_dt)
        points.append(total)
    return points


def dose_constants(d):
    """Constants that actually govern dose `d`, after route normalization."""
    table = E2_ESTERS if d.medication == "Estrogen" else T_ESTERS
    return table[effective_ester_name(d.ester, d.route)]


def simulate_fixed(doses, t_grid):
    """Behavior after the 2026-07-28 and 2026-07-31 fixes.

    2026-07-31: both the rate constants and the scaling constant for every route now
    come from the route's effective ester, so testosterone gets its own oral and
    transdermal calibration instead of falling through to estrogen's (or, worse, to a
    hardcoded literal). EDF is resolved the same way, so a gel dose uses the gel's
    EWF 1.0 x F 0.10 rather than the stored injectable ester's 0.699 x 1.0.
    """
    points = []
    taken = [d for d in doses if d.status == "taken"]   # FIX: skipped doses excluded
    for t in t_grid:
        total = 0.0
        for d in taken:
            dt = t - d.t_days
            if dt < 0:
                continue
            const = dose_constants(d)                    # FIX: route-normalized lookup
            eff_amount = d.dose_mg * effective_dose_factor(const)
            ka, ke = ka_ke(const) if const["elim_h"] else (math.log(2) / const["half_life_days"], 0.0)

            # FIX: branch on this dose's OWN route, not the global selection.
            if d.route in ("Injectable", "Oral"):
                total += bateman(eff_amount, const["S"], ka, ke, dt)
            elif d.route == "Cream":
                micro = eff_amount / 24.0
                for h in range(24):
                    micro_dt = t - (d.t_days + h / 24.0)
                    if micro_dt < 0:
                        continue
                    total += micro * const["S"] * math.exp(-ka * micro_dt)  # FIX: scaling applied
        points.append(total)
    return points


if __name__ == "__main__":
    print("Imported by run_scenarios.py / test_users.py -- see those files for output.")
