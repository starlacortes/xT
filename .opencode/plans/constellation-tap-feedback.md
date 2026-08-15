# Plan — Playful Constellation Tap Feedback (Time 3D Body Model)

## Context
On the Time tab (`TimeView` → `TimeBodyExplorerView` → `TimeBodyDiagramView`), tapping the SceneKit body currently fires a shader ripple (`HeatMap3DRenderer.triggerRipple`) + light haptic, then toggles region selection. We add a **playful but subtle constellation burst** on top: 5–8 glowing stars connected by thin lines, spawned at the tap's world hit point, hugging the body surface, twinkling in with stagger, then fading out (~1.2 s). Body taps only; empty-space taps keep their dismiss behavior. Existing ripple, haptic, and region selection are unchanged.

## User decisions (confirmed)
- World-anchored SceneKit effect (body world is static — the camera orbits it — so anchoring = adding a node at the hit's world coordinates; it follows naturally).
- Body-mesh taps only.
- ~5–8 stars, connect-the-dots lines, staggered twinkle-in, gentle fade-out; Reduce Motion = simple uniform fade (~0.6 s), no stagger/pop.
- Max ~4 concurrent bursts (matches ripple `maxTaps`), purely visual, zero effect on selection logic.

## Files

### New: `xT/Elements/Home/Components/BodyModel3D/ConstellationBurstEffect.swift`
Self-contained `@MainActor` class, mirroring `HeatMap3DRenderer`/`StarFieldGeometry` conventions (file-header intent comment, no SwiftUI dependency):

1. `ConstellationBurstLayout` (pure struct, unit-testable):
   - `static func make(seed: UInt64, starCount: Int = 6)` → `(positions: [SIMD3<Float>], connections: [(Int, Int)])`.
   - Positions = deterministic-seeded random offsets in a small disc (radius ~4–5 cm), each star slightly lifted along the surface normal; connections = greedily connect nearest neighbors into a short pleasing path (2–5 segments), like a real constellation figure.
2. `final class ConstellationBurstEffect: NSObject` (@MainActor):
   - `func spawn(at world: SCNVector3, normal: SCNVector3, in scene: SCNScene, reduceMotion: Bool)` — builds one group node named **`constellationBurst`** at `world`, oriented to `normal`:
     - **stars node**: `SCNGeometry` point cloud (same additive glow material + per-star phase-in-alpha trick as `StarFieldGeometry.make`, positions from layout transformed into tangent space); per-star birth delay encoded in vertex alpha drives staggered pop-in via a small shader modifier keyed to a burst-clock uniform (or simple whole-node scale/opacity envelope if the modifier proves fiddly — keep simple).
     - **lines node**: `SCNGeometry` with `SCNGeometryPrimitiveTypeLine` elements over the layout connections; thin, additive, ~40% opacity.
   - Owns its **own `CADisplayLink`** (pattern: `HeatMap3DRenderer.swift` L199–224). Do NOT reuse the Coordinator's link — `TimeBodyDiagramView.tick` pauses it whenever a selection exists (L666, L672), and taps usually create selections. Link runs only while ≥1 burst is active; invalidated when the last burst finishes.
   - Timeline (~1.2 s total): stars pop 0→0.45 s (0.05 s stagger), lines fade in 0.35–0.65 s, hold to 0.8 s, fade-out 0.8–1.2 s, then `removeFromParentNode()`. Reduce Motion: skip stagger/pop; uniform opacity fade in/out over ~0.6 s.
   - Cap: if 4 active, remove oldest before spawning.

### Edit: `xT/Elements/Home/Components/BodyModel3D/TimeBodyDiagramView.swift`
1. Coordinator: add `let burstEffect = ConstellationBurstEffect()` (Coordinator spans ~L395–698).
2. Hit filter (L575–579): add `&& $0.node.name != Self.burstNodeName`-style exclusion (define `static let burstNodeName = "constellationBurst"` next to `orientationCardName` at L563) — otherwise taps would hit star/line geometry instead of the body.
3. `handleTap` body branch (after the ripple at L590–593): call
   `burstEffect.spawn(at: world, normal: hit.worldNormal, in: view.scene ?? scnScene, reduceMotion: reduceMotion)`.
   Uses `hit.worldNormal` (free from the hit test) so the burst plane hugs the surface.
4. Cleanup: ensure the effect's display link is invalidated when the view is dismantled (Coordinator teardown path / `stopLink()` L648–651).

## Reuse / existing patterns honored
- Point sprite + additive glow + per-star phase: `StarFieldGeometry.swift`.
- Self-owned display link with pause-on-empty: `HeatMap3DRenderer.swift` L199–224.
- Haptics & ripple pairing and tap semantics: unchanged (`handleTap` L565–598).
- Reduce Motion gating everywhere (`reduceMotion` flag already in the Coordinator).
- Xcode sync-groups: no pbxproj surgery — new file in the folder is picked up automatically.

## Verification
1. **Unit test** (Swift Testing, `xTTests/`): `ConstellationBurstLayout` — deterministic for a fixed seed, star count honored, offsets bounded within radius, connections reference valid indices and form no duplicates.
2. **Build**: `xcodebuild build -project xT.xcodeproj -scheme xT -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'` must be green.
3. **Manual/simulator end-to-end**: launch app → Time tab → tap a body region → constellation twinkles in at the tap point with lines, fades out ~1.2 s, ripple + region selection unchanged; tap during an open region card still spawns it (selection exists → proves the independent display link); rotate camera → burst stays attached to the spot; rapid taps cap at 4; empty-space tap dismisses card with no burst; enable Reduce Motion → simple fade only.

## Deferred / open
- Exact star visual (pure points vs. tiny sparkle sprite) — tune during implementation, non-blocking.
- Not applying to the QuickDose/injection-site body (`BodyModel3DView`) — Time-tab only per request; the class is reusable if desired later.
- No `assumptions.md`/`AGENTS.md` changes needed beyond this plan (no AGENTS.md exists).

## Sustainability & fix-forward
- If the per-star shader stagger is flaky in the SceneKit shader-modifier pipeline, fall back to whole-node envelope animation (simpler, still playful) — documented fallback above; do not widen scope to keep the shader version.
- If display-link churn shows up in profiling, pool burst nodes; expected cost is trivial (≤4 bursts × <20 primitives).
