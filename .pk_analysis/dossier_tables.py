#!/usr/bin/env python3
"""
dossier_tables.py -- generates every numeric table in docs/pk-validation-dossier.tex.

The dossier quotes a lot of figures. Rather than hand-copying them out of the other
scripts (where they would silently rot the next time a constant moves), this file
computes them all in one place and prints them as LaTeX table bodies, ready to paste.

Run:  python3 .pk_analysis/dossier_tables.py
"""

import math

from pk_engine_replica import (
    DoseEvent, E2_ESTERS, T_ESTERS, OLD_T_ESTERS, OLD_T_ROUTE_FALLBACK_S,
    simulate_fixed, simulate_pre_20260731, ka_ke, effective_dose_factor,
    expected_time_to_peak,
)

LN2 = math.log(2)


def ss(medication, ester, route, dose, tau, n=400, pts=600):
    doses = [DoseEvent(t_days=i * tau, ester=ester, medication=medication,
                       route=route, dose_mg=dose) for i in range(n)]
    t0 = (n - 1) * tau
    grid = [t0 + tau * k / pts for k in range(pts + 1)]
    ys = simulate_fixed(doses, grid)
    return max(ys), min(ys), sum(ys[:-1]) / (len(ys) - 1)


def single(medication, ester, route, dose, horizon, pts=6000):
    doses = [DoseEvent(t_days=0.0, ester=ester, medication=medication,
                       route=route, dose_mg=dose)]
    grid = [horizon * k / pts for k in range(pts + 1)]
    ys = simulate_fixed(doses, grid)
    cmax = max(ys)
    return cmax, grid[ys.index(cmax)]


def row(*cells):
    print(" & ".join(str(c) for c in cells) + r" \\")


# ======================================================================
print(r"% ---- TABLE: encoded constants ----")
NAMES = [("Estrogen", "Valerate (EV)", "EV"), ("Estrogen", "Cypionate (EC)", "EC"),
         ("Estrogen", "Oral", "E2 oral"), ("Estrogen", "Transdermal", "E2 gel/cream"),
         ("Testosterone", "Cypionate (TC)", "TC"), ("Testosterone", "Enanthate (TE)", "TE"),
         ("Testosterone", "Propionate (TP)", "TP"), ("Testosterone", "Undecanoate (TU)", "TU"),
         ("Testosterone", "Oral", "T oral (TU)"), ("Testosterone", "Transdermal", "T gel")]
for med, key, label in NAMES:
    c = (E2_ESTERS if med == "Estrogen" else T_ESTERS)[key]
    ka = LN2 / c["half_life_days"]
    if c["elim_h"]:
        ke = LN2 / (c["elim_h"] / 24.0)
        tmax = f"{math.log(ka/ke)/(ka-ke):.2f}"
        ke_s = f"{ke:.4f}"
    else:
        ke_s, tmax = "--", "--"
    row(label, f"{c['half_life_days']:.4f}", f"{ka:.4f}", ke_s,
        f"{c['ewf']:.3f}", f"{c['F']:.2f}", f"{c['S']:.2f}", tmax)

# ======================================================================
print()
print(r"% ---- TABLE: predicted vs published ----")

