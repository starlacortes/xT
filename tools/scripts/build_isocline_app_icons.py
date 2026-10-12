#!/usr/bin/env python3
"""Build the Isocline app-icon set (I1-I3) as Icon Composer bundles.

The masters live in docs/design/external-work/isocline-logos/app-icons/
(delivered sample icon work): one icon per quick-stop hue (`Theme.Seed.stops`
/ `resolved.seedStops`) plus the stealth "Discreet" icon — the "I." mark on a
light seed-tint gradient ground, in ink, matching IsoclineMarkPaths exactly.

The sample PNGs are display renders (rounded corners, transparent outside the
mask), but Apple masks full-bleed squares itself, so every bundle is emitted
with two SVG layers instead:

    background.svg   full-bleed 1024 ground (gradient, or paper for stealth)
    mark.svg        the "I." mark at the masters' own placement and scale

The stealth mark keeps the three-pass emboss of the masters (light edge
up-left at .85, dark edge down-right at .16, paper face on top).

Preview imagesets for the in-app icon picker (I4) reuse the sample PNGs
directly — rounded is correct in-app, where no system mask is applied.

This script reads the masters rather than transcribing values, and fails
loudly if the masters drift from the structure it expects.

Output (deterministic — re-running produces byte-identical files):
    xT/<bundle>.icon/icon.json            (xTGlassIcon rebuilt + 8 alternates)
    xT/<bundle>.icon/Assets/{background,mark}.svg
    xT/Assets.xcassets/IconPreview*.imageset/

Run:  python3 -I tools/scripts/build_isocline_app_icons.py
"""

import json
import re
import shutil
import struct
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MASTERS = REPO / "docs/design/external-work/isocline-logos/app-icons"
APP_DIR = REPO / "xT"
CATALOG = APP_DIR / "Assets.xcassets"

CANVAS = 1024

# The delivered set: (bundle name, master stem, preview imageset name).
# The first entry is the primary icon (ASSETCATALOG_COMPILER_APPICON_NAME =
# xTGlassIcon); the rest are alternates listed in
# ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES. Bundle order matches
# `Theme.Seed.stops` (default rose first), then Discreet.
ICONS = [
    ("xTGlassIcon", "app-icon-stop1-000deg", "IconPreviewPrimary"),
    ("AppIconHue48", "app-icon-stop2-045deg", "IconPreviewHue48"),
    ("AppIconHue93", "app-icon-stop3-090deg", "IconPreviewHue93"),
    ("AppIconHue138", "app-icon-stop4-135deg", "IconPreviewHue138"),
    ("AppIconHue183", "app-icon-stop5-180deg", "IconPreviewHue183"),
    ("AppIconHue228", "app-icon-stop6-225deg", "IconPreviewHue228"),
    ("AppIconHue273", "app-icon-stop7-270deg", "IconPreviewHue273"),
    ("AppIconHue318", "app-icon-stop8-315deg", "IconPreviewHue318"),
    ("AppIconDiscreet", "stealth-icon", "IconPreviewDiscreet"),
]

SVG_HEADER = (
    '<svg xmlns="http://www.w3.org/2000/svg" '
    f'viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" height="{CANVAS}">'
)


def fail(message: str) -> None:
    raise SystemExit(f"build_isocline_app_icons: {message}")


def read_master(stem: str) -> str:
    path = MASTERS / f"{stem}.svg"
    if not path.is_file():
        fail(f"missing master {path}")
    return path.read_text(encoding="utf-8")


