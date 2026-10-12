#!/usr/bin/env python3
"""Resolve Isocline design tokens and emit them for web, print, and tests.

Source of truth: docs/design/tokens/isocline.tokens.json (hand-edited).
This script ports the color math from xT/Theme/ThemeEngine.swift (OKLab /
OKLCH, gamut clamp by chroma bisection, WCAG contrast repair) so the values
it resolves at the default seed match what the app renders.

Writes (deterministically — re-running produces no diff):
    docs/design/tokens/isocline.tokens.json   'resolved' block only
    docs/design/tokens/isocline.css           CSS custom properties, light + dark
    docs/design/tokens/isocline.tokens.js     the same JSON for file:// HTML docs
    docs/research/isocline.sty                Isocline Research LaTeX template
    xTTests/IsoclineTokenExpectations.swift   expected hexes for the parity test
    xT/Assets.xcassets/LaunchPaper.colorset   the launch screen's paper (O3)
    THEME_COLOR_PAGES                         <meta name="theme-color"> values kept in sync

Usage: python3 -I tools/scripts/gen_isocline_tokens.py   (stdlib only, Python 3.9+)
"""

import json
import math
from collections import OrderedDict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOKENS = REPO / "docs" / "design" / "tokens" / "isocline.tokens.json"
CSS_OUT = REPO / "docs" / "design" / "tokens" / "isocline.css"
STY_OUT = REPO / "docs" / "research" / "isocline.sty"
SWIFT_OUT = REPO / "xTTests" / "IsoclineTokenExpectations.swift"
JS_OUT = REPO / "docs" / "design" / "tokens" / "isocline.tokens.js"
# The launch screen can't read the user's seed, so it renders the default-seed
# paper (element O3): light is cream at every seed (absolute hue) and only the
# dark value is a default-seed approximation. A sub-second flash, close enough.
# The colorset is emitted for completeness, but the launch *storyboard* embeds
# raw resolved RGB values — ibtool rejects named-color references it can't
# resolve at compile time, so `sync_launch_storyboard` keeps the two `<color>`
# entries in step with the same resolved paper.
LAUNCH_COLORSET = REPO / "xT" / "Assets.xcassets" / "LaunchPaper.colorset"
LAUNCH_STORYBOARD = REPO / "xT" / "Base.lproj" / "xTLaunchScreen.storyboard"
# Web pages whose per-scheme <meta name="theme-color"> must match the resolved paper.
# Add every future web surface (landing page, Research site) here.
THEME_COLOR_PAGES = [
    REPO / "docs" / "design" / "ISOCLINE_DESIGN_SYSTEM.html",
]

# ── ThemeEngine port ──────────────────────────────────────────────────────


