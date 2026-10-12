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

Also emits xT/Theme/IsoclineMarkPaths.swift — the same two outlines as SwiftUI
`Shape`s (element F7), so the app can draw the logo with no live text. The
glyph outlines come from the same RecordingPen pass; the mark's point is a true
circle (`Path(ellipseIn:)`), matching the SVG master's arc pair.

Output: docs/design/brand/isocline-{wordmark,mark}-{ink,hairline,emboss}.svg
        xT/Theme/IsoclineMarkPaths.swift
Deterministic — re-running produces byte-identical files.
"""

import json
import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

REPO = Path(__file__).resolve().parents[2]
FONT = Path("/usr/local/texlive/2026/texmf-dist/fonts/opentype/ibm/plex/IBMPlexSerif-SemiBold.otf")
OUT = REPO / "docs" / "design" / "brand"
SWIFT_OUT = REPO / "xT" / "Theme" / "IsoclineMarkPaths.swift"
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
    spen = SwiftPen(glyph_set, dx)
    glyph_set[name].draw(spen)
    bounds = BoundsPen(glyph_set)
    glyph_set[name].draw(bounds)
    return pen.getCommands(), name, bounds.bounds, spen.ops


def circle_path(cx, cy, r):
    # Two arcs — a true geometric circle, not the font's squarish period.
    return (f"M{fmt(cx - r)} {fmt(cy)}"
            f"A{fmt(r)} {fmt(r)} 0 1 0 {fmt(cx + r)} {fmt(cy)}"
            f"A{fmt(r)} {fmt(r)} 0 1 0 {fmt(cx - r)} {fmt(cy)}Z")


def build_wordmark(font, gs):
    upm = font["head"].unitsPerEm
    hmtx = font["hmtx"]
    track = TRACKING_EM * upm
    x, parts, ops, minx, maxx = 0.0, [], [], None, None
    for i, ch in enumerate(WORD):
        d, name, (x0, _, x1, _), glyph_ops = glyph_path(font, gs, ch, x)
        parts.append(d)
        ops.extend(glyph_ops)
        minx = x + x0 if minx is None else minx
        maxx = x + x1
        x += hmtx[name][0]
        if i < len(WORD) - 1:
            x += track + KERN.get((ch, WORD[i + 1]), 0)
    cap = font["OS/2"].sCapHeight
    overshoot = 12          # round letters (S, O, C) dip 12 units past cap/baseline
    view = (minx, -(cap + overshoot), maxx - minx, cap + 2 * overshoot)
    return "".join(parts), view, {"d": "".join(parts), "view": view, "ops": ops}


def build_mark(font, gs):
    """ "I." — the wordmark's own I, then a perfect-circle point.

    Diameter = the width of Plex Serif's period (so the point carries the
    same visual weight the font gives punctuation); gap = the font's native
    I→period spacing (I right side-bearing + period left side-bearing).
    """
    hmtx = font["hmtx"]
    i_d, i_name, (ix0, _, ix1, _), i_ops = glyph_path(font, gs, "I", 0)
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
    view = (vx, vy, side, side)
    return d, view, {"d": d, "view": view, "ops": i_ops, "circle": (cx, cy, r)}


# ── Swift shape emitter (element F7) ──────────────────────────────────────
#
# Collects the same decomposed segments SVGPathPen sees (BasePen decomposes
# multi-offcurve qCurves into single quad segments) and emits them as SwiftUI
# `Path` calls, in the same y-down unit space as the SVG `d` strings.

from fontTools.pens.basePen import BasePen


class SwiftPen(BasePen):
    """Records moveTo/lineTo/curveTo/quad segments, y-flipped and x-translated."""

    def __init__(self, glyph_set, dx):
        BasePen.__init__(self, glyph_set)
        self.dx = dx
        self.ops = []
        self._last = None

    def _t(self, pt):
        return (pt[0] + self.dx, -pt[1])          # same transform as the SVG pass

    def _moveTo(self, pt):
        p = self._t(pt)
        self.ops.append(("m", p))
        self._last = p

    def _lineTo(self, pt):
        p = self._t(pt)
        if p != self._last:                        # SVGPathPen drops dup points
            self.ops.append(("l", p))
        self._last = p

    def _curveToOne(self, pt1, pt2, pt3):
        c1, c2, to = self._t(pt1), self._t(pt2), self._t(pt3)
        self.ops.append(("c", c1, c2, to))
        self._last = to

    def _qCurveToOne(self, pt1, pt2):
        ctl, to = self._t(pt1), self._t(pt2)
        self.ops.append(("q", ctl, to))
        self._last = to

    def _closePath(self):
        self.ops.append(("z",))
        self._last = None


def swift_pt(p):
    return f"pt({fmt(p[0])}, {fmt(p[1])})"


def swift_ops(ops, indent="        "):
    out = []
    for op in ops:
        if op[0] == "m":
            out.append(f"{indent}p.move(to: {swift_pt(op[1])})")
        elif op[0] == "l":
            out.append(f"{indent}p.addLine(to: {swift_pt(op[1])})")
        elif op[0] == "q":
            out.append(f"{indent}p.addQuadCurve(to: {swift_pt(op[2])}, control: {swift_pt(op[1])})")
        elif op[0] == "c":
            out.append(f"{indent}p.addCurve(to: {swift_pt(op[3])}, control1: {swift_pt(op[1])}, control2: {swift_pt(op[2])})")
        else:
            out.append(f"{indent}p.closeSubpath()")
    return "\n".join(out)


def swift_viewbox(view):
    return f"CGRect(x: {fmt(view[0])}, y: {fmt(view[1])}, width: {fmt(view[2])}, height: {fmt(view[3])})"


def emit_swift(marks):
    """One file: both outlines as Path appends, plus the two Shapes over them."""
    def wordmark_append(indent="        "):
        return swift_ops(marks["wordmark"]["ops"], indent)

    def mark_append(indent="        "):
        # The point: a true geometric circle, matching the SVG master's arc pair
        # (cx, cy, r straight from build_mark, already in the y-down d space).
        cx, cy, r = marks["mark"]["circle"]
        ellipse = (f"{indent}p.addEllipse(in: CGRect(x: {fmt(cx - r)}, y: {fmt(cy - r)}, "
                   f"width: {fmt(2 * r)}, height: {fmt(2 * r)}))")
        return swift_ops(marks["mark"]["ops"], indent) + "\n" + ellipse

    return f"""//
