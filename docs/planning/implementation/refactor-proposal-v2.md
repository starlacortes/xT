# xT Codebase Refactor & Pruning Proposal v2

**Date:** 2026-07-26
**Based on:** HEAD `765198d` — verified against live codebase with 4 subagent analyses + manual cross-checks
**Scope:** ~85 Swift files in `xT/`, ~4 in `xTTests/`, plus tooling in `tools/`
**Intent:** Reduce complexity, remove dead code, eliminate the 2D body sketch system, consolidate onto a single 3D body picker, and improve navigability.

> **Important:** The original proposal (`refactor-proposal.md`) was written against an earlier state of the codebase. Approximately 60% of its recommendations were already implemented. This v2 document replaces it entirely, reflecting only the verified current state and incorporating the decision to fully remove the 2D sketch system in favor of the 3D body picker.

Risk legend: 🟢 safe / mechanical · 🟡 needs confirming build · 🔴 behavioral, discuss first

---

## 0. Verified Current Structure

```
xT/  (repo root)
├── .gitignore                         ← clean: covers build/, .DS_Store, *.xcresult ✓
├── docs/                              ← SPEC.md, README.md, TIME_*.md, implementation/
├── tools/                             ← figma-mcp-server/, scripts/, prototypes/, xT-interactive-flow/
├── xT.xcodeproj/
├── xT/                                ← the app (all Swift source under here)
│   ├── xTApp.swift, ContentView.swift
│   ├── Managers/       (9 files)
│   ├── Models/         (10 files)
│   ├── Elements/
│   │   ├── Home/       (views + Components/BodyModel3D/ + Components/BodySketches/)
│   │   ├── Journal/    (views + Components/)
│   │   ├── Onboarding/ (OnboardingView.swift)
│   │   ├── Profile/    (ProfileEditorView.swift)
│   │   └── Settings/   (views)
│   ├── Shared/         (helpers, components, ZoneCentroidStore, DeveloperSettings)
│   ├── Theme/          (colors, motion, styling, UIColor+ThemeExtensions)
│   ├── Resources/      (Models/*.usdz, Models/*.json)
│   └── Tests/          ← EMPTY directory
├── xTTests/            (4 test files, correct location)
└── xTUITests/          (2 test files)
```

**Key cleanups already applied (not in this proposal):**
- ✅ All 7 dead views from original §1a deleted
- ✅ `design-files/` directory removed
- ✅ Insights/research subsystem (~2,500 lines) deleted
- ✅ `.gitignore` covers `build/`, `.DS_Store`, `*.xcresult`
- ✅ `build/` and `.DS_Store` not tracked by git
- ✅ No `.swift` files stranded at repo root
- ✅ `DoseRecord` has clean accessors (no legacy `injectionSite` bridge)
- ✅ `AuthenticationManager` auto-lock timer is wired correctly

---

## 1. New Dead Code Discovered (current HEAD)

### 1a. Unreferenced SwiftUI Views 🟡

Four files were found with zero external references (declared, never instantiated):

| File | Lines (approx) | Evidence |
|---|---|---|
| `xT/Elements/Home/Components/DoseStreakCard.swift` | ~80 | Only self + `#Preview` |
| `xT/Elements/Home/Components/MiniTrendGraph.swift` | ~100 | Only self + `#Preview` |
| `xT/Elements/Journal/Components/JournalCardView.swift` | ~120 | Only self + `#Preview`; `MoodRowView` mentions it in a comment only |
| `xT/Elements/Journal/Components/HealthInsightsView.swift` | ~60 | Only self + `#Preview` |

> **Recommendation:** Delete after confirming build. ~360 lines removed with zero behavioral impact.

### 1b. Empty `xT/Tests/` Directory 🟢

`xT/Tests/` exists but is completely empty. It's confusing — it looks like it could contain test files but doesn't. All actual tests live in `xTTests/`.

> **Recommendation:** Delete the empty directory and remove any stale reference in `project.pbxproj`.

### 1c. Stale `project.pbxproj` References 🟡

The subagent flagged potential stale entries in `project.pbxproj` referencing files that no longer exist (likely leftovers from the already-deleted views and Insights subsystem).

> **Recommendation:** Run a diff between files-on-disk and `project.pbxproj` references. Remove any orphaned entries. This is mechanical but requires a build to verify nothing breaks.

