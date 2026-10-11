# Bundled typefaces (Isocline · element F1)

Three OFL families power the Paper & Instrument type system. All are bundled under
`UIAppFonts` in `xT/Info.plist` and loaded via `Font.custom(_:size:relativeTo:)`
through `Theme.FontFace` / `Theme.Fonts`.

The license texts ship in the app bundle at `xT/Resources/Licenses/` and are shown on
the Acknowledgements screen (element F8).

## Faces

| File | PostScript name | Weight | Family role |
|---|---|---|---|
| `IBMPlexSerif-SemiBold.ttf` | `IBMPlexSerif-SemiBold` | 600 | display |
| `IBMPlexSerif-Bold.ttf` | `IBMPlexSerif-Bold` | 700 | display |
| `IBMPlexMono-Regular.ttf` | `IBMPlexMono` | 400 | mono |
| `IBMPlexMono-Medium.ttf` | `IBMPlexMono-Medm` | 500 | mono |
| `AtkinsonHyperlegibleNext-Regular.ttf` | `AtkinsonHyperlegibleNext-Regular` | 400 | prose |
| `AtkinsonHyperlegibleNext-Bold.ttf` | `AtkinsonHyperlegibleNext-Bold` | 700 | prose |

> **Note the PostScript names, not the filenames.** IBM Plex Mono's PS names are
> `IBMPlexMono` (Regular, no suffix) and `IBMPlexMono-Medm` (Medium, abbreviated to fit
> the classic 31-char limit) — *not* `-Regular` / `-Medium`. `Font.custom` takes the
> PostScript name, so `Theme.FontFace` must use these exact strings.
> `xTTests/FontRegistrationTests` guards this.

## Provenance

- **IBM Plex Serif / Mono** — IBM's official distribution,
  `github.com/IBM/plex` → `packages/plex-serif|plex-mono/fonts/complete/ttf/`.
  (IBM's release, not the Google Fonts mirror, so the PS names match the spec's
  `IBMPlexMono` / `IBMPlexMono-Medm`.)
- **Atkinson Hyperlegible Next** — the Google Fonts release (decision X1),
  `github.com/googlefonts/atkinson-hyperlegible-next` → `fonts/ttf/`.
  Static instances, **not** the TeX Live or 2020 Braille Institute builds.

All three are SIL OFL 1.1.

## SHA-256

```
857edeaaff0f3913f4dfaf6bc0e9c89ef73e475429cf63d6a3cb5d1022a213d5  IBMPlexSerif-SemiBold.ttf
5fa66833dc80adb6252c793adb555716ec10833d2b1e5b0235b68c72cd69adf0  IBMPlexSerif-Bold.ttf
7c6fbddca4b700be918f5f6183d9bd4464fa427fe435f0b480d77fe2bb8c5a43  IBMPlexMono-Regular.ttf
98fbd727aae340b236955879dabed4d991aac9e8e90b3b2a67ce4a59221cc97c  IBMPlexMono-Medium.ttf
88ed5c31a71584c7772963b02d04bef1eb7e3d2e9c8b9cb204339b1f82cf432c  AtkinsonHyperlegibleNext-Regular.ttf
994414047df66bb4998d01c1cb1eeb4a2ddc4622d1aa56bbb8adbeca7645b041  AtkinsonHyperlegibleNext-Bold.ttf
```

Verify: `shasum -a 256 -c` against this list, or `shasum -a 256 *.ttf` from this folder.