//  IsoclineMarkPaths.swift
//  xT
//
//  The Isocline logo outlines as SwiftUI `Path`s (element F7).
//
//  Generated by tools/scripts/build_isocline_marks.py from IBM Plex Serif
//  SemiBold — the *same* path data as the SVG masters in docs/design/brand/.
//  The logo's shape is fixed and never re-set as live text; only its
//  rendering varies (S9: IsoclineMarkView). Do not edit; re-run the script.
//
//  Coordinates are in font units, y-down (matching the SVG viewBoxes), with
//  each mark's viewBox exposed so callers can fit and scale with
//  `.aspectRatio` + a frame.
//

import SwiftUI

// MARK: - Outlines

/// CGPoint in font units. A free function so the emitted append bodies read
/// as geometry, not initializer noise.
private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {{
    CGPoint(x: x, y: y)
}}

enum IsoclineMarkPaths {{

    /// The wordmark's viewBox in font units (x, y, width, height — y-down).
    static let wordmarkViewBox = {swift_viewbox(marks["wordmark"]["view"])}

    /// The "I." mark's square-safe viewBox, mark centred optically on its bounds.
    static let markViewBox = {swift_viewbox(marks["mark"]["view"])}

    /// The wordmark "ISOCLINE", scaled + centred aspect-fit into `rect`.
    static func wordmarkPath(in rect: CGRect) -> Path {{
        var p = Path()
        appendWordmark(to: &p)
        return p.scaledToFit(wordmarkViewBox, in: rect)
    }}

    /// The "I." mark (the wordmark's own I plus a true-circle point).
    static func markPath(in rect: CGRect) -> Path {{
        var p = Path()
        appendMark(to: &p)
        return p.scaledToFit(markViewBox, in: rect)
    }}

    static func appendWordmark(to p: inout Path) {{
{wordmark_append()}
    }}

    static func appendMark(to p: inout Path) {{
{mark_append()}
    }}
}}

// MARK: - Shapes

/// The "ISOCLINE" wordmark as a fixed outline. Fill or stroke per S9's
/// renderings; never set it as text.
struct IsoclineWordmark: Shape {{
    func path(in rect: CGRect) -> Path {{
        IsoclineMarkPaths.wordmarkPath(in: rect)
    }}
}}

/// The "I." mark as a fixed outline.
struct IsoclineMark: Shape {{
    func path(in rect: CGRect) -> Path {{
        IsoclineMarkPaths.markPath(in: rect)
    }}
}}

// MARK: - Scaling

private extension Path {{
    /// Uniform scale from a font-unit viewBox into `rect`, centred when the
    /// rect's aspect differs (SVG `preserveAspectRatio` default).
    func scaledToFit(_ vb: CGRect, in rect: CGRect) -> Path {{
        let s = min(rect.width / vb.width, rect.height / vb.height)
        let tx = rect.minX + (rect.width - vb.width * s) / 2 - vb.minX * s
        let ty = rect.minY + (rect.height - vb.height * s) / 2 - vb.minY * s
        return applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty))
    }}
}}
"""


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
    wordmark = build_wordmark(font, gs)
    mark = build_mark(font, gs)
    marks = {
        "wordmark": {"d": wordmark[0], "view": wordmark[1], "title": "Isocline", "ops": wordmark[2]["ops"]},
        "mark": {"d": mark[0], "view": mark[1], "title": "Isocline", "ops": mark[2]["ops"], "circle": mark[2]["circle"]},
    }
    # Element F7: the same outlines as SwiftUI Paths. Skip if identical, so
    # re-running stays byte-identical (and mtime-stable) like the other outputs.
    SWIFT_OUT.parent.mkdir(parents=True, exist_ok=True)
    swift = emit_swift(marks)
    if not SWIFT_OUT.exists() or SWIFT_OUT.read_text() != swift:
        SWIFT_OUT.write_text(swift)
    print(SWIFT_OUT.relative_to(REPO))
    for key, m in marks.items():
        d, view, title = m["d"], m["view"], m["title"]
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
    data = {k: {"d": m["d"], "viewBox": " ".join(fmt(v) for v in m["view"])} for k, m in marks.items()}
    js.write_text("// Generated by tools/scripts/build_isocline_marks.py — do not edit.\n"
                  f"window.ISOCLINE_MARKS = {json.dumps(data, sort_keys=True)};\n")
    print(js.relative_to(REPO))


if __name__ == "__main__":
    main()
