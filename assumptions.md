# Assumptions — Constellation Tap Feedback on 3D Model (Time)

## Established facts (from exploration)
- "Time" = the Time tab: `TimeView` → `TimeBodyExplorerView` → `TimeBodyDiagramView` (SceneKit 3D **human body** model, UIViewRepresentable + Coordinator pattern, x2 body variants via USDZ).
- Taps today: `TimeBodyDiagramView.Coordinator.handleTap` (~L565) does a hit-test, then fires `HeatMap3DRenderer.triggerRipple` (shader ripple, 0.7s, max 4 concurrent) + light haptic, then toggles region selection (camera focus, region glow, panels).
- A body "starfield" already exists (`StarFieldGeometry`, ~18k twinkling points built from mesh vertices, additive blend) plus a "constellation dissolve" shader mode.
- A reusable SwiftUI `ConstellationView` (Canvas + TimelineView point-field with connecting lines) exists but is currently orphaned (only legacy detail views reference it).
- Conventions: Reduce Motion fallbacks, `Theme.Motion` springs, haptics, self-contained renderer classes in `Elements/Home/Components/BodyModel3D/`.
- Build/test: `xcodebuild build` / `xcodebuild test`, scheme `xT`, iPhone 17 iOS 26.0 sim; tests are Swift Testing with `TestDefaults`.

## Interpretation
- "Playful constellation visual feedback" = a short-lived star cluster with connecting lines that appears on tap and playfully resolves — layered *on top of* (not replacing) the existing ripple + selection behavior.

## User decisions (confirmed)
- Anchor: **world-anchored** — SceneKit burst at the tap's world hit point, rotates with the body.
- Trigger: **body taps only** — fires alongside existing ripple/selection; empty-space taps keep current dismiss behavior.
- Intensity: **playful but subtle** — ~5–8 stars, connect-the-dots lines, staggered twinkle-in, gentle fade-out (~1–1.2s), honors Reduce Motion with a simple fade.
- Persistence: ephemeral, purely visual, capped count, no effect on region selection logic.