---

## 2. Structural Improvements

### 2a. Split `MedicationManager.swift` (2,319 lines) 🔴 — Highest Value

This single file is the app's brain. It contains **33 MARK sections** mixing at least **5 distinct responsibilities**:

| Concern | Approx Lines | Description |
|---|---|---|
| Core state & configuration | ~300 | `@Published` props, UserDefaults keys, enums (MedicationType, AdministrationMethod, etc.) |
| Pharmacokinetic engine | ~500 | Hormone-level math, half-life/absorption constants, Layer 1-4 classification, aromatization estimator, blood test calibration |
| Dosing logic | ~350 | Record/edit/delete dose, dose validation, concentration/volume helpers |
| Scheduling & adherence | ~400 | Next-dose calculation, missed-dose detection, monthly adherence rate, on-time streak, regimen transition tracking |
| Injection site tracking | ~350 | Site rotation, avoid zone management, site history queries |
| SwiftData persistence | ~200 | Queries, saves, migrations, model context wiring |
| UI helpers & formatting | ~200 | Formatters, summary strings, configuration labels |

Recommend splitting into extensions (same class, no behavior change):

```
Managers/Medication/
├── MedicationManager.swift                 ← core: state, published props, init, enums
├── MedicationManager+Dosing.swift          ← record/edit/delete dose, validation
├── MedicationManager+Schedule.swift        ← next-dose, adherence, missed-dose, streaks
├── MedicationManager+Pharmacokinetics.swift ← PK math, hormone levels, calibration
├── MedicationManager+Sites.swift           ← injection site tracking, avoid zones
└── MedicationManager+Persistence.swift     ← SwiftData queries, load/save, migration
```

Because Swift extensions share the type, this is a **pure move** — no logic changes. It dramatically improves navigability.

### 2b. Externalize `TimeContent.swift` (1,626 lines) 🟡

Analysis shows ~85-90% of this file is static content (string literals for educational/timeline copy in the "Time" tab). The types defined are NOT `Codable`, which means they can't be trivially loaded from JSON today. However, the structure is straightforward:

- ~240 lines: type declarations (`TenureTier`, `TimeBodySystem`, `TimeMilestone`, `TimeChange`, etc.)
- ~1,380 lines: `TimeContentEngine` — hardcoded string arrays, milestone definitions, color palettes

> **Recommendation:** Split into `TimeContentTypes.swift` + `TimeContentData.swift` to separate types from data. This is the lowest-risk starting point. The data can be externalized to JSON later.

### 2c. Remove 2D Body Sketch System Entirely 🔴 — Major Architectural Decision

The codebase currently has two body-picker systems:

#### 3D System (981 lines of Swift + assets) — THE LIVE DEFAULT
| Component | Lines | File |
|---|---|---|
| `BodyModel3DView` | 530 | `xT/Elements/Home/Components/BodyModel3D/BodyModel3DView.swift` |
| `HeatMap3DRenderer` | 242 | `xT/Elements/Home/Components/BodyModel3D/HeatMap3DRenderer.swift` |
| `ZoneHitTestEngine` | 42 | `xT/Elements/Home/Components/BodyModel3D/ZoneHitTestEngine.swift` |
| `BodyHeatMapShader` | 167 | `xT/Elements/Home/Components/BodyModel3D/BodyHeatMapShader.swift` |
| `ZoneCentroidStore` | ~85 | `xT/Shared/ZoneCentroidStore.swift` |
| **Assets** | — | 3× `.usdz` models + 3× `zone_centroids_*.json` |

**Entry point:** `QuickDoseSheet.swift:568-569` — `step2BodySitePicker()` calls `step23DBodyPicker()` **unconditionally**. There is NO feature flag or toggle. The 3D body picker is always active for injection routes.

#### 2D System (~1,100 lines) — TO BE REMOVED
| File | Lines (approx) |
|---|---|
| `BodySketchData.swift` | ~399 |
| 6 detail/overview sketch files | ~850 combined |

**Entry points:** `QuickDoseSheet` (step 2 wrapper/delegate), `AvoidZonesEditorView`, `PreferredZonesEditorView`, `DoseScheduleSettingsView`.

> **Decision:** Remove the 2D sketch system entirely. The 3D system is the live default and is unconditionally active in `QuickDoseSheet`. Maintaining two coordinate systems, two hit-testing engines, and two data representations is unnecessary complexity.

