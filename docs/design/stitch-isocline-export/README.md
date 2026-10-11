# Stitch export: Isocline Liquid Glass (October 2026)

Downloaded on 2026-10-10 from Stitch project `1268775074211550640` ("xT — Isocline (design export)").

**Status: reference only.** This folder is not the identity. The canonical spec is
[`../ISOCLINE_DESIGN_SYSTEM.html`](../ISOCLINE_DESIGN_SYSTEM.html) (Paper & Instrument). See §14 of that spec, "Stitch export notes".

| File | Screen |
|---|---|
| `home.html` / `home.jpg` | Isocline: Home (Precision Instrument) |
| `journal.html` / `journal.jpg` | Isocline: Journal (Liquid Glass) |
| `time.html` / `time.jpg` | xT: HRT Tracker Time (Redesigned) |
| `settings.html` / `settings.jpg` | Isocline: Settings (Liquid Glass System) |
| `DESIGN.md` | Stitch's design-system notes, left as exported |

## What we took

- **Night paper:** the lightness and chroma of `#151022` (L .19 / C .036) define the dark ground. Its hue follows the user's seed.
- **Home:** the flush hero readout (a big mono number with no card).
- **Journal:** the week strip with dose and mood dots.
- **Settings:** the profile header (avatar, name, mono subtitle) above gateway cards with mono subtitles.
- **Footer line:** "SHAPED PROTOCOL." as a quiet footer.

## Known defects (do not copy)

- **Mid-word wrapping:** mono labels break mid-word ("HOM/E", "Journ/al", "21:1/5").
- **Inconsistent tab bars:** each screen has a different tab bar (icons, serif vs mono labels).
- **Two dark grounds:** plum `#1b1113`/`#24191b` competes with violet `#151022`.
- **Settings avatar treatment:** the Settings profile avatar itself is right, but the mockup fills it with a stock photo and a gradient ring. Use the user's own photo or the seed-tinted placeholder, with a hairline ring.
- **Glass on content:** glass cards are layered on content. Glass belongs only to system chrome.
- **Empty Home:** below the readout, the Home screen is empty.
- **"OKLCH" claim:** `DESIGN.md` says OKLCH but lists only fixed hex values.
- **Screenshot heights:** the screenshots are shorter than the heights Stitch reported, so they may predate final generation.
