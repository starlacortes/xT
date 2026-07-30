#!/usr/bin/env python3
"""
run_scenarios.py -- literature validation, before/after bug-fix comparison.
Run: python3 run_scenarios.py
"""
import math
from pk_engine_replica import (
    E2_ESTERS, T_ESTERS, OLD_E2_ESTERS, OLD_T_ESTERS,
    ka_ke, bateman, expected_time_to_peak, effective_dose_factor,
    DoseEvent, simulate_buggy, simulate_fixed,
)

def single_dose_curve(table, ester, dose_mg, t_max_days=30, step=0.005):
    const = table[ester]
    ka, ke = ka_ke(const)
    eff = dose_mg * effective_dose_factor(const)
    S = const["S"]
    best_t, best_c = 0.0, 0.0
    t = 0.0
    while t <= t_max_days:
        c = bateman(eff, S, ka, ke, t)
        if c > best_c:
            best_c, best_t = c, t
        t += step
    return best_t, best_c

def steady_state_curve(table, ester, dose_mg, interval_days, n_cycles=25, step=0.02):
    const = table[ester]
    ka, ke = ka_ke(const)
    eff = dose_mg * effective_dose_factor(const)
    S = const["S"]
    dose_times = [i * interval_days for i in range(n_cycles)]
    t0 = dose_times[-1]
    t1 = t0 + interval_days
    ts = []
    t = t0
    while t <= t1:
        ts.append(t)
        t += step
    vals = []
    for t in ts:
        total = sum(bateman(eff, S, ka, ke, t - dt0) for dt0 in dose_times if t - dt0 >= 0)
        vals.append(total)
    cmax, cmin = max(vals), min(vals)
    cavg = sum(vals) / len(vals)
    return ts[vals.index(cmax)] - t0, cmax, cmin, cavg


print("=" * 108)
print("PART A -- INJECTABLE ESTROGEN vs. transfemscience.org meta-analysis (single 5 mg dose, Table 9)")
print("=" * 108)
lit_single = {"Valerate (EV)": dict(tmax=2.1, cmax=295), "Cypionate (EC)": dict(tmax=4.3, cmax=155)}
print(f"{'Ester':<18}{'Model Tmax':>12}{'Lit Tmax':>10}{'Model Cmax':>12}{'Lit Cmax':>10}{'Cmax err':>10}")
for ester, lit in lit_single.items():
    t, c = single_dose_curve(E2_ESTERS, ester, 5.0)
    err = (c - lit["cmax"]) / lit["cmax"] * 100
    print(f"{ester:<18}{t:>12.2f}{lit['tmax']:>10.2f}{c:>12.1f}{lit['cmax']:>10.1f}{err:>+9.1f}%")

print("\nSteady state, 5 mg weekly (vs. transfemscience.org Table 10):")
lit_ss = {
    "Valerate (EV)":  dict(cmax=384, cmin=142, cavg=269),
    "Cypionate (EC)": dict(cmax=339, cmin=262, cavg=307),
}
print(f"{'Ester':<18}{'Model Cmax':>11}{'LitCmax':>9}{'err':>7}{'ModelCmin':>11}{'LitCmin':>9}{'err':>7}{'ModelCavg':>11}{'LitCavg':>9}{'err':>7}")
for ester, lit in lit_ss.items():
    _, cmax, cmin, cavg = steady_state_curve(E2_ESTERS, ester, 5.0, 7.0)
    e1 = (cmax - lit["cmax"]) / lit["cmax"] * 100
    e2 = (cmin - lit["cmin"]) / lit["cmin"] * 100
    e3 = (cavg - lit["cavg"]) / lit["cavg"] * 100
    print(f"{ester:<18}{cmax:>11.1f}{lit['cmax']:>9.1f}{e1:>+6.1f}%{cmin:>11.1f}{lit['cmin']:>9.1f}{e2:>+6.1f}%{cavg:>11.1f}{lit['cavg']:>9.1f}{e3:>+6.1f}%")
print("(Recalibrated 2026-07-29: ka fit to the Table 10 trough, ke to the published Tmax, S anchored")
print(" to the Table 10 steady-state peak. Single-dose Cmax above was NOT a fit target -- it lands")
print(" within ~1% (EV) / ~5% (EC) of Table 9 independently, which cross-validates the shape.)")

print()
print("=" * 108)
print("PART B -- TESTOSTERONE ESTERS: before vs. after scalingConstant fix")
print("=" * 108)
t_targets = {
    "Cypionate (TC)":   dict(dose=100.0, lo=600, hi=900,  lit_note="lit ~550-750 ng/dL @100mg (scaled from 200mg trial)"),
    "Enanthate (TE)":   dict(dose=100.0, lo=600, hi=900,  lit_note="lit ~740 ng/dL @100mg (scaled from 200mg, Lakshman et al.)"),
    "Propionate (TP)":  dict(dose=50.0,  lo=800, hi=1200, lit_note="app-internal target (sparse published TG data)"),
    "Undecanoate (TU)": dict(dose=1000.0, lo=400, hi=700, lit_note="lit ~1100 ng/dL @1000mg first inj. (Wang et al. 2010) -- see note"),
}
print(f"{'Ester':<18}{'Dose':>7}  {'OLD Cmax':>10}  {'NEW Cmax':>10}  {'Target':>13}   Notes")
for ester, t in t_targets.items():
    _, old_c = single_dose_curve(OLD_T_ESTERS, ester, t["dose"])
    _, new_c = single_dose_curve(T_ESTERS, ester, t["dose"])
    print(f"{ester:<18}{t['dose']:>7.0f}  {old_c:>10.1f}  {new_c:>10.1f}  {t['lo']:.0f}-{t['hi']:.0f}{'':>5}   {t['lit_note']}")