### 2d. Zone Label Audit — Complete ✅

Audited all 49 zone labels across all three centroid JSON files (neutral, feminine, masculine) and `BodySketchData.zoneToSketch`. All labels are identical across every system. Zero discrepancies.

**Complete zone inventory (49 zones):**

| Body Region | Front Zones | Back Zones | Count |
|---|---|---|---|
| Upper Body | Left/Right Shoulder, Left/Right Upper Chest, Left/Right Lower Chest, Upper Chest, Left/Right Abdomen (Upper/Lower), Periumbilical, Neck, Left/Right Inner Wrist | — | 13 |
| Arms | Left/Right Deltoid, Left/Right Upper Arm, Left/Right Forearm | Left/Right Posterior Deltoid, Left/Right Triceps, Left/Right Posterior Forearm | 12 |
| Glutes | — | Left/Right Upper Glute, Left/Right Lower Glute, Left/Right Ventrogluteal | 6 |
| Thighs | Left/Right Upper/Mid/Lower/Outer/Inner Thigh | Left/Right Upper/Mid/Lower Hamstring | 16 |

### 2e. Migrate Zone Metadata to `ZoneCentroidStore` 🔴

With 2D removed, `BodySketchData` still serves as the data source for several concepts the 3D system doesn't own yet:

| Concept | Current Location | Migration Target |
|---|---|---|
| All zone labels | `BodySketchData.zoneLabels(for:)` | Already in `ZoneCentroidStore.labels` ✅ |
| Zone → body region mapping | `BodySketchData.region(for:)` | → `ZoneCentroidStore` (new method) |
| Preferred zones per med+route | `BodySketchData.preferredZones` | → `ZoneCentroidStore` (new static dict) |
| Recommended zones per route | `BodySketchData.recommendedZones(for:)` | → `ZoneCentroidStore` (new method) |
| Zone → sketch mapping | `BodySketchData.sketchId(for:)` | → **Deleted** (no sketches) |
| 2D bounding rects + hit testing | `BodySketchData.zoneBoundingRects` etc. | → **Deleted** (replaced by 3D hit testing) |
| `viewContext` (front/back) | `BodySketchData.sketchViewContext` | → Derived from camera yaw at tap time |

### 2f. Wire `viewContext` for 3D Taps 🔴 — Behavioral Change

Currently, 3D records have `viewContext = ""` and `lastDoseSentence` shows `"Left Deltoid (3D)"`. After removing 2D sketches, `viewContext` should be derived from the camera yaw angle at tap time:

| Yaw Range (radians) | `viewContext` |
|---|---|
| -π/4 … π/4 | `"front"` |
| π/4 … 3π/4 | `"right"` |
| 3π/4 … -3π/4 | `"back"` |
| -3π/4 … -π/4 | `"left"` |

This is the **only behavioral change** in this proposal — dose history labels will show real anatomical context like `"Left Deltoid (front)"` instead of the generic `"(3D)"` suffix.

### 2g. Centroid-to-Mesh Validation 🔴 — New Quality Gate

To ensure the 3D tap experience doesn't silently break as models evolve:

1. **Minimum zone separation assertion** — `ZoneCentroidStore.loadCentroids()` asserts no two centroids are within `2 × baseRadius` (0.14 units), preventing ambiguous tap zones
2. **Centroid-on-mesh tests** — New `CentroidValidationTests` in `xTTests/` loads each USDZ + JSON pair and validates every centroid is within 0.02 units of the mesh surface with normals pointing outward
3. **Debug visualization** — `#if DEBUG` overlay in `BodyModel3DView` renders centroid positions and hit-test radii as small colored spheres

### 2h. Large Data Literals Embedded in Swift 🟡

| File | Data | Lines |
|---|---|---|
| `TimeContent.swift` | Static content strings | ~1,380 |
| `BodySketchData.swift` | Coordinate arrays per body region | ~200 |
| 6 sketch files | Duplicated coordinate arrays | ~650 combined |
| `MedicationManager.swift` | Pharmacokinetic constants (half-lives, absorption rates) | ~80 |

> **Recommendation:**
> - Pharmacokinetic constants → extract to a named `PharmacokineticConstants` enum/struct with comments citing sources
> - Sketch coordinate data → **deleted** (2D system removed)
> - TimeContent → split types from data (see 2b)