def png_size(path: Path) -> tuple[int, int]:
    # IHDR lands 16 bytes in: width then height, big-endian u32.
    with path.open("rb") as f:
        header = f.read(24)
    if len(header) < 24 or header[12:16] != b"IHDR":
        fail(f"not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def parse_master(svg: str, stem: str) -> dict:
    """Extract the ground, the mark placement and the mark passes from a master."""

    # Ground: a vertical two-stop gradient over the full canvas, or a solid.
    rect = re.search(r'<rect[^>]*fill="([^"]+)"', svg)
    if rect is None:
        fail(f"{stem}: no ground rect")
    ground = {"fill": rect.group(1)}

    gradient = re.search(r"<linearGradient[^>]*>(.*?)</linearGradient>", svg, re.S)
    if gradient:
        stops = re.findall(r'stop-color="([^"]+)"', gradient.group(1))
        if len(stops) != 2:
            fail(f"{stem}: expected a two-stop gradient, found {len(stops)}")
        ground = {"gradient": stops}

    # Mark placement: translate(tx, ty) scale(s) — identical across the set.
    placement = re.search(
        r"translate\((-?[\d.]+) (-?[\d.]+)\) scale\(([\d.]+)\)", svg
    )
    if placement is None:
        fail(f"{stem}: no mark placement transform")
    tx, ty, scale = (float(g) for g in placement.groups())

    # Mark passes: every <path> inside the mark group, in document order.
    group = re.search(r"<g transform=\"[^\"]*\">\s*(.*)\s*</g>", svg, re.S)
    if group is None:
        fail(f"{stem}: no mark group")
    passes = []
    for attrs in re.findall(r"<path ([^>]*)/?>", group.group(1)):
        d = re.search(r' d="([^"]+)"', attrs)
        if d is None:
            fail(f"{stem}: mark path without geometry")
        offset = re.search(r'translate\((-?[\d.]+) (-?[\d.]+)\)', attrs)
        fill = re.search(r'fill:([^;"]+)|fill="([^"]+)"', attrs)
        opacity = re.search(r'fill-opacity:\.?(\d+)', attrs)
        passes.append(
            {
                "d": d.group(1),
                "dx": float(offset.group(1)) if offset else 0.0,
                "dy": float(offset.group(2)) if offset else 0.0,
                "fill": (fill.group(1) or fill.group(2)) if fill else "",
                "opacity": (int(opacity.group(1)) / 100) if opacity else 1.0,
            }
        )
    if not passes:
        fail(f"{stem}: no mark passes")

    return {"ground": ground, "tx": tx, "ty": ty, "scale": scale, "passes": passes}


def ground_svg(ground: dict) -> str:
    if "gradient" in ground:
        top, bottom = ground["gradient"]
        return (
            f"{SVG_HEADER}<defs>"
            '<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/>'
            f"</linearGradient></defs>"
            f'<rect width="{CANVAS}" height="{CANVAS}" fill="url(#ground)"/>'
            "</svg>"
        )
    return f'{SVG_HEADER}<rect width="{CANVAS}" height="{CANVAS}" fill="{ground["fill"]}"/>' + "</svg>"


def mark_svg(master: dict) -> str:
    """Re-emit the mark on a transparent canvas, same placement and passes."""
    parts = [SVG_HEADER]
    tx, ty, scale = master["tx"], master["ty"], master["scale"]
    parts.append(f'<g transform="translate({tx:g} {ty:g}) scale({scale:g})">')
    for p in master["passes"]:
        transform = ""
        if p["dx"] or p["dy"]:
            transform = f' transform="translate({p["dx"]:g} {p["dy"]:g})"'
        opacity = f' fill-opacity="{p["opacity"]:g}"' if p["opacity"] != 1.0 else ""
        parts.append(f'<path{transform} fill="{p["fill"]}"{opacity} d="{p["d"]}"/>')
    parts.append("</g></svg>")
    return "".join(parts)


def icon_json() -> str:
    # Two flat groups, no shadow or translucency — the paper look reads
    # through the artwork itself. Groups render FRONT FIRST (the sidebar's
    # top group is the icon's front), so the mark group leads and the ground
    # group sits behind it. Mirrors the structure Icon Composer writes;
    # `fill: automatic` defers to each SVG.
    doc = {
        "fill": "automatic",
        "groups": [
            {
                "layers": [
                    {
                        "blend-mode": "normal",
                        "image-name": "mark.svg",
                        "name": "mark",
                        "position": {"scale": 1.0, "translation-in-points": [0, 0]},
                    }
                ]
            },
            {
                "layers": [
                    {
                        "blend-mode": "normal",
                        "image-name": "background.svg",
                        "name": "background",
                        "position": {"scale": 1.0, "translation-in-points": [0, 0]},
                    }
                ]
            },
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def write_icon_bundle(bundle: str, master: dict) -> None:
    bundle_dir = APP_DIR / f"{bundle}.icon"
    assets = bundle_dir / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    (assets / "background.svg").write_text(ground_svg(master["ground"]), encoding="utf-8")
    (assets / "mark.svg").write_text(mark_svg(master), encoding="utf-8")
    (bundle_dir / "icon.json").write_text(icon_json(), encoding="utf-8")


def write_preview_imageset(name: str, master_stem: str) -> None:
    src = MASTERS / f"{master_stem}.png"
    if not src.is_file():
        fail(f"missing master render {src}")
    size = png_size(src)
    if size != (CANVAS, CANVAS):
        fail(f"{src} is {size[0]}x{size[1]}, expected {CANVAS}x{CANVAS}")

    imageset = CATALOG / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, imageset / f"{name}.png")
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (imageset / "Contents.json").write_text(
        json.dumps(contents, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> None:
    if not MASTERS.is_dir():
        fail(f"missing masters directory {MASTERS}")

    placements = set()
    for bundle, stem, preview in ICONS:
        master = parse_master(read_master(stem), stem)
        placements.add((master["tx"], master["ty"], master["scale"]))
        write_icon_bundle(bundle, master)
        write_preview_imageset(preview, stem)

    # Every icon places the mark identically — the set differs only in ground.
    if len(placements) != 1:
        fail(f"mark placement drifted across the masters: {placements}")

    print(f"wrote {len(ICONS)} icon bundles + {len(ICONS)} preview imagesets")


if __name__ == "__main__":
    main()
