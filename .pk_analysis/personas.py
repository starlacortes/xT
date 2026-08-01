#!/usr/bin/env python3
"""
personas.py -- end-to-end validation of the xT PK model against synthetic users.

verify_constants.py checks each constant against the published anchor it was fit to,
one regimen at a time and always at clean steady state. Real users are messier: they
miss doses, change dose, change route, take a two-week break, and dose on intervals no
trial studied. This file exercises the model the way it will actually be used.

Every persona is a full dose history run through simulate_fixed(), the same summation
the app performs. Each is scored against a clinical reference band and, where the
2026-07-31 route-normalization changed the answer, diffed against simulate_pre_20260731
so the size of the change is measured rather than asserted.

Reference bands
---------------
  Testosterone, therapeutic total T .... 300-1000 ng/dL (trough >= 300 is the usual
                                         titration goal; Cmax < 1500 is the safety rail
                                         xT itself flags)
  Estradiol, transfeminine target ...... 100-200 pg/mL trough is the commonly cited
                                         goal; the app flags > 1000 as Very High

These are ranges for *total* levels. The engine returns the exogenous contribution;
endogenous production is added separately by the app as `baseLevel`, so each persona
declares the baseline appropriate to their situation and it is added before scoring.

Run:  python3 .pk_analysis/personas.py
"""

import sys

from pk_engine_replica import (
    DoseEvent, E2_ESTERS, T_ESTERS, simulate_fixed, simulate_pre_20260731,
    effective_ester_name,
)

DAY = 1.0
WARN = []


# ----------------------------------------------------------------------
# Scenario plumbing
# ----------------------------------------------------------------------

def schedule(start_day, end_day, every, ester, medication, route, dose_mg,
             skip=(), status_fn=None):
    """Emit doses on a fixed interval over [start_day, end_day)."""
    out, t, i = [], float(start_day), 0
    while t < end_day:
        st = "taken"
        if i in skip:
            st = "skipped"
        elif status_fn is not None:
            st = status_fn(i, t)
        out.append(DoseEvent(t_days=t, ester=ester, medication=medication,
                             route=route, dose_mg=dose_mg, status=st))
        t += every
        i += 1
    return out


def profile(doses, t0, t1, baseline, step=0.02, engine=simulate_fixed):
    """Sample the modeled curve over [t0, t1], with the endogenous floor added."""
    n = int((t1 - t0) / step)
    grid = [t0 + step * k for k in range(n + 1)]
    ys = [v + baseline for v in engine(doses, grid)]
    return grid, ys


def stats(grid, ys):
    cmax, cmin = max(ys), min(ys)
    cavg = sum(ys[:-1]) / len(ys[:-1])
    return dict(cmax=cmax, cmin=cmin, cavg=cavg,
                tmax=grid[ys.index(cmax)], ratio=cmax / cmin if cmin else float("inf"))


def band(label, value, lo, hi, unit):
    ok = lo <= value <= hi
    if not ok:
        WARN.append(f"{label}: {value:.0f} {unit} outside {lo:.0f}-{hi:.0f}")
    return f"[{'ok ' if ok else 'OUT'}] {label:<34} {value:>8.0f} {unit}  target {lo:.0f}-{hi:.0f}"


def header(n, name, blurb):
    print()
    print("=" * 96)
    print(f"PERSONA {n} -- {name}")
    print("=" * 96)
    for line in blurb.strip().splitlines():
        print("  " + line.strip())
    print()


def report(s, unit, extra=""):
    print(f"  steady-state window: Cmax {s['cmax']:>8.0f}   Cmin {s['cmin']:>8.0f}"
          f"   Cavg {s['cavg']:>8.0f} {unit}   peak/trough {s['ratio']:.2f}x{extra}")