---

## 3. Minor Cleanups

### 3a. TODO/FIXME Scan 🟢

12 TODO/FIXME comments found across the codebase. Most are minor polish items. Worth a quick triage pass — any that are stale should be removed or converted to issues.

### 3b. `#if DEBUG` Audit 🟢

`DeveloperSettings` properly gates mutable settings behind `#if DEBUG` and hardwires `false` in RELEASE. `SpoofProfile` is similarly gated. No leakage risk found. Keep as-is.

### 3c. Row Component Consolidation 🟢

`InsightRowView`, `MoodRowView`, `NextDoseRowView` share visual patterns. Low priority — consider a shared `InfoRowStyle` modifier if these grow.

---

## 4. Suggested Target Structure (post-refactor)

```
xT/  (repo root)
├── xT.xcodeproj
├── xT/                     ← app only
│   ├── App/                (xTApp, ContentView, MainTabView)
│   ├── Managers/
│   │   ├── Medication/     ← split from MedicationManager.swift
│   │   │   ├── MedicationManager.swift
│   │   │   ├── MedicationManager+Dosing.swift
│   │   │   ├── MedicationManager+Schedule.swift
│   │   │   ├── MedicationManager+Pharmacokinetics.swift
│   │   │   ├── MedicationManager+Sites.swift
│   │   │   └── MedicationManager+Persistence.swift
│   │   ├── AuthenticationManager.swift
│   │   ├── CalendarSyncManager.swift
│   │   ├── JournalManager.swift
│   │   ├── NotificationManager.swift
│   │   ├── ProfileManager.swift
│   │   └── SecurityManager.swift
│   ├── Models/
│   │   ├── TimeContentTypes.swift     ← types only (split from TimeContent.swift)
│   │   ├── TimeContentData.swift      ← static content (split from TimeContent.swift)
│   │   └── InjectionSite.swift        ← v3-only: 2D fields deprecated
│   ├── Elements/           (dead views removed: DoseStreakCard, MiniTrendGraph, JournalCardView, HealthInsightsView)
│   │   └── Home/Components/
│   │       └── BodyModel3D/           ← sole body picker system
│   ├── Shared/
│   │   ├── PharmacokineticConstants.swift  ← extracted magic numbers
│   │   ├── ZoneCentroidStore.swift         ← single source of truth for zone metadata
│   │   ├── DeveloperSettings.swift
│   │   └── ...
│   └── Theme/
├── xTTests/
│   ├── CentroidValidationTests.swift       ← new: validates centroids are on mesh
│   └── ...
├── xTUITests/
├── docs/
└── tools/
```

---

## 5. Files Deleted (Complete List)

| File/Directory | Lines | Reason |
|---|---|---|
| `xT/Tests/` (empty directory) | 0 | Confusing; all tests in `xTTests/` |
| `xT/Elements/Home/Components/DoseStreakCard.swift` | ~80 | Orphaned view |
| `xT/Elements/Home/Components/MiniTrendGraph.swift` | ~100 | Orphaned view |
| `xT/Elements/Journal/Components/JournalCardView.swift` | ~120 | Orphaned view |
| `xT/Elements/Journal/Components/HealthInsightsView.swift` | ~60 | Orphaned view |
| `xT/Elements/Home/Components/BodySketches/` (entire directory) | ~399 | 2D sketch system removed |
| 6 sketch detail/overview files | ~850 | 2D coordinate data |
| **Total deleted** | **~1,609 lines** | |

---

## 6. Suggested Sequencing (Lowest Risk First)

