# Isocline: HRT tracking, research and care

**Isocline** is the umbrella brand. It has three arms:

| Arm | What it is | Notes |
|---|---|---|
| **Isocline** (the app) | The private, on-device HRT tracker. | Its code target is still named `xT`, which is why `xT/`, `xTTests/` and the Xcode project keep that name. |
| **Isocline Research** | The published papers in `research/`, built on the shared LaTeX template `research/isocline.sty`. | |
| **Isocline Labs** | The company: legal and operational entity. | Documents are in `legal/`. |

## Vision

Change how people understand and manage hormone replacement therapy, with an instrument that shows the curve:
- privately,
- honestly about what is modeled versus measured,
- and without judgment.

## Core pillars

1. **User empowerment (the app).** A reliable, private, local-first tracker: doses, reminders, labs, journal, and a pharmacokinetic model of where your levels are.
2. **Research advancement (Isocline Research).** Open methodology papers on the PK model, its validation, and the product's design.
3. **Business foundation (Isocline Labs).** The legal and operational entity, based in Central Ohio, that carries grants, partnerships and scale.

## Key considerations

- **Privacy and discretion.** Sensitive health data stays on-device and in the user's iCloud. Consumer health-privacy rules shape every technical decision: the FTC Health Breach Notification Rule, state consumer-health-data laws, and GDPR for EU users. HIPAA generally doesn't apply to a direct-to-consumer app (see `planning/BUSINESS_AND_LAUNCH_PLAN.md`). Nothing in the product may out a user as being on HRT at a glance.
- **Honesty.** Modeled values are labeled as modeled. Copy describes observations, never verdicts.
- **Scope.** Protect the core so it ships.

## Doc map

| Folder | Contents |
|---|---|
| `design/` | **[ISOCLINE_DESIGN_SYSTEM.html](design/ISOCLINE_DESIGN_SYSTEM.html), the canonical brand and design system.** Also: brand positioning, the reference plate, logo masters (`brand/`), tokens (`tokens/`), and archived directions (`archive/`) |
| `app-design/` | Feature design for the Time tab, stage system and copy |
| `planning/` | Business, launch, monetization, implementation plans |
| `research/` | Isocline Research papers (LaTeX + PDF) and research memos |
| `legal/` | Isocline Labs policies |
| `notes/` | Dated codebase reviews |

## Generators

| Command | Writes |
|---|---|
| `python3 -I tools/scripts/gen_isocline_tokens.py` | Resolves `design/tokens/isocline.tokens.json` into the CSS, the LaTeX template, the docs' JS, and the app parity-test expectations. |
| `tools/scripts/build_isocline_marks.py` | Rebuilds the wordmark and "I." mark from IBM Plex Serif. Needs fontTools in a venv; see the script header. |