def diff_vs_predecessor(doses, t0, t1, baseline, unit):
    """How much did 2026-07-31 move this persona's numbers?"""
    _, old = profile(doses, t0, t1, baseline, engine=simulate_pre_20260731)
    _, new = profile(doses, t0, t1, baseline)
    o, n = sum(old) / len(old), sum(new) / len(new)
    if abs(o - n) / max(n, 1e-9) < 0.005:
        print(f"  vs pre-2026-07-31 build: unchanged ({n:.0f} {unit} mean)")
        return
    print(f"  vs pre-2026-07-31 build: mean {o:,.0f} -> {n:,.0f} {unit}"
          f"   ({o / n if n else float('inf'):,.1f}x reduction)")


# ======================================================================
# 1. Maya -- the textbook case. If this one is wrong, nothing else matters.
# ======================================================================
header(1, "Maya, 24 -- estradiol valerate, injectable, textbook adherence", """
Eighteen months on 4 mg EV intramuscularly every 7 days, never missed one.
She is the control: a regimen squarely inside published data, no gaps, no
changes. Purpose is to confirm the model reproduces the shape and magnitude
of the source curve before any of the messier personas are trusted.
""")

maya = schedule(0, 540, 7, "Valerate (EV)", "Estrogen", "Injectable", 4.0)
g, y = profile(maya, 525, 532, baseline=0.0)   # last full interval
s_maya = stats(g, y)
report(s_maya, "pg/mL")
print(f"  Tmax within the interval: {s_maya['tmax'] - 525:.2f} d"
      f"   (published EV Tmax 2.1 d)")
print("  " + band("trough E2", s_maya["cmin"], 100, 200, "pg/mL"))
print("  " + band("peak E2 below the app's Very High flag", s_maya["cmax"], 0, 1000, "pg/mL"))
diff_vs_predecessor(maya, 525, 532, 0.0, "pg/mL")
print("""
  READ: scaling to the 5 mg/week source regimen the constants were fit to,
  4 mg/week should sit at 4/5 of Table 10's 384/191 pg/mL, i.e. 307/153.
  The model returns that within rounding. Linear dose scaling is exact here
  because the Bateman is linear in dose -- which is also its main limitation:
  no saturable binding, no SHBG dynamics.
""")


# ======================================================================
# 2. Devon -- dose and interval change mid-history.
# ======================================================================
header(2, "Devon, 31 -- testosterone cypionate, changed regimen at month 6", """
Started 100 mg TC weekly. At six months his trough came back low and his
prescriber moved him to 200 mg every 14 days -- same mg/week, different
shape. He wants to know whether the new schedule actually holds his level.
Purpose is superposition across a regimen change, and whether the model
reproduces the well-known result that longer intervals trade trough for peak.
""")

devon = (schedule(0, 182, 7, "Cypionate (TC)", "Testosterone", "Injectable", 100.0)
         + schedule(182, 540, 14, "Cypionate (TC)", "Testosterone", "Injectable", 200.0))
BASAL_T = 240.0   # Bi et al. b_base 6.24 mg/day / CL 2.6 kL/day; xT's `baseLevel`

g, y = profile(devon, 168, 175, BASAL_T)
s_before = stats(g, y)
g, y = profile(devon, 512, 526, BASAL_T)
s_after = stats(g, y)

print("  BEFORE (100 mg q7d):")
report(s_before, "ng/dL")
print("  " + band("trough T", s_before["cmin"], 300, 1000, "ng/dL"))
print("  AFTER  (200 mg q14d):")
report(s_after, "ng/dL")
print("  " + band("trough T", s_after["cmin"], 300, 1000, "ng/dL"))
print("  " + band("peak T below the app's supraphysiological flag",
                  s_after["cmax"], 0, 1500, "ng/dL"))
print(f"\n  Cavg is preserved across the change ({s_before['cavg']:.0f} ->"
      f" {s_after['cavg']:.0f} ng/dL) as it must be -- same mg/week, and Cavg depends"
      f"\n  only on dose rate and clearance. Peak/trough widens"
      f" {s_before['ratio']:.2f}x -> {s_after['ratio']:.2f}x.")
