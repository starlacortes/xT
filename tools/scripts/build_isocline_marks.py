#!/usr/bin/env python3
"""Build the Isocline logo masters (wordmark + "I." mark) as outlined SVGs.

The logo's *shape* is fixed: it is generated once from IBM Plex Serif SemiBold
(SIL OFL 1.1) and never re-set as live text. Only its *rendering* varies, so
every rendering below is emitted from the identical path data:

    ink       solid fill in currentColor (ink, or the user's seed hue)
    hairline  stroke-only engraving, non-scaling 1px
    emboss    inkless relief (after Omar Rayo's intaglios): paper on paper,
              read only through a light edge and a shadow edge

Requires fontTools (run from a venv):
    python3 -m venv /tmp/isocline-venv && /tmp/isocline-venv/bin/pip install fonttools
    /tmp/isocline-venv/bin/python -I tools/scripts/build_isocline_marks.py

Output: docs/design/brand/isocline-{wordmark,mark}-{ink,hairline,emboss}.svg
Deterministic — re-running produces byte-identical files.
"""

import json
import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

REPO = Path(__file__).resolve().parents[2]
FONT = Path("/usr/local/texlive/2026/texmf-dist/fonts/opentype/ibm/plex/IBMPlexSerif-SemiBold.otf")
OUT = REPO / "docs" / "design" / "brand"
TOKENS = json.loads((REPO / "docs" / "design" / "tokens" / "isocline.tokens.json").read_text())
EMBOSS = TOKENS["logo"]["emboss"]

WORD = "ISOCLINE"
TRACKING_EM = 0.07          # wordmark spec: all-caps tracking +0.07em
# Optical kerning adjustments in font units, applied after tracking. Kept
# deliberately light — letterform customization is reserved for a type
# designer pass (see ISOCLINE_DESIGN_SYSTEM.html §2).
KERN = {
    ("C", "L"): -6,
    ("L", "I"): -10,
}

# Fallback paper for the emboss face (var(--paper) wins inline): the resolved day paper.
PAPER = TOKENS["resolved"]["light"]["paper"]


def fmt(v: float) -> str:
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def svg_hex(h):
    # Keep the masters byte-identical: white was always written as the short #fff.
    return "#fff" if h.upper() == "#FFFFFF" else h


def opacity(v):
    return fmt(v).lstrip("0") if 0 < v < 1 else fmt(v)      # ".85", as the masters were written


def glyph_path(font, glyph_set, char, dx):
    """Outline of `char` translated by dx, flipped to SVG's y-down space."""
    name = font.getBestCmap()[ord(char)]
    pen = SVGPathPen(glyph_set, ntos=fmt)
    glyph_set[name].draw(TransformPen(pen, (1, 0, 0, -1, dx, 0)))
    bounds = BoundsPen(glyph_set)
    glyph_set[name].draw(bounds)
    return pen.getCommands(), name, bounds.bounds


def circle_path(cx, cy, r):
    # Two arcs — a true geometric circle, not the font's squarish period.
    return (f"M{fmt(cx - r)} {fmt(cy)}"
            f"A{fmt(r)} {fmt(r)} 0 1 0 {fmt(cx + r)} {fmt(cy)}"
            f"A{fmt(r)} {fmt(r)} 0 1 0 {fmt(cx - r)} {fmt(cy)}Z")


def build_wordmark(font, gs):
    upm = font["head"].unitsPerEm
    hmtx = font["hmtx"]
    track = TRACKING_EM * upm
    x, parts, minx, maxx = 0.0, [], None, None
    for i, ch in enumerate(WORD):
        d, name, (x0, _, x1, _) = glyph_path(font, gs, ch, x)
        parts.append(d)
        minx = x + x0 if minx is None else minx
        maxx = x + x1
        x += hmtx[name][0]
        if i < len(WORD) - 1:
            x += track + KERN.get((ch, WORD[i + 1]), 0)
    cap = font["OS/2"].sCapHeight
    overshoot = 12          # round letters (S, O, C) dip 12 units past cap/baseline
    view = (minx, -(cap + overshoot), maxx - minx, cap + 2 * overshoot)
    return "".join(parts), view


