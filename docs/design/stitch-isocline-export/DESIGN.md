# Isocline Design System: Liquid Glass & Instrument Paradigm

## Philosophy & Lineage
Isocline is an instrument of personal observation and endocrine chronobiology, not clinical surveillance. It marries the lineage of 1960s–70s precision laboratory instruments (Dieter Rams/Braun, IBM System/360, Tektronix oscilloscopes) with an ethereal, modern dark "Liquid Glass" sensory experience.

- **The Sovereignty of the Curve**: Pharmacokinetic tidal curves represent continuous bodily rhythm rather than gamified checklists.
- **Calm Empirical Coordinates**: Rejects patronizing judgements ("Good" vs "Bad"). Presents non-prescriptive, exact measurements, comfort corridors, and rate of change.
- **Stealth & Discretion**: Mundane, serene aesthetics that demand zero external explanation.

---

## Color Architecture (OKLCH Perceptual Gamut)

### Surface & Canvas Grounds
- **Background Base**: `#151022` / `#1b1113` (Deep dusk violet / night-sky plum)
- **Translucent Glass Surfaces**: `rgba(255, 255, 255, 0.04)` to `rgba(255, 255, 255, 0.07)` with `backdrop-filter: blur(16px)`
- **Elevated Containers**: `#1e1830` to `#24191b`

### Primary & Accent Tokens
- **Rose Marker** (*"You Are Here"* / Primary Active): `#C46B86` / `#D4537E` (warm rose jewel tone)
- **Lavender Accent** (Tide Curves & Structure): `#7B5FC0` / `#8B72C9` / `#A98FE0`
- **Trough Indigo**: `#4A3F66` / `#221E36`
- **Steady Sage**: `#8FA382`

### Hairlines & Registration Borders
- **Border Stroke**: `rgba(255, 255, 255, 0.08)` to `rgba(227, 221, 238, 0.12)` (0.5px–1px hairline registration rules)
- **Inner Sheen**: Subtle inset highlight `inset 0 1px 0 rgba(255, 255, 255, 0.08)`

---

## Typography

Three distinct type families with dedicated roles:

1. **Display & Chapter Headings**:
   - `IBM Plex Serif` (600, 700). Generous scale, calm authority, warm editorial weight.
   - Used for primary headings (e.g. `Settings`, `Journal`), hero values (`412 pg/mL`), and profile names (`Starla`).
2. **Values, Coordinates & Technical Eyebrows**:
   - `IBM Plex Mono` (400, 500). Tabular numerals, uppercase tracking (+0.12em to +0.18em), 10px–12px.
   - Used for dosages (`4.0 mg q5d`), timestamps (`08:30`), dates, build metadata, and registration labels.
3. **Prose & Journal Reflections**:
   - `Atkinson Hyperlegible` / Clean Humanist Sans. Warm, accessible, highly legible body copy for reflections and notes.

---

## Component Anatomy & Spatial Patterns

1. **Top Header & Readouts**:
   - Flush top readouts directly integrated into the canvas plane without heavy card boundaries.
   - Uppercase micro-eyebrow (`ISOCLINE`) paired with display title or numeric readout.
2. **Cards & Glass Panes**:
   - 20px–24px rounded corners (`rounded-2xl` to `rounded-3xl`).
   - Frosted liquid glass backdrop with subtle light catch on the top edge.
   - High-level gateways with jewel icon tiles and subtle right-angle chevrons.
3. **Floating Navigation Pill**:
   - Suspended translucent pill bar docked at bottom with generous clearance (`rounded-full`, `backdrop-blur-xl`).
   - Strict 4-tab destination order:
     1. **Home** (House / grid)
     2. **Journal** (Open book / notebook)
     3. **Time** (Constellation / body wave)
     4. **Settings** (Gear / calibration sliders)
   - Active destination highlighted in warm rose (`#D4537E` / `#C46B86`), inactive in muted lavender/slate.
4. **Interactive Accents & CTA**:
   - Floating pill buttons (e.g., `New entry`) resting above the fade gradient with warm rose fill and dark text/icons.
   - Ambient glow: soft 12px–20px diffuse blur without hard cast shadows.