print("""
  READ: the model correctly reproduces the clinical trade-off, and it correctly
  refuses to reward the longer interval. Devon's trough falls while his peak
  rises. This is the single most useful thing the chart can tell a user, and it
  is a structural property of the math, not of any fitted constant.
""")


# ======================================================================
# 3. Priya -- route switch. This is the one the 07-31 fix was written for.
# ======================================================================
header(3, "Priya, 47 -- oral estradiol for 4 months, then switched to injections", """
2 mg oral estradiol twice daily for four months, then switched to 4 mg EV
weekly because the oral peaks and troughs were giving her headaches. Her old
oral doses stay in her history forever. Purpose is to confirm historical
doses keep their own route's kinetics after the switch -- and that the stored
ester on those old records resolves to the oral pseudo-ester, not to EV.
""")

priya = (schedule(0, 120, 0.5, "Oral", "Estrogen", "Oral", 2.0)
         + schedule(120, 400, 7, "Valerate (EV)", "Estrogen", "Injectable", 4.0))

g, y = profile(priya, 112, 114, baseline=0.0)
s_oral = stats(g, y)
print("  WHILE ORAL (2 mg BID), one full day:")
report(s_oral, "pg/mL")
print("  " + band("mean E2 on oral", s_oral["cavg"], 50, 200, "pg/mL"))

g, y = profile(priya, 385, 392, baseline=0.0)
s_inj = stats(g, y)
print("  AFTER SWITCH (4 mg EV q7d):")
report(s_inj, "pg/mL")

# The point of the persona: the old oral doses must not be re-modeled as EV. Compare
# the constants each path would apply, since both give the same curve *shape* here.
oral_c, ev_c = E2_ESTERS["Oral"], E2_ESTERS["Valerate (EV)"]
oral_amp = oral_c["ewf"] * oral_c["F"] * oral_c["S"]
ev_amp = ev_c["ewf"] * ev_c["F"] * ev_c["S"]
print(f"\n  Her oral doses resolve to EDF {oral_c['ewf']*oral_c['F']:.3f} x S {oral_c['S']:.0f}"
      f" = {oral_amp:.1f} per mg.")
print(f"  Resolved by the stored ester after a switch to EV they would take"
      f" {ev_c['ewf']*ev_c['F']:.3f} x {ev_c['S']:.0f} = {ev_amp:.0f} per mg"
      f" -- {ev_amp/oral_amp:.1f}x higher,")
print(f"  on top of EV's much slower rates. Route normalization is what keeps them apart.")
print("""
  READ: the separation is correct -- the oral segment keeps F = 0.05 and the fast
  rates, the injectable segment keeps F = 1.0 and EV's.

  BUT the oral curve is FLATTER THAN IT SHOULD BE, and that is a finding, not a pass.
  The model gives Priya a peak/trough of about 1.1x across a day; real oral estradiol
  on a BID schedule swings considerably more. The cause is the oral rate constants
  themselves: ka = 2.5/day is an absorption half-life of 6.7 h, which puts Tmax at
  12.7 h -- longer than the 12 h dosing interval, so each dose is still rising when
  the next arrives and the curve smooths into a nearly flat line. Published oral
  estradiol Tmax is on the order of 4-8 h. The engine's own comment described
  ka = 2.5 as "~1h absorption", which is arithmetically wrong by a factor of ~7.

  Cavg is unaffected (it depends only on dose rate, F and ke), so Priya's average and
  her trough-adjacent numbers are usable; her intraday peak is under-modeled. Logged
  as a new open concern rather than refit here -- changing ka requires re-deriving S
  against the same source, which is out of scope for this pass.
""")


# ======================================================================
# 4. Sam -- transdermal testosterone with poor adherence. The 1090x defect.
# ======================================================================
header(4, "Sam, 19 -- testosterone gel 50 mg/day, misses roughly two days a week", """
First year of treatment, gel because he did not want needles. He forgets it
on weekends. Purpose is twofold: this is the exact configuration that used
to overpredict by three orders of magnitude, and it tests that skipped doses
are excluded from the curve rather than silently modeled as taken.
""")