CASES = [
    # label, med, ester, route, dose, tau, quantity, model_fn, published, source
    ("EV 5\\,mg q7d", "Estrogen", "Valerate (EV)", "Injectable", 5.0, 7.0,
     "$C_{\\max}$", "cmax", 384.0, "TFS Table 10"),
    ("EV 5\\,mg q7d", "Estrogen", "Valerate (EV)", "Injectable", 5.0, 7.0,
     "$C_{\\min}$", "cmin", 142.0, "TFS Table 10"),
    ("EC 5\\,mg q7d", "Estrogen", "Cypionate (EC)", "Injectable", 5.0, 7.0,
     "$C_{\\max}$", "cmax", 339.0, "TFS Table 10"),
    ("EC 5\\,mg q7d", "Estrogen", "Cypionate (EC)", "Injectable", 5.0, 7.0,
     "$C_{\\min}$", "cmin", 262.0, "TFS Table 10"),
    ("TC 100\\,mg q7d", "Testosterone", "Cypionate (TC)", "Injectable", 100.0, 7.0,
     "$C_{\\mathrm{avg}}$", "cavg", 1e5 * 100.0 / (2600.0 * 7.0), "Bi Table 2 (CL/F)"),
    ("T gel 50\\,mg/d", "Testosterone", "Transdermal", "Cream", 50.0, 1.0,
     "$C_{\\mathrm{avg}}$", "cavg", 555.0, "AndroGel 1\\% Table 5"),
    ("T gel 75\\,mg/d", "Testosterone", "Transdermal", "Cream", 75.0, 1.0,
     "$C_{\\mathrm{avg}}$", "cavg", 601.0, "AndroGel 1\\% Table 5"),
    ("T gel 100\\,mg/d", "Testosterone", "Transdermal", "Cream", 100.0, 1.0,
     "$C_{\\mathrm{avg}}$", "cavg", 713.0, "AndroGel 1\\% Table 5"),
    ("Oral TU 237\\,mg BID", "Testosterone", "Oral", "Oral", 237.0, 0.5,
     "$C_{\\mathrm{avg}}$", "cavg", 488.7, "Jatenzo"),
    ("Oral TU 237\\,mg BID", "Testosterone", "Oral", "Oral", 237.0, 0.5,
     "$C_{\\max}$", "cmax", 1008.3, "Jatenzo"),
]
for label, med, ester, route, dose, tau, qty, key, pub, src in CASES:
    cmax, cmin, cavg = ss(med, ester, route, dose, tau)
    got = {"cmax": cmax, "cmin": cmin, "cavg": cavg}[key]
    err = (got - pub) / pub * 100.0
    row(label, qty, f"{got:.0f}", f"{pub:.0f}", f"{err:+.1f}\\%", src)

# ======================================================================
print()
print(r"% ---- TABLE: out-of-sample checks (not used in any fit) ----")
cmax100, tmax100 = single("Testosterone", "Cypionate (TC)", "Injectable", 100.0, 20.0)
cmax200, _ = single("Testosterone", "Cypionate (TC)", "Injectable", 200.0, 20.0)
row("TC single 200\\,mg, $C_{\\max}$ (exogenous)", f"{cmax200:.0f}", "872",
    f"{(cmax200-872)/872*100:+.1f}\\%",
    "200\\,mg IM literature 1112 less Bi's 240 basal")
tc_cmax_w, tc_cmin_w, _ = ss("Testosterone", "Cypionate (TC)", "Injectable", 100.0, 7.0)
row("TC 100\\,mg q7d, $C_{\\max}$ + basal", f"{tc_cmax_w+240:.0f}", "1150",
    f"{(tc_cmax_w+240-1150)/1150*100:+.1f}\\%", "Bi Figure 2, 100\\,mg panel")
ev_c, _ = single("Estrogen", "Valerate (EV)", "Injectable", 2.0, 30.0)
ec_c, _ = single("Estrogen", "Cypionate (EC)", "Injectable", 2.0, 40.0)
row("EV single 2\\,mg, $C_{\\max}$", f"{ev_c:.0f}", "118",
    f"{(ev_c-118)/118*100:+.1f}\\%", "TFS Table 9")
row("EC single 2\\,mg, $C_{\\max}$", f"{ec_c:.0f}", "62",
    f"{(ec_c-62)/62*100:+.1f}\\%", "TFS Table 9")

# ======================================================================
print()
print(r"% ---- TABLE: clearance identity ----")
CL_T = 2600.0 * T_ESTERS["Cypionate (TC)"]["ewf"]
print(f"% CL_T = {CL_T:.1f} L/day")
OLD_S = {"Cypionate (TC)": 1081.0, "Enanthate (TE)": 923.0,
         "Propionate (TP)": 359.0, "Undecanoate (TU)": 214.0}
REGIMEN = {"Cypionate (TC)": (100.0, 7.0), "Enanthate (TE)": (100.0, 7.0),
           "Propionate (TP)": (50.0, 2.0), "Undecanoate (TU)": (1000.0, 70.0)}