def cbrt(x):
    return math.copysign(abs(x) ** (1 / 3), x)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def oklab_from_linear(r, g, b):
    l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def linear_from_oklab(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def norm_hue(h):
    h = math.fmod(h, 360)
    return h + 360 if h < 0 else h


def lch_to_linear(lch):
    L, C, H = lch
    rad = math.radians(H)
    return linear_from_oklab(L, C * math.cos(rad), C * math.sin(rad))


def lch_to_srgb(lch):
    return tuple(linear_to_srgb(min(max(c, 0.0), 1.0)) for c in lch_to_linear(lch))


def oklch_from_hex(hexstr):
    h = hexstr.lstrip("#")
    r, g, b = (srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    L, a, bb = oklab_from_linear(r, g, b)
    return (L, math.hypot(a, bb), norm_hue(math.degrees(math.atan2(bb, a))))


def in_gamut(lch, tol=1e-4):
    return all(-tol <= c <= 1 + tol for c in lch_to_linear(lch))


def clamp_to_gamut(lch, iterations=12):
    if in_gamut(lch):
        return lch
    lo, hi = 0.0, lch[1]
    best = (lch[0], 0.0, lch[2])
    for _ in range(iterations):
        mid = (lo + hi) / 2
        cand = (lch[0], mid, lch[2])
        if in_gamut(cand):
            best, lo = cand, mid
        else:
            hi = mid
    return best


def luminance(rgb):
    r, g, b = (srgb_to_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a_rgb, b_rgb):
    la, lb = luminance(a_rgb), luminance(b_rgb)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


FLOORS = {"bodyText": 4.5, "largeTextOrGraphic": 3.0}


def repair(fg, bg_rgb, floor, toward_light, iterations=16):
    target = FLOORS[floor]
    initial = clamp_to_gamut(fg)

    def ratio(l):
        return contrast(lch_to_srgb(clamp_to_gamut((l, initial[1], initial[2]))), bg_rgb)

    if ratio(initial[0]) >= target:
        return initial
    extreme = 1.0 if toward_light else 0.0
    if ratio(extreme) < target:
        return clamp_to_gamut((extreme, initial[1], initial[2]))
    lo, hi = (initial[0], extreme) if toward_light else (extreme, initial[0])
    for _ in range(iterations):
        mid = (lo + hi) / 2
        if ratio(mid) >= target:
            if toward_light:
                hi = mid
            else:
                lo = mid
        else:
            if toward_light:
                lo = mid
            else:
                hi = mid
    return clamp_to_gamut((hi if toward_light else lo, initial[1], initial[2]))


# ── Resolution ────────────────────────────────────────────────────────────


def to_hex(rgb):
    return "#" + "".join(f"{round(c * 255):02X}" for c in rgb)


def resolve(tokens):
    seed = oklch_from_hex(tokens["seed"]["defaultHex"])[2]
    out = OrderedDict()
    out["seedHue"] = round(seed, 4)
    rgb = {}
    for appearance, idx in (("light", 0), ("dark", 1)):
        resolved = OrderedDict()
        for name, recipe in tokens["recipes"].items():
            L, C, h = recipe[appearance]
            # Hue is an offset from the seed unless the recipe pins it for this
            # appearance ("hue": {"light": "absolute"}): day paper is cream at
            # every dial position, the safety red is never themed.
            absolute = recipe.get("hue", {}).get(appearance) == "absolute"
            lch = clamp_to_gamut((L, C, norm_hue(h if absolute else seed + h)))
            rep = recipe.get("repair")
            if rep:
                bg = rgb[(rep["against"], appearance)]
                # Text repairs away from its ground: lighter on night paper, darker on day
                # paper, unless the recipe names a direction (ink on an accent fill).
                direction = rep.get("direction")
                toward_light = direction == "light" if direction else appearance == "dark"
                lch = repair(lch, bg, rep["floor"], toward_light=toward_light)
            value = lch_to_srgb(lch)
            rgb[(name, appearance)] = value
            resolved[name] = to_hex(value)
        ink = rgb[("ink", appearance)]
        for name, alphas in tokens["inkAlpha"].items():
            r, g, b = (round(c * 255) for c in ink)
            resolved[name] = f"rgba({r}, {g}, {b}, {alphas[idx]})"
        out[appearance] = resolved
    stops = tokens["seed"]["stops"]
    out["seedStops"] = [round(norm_hue(seed + i * stops["stepDegrees"]), 2) for i in range(stops["count"])]
    return out


def ink_rgba(res, appearance, alpha):
    r, g, b = (int(res[appearance]["ink"][i:i + 2], 16) for i in (1, 3, 5))
    return f"rgba({r}, {g}, {b}, {alpha})"


# ── Emitters ──────────────────────────────────────────────────────────────

HEADER = "Generated by tools/scripts/gen_isocline_tokens.py from docs/design/tokens/isocline.tokens.json — do not edit by hand."


def kebab(name):
    return "".join("-" + c.lower() if c.isupper() else c for c in name).replace("accent2", "accent-2")


def emit_css(tokens, res):
    fam = tokens["type"]["families"]
    lines = [f"/* {HEADER} */", "", ":root {", "  color-scheme: light dark;"]

    def block(values, indent="  "):
        return [f"{indent}--{kebab(k)}: {v};" for k, v in values.items()]

    def px(v):
        return f"{v}px" if isinstance(v, (int, float)) else None

    lines += block(res["light"])
    # Both grounds, always available (logo plates and previews show day and night side by side).
    lines += [
        f"  --day-paper: {res['light']['paper']};",
        f"  --day-ink: {res['light']['ink']};",
        f"  --night-paper: {res['dark']['paper']};",
        f"  --night-ink: {res['dark']['ink']};",
        f"  --success: {tokens['fixed']['success']['hex']};",
        f"  --sage: {tokens['fixed']['sage']['hex']};",
        f"  --font-display: '{fam['display']['name']}', Georgia, serif;",
        f"  --font-mono: '{fam['mono']['name']}', 'SF Mono', ui-monospace, monospace;",
        f"  --font-body: '{fam['prose']['name']}', 'Atkinson Hyperlegible', 'Helvetica Neue', system-ui, sans-serif;",
    ]
    for k, v in tokens["radius"].items():
        lines.append(f"  --radius-{kebab(k)}: {v}px;")
    for k, v in tokens["spacing"].items():
        lines.append(f"  --space-{kebab(k)}: {v}px;")
    for k, v in tokens["line"].items():
        lines.append(f"  --line-{kebab(k)}: {v}px;")
    cv = tokens["curve"]
    lines += [
        f"  --curve-fill-top-opacity: {cv['fill']['topOpacity']};",
        f"  --range-band-opacity: {cv['rangeBand']['opacity']};",
        f"  --now-halo-opacity: {cv['nowPoint']['haloOpacity']};",
        f"  --now-dot: {cv['nowPoint']['dotDiameter']}px;",
        f"  --now-halo: {cv['nowPoint']['haloDiameter']}px;",
        f"  --lab-ring: {cv['labPoint']['diameter']}px;",
        f"  --curve-glow-opacity: {cv['glow']['opacity']};",
        f"  --curve-glow-radius: {cv['glow']['radius']}px;",
    ]
    for comp, spec in tokens["components"].items():
        for k, v in spec.items():
            if k == "role" or not isinstance(v, (int, float)):
                continue
            unit = "" if "Opacity" in k or k == "aspect" else "px"
            lines.append(f"  --{kebab(comp)}-{kebab(k)}: {v}{unit};")
    lines += [
        "}",
        "",
        "/* A forced theme also forces the browser's own UI (scrollbars, form controls). */",
        ":root[data-theme=\"light\"] { color-scheme: light; }",
        "",
        "@media (prefers-color-scheme: dark) {",
        "  :root:not([data-theme=\"light\"]) {",
    ]
    lines += block(res["dark"], "    ")
    lines += ["  }", "}", "", ":root[data-theme=\"dark\"] {", "  color-scheme: dark;"]
    lines += block(res["dark"])
    lines += ["}", ""]
    # Increase Contrast on the web: stronger hairlines and grid, per appearance.
    hc = tokens["inkAlphaIncreasedContrast"]
    def hc_block(appearance, idx, indent):
        return [f"{indent}--{kebab(k)}: {ink_rgba(res, appearance, v[idx])};" for k, v in hc.items() if k != "role"]
    lines += ["@media (prefers-contrast: more) {", "  :root {"]
    lines += hc_block("light", 0, "    ")
    lines += ["  }", "  :root[data-theme=\"dark\"] {"]
    lines += hc_block("dark", 1, "    ")
    lines += ["  }", "}", "", "@media (prefers-contrast: more) and (prefers-color-scheme: dark) {",
              "  :root:not([data-theme=\"light\"]) {"]
    lines += hc_block("dark", 1, "    ")
    lines += ["  }", "}", ""]
    return "\n".join(lines)


def sync_theme_color(path, res):
    """Rewrite <meta name="theme-color" … media="(prefers-color-scheme: light|dark)"> to the resolved paper."""
    import re
    text = path.read_text()
    for appearance in ("light", "dark"):
        pattern = (r'(<meta name="theme-color" content=")#[0-9A-Fa-f]{6}'
                   r'(" media="\(prefers-color-scheme: ' + appearance + r'\)">)')
        text, n = re.subn(pattern, r"\g<1>" + res[appearance]["paper"] + r"\g<2>", text)
        if n != 1:
            raise SystemExit(f"{path}: expected one {appearance} theme-color meta, found {n}")
    write(path, text)


def emit_launch_colorset(res):
    """LaunchPaper.colorset (element O3) — default-seed paper, light + dark."""
    def color(h):
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
        s = f"{r:.14g}, {g:.14g}, {b:.14g}"
        return ('      {"color" : {"color-space" : "srgb", "components" : '
                '{"red" : "%s", "green" : "%s", "blue" : "%s"}}, '
                '"idiom" : "universal"}' % tuple(s.split(", ")))
    def dark_color(h):
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
        return ('      {"appearances" : [{"appearance" : "luminosity", "value" : "dark"}], '
                '"color" : {"color-space" : "srgb", "components" : '
                '{"red" : "%s", "green" : "%s", "blue" : "%s"}}, '
                '"idiom" : "universal"}' % (f"{r:.14g}", f"{g:.14g}", f"{b:.14g}"))
    return (
        "{\n"
        "  \"colors\" : [\n"
        + color(res["light"]["paper"]) + ",\n"
        + dark_color(res["dark"]["paper"]) + "\n"
        "  ],\n"
        "  \"info\" : {\n"
        "    \"author\" : \"xcode\",\n"
        "    \"version\" : 1\n"
        "  }\n"
        "}\n"
    )


def sync_launch_storyboard(res):
    """Rewrite the launch storyboard's `<color key="backgroundColor">` to the resolved
    default-seed light paper. Raw RGB, not the LaunchPaper color name — a launch
    storyboard's XML can't express per-appearance background colors and ibtool
    rejects named colors in launch screens, so dark mode shows the cream for the
    sub-second flash until the app's own dark paper takes over (O3 accepts this)."""
    import re
    text = LAUNCH_STORYBOARD.read_text()
    h = res["light"]["paper"].lstrip("#")
    r, g, b = (f"{int(h[i:i + 2], 16) / 255:.14g}" for i in (0, 2, 4))
    repl = (f'<color key="backgroundColor" red="{r}" green="{g}" blue="{b}" '
            'alpha="1" colorSpace="custom" customColorSpace="sRGB"/>')
    # Match either the seed marker (first generation) or a previously resolved
    # value (re-generation) — idempotent like sync_theme_color.
    pattern = (r'<color key="backgroundColor"(?: data-color="paper-light")?'
               r'(?: red="[0-9.]+" green="[0-9.]+" blue="[0-9.]+" alpha="1"'
               r' colorSpace="custom" customColorSpace="sRGB")?/>')
    text, n = re.subn(pattern, repl, text)
    if n != 1:
        raise SystemExit(f"{LAUNCH_STORYBOARD}: expected one background color, found {n}")
    write(LAUNCH_STORYBOARD, text)


def latex_rgb(hexstr):
    h = hexstr.lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def emit_sty(tokens, res):
    light = res["light"]
    p = tokens["fixed"]["print"]
    return rf"""% {HEADER}
%
% isocline.sty — the Isocline Research paper template (print form of the
% Paper & Instrument system). Ink on paper, IBM Plex type, one accent, no
% status colors. Spec: docs/design/ISOCLINE_DESIGN_SYSTEM.html §11.
%
% Usage (pdfLaTeX), from a paper in docs/research/<paper>/:
%   \makeatletter\def\input@path{{{{../}}{{../../design/brand/}}}}\makeatother
%   \usepackage{{isocline}}
%   \isoclineshorttitle{{PK Model}}        % right-hand running head
%   \isoclineeyebrow{{Technical Report}}   % mono line above the title
%
\NeedsTeXFormat{{LaTeX2e}}
\ProvidesPackage{{isocline}}[{tokens['meta']['version'].replace('.', '/')} Isocline Research template]

\RequirePackage[T1]{{fontenc}}
\RequirePackage{{xcolor}}
\RequirePackage{{fancyhdr}}
\RequirePackage{{titlesec}}
\RequirePackage{{graphicx}}
\RequirePackage{{tikz}}

% ── Type ─────────────────────────────────────────────────────────────────
% Plex Serif carries body and headings; Plex Mono carries numbers, code and
% running heads; Atkinson Hyperlegible Next carries captions and table text.
\IfFileExists{{plex-serif.sty}}{{\RequirePackage{{plex-serif}}}}{{\PackageWarning{{isocline}}{{plex-serif not found; using default serif}}}}
\IfFileExists{{plex-mono.sty}}{{\RequirePackage[scale=0.92]{{plex-mono}}}}{{\PackageWarning{{isocline}}{{plex-mono not found; using default mono}}}}
\IfFileExists{{atkinson.sty}}{{\RequirePackage[nomono,scale=0.94]{{atkinson}}}}{{\PackageWarning{{isocline}}{{atkinson not found; using default sans}}}}

% ── Color (resolved at the default seed, light appearance) ─────────────────
\definecolor{{isoInk}}{{RGB}}{{{latex_rgb(p['ink'])}}}
\colorlet{{isoMuted}}{{isoInk!62!white}}
\colorlet{{isoFaint}}{{isoInk!38!white}}
\colorlet{{isoRule}}{{isoInk!22!white}}
\definecolor{{isoAccent}}{{RGB}}{{{latex_rgb(light['accent'])}}}
\definecolor{{isoLevelLow}}{{RGB}}{{{latex_rgb(light['levelLow'])}}}
\definecolor{{isoLevelHigh}}{{RGB}}{{{latex_rgb(light['levelHigh'])}}}
\color{{isoInk}}

% Neutral markup. Replaces the old red/green warn/ok macros: Isocline
% presents observations, never verdicts.
\newcommand{{\obs}}[1]{{\textbf{{#1}}}}
\newcommand{{\note}}[1]{{\textcolor{{isoMuted}}{{#1}}}}
% Mono eyebrow: uppercase, letterspaced via microtype when available.
\newif\ifiso@tracking
\IfFileExists{{microtype.sty}}{{\RequirePackage[tracking=true]{{microtype}}\iso@trackingtrue}}{{}}
\ifiso@tracking
  \newcommand{{\eyebrow}}[1]{{{{\ttfamily\scriptsize\textls[180]{{\MakeUppercase{{#1}}}}}}}}
\else
  \newcommand{{\eyebrow}}[1]{{{{\ttfamily\scriptsize\MakeUppercase{{#1}}}}}}
\fi

% ── Headings ───────────────────────────────────────────────────────────────
\titleformat{{\section}}{{\normalfont\Large\bfseries}}{{\textcolor{{isoMuted}}{{\ttfamily\large\thesection}}}}{{0.8em}}{{}}
\titleformat{{\subsection}}{{\normalfont\large\bfseries}}{{\textcolor{{isoMuted}}{{\ttfamily\normalsize\thesubsection}}}}{{0.8em}}{{}}
\titleformat{{\subsubsection}}{{\normalfont\normalsize\bfseries}}{{\textcolor{{isoMuted}}{{\ttfamily\small\thesubsubsection}}}}{{0.8em}}{{}}

% ── Running heads ──────────────────────────────────────────────────────────
\newcommand{{\isocline@short}}{{}}
\newcommand{{\isoclineshorttitle}}[1]{{\renewcommand{{\isocline@short}}{{#1}}}}
\newcommand{{\isocline@eyebrow}}{{Isocline Research}}
\newcommand{{\isoclineeyebrow}}[1]{{\renewcommand{{\isocline@eyebrow}}{{#1}}}}
\pagestyle{{fancy}}
\fancyhf{{}}
\fancyhead[L]{{\textcolor{{isoMuted}}{{\eyebrow{{Isocline\ \ Research}}}}}}
\fancyhead[R]{{\textcolor{{isoMuted}}{{\eyebrow{{\isocline@short}}}}}}
\fancyfoot[C]{{\textcolor{{isoMuted}}{{\ttfamily\small\thepage}}}}
\renewcommand{{\headrulewidth}}{{0.4pt}}
\renewcommand{{\headrule}}{{{{\color{{isoRule}}\hrule height\headrulewidth width\headwidth}}}}

% ── Title block ────────────────────────────────────────────────────────────
% The outlined wordmark (docs/design/brand/isocline-wordmark.pgf — the same
% path data as the SVG masters) is drawn when found on \input@path; otherwise
% the "I." mark is set in place.
\usetikzlibrary{{svg.path}}
\newcommand{{\isocline@mark}}{{%
  \IfFileExists{{isocline-wordmark.pgf}}%
    {{\resizebox{{!}}{{1.9ex}}{{\tikz{{\input{{isocline-wordmark.pgf}}}}}}}}%
    {{{{\Large\bfseries I}}\kern0.1em\tikz[baseline]\fill (0,0.32ex) circle (0.32ex);}}}}
\renewcommand{{\maketitle}}{{%
  \begingroup
  \thispagestyle{{empty}}%
  \noindent\isocline@mark\par\vspace{{2.2em}}%
  \noindent\textcolor{{isoMuted}}{{\eyebrow{{\isocline@eyebrow}}}}\par\vspace{{0.6em}}%
  \noindent{{\LARGE\bfseries\@title\par}}\vspace{{1.2em}}%
  \noindent{{\normalsize\@author\par}}\vspace{{0.3em}}%
  \noindent\textcolor{{isoMuted}}{{\ttfamily\small\@date}}\par
  \vspace{{0.9em}}{{\color{{isoRule}}\hrule height 0.4pt}}\vspace{{1.8em}}%
  \endgroup}}

\endinput
"""


def emit_swift(tokens, res):
    lines = [
        "//",
        "//  IsoclineTokenExpectations.swift",
        "//  xTTests",
        "//",
        f"//  {HEADER}",
        "//  Expected default-seed hexes for tokens that exist in ThemePalette today;",
        "//  IsoclineTokenParityTests asserts the live engine still produces them.",
        "//",
        "",
        "enum IsoclineTokenExpectations {",
        "    /// (ThemePalette field, light hex, dark hex)",
        "    static let palette: [(field: String, light: String, dark: String)] = [",
    ]
    for name, recipe in tokens["recipes"].items():
        field = recipe.get("app")
        if field:
            lines.append(f'        ("{field}", "{res["light"][name]}", "{res["dark"][name]}"),')
    lines += ["    ]", "}", ""]
    return "\n".join(lines)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != text:
        path.write_text(text)
    print(path.relative_to(REPO))


def main():
    tokens = json.loads(TOKENS.read_text(), object_pairs_hook=OrderedDict)
    res = resolve(tokens)
    tokens["resolved"] = res
    write(TOKENS, json.dumps(tokens, indent=2, ensure_ascii=False) + "\n")
    write(CSS_OUT, emit_css(tokens, res))
    write(STY_OUT, emit_sty(tokens, res))
    write(SWIFT_OUT, emit_swift(tokens, res))
    # The launch screen's static paper (O3) — regenerated with the tokens.
    LAUNCH_COLORSET.mkdir(parents=True, exist_ok=True)
    write(LAUNCH_COLORSET / "Contents.json", emit_launch_colorset(res))
    sync_launch_storyboard(res)
    for page in THEME_COLOR_PAGES:
        sync_theme_color(page, res)
    # For HTML docs opened over file:// (no fetch): the live hue dial reads this.
    write(JS_OUT, f"// {HEADER}\nwindow.ISOCLINE_TOKENS = {json.dumps(tokens, ensure_ascii=False)};\n")


if __name__ == "__main__":
    main()