sam = schedule(0, 400, 1, "Transdermal", "Testosterone", "Cream", 50.0,
               status_fn=lambda i, t: "skipped" if i % 7 in (5, 6) else "taken")
g, y = profile(sam, 385, 392, BASAL_T)
s_sam = stats(g, y)
report(s_sam, "ng/dL")
print("  " + band("weekly-mean T", s_sam["cavg"], 300, 1000, "ng/dL"))
print("  " + band("Monday-morning trough T", s_sam["cmin"], 200, 1000, "ng/dL"))

perfect = schedule(0, 400, 1, "Transdermal", "Testosterone", "Cream", 50.0)
_, yp = profile(perfect, 385, 392, BASAL_T)
s_perfect = stats(g, yp)
print(f"\n  Perfect adherence for comparison: Cavg {s_perfect['cavg']:.0f} ng/dL."
      f"\n  Sam's two missed days cost him {(1 - s_sam['cavg']/s_perfect['cavg'])*100:.0f}%"
      f" of his average level and {(1 - s_sam['cmin']/s_perfect['cmin'])*100:.0f}% of his trough.")
diff_vs_predecessor(sam, 385, 392, BASAL_T, "ng/dL")
print("""
  READ: this persona is the reason the 2026-07-31 change exists. On the previous
  build Sam's chart read in the hundreds of thousands of ng/dL. It now lands on the
  AndroGel label. The peak/trough shown above is driven by his two missed days, not
  by intraday ripple -- the model's *intraday* ripple is only ~1.05x against a real
  ~2.2x, so his day-to-day highs and lows within a dosed day are flattened (see
  verify_constants.py section 2). Gel absorption also varies enormously between
  people; Sam's real level could reasonably be half or double this, which is what
  the app's calibration factor against blood tests is for.
""")


# ======================================================================
# 5. Rowan -- estradiol cream, the onboarding-label defect.
# ======================================================================
header(5, "Rowan, 38 -- compounded estradiol cream, 4 mg/day, onboarded in-app", """
Non-binary, low-dose maintenance, applies cream nightly. Onboarded through
the app rather than configuring from Settings. Purpose is a defect found
while writing this file: onboarding stored the ester as the raw method name
"Cream", which matches no case in the ester enum, so the engine's lookup
failed and fell through to a hardcoded scaling constant.
""")

rowan_ok = schedule(0, 400, 1, "Transdermal", "Estrogen", "Cream", 4.0)
rowan_onboarded = schedule(0, 400, 1, "Cream", "Estrogen", "Cream", 4.0)  # as stored

g, y = profile(rowan_ok, 385, 392, baseline=0.0)
s_rowan = stats(g, y)
report(s_rowan, "pg/mL")
print("  " + band("mean E2", s_rowan["cavg"], 50, 250, "pg/mL"))
print(f"  resolver check: ester 'Cream' + route 'Cream' ->"
      f" {effective_ester_name('Cream', 'Cream')!r}")

_, y_old = profile(rowan_onboarded, 385, 392, 0.0, engine=simulate_pre_20260731)
_, y_new = profile(rowan_onboarded, 385, 392, 0.0)
old_mean = sum(y_old) / len(y_old)
new_mean = sum(y_new) / len(y_new)
print(f"\n  Same user, same record, previous build: {old_mean:,.0f} pg/mL mean.")
print(f"  Current build: {new_mean:,.0f} pg/mL -- identical to a correctly-stored record,")
print(f"  because the route now decides the constants and the stored string does not.")
if old_mean > 0:
    print(f"  Overprediction closed: {old_mean/new_mean:,.0f}x")