print()
print("=" * 108)
print("PART C -- ORAL & TRANSDERMAL E2: before vs. after routing+scaling fix")
print("=" * 108)
oral_doses = [DoseEvent(t_days=0.0, ester="Oral", medication="Estrogen", route="Oral", dose_mg=2.0)]
grid = [i * 0.0417 for i in range(int(2 / 0.0417))]  # 0..2 days, hourly
old_oral = simulate_buggy(oral_doses, "Oral", grid, use_old_constants=True)
new_oral = simulate_fixed(oral_doses, grid)
print(f"Oral 2mg single dose:  OLD Cmax = {max(old_oral):.2f} pg/mL   NEW Cmax = {max(new_oral):.1f} pg/mL   "
      f"(app target ~60 pg/mL; single-dose literature ~31 pg/mL fasting, Kim et al.)")

td_doses = [DoseEvent(t_days=d, ester="Transdermal", medication="Estrogen", route="Cream", dose_mg=1.0) for d in range(10)]
grid2 = [9 + i * 0.02 for i in range(51)]
old_td = simulate_buggy(td_doses, "Cream", grid2, use_old_constants=True)
new_td = simulate_fixed(td_doses, grid2)
print(f"Transdermal 1mg/day, steady state (day 9-10):  OLD Cmax = {max(old_td):.3f} pg/mL   NEW Cmax = {max(new_td):.1f} pg/mL   "
      f"(app target ~50 pg/mL; literature ~54 pg/mL peak for 1g gel, Wiegratz et al.)")

print()
print("=" * 108)
print("PART D -- BUG IMPACT: skipped-dose inclusion & route-switch mismodeling (worked examples)")
print("=" * 108)

doses_with_skip = [
    DoseEvent(t_days=0.0, ester="Cypionate (TC)", medication="Testosterone", route="Injectable", dose_mg=100.0, status="taken"),
    DoseEvent(t_days=7.0, ester="Cypionate (TC)", medication="Testosterone", route="Injectable", dose_mg=100.0, status="skipped"),
]
t_check = [14.0]
old_val = simulate_buggy(doses_with_skip, "Injectable", t_check, use_old_constants=False)[0]
fixed_val = simulate_fixed(doses_with_skip, t_check)[0]
print(f"D1. User takes TC 100mg on day 0, explicitly SKIPS the day-7 dose. Level checked on day 14:")
print(f"    Before fix: skip still contributes -> predicted contribution = {old_val:.1f} ng/dL")
print(f"    After  fix: skip excluded          -> predicted contribution = {fixed_val:.1f} ng/dL "
      f"({(old_val - fixed_val) / max(fixed_val, 0.01) * 100:+.0f}% overstatement before the fix)")

doses_route_switch = [
    DoseEvent(t_days=0.0, ester="Oral", medication="Estrogen", route="Oral", dose_mg=2.0, status="taken"),
]
t_check2 = [10/24]  # 10 hours later, same day
old_val2 = simulate_buggy(doses_route_switch, "Injectable", t_check2, use_old_constants=True)[0]
fixed_val2 = simulate_fixed(doses_route_switch, t_check2)[0]
print(f"\nD2. User takes oral E2 2mg, then immediately switches their app setting to Injectable")
print(f"    (first EV dose not due for a week). Level checked 10h later, oral dose still active:")
print(f"    Before fix: historical oral dose retroactively re-modeled with injectable kinetics -> {old_val2:.1f} pg/mL")
print(f"    After  fix: dose keeps its own route\'s kinetics regardless of current selection    -> {fixed_val2:.1f} pg/mL")

print()
print("=" * 108)
print("PART E -- expectedTimeToPeak() vs. literature Tmax windows")
print("=" * 108)
lit_tmax = {
    ("Estrogen", "Valerate (EV)"):    (1.5, 2.5, "Tiong/transfemscience: 1.9-2.1d"),
    ("Estrogen", "Cypionate (EC)"):   (3.0, 4.5, "transfemscience: 3.1-4.3d"),
    ("Testosterone", "Cypionate (TC)"):  (1.0, 2.0, "Multiple TRT PK studies: 24-48h"),
    ("Testosterone", "Enanthate (TE)"):  (1.0, 3.0, "Ichihara et al. 2020 (trans men): mean 1.7d"),
}
for (med, ester), (lo, hi, note) in lit_tmax.items():
    table = E2_ESTERS if med == "Estrogen" else T_ESTERS
    tmax = expected_time_to_peak(table[ester])
    status = "OK" if lo <= tmax <= hi else "MODEL UNDERESTIMATES" if tmax < lo else "MODEL OVERESTIMATES"
    print(f"{med:<14}{ester:<20} model={tmax:.2f}d  lit_window={lo}-{hi}d  [{status}]   ({note})")
print()
print("Note: EV/EC were recalibrated 2026-07-29 and now match their literature windows. The")
print("testosterone esters still underestimate Tmax -- their ke is untouched pending published")
print("steady-state trough data to fit ka against (see fit_constants.py, T-ester section).")