def build_mark(font, gs):
    """ "I." — the wordmark's own I, then a perfect-circle point.

    Diameter = the width of Plex Serif's period (so the point carries the
    same visual weight the font gives punctuation); gap = the font's native
    I→period spacing (I right side-bearing + period left side-bearing).
    """
    hmtx = font["hmtx"]
    i_d, i_name, (ix0, _, ix1, _) = glyph_path(font, gs, "I", 0)
    p_name = font.getBestCmap()[ord(".")]
    pb = BoundsPen(gs)
    gs[p_name].draw(pb)
    px0, _, px1, _ = pb.bounds
    diameter = px1 - px0
    gap = (hmtx[i_name][0] - ix1) + px0
    r = diameter / 2
    cx = ix1 + gap + r
    cy = -r                 # sits on the baseline
    d = i_d + circle_path(cx, cy, r)
    cap = font["OS/2"].sCapHeight
    width = (cx + r) - ix0
    side = max(width, cap) * 1.0
    # Square-safe viewBox, mark centred optically on its bounds.
    vx = ix0 - (side - width) / 2
    vy = -cap - (side - cap) / 2
    return d, (vx, vy, side, side)


def svg(d, view, rendering, title):
    w = view[2]
    ratio = EMBOSS["largeDepthRatio"] if w > EMBOSS["largeThreshold"] else EMBOSS["depthRatio"]
    depth = w * ratio                                  # relief depth scales with the drawing
    off = fmt(depth)
    if rendering == "emboss":                          # room for the light/shadow edges
        view = (view[0] - depth, view[1] - depth, view[2] + 2 * depth, view[3] + 2 * depth)
    vb = " ".join(fmt(v) for v in view)
    head = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" role="img" '
            f'aria-label="{title}">\n<title>{title}</title>\n')
    if rendering == "ink":
        body = f'<path fill="currentColor" d="{d}"/>\n'
    elif rendering == "hairline":
        body = (f'<path fill="none" stroke="currentColor" stroke-width="1" '
                f'vector-effect="non-scaling-stroke" stroke-linejoin="round" d="{d}"/>\n')
    elif rendering == "emboss":
        body = (f'<g>\n'
                f'<path transform="translate(-{off} -{off})" style="fill:{svg_hex(EMBOSS["light"])};fill-opacity:{opacity(EMBOSS["lightOpacity"])}" d="{d}"/>\n'
                f'<path transform="translate({off} {off})" style="fill:{EMBOSS["shadow"]};fill-opacity:{opacity(EMBOSS["shadowOpacity"])}" d="{d}"/>\n'
                f'<path style="fill:var(--paper, {PAPER})" d="{d}"/>\n'
                f'</g>\n')
    else:
        raise ValueError(rendering)
    return head + body + "</svg>\n"


def main():
    if not FONT.exists():
        sys.exit(f"missing font: {FONT}")
    font = TTFont(FONT)
    gs = font.getGlyphSet()
    OUT.mkdir(parents=True, exist_ok=True)
    marks = {
        "wordmark": (*build_wordmark(font, gs), "Isocline"),
        "mark": (*build_mark(font, gs), "Isocline"),
    }
    for key, (d, view, title) in marks.items():
        for rendering in ("ink", "hairline", "emboss"):
            path = OUT / f"isocline-{key}-{rendering}.svg"
            path.write_text(svg(d, view, rendering, title))
            print(path.relative_to(REPO))
        # Same path data for LaTeX (TikZ svg.path library), used by
        # docs/research/isocline.sty's title block. y is flipped back to TikZ's y-up.
        pgf = OUT / f"isocline-{key}.pgf"
        pgf.write_text("% Generated by tools/scripts/build_isocline_marks.py — do not edit.\n"
                       f"\\fill[yscale=-1] svg {{{d}}};\n")
        print(pgf.relative_to(REPO))
    # Path data for HTML docs (loads over file:// where fetch() can't).
    js = OUT / "isocline-marks.js"
    data = {k: {"d": d, "viewBox": " ".join(fmt(v) for v in view)} for k, (d, view, _) in marks.items()}
    js.write_text("// Generated by tools/scripts/build_isocline_marks.py — do not edit.\n"
                  f"window.ISOCLINE_MARKS = {json.dumps(data, sort_keys=True)};\n")
    print(js.relative_to(REPO))


if __name__ == "__main__":
    main()