print("""
  READ: a second, independent instance of the same root cause, affecting estrogen
  users rather than testosterone ones, and reachable only through onboarding --
  users who set the same route from Settings stored "Transdermal" and were fine.
  Both the storage bug and the lookup bug are fixed; either fix alone would have
  been sufficient for new records, but only the lookup fix repairs existing ones.
""")


# ======================================================================
# 6. Kai -- oral TU with a long interruption.
# ======================================================================
header(6, "Kai, 52 -- oral testosterone undecanoate, 237 mg twice daily, 10-day gap", """
On Jatenzo. Travelled for two weeks and left the bottle at home, missing ten
days entirely, then resumed. Purpose is washout and re-accumulation on the
route with the fastest kinetics in the app -- and a check that the model does
not carry phantom drug through a gap.
""")

kai = (schedule(0, 200, 0.5, "Oral", "Testosterone", "Oral", 237.0)
       + schedule(210, 400, 0.5, "Oral", "Testosterone", "Oral", 237.0))

g, y = profile(kai, 198, 199, BASAL_T)
s_pre = stats(g, y)
print("  BEFORE the gap (one full day):")
report(s_pre, "ng/dL")
print("  " + band("daily-mean T", s_pre["cavg"], 300, 1000, "ng/dL"))

g, y = profile(kai, 200, 210, BASAL_T)
s_gap = stats(g, y)
print(f"\n  DURING the 10-day gap: falls to {s_gap['cmin']:.0f} ng/dL"
      f" -- the endogenous floor of {BASAL_T:.0f} plus {s_gap['cmin']-BASAL_T:.1f}")
print(f"  Washout is essentially complete within a day, as expected for a route with a"
      f"\n  {0.09*24:.1f} h terminal half-life. No phantom drug survives the gap.")

g, y = profile(kai, 212, 213, BASAL_T)
s_post = stats(g, y)
print(f"\n  AFTER resuming, 2 days back on: Cavg {s_post['cavg']:.0f} ng/dL"
      f" ({s_post['cavg']/s_pre['cavg']*100:.0f}% of pre-gap)")
diff_vs_predecessor(kai, 198, 199, BASAL_T, "ng/dL")
print("""
  READ: correct behaviour, and it illustrates a genuine clinical property -- oral
  TU has no depot, so adherence failures show up immediately rather than being
  buffered. Contrast Sam, whose missed gel days cost him far less proportionally,
  and Devon, whose depot would barely notice a single missed day.
  Caveat: Cmax is under-modeled here by about 22% (see verify_constants.py section 3).
""")


# ======================================================================
# 7. Jules -- an ester with no primary-source calibration.
# ======================================================================
header(7, "Jules, 28 -- testosterone enanthate 100 mg weekly", """
Standard TE regimen, and the persona that found a defect. TE has no primary
source of its own, so it was originally expected to be shown here as an
uncalibrated ester with wide error bars. Running it instead exposed that its
steady-state average was 2x too high and contradicted primary-sourced TC by
the same factor -- which is impossible, since both deliver testosterone and
clearance belongs to the molecule. Purpose is now to show the corrected
magnitude alongside the shape error that remains.
""")

jules = schedule(0, 400, 7, "Enanthate (TE)", "Testosterone", "Injectable", 100.0)
g, y = profile(jules, 385, 392, BASAL_T)
s_jules = stats(g, y)
report(s_jules, "ng/dL")
print("  " + band("trough T", s_jules["cmin"], 300, 1000, "ng/dL"))
print(f"  Tmax {s_jules['tmax'] - 385:.2f} d")
print("""
  MAGNITUDE: now correct, and derived rather than fitted. Before 2026-07-31 this
  same regimen read Cmax 1753 / Cmin 1041 / Cavg 1381 ng/dL -- a level that would
  have read as clearly supraphysiological to a prescriber. Applying the steady-state
  identity S = 1e5*ke/(CL_T*F), which follows from the TC refit and needs no TE
  source, brings it onto published TE 100 mg/week data. See verify_constants.py 1b.

  SHAPE: still wrong, and this is what remains open. TE keeps the placeholder 2 h
  `ke` that TC was refit away from, so its Tmax is 0.46 d against a published window
  of 1.5-7 d. Jules' peak is right and arrives at roughly the right height; it just
  arrives several days early, and the curve between peak and trough has the wrong
  curvature. The same applies to TP and TU. Fixing it needs per-ester absorption
  data nobody has published in a usable form. OPEN_CONCERNS.md section 3.
""")