| # | Step | Risk | Lines Affected | Behavior Change? |
|---|---|---|---|---|
| 1 | Delete empty `xT/Tests/` + stale pbxproj reference | 🟢 | 0 (empty dir) | No |
| 2 | Delete 4 orphaned views, verify build | 🟡 | ~360 removed | No |
| 3 | Clean stale `project.pbxproj` references | 🟡 | ~20 removed | No |
| 4 | Extract `PharmacokineticConstants` → new struct | 🟡 | ~80 moved | No |
| 5 | Split `TimeContent.swift` → Types + Data | 🟡 | ~1,600 reorganized | No |
| 6 | Migrate zone metadata to `ZoneCentroidStore` — absorb `region(for:)`, `preferredZones`, `recommendedZones(for:)`, add `viewContext(from yaw:)` helper | 🔴 | ~200 moved | No |
| 6a | **Validate centroid-to-mesh mapping** — minimum separation assertion in `ZoneCentroidStore`, centroid-on-mesh tests in `CentroidValidationTests`, `#if DEBUG` centroid visualization overlay in `BodyModel3DView` | 🔴 | ~150 new | No (validates existing) |
| 7 | **Delete `BodySketchData` + `BodySketches/` directory** + rewrite 3 settings views (`AvoidZonesEditorView` → drop sketch preview, text-only; `PreferredZonesEditorView` → flat alphabetical list from `ZoneCentroidStore.labels`; `DoseScheduleSettingsView` → swap data source to `ZoneCentroidStore`) | 🔴 | ~600 removed / rewritten | No |
| 8 | Split `MedicationManager` → 6 extensions | 🔴 | ~2,300 reorganized | No |
| 9 | **Wire `viewContext` for 3D taps** — `BodyModel3DView.Coordinator` passes yaw → `QuickDoseSheet` derives viewContext → `InjectionSite` v3 initializer stores it → `lastDoseSentence` uses real context | 🟡 | ~40 changed | **Yes** — dose history labels show real context |
| 10 | Triage TODO/FIXME comments | 🟡 | ~20 | No |

---

## 7. Items Explicitly NOT Changing

- **3D body system stays** — it's the live default in QuickDoseSheet, the sole body picker post-refactor.
- **`DeveloperSettings` / `SpoofProfile`** — already properly `#if DEBUG`-gated. Clean.
- **`tools/` directory** (figma-mcp-server, scripts, prototypes) — dev tooling, correctly separated from app source.
- **`AuthenticationManager` auto-lock** — timer IS wired, `lastActivityTime` IS read. Not dead code.
- **Existing `InjectionSite` records** — `init(from:)` decoder handles graceful fallback. No migration script needed. Old 2D records keep their fields; new 3D-only records get defaults for deprecated fields.

---

## 8. Zone Label Mapping — How It Works

The 3D tap pipeline maps a screen tap to a zone label through this chain:

```
User taps screen
    ↓
UITapGestureRecognizer → CGPoint (2D screen coords)
    ↓
SCNView.hitTest() → SCNHitTestResult → worldCoordinates (3D)
    ↓
ZoneHitTestEngine.isBodyGeometry() → filters out non-body nodes
    ↓
ZoneCentroidStore.nearestLabel(to:within:0.15)
    → iterates 49 centroids from JSON
    → returns label if distance < 0.15 units
    → returns nil if tap is in dead space
```

**Invariants enforced post-refactor:**
1. **Runtime:** `ZoneCentroidStore.loadCentroids()` asserts no two centroids are within 0.14 units (2 × baseRadius) of each other
2. **Tests:** `CentroidValidationTests` loads each USDZ + JSON pair and validates every centroid is within 0.02 units of the mesh surface with normals pointing outward
3. **Debug:** `#if DEBUG` overlay visualizes centroid positions and hit-test radii on the model

---

## 9. Risk Summary

| Item | Risk | Lines Affected | Behavior Change? |
|---|---|---|---|
| Delete empty `xT/Tests/` | 🟢 | 0 (empty dir) | No |
| Delete 4 orphaned views | 🟡 | ~360 removed | No |
| Clean pbxproj | 🟡 | ~20 removed | No |
| Extract PK constants | 🟡 | ~80 moved | No |
| Split TimeContent | 🟡 | ~1,600 reorganized | No |
| Migrate zone metadata to ZoneCentroidStore | 🔴 | ~200 moved | No |
| Validate centroid-to-mesh mapping | 🔴 | ~150 new | No |
| Delete BodySketchData + rewrite settings views | 🔴 | ~600 removed/rewritten | No |
| Split MedicationManager | 🔴 | ~2,300 reorganized | No |
| Wire viewContext for 3D taps | 🟡 | ~40 changed | **Yes** |
| Triage TODO/FIXME | 🟡 | ~20 | No |

**Total potential impact:** ~1,609 lines deleted + ~4,500 lines reorganized + ~150 lines new tests. One behavioral change: 3D dose history labels show real anatomical context instead of generic `"(3D)"`.

---

*Next step: approve the sequencing above, toggle to ACT MODE, and execute items 1-10 in order.*