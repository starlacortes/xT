# xT Codebase Review — 8 October 2026

A structural and hygiene review of the xT iOS app repository. Verified against
live git index, history, and build system — not just the file listing.

## Summary

The app source is in good shape. The real problems are repo hygiene, not code
structure. The refactor-proposal-v2.md has been substantially executed:
MedicationManager split into 6 extensions, TimeContent split into Types/Data,
PK constants extracted, 2D sketch system removed, empty xT/Tests/ dir gone.
121 Swift files / ~30k LOC app, zero TODO/FIXME, strong test suite (~6.7k LOC
across 20 files).

## Issues found and actions taken

### 1. Git history bloat (~100 MB of old build artifacts) — NOT YET ADDRESSED

The pack is 102.5 MiB. Top 15 blobs are ~100 MB of `build/` dylibs and .pcm
files (largest: 13.7 MB dylib). Build artifacts were pruned from the tree
(commit e621fdf) and gitignored, but every clone still downloads them.

Fix (rewrites commit IDs, requires force-push):
```
git filter-repo --path build --invert-paths
# then re-add remote and force-push
```

**Deferred** — confirm before executing.

### 2. Legal/business docs in app repo with GitHub remote — NOT YET ADDRESSED

`docs/legal/` (Ohio LLC formation, trademark applications) and
`docs/planning/` (monetization strategy) live in a repo with
`git@github.com:starlacortes/xT.git` configured. If the repo goes public
(or gets mirrored), these go with it, including in history.

**Deferred** — confirm repo visibility before acting.

### 3. Time feature files under Elements/Home/ — FIXED

The entire Time tab (~4,500 lines) was parked under `Elements/Home/`.
`Elements/` had Home, Journal, Onboarding, Profile, Settings — but no Time.
Even `MainTabView` (root navigation) sat under Home.

**Action taken:** Created `xT/Elements/Time/` and moved 4 files:
- `TimeView.swift`
- `TimeBodyExplorerView.swift`
- `TimeRegionDetailView.swift`
- `TimeBodyDiagramView.swift` (was in `Home/Components/BodyModel3D/`)

`MainTabView.swift` and `UnifiedScheduleView.swift` remain in `Home/` —
`MainTabView` is root navigation (belongs near the app entry point), and
`UnifiedScheduleView` is used by dose-record flows (NextDoseRowView,
RecordDoseView), not the Time tab specifically.

Safe because the project uses Xcode 16 synchronized folder groups — no
pbxproj edits needed. Build verified: **compiles clean** (exit 0, only
pre-existing warnings). All renames are content-identical (R100 in git
diff).

### 4. Duplicate icon binary — NOT YET ADDRESSED

`xTlogo(dark)-Picsart-AiImageEnhancer 1.png` is byte-identical to
`xTlogo(dark)-Picsart-AiImageEnhancer.png` (984 KB twice). The " 1" copy
is the tinted-appearance slot in `Contents.json`.

**Deferred** — minor, but trivial to fix.

### 5. Geometry code mirrored app ↔ tool — ALREADY SOLVED (review was wrong)

My initial review flagged `BodyOrientation`, `BodyTransform`, and
`ZoneMapFile` as "byte-identical copies" between `xT/Shared/` and
`tools/zonebake/Sources/zonebake/`. This was wrong. The zonebake versions
are **tracked symlinks** (git mode 120000) pointing into `xT/Shared/`.
`diff -q` followed the links and reported "identical." One source of truth
already exists. The `Package.swift` comment documents this intent.

No action needed. The original review claim is retracted.

### 6. tools/figma-mcp-server naked gitlink — FIXED

Was tracked as mode 160000 (submodule) with no `.gitmodules`, AND listed
in `.gitignore` (line 101). Clones got an empty directory; `git submodule`
wouldn't restore it; showed perpetually modified.

**Action taken:** `git rm --cached tools/figma-mcp-server`. The directory
remains on disk for local use. Now covered by `.gitignore`.

### 7. Tracked .pyc — FIXED

`tools/scripts/__pycache__/blender_generate_body.cpython-313.pyc` was
tracked in git.

**Action taken:** `git rm --cached` the .pyc. Added `__pycache__/` and
`*.pyc` to `.gitignore`.

### 8. Editor/agent configs tracked — FIXED

`.claude/settings.json`, `.vscode/extensions.json`,
`.xcodebuildmcp/config.yaml`, `opencode.json` were tracked. Also found
xcuserdata files that slipped past the old ignore:
`UserInterfaceState.xcuserstate` and `xcschememanagement.plist`.

**Action taken:** `git rm --cached` all of them. Added `.claude/`,
`.vscode/`, `.xcodebuildmcp/`, `.opencode/`, `opencode.json`, and
`xcuserdata/` to `.gitignore`.

### 9. .gitignore stacked templates — FIXED

Was 116 lines of stacked gitignore.io templates with a footgun: line 71
`*.xcodeproj` ignored the entire project, rescued only by line 82's
`!*.xcodeproj/project.pbxproj`. Replaced with a clean 48-line file covering
only what this project actually needs.

## Items verified as non-issues

- **Nested `xT/xT`** — standard Xcode layout (repo root contains
  xT.xcodeproj + same-named source dir). Not wrong.
- **Three `zone_map_*.json`** — different MD5s, per-body-type data, not
  duplicates.
- **PDFs next to .tex** in `docs/research/` — normal LaTeX output.
- **Only true 4-digit view** is `QuickDoseSheet` (~1,000 lines); other big
  files (PK constants, TimeBodyRegions) are data, not logic.
- **DatasetReset.swift** has zero `#if DEBUG` guards — if it's the
  production data-wipe path that's intentional; confirm if not.

## Smaller remaining items (not addressed this session)

- `SpoofProfile.swift` (~935 lines, dev-only) lives in `Shared/` — a
  `DevTools/` group would keep production `Shared/` clean.
- No CI (no `.github/`) — tests exist; a build+test on push is cheap.
- 12 TODO/FIXME comments (per refactor-proposal-v2.md §3a) — actually
  grep found 0 now; already triaged or removed.
- 21 dirty files (docs reorg mid-flight) — land separately.

## Staged changes (not yet committed)

All changes are staged in git, ready to commit:

```
Renamed: 4 files → xT/Elements/Time/
Deleted from index: .claude/settings.json, .vscode/extensions.json,
  .xcodebuildmcp/config.yaml, opencode.json, tools/figma-mcp-server,
  tools/scripts/__pycache__/blender_generate_body.cpython-313.pyc,
  xcuserdata files (2)
Modified: .gitignore (116 → 48 lines, rewritten)
```

Tracked file count: 257 → 249.

Build status: **compiles clean** (Debug, iPhone 17 Pro Simulator).
Test status: running (see background process).