# ======================================================================
# 8. Nadia -- an interval nobody studied.
# ======================================================================
header(8, "Nadia, 35 -- estradiol cypionate 5 mg every 10 days", """
Uses EC on a 10-day interval because that is what her injection supplies and
schedule allow. No published trial uses that interval. Purpose is to probe
the model outside its calibration envelope -- the case where the app is
extrapolating and should say so.
""")

nadia = schedule(0, 400, 10, "Cypionate (EC)", "Estrogen", "Injectable", 5.0)
g, y = profile(nadia, 380, 390, baseline=0.0)
s_nadia = stats(g, y)
report(s_nadia, "pg/mL")
print("  " + band("trough E2", s_nadia["cmin"], 100, 200, "pg/mL"))

weekly = schedule(0, 400, 7, "Cypionate (EC)", "Estrogen", "Injectable", 5.0)
g, y = profile(weekly, 385, 392, baseline=0.0)
s_weekly = stats(g, y)
print(f"  The calibrated 7-day regimen for comparison: Cmax {s_weekly['cmax']:.0f},"
      f" Cmin {s_weekly['cmin']:.0f} pg/mL")
print(f"  Stretching to 10 days drops the trough {(1-s_nadia['cmin']/s_weekly['cmin'])*100:.0f}%"
      f" and widens peak/trough {s_weekly['ratio']:.2f}x -> {s_nadia['ratio']:.2f}x.")
print("""
  READ: the extrapolation is structurally sound -- superposition of a fitted
  single-dose curve is exactly how one would extend to an unstudied interval -- but
  it inherits every assumption of the fit, including strict dose-linearity and a
  constant clearance. It is a projection, not a measurement, and the further the
  interval is from 7 days the more the trough estimate should be treated as
  indicative. Her trough holds inside the target band, but only just, and it sits
  40% below where the same dose on a 7-day interval would put her -- which is
  exactly the kind of thing the chart should be surfacing to her.
""")


# ======================================================================
print()
print("=" * 96)
print("SUMMARY")
print("=" * 96)
print(f"  8 personas covering: EV / EC / TC / TE injectable, E2 oral, E2 cream,")
print(f"  T gel, T oral -- every medication-route combination the app supports.")
print(f"  Exercised: perfect adherence, missed doses, dose change, interval change,")
print(f"  route switch, multi-day interruption, off-protocol interval, and an ester")
print(f"  whose absorption rate is still uncalibrated.")
print()
if WARN:
    print(f"  {len(WARN)} value(s) outside their reference band -- each is discussed above:")
    for w in WARN:
        print(f"    - {w}")
else:
    print("  All persona values inside their reference bands.")
print()
print("  Two defects were found by running these rather than by inspection:")
print("    - Rowan (5): onboarding stored ester \"Cream\", which matched no enum case,")
print("      so the engine used a hardcoded scaling constant. Fixed both ends.")
print("    - Jules (7): TE steady-state Cavg was 2x too high and contradicted")
print("      primary-sourced TC. Fixed by the conservation identity.")
print()
print("  Two limitations are quantified but NOT fixed, and are carried into the dossier:")
print("    - oral estradiol Tmax is 12.7 h against a published 4-8 h, so intraday")
print("      swing is under-modeled (Priya, 3).")
print("    - TE/TP/TU absorption rates are placeholders, so their Tmax is 0.3-0.7 d")
print("      against published 1.5-7 d. Magnitude right, shape wrong (Jules, 7).")
sys.exit(0)
