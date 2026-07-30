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
    "Oral":             dict(half_life_days=0.5, elim_h=3.0, ewf=1.000, F=0.05, S=1250.0),
    "Transdermal":      dict(half_life_days=1.5, elim_h=3.0, ewf=1.000, F=0.15, S=155.0),
}

T_ESTERS = {
    "Cypionate (TC)":   dict(half_life_days=8.0,  elim_h=2.0, ewf=0.699, F=1.0, S=1081.0),
    "Enanthate (TE)":   dict(half_life_days=7.0,  elim_h=2.0, ewf=0.720, F=1.0, S=923.0),
    "Propionate (TP)":  dict(half_life_days=1.0,  elim_h=2.0, ewf=0.837, F=1.0, S=359.0),
    "Undecanoate (TU)": dict(half_life_days=20.0, elim_h=2.0, ewf=0.631, F=1.0, S=214.0),
}

# ----------------------------------------------------------------------
# ORIGINAL (pre-fix) constants, exactly as found during QA
# ----------------------------------------------------------------------

OLD_E2_ESTERS = {k: dict(v) for k, v in E2_ESTERS.items()}
OLD_E2_ESTERS["Oral"]["S"] = 12000.0
OLD_E2_ESTERS["Transdermal"]["S"] = 8000.0

OLD_T_ESTERS = {k: dict(v) for k, v in T_ESTERS.items()}
OLD_T_ESTERS["Cypionate (TC)"]["S"] = 11.0
OLD_T_ESTERS["Enanthate (TE)"]["S"] = 11.0
OLD_T_ESTERS["Propionate (TP)"]["S"] = 18.0
OLD_T_ESTERS["Undecanoate (TU)"]["S"] = 5.0


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


def simulate_fixed(doses, t_grid):
    """Behavior after the 2026-07-28 fixes."""
    points = []
    taken = [d for d in doses if d.status == "taken"]   # FIX: skipped doses excluded
    for t in t_grid:
        total = 0.0
        for d in taken:
            dt = t - d.t_days
            if dt < 0:
                continue
            table = E2_ESTERS if d.medication == "Estrogen" else T_ESTERS
            const = table[d.ester]
            eff_amount = d.dose_mg * effective_dose_factor(const)

            # FIX: branch on this dose's OWN route, not the global selection.
            if d.route == "Injectable":
                ka, ke = ka_ke(const)
                total += bateman(eff_amount, const["S"], ka, ke, dt)
            elif d.route == "Oral":
                oral_ka, oral_ke = 2.5, 1.386
                S = E2_ESTERS.get(d.ester, E2_ESTERS["Oral"])["S"]
                total += bateman(eff_amount, S, oral_ka, oral_ke, dt)
            elif d.route == "Cream":
                td_ka = math.log(2) / 1.5
                S = E2_ESTERS.get(d.ester, E2_ESTERS["Transdermal"])["S"]
                micro = eff_amount / 24.0
                for h in range(24):
                    micro_dt = t - (d.t_days + h / 24.0)
                    if micro_dt < 0:
                        continue
                    total += micro * S * math.exp(-td_ka * micro_dt)   # FIX: scaling applied
        points.append(total)
    return points


if __name__ == "__main__":
    print("Imported by run_scenarios.py / test_users.py -- see those files for output.")