for name in OLD_S:
    c = T_ESTERS[name]
    ka, ke = ka_ke(c)
    implied = 1e5 * ke / (CL_T * c["F"])
    dose, tau = REGIMEN[name]
    # Cavg under the OLD constants -- TC's ke also moved (2.0 h -> 13.64 h), so the
    # "before" column has to use the old ke, not the current one.
    edf = effective_dose_factor(c)
    old_ke = LN2 / (OLD_T_ESTERS[name]["elim_h"] / 24.0)
    old_cavg = dose * edf * OLD_S[name] / (tau * old_ke)
    new_cavg = dose * edf * c["S"] / (tau * ke)
    row(name.split()[0], f"{OLD_S[name]:.1f}", f"{c['S']:.2f}", f"{implied:.2f}",
        f"{OLD_S[name]/implied:.2f}$\\times$",
        f"{dose:.0f}\\,mg q{tau:.0f}d", f"{old_cavg:.0f}", f"{new_cavg:.0f}")

# ======================================================================
print()
print(r"% ---- TABLE: defect magnitudes ----")


def old_cream_cavg(dose_mg, stored_ester, medication, n_days=60, samples=400):
    S = OLD_T_ROUTE_FALLBACK_S["Cream"]
    const = OLD_T_ESTERS.get(stored_ester)
    edf = effective_dose_factor(const) if const else 1.0
    ka = LN2 / 1.5
    micro = dose_mg * edf / 24.0
    t0 = float(n_days - 1)
    ys = []
    for k in range(samples + 1):
        t = t0 + k / samples
        tot = 0.0
        for day in range(n_days):
            for h in range(24):
                dt = t - (day + h / 24.0)
                if dt >= 0:
                    tot += micro * S * math.exp(-ka * dt)
        ys.append(tot)
    return sum(ys[:-1]) / (len(ys) - 1)


def pre_cavg(medication, ester, route, dose, tau, n=200, pts=200):
    doses = [DoseEvent(t_days=i * tau, ester=ester, medication=medication,
                       route=route, dose_mg=dose) for i in range(n)]
    t0 = (n - 1) * tau
    grid = [t0 + tau * k / pts for k in range(pts + 1)]
    ys = simulate_pre_20260731(doses, grid)
    return sum(ys[:-1]) / (len(ys) - 1)


gel_old = old_cream_cavg(50.0, "Cypionate (TC)", "Testosterone")
_, _, gel_new = ss("Testosterone", "Transdermal", "Cream", 50.0, 1.0)
row("T gel 50\\,mg/d (stored ester TC)", f"{gel_old:,.0f}", f"{gel_new:.0f}",
    f"{gel_old/gel_new:,.0f}$\\times$", "555")

oral_old = pre_cavg("Testosterone", "Undecanoate (TU)", "Oral", 237.0, 0.5)
_, _, oral_new = ss("Testosterone", "Oral", "Oral", 237.0, 0.5)
row("Oral TU 237\\,mg BID (stored ester TU)", f"{oral_old:,.0f}", f"{oral_new:.0f}",
    f"{oral_old/oral_new:,.0f}$\\times$", "489")

cream_old = old_cream_cavg(4.0, "Cream", "Estrogen")
_, _, cream_new = ss("Estrogen", "Transdermal", "Cream", 4.0, 1.0)
row("E2 cream 4\\,mg/d (onboarded, ester \\texttt{\"Cream\"})",
    f"{cream_old:,.0f}", f"{cream_new:.0f}", f"{cream_old/cream_new:,.0f}$\\times$", "--")

# ======================================================================
print()
print(r"% ---- TABLE: Tmax vs published ----")
TMAX = [("EV", "Estrogen", "Valerate (EV)", "2.1 d", "TFS"),
        ("EC", "Estrogen", "Cypionate (EC)", "3.1--4.3 d", "TFS"),
        ("E2 oral", "Estrogen", "Oral", "4--8 h", "secondary"),
        ("TC", "Testosterone", "Cypionate (TC)", "1.84 d", "Bi Table 2"),
        ("TE", "Testosterone", "Enanthate (TE)", "1.5--7 d", "secondary"),
        ("TP", "Testosterone", "Propionate (TP)", "$\\sim$0.6 d", "sparse"),
        ("TU", "Testosterone", "Undecanoate (TU)", "$\\sim$7 d", "secondary (Wang 2010)"),
        ("T oral", "Testosterone", "Oral", "2--4 h", "Jatenzo")]
for label, med, key, pub, src in TMAX:
    c = (E2_ESTERS if med == "Estrogen" else T_ESTERS)[key]
    tm = expected_time_to_peak(c)
    disp = f"{tm*24:.1f} h" if tm < 1.0 else f"{tm:.2f} d"
    row(label, disp, pub, src)

print()
print("% done")
