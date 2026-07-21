# HomeView Redesign — Implementation Specification (Reuse-Optimized)

## Overview
Redesign Home to a **unified glass stack** over a **full-bleed Canvas graph background** with an **overlaid level badge**. Maximize reuse of existing components, adopt SwiftUI `Canvas` for performant drawing, and use iOS 17+ `glassBackgroundEffect` for Liquid Glass.

---

## Reuse Audit — What Already Exists

| New Component | Reuses / Adapts | Notes |
|---------------|-----------------|-------|
| `GraphBackgroundView` | `FlatGraphView` curve logic (`curvePath`, `curveFillPath`, `yPos`, `markerX`), `levelTint` computation, `latestDoseDotOffset` animation | **Port to `Canvas`** — immediate-mode drawing, 60 fps, no View tree overhead |
| `LevelOverlayView` | `FlatGraphView.levelLabel` (`AnimatedCounter` + unit + range pill), `rangeWord(for:)` logic | Extract into standalone; `AnimatedCounter` from `Motion.swift` |
| `UnifiedStackView` | **New container** — uses existing `Theme` glass tokens (`ultraThinMaterial`, `Theme.Colors.border`) | Use `.glassBackgroundEffect(in: .rect(cornerRadius: 20))` on iOS 17+ |
| `InsightRowView` | `FlatInsightRow` (insight text logic, `statusColor` computation) | Simplify layout: dot + text, no card background |
| `MoodRowView` | `JournalCardView` (mood emoji + value + subtext), `JournalManager.lastEntry` | Read-only row; tap → `JournalComposerView` |
| `NextDoseRowView` | `FlatNextDoseRow` (cycle math, `completedDays`, `cycleDays`, `nextLabel`) | Replace bar with `DotTrackView` |
| `DotTrackView` | **New reusable** — simple `HStack` of `RoundedRectangle` | Used by `NextDoseRowView`; reusable elsewhere |
| `ActionBarView` | `FlatQuickActionsRow` (two-button layout, `.pressable` style, `QuickDoseSheet`, `JournalComposerView`) | Glass buttons with icon circles; primary/secondary variants |
| `HeroView` | **Slim down** — keep greeting + name only; drop medication line (moves to insight/next-dose) | Keep `.entrance` animation |
| `HomeColorBackdrop` | **Replace** → `GraphBackgroundView` (parallax handled by `HomeView` scroll offset) | `Canvas` draws full SVG-equivalent background |

**Existing utilities to use directly:**
- `AnimatedCounter` (`Theme/Motion.swift:76`) — level number animation
- `.entrance(delay:)` / `.entrance(index:)` (`Theme/Motion.swift:38`) — staggered reveals
- `.pressable` button style (`Theme/Motion.swift:53`) — tactile press + haptic
- `Theme.Colors` — all semantic colors (accent, levelLow/levelHigh, Time palettes, success/warning/error)
- `Theme.Radius`, `Theme.Spacing`, `Theme.Fonts` — design tokens
- `MedicationManager` — `currentHormoneLevel`, `recentLevels`, `lastDoseDate`, `nextDoseDate`, `doseRecordedCount`, `hasMissedDose`, `isFullyConfigured`
- `JournalManager` — `lastEntry` (today), `JournalComposerView`
- `QuickDoseSheet` — dose recording sheet

---

## Apple Best Practices Applied

| Area | Guideline (from sosumi search) | Implementation |
|------|--------------------------------|----------------|
| **Custom Drawing** | Use `Canvas` + `GraphicsContext` for immediate-mode, high-perf drawing (WWDC 2021 "Add rich graphics") | `GraphBackgroundView` = `Canvas { ctx, size in … }` |
| **Glassmorphism** | iOS 17+ `glassBackgroundEffect(in:)` / `glassEffect(in:)` for Liquid Glass (Adopting Liquid Glass doc) | `UnifiedStackView.background { GlassBackground() }` |
| **Scroll Parallax** | Read offset via `.scrollTargetBehavior(.viewAligned)` + `GeometryReader` in named coordinate space (WWDC 2023 "Beyond scroll views") | `HomeView` already uses `ScrollOffsetPreferenceKey` — keep |
| **Performance** | `drawingGroup()` for complex view trees; `Canvas` renders to single layer | `GraphBackgroundView` is one `Canvas`; no subviews |
| **Accessibility** | Honor `@Environment(\.accessibilityReduceMotion)` — already in `EntranceModifier` & `AnimatedCounter` | No changes needed |

---

## File Plan (Minimal New Files)

### New Files (6)
```
xT/Elements/Home/Components/
├── GraphBackgroundView.swift      // Canvas-based SVG-equivalent background
├── LevelOverlayView.swift         // Top-left badge (Extracted from FlatGraphView)
├── UnifiedStackView.swift         // Glass card container (NEW)
├── InsightRowView.swift           // Adapted from FlatInsightRow
├── MoodRowView.swift              // Adapted from JournalCardView
├── NextDoseRowView.swift          // Adapted from FlatNextDoseRow
├── ActionBarView.swift            // Adapted from FlatQuickActionsRow
└── DotTrackView.swift             // Reusable dot track (NEW)
```

### Modified Files (3)
```
xT/Elements/Home/
├── HomeView.swift                 // Restructure: ZStack(GraphBackground + LevelOverlay + ScrollView(Hero + UnifiedStack))
├── HomeColorBackdrop.swift        // DEPRECATE → redirect to GraphBackgroundView (or delete)
└── HeroView.swift                 // Slim: greeting + name only
```

### Deleted Files (5 — after migration)
```
xT/Elements/Home/
├── FlatGraphView.swift            // → GraphBackgroundView + LevelOverlayView
├── Components/
│   ├── MainContentView.swift      // → UnifiedStackView
│   ├── LevelTrendCard.swift       // → deprecated (replaced by UnifiedStack)
│   ├── MissedDosePrompt.swift     // Keep if used elsewhere; else inline in UnifiedStack
│   └── FlatQuickActionsRow.swift  // → ActionBarView
```

---

## Component Specs (Reuse-Focused)

### 1. GraphBackgroundView.swift — `Canvas` Port of FlatGraphView
```swift
struct GraphBackgroundView: View {
    @Environment(\.medicationManager) private var mm
    let scrollOffset: CGFloat        // For parallax (passed from HomeView)
    
    var body: some View {
        Canvas { ctx, size in
            drawBackgroundGradients(ctx, size)
            drawGridLines(ctx, size)
            drawYAxisLabels(ctx, size)
            drawPeakTroughLines(ctx, size)
            drawHormoneCurve(ctx, size)
            drawDoseMarker(ctx, size)
            drawFutureDots(ctx, size)
        }
        .parallaxOffset(scrollOffset)  // Custom modifier: .offset(y: scrollOffset * 0.35)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
```
**Reused logic** (copy/paste adapt from `FlatGraphView`):
- `curvePath`, `curveFillPath`, `xPos`, `yPos`, `markerX` → become `Canvas` drawing calls
- `levelTint` computation (rose→lavender based on level/ceiling)
- `latestDoseDotOffset` animation state (drive via `.onChange(of: mm.doseRecordedCount)`)
- `points` from `mm.recentLevels`

**Performance**: Single `Canvas` = one GPU layer. No View tree. 60 fps guaranteed.

---

### 2. LevelOverlayView.swift — Extracted from FlatGraphView.levelLabel
```swift
struct LevelOverlayView: View {
    @Environment(\.medicationManager) private var mm
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Estimated")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.white.opacity(0.32))
            
            if let level = mm.currentHormoneLevel?.value {
                AnimatedCounter(value: level)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text(unitText)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.white.opacity(0.32))
                    
                    RangePill(text: rangeText, color: rangeColor)
                }
            }
        }
        .padding(.top, 42)   // Safe area + 42pt
        .padding(.leading, 22)
    }
}
```
**Reuses**: `AnimatedCounter`, `rangeWord(for:)` from `FlatGraphView`, `Theme.Fonts`.

---

### 3. UnifiedStackView.swift — Liquid Glass Container
```swift
struct UnifiedStackView: View {
    @Environment(\.medicationManager) private var mm
    @Environment(\.journalManager) private var jm
    @Binding var showingGraphDetail: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if mm.hasMissedDose { MissedDosePrompt() }
            
            InsightRowView()
            Divider().opacity(0.07)
            
            MoodRowView()
            Divider().opacity(0.07)
            
            NextDoseRowView()
            Divider().opacity(0.07)
            
            ActionBarView(showingGraphDetail: $showingGraphDetail)
        }
        .padding(.horizontal, 14)  // Internal padding
        .background {
            // iOS 17+ Liquid Glass
            Rectangle()
                .fill(Color(hex: "0A0814").opacity(0.68))
                .glassBackgroundEffect(in: .rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Staggered entrance
        .entrance(index: 0)  // Applied to each row via ForEach or manual index
    }
}
```
**Uses**: `.glassBackgroundEffect(in:)` (iOS 17+) with custom dark tint matching design `#0A0814` 68%.

---

### 4. InsightRowView.swift — Adapted from FlatInsightRow
```swift
struct InsightRowView: View {
    @Environment(\.medicationManager) private var mm
    
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(Color(hex: "64DC9E")).frame(width: 5, height: 5).padding(.top, 4)
            Text(insightText)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
```
**Reuses**: `insightText` logic, `statusColor` computation from `FlatInsightRow` (lines 187-234).

---

### 5. MoodRowView.swift — Adapted from JournalCardView
```swift
struct MoodRowView: View {
    @Environment(\.journalManager) private var jm
    @State private var showComposer = false
    
    var body: some View {
        HStack(spacing: 10) {
            Text(todayEntry?.mood.emoji ?? "🌸").font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(todayEntry?.mood.rawValue.capitalized ?? "Add mood")
                    .font(Theme.Fonts.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                Text(todayEntry?.previewText ?? "Tap to journal")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.white.opacity(0.36))
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture { showComposer = true }
        .sheet(isPresented: $showComposer) { JournalComposerView().environment(\.journalManager, jm).environment(\.medicationManager, mm) }
    }
}
```
**Reuses**: `JournalManager.lastEntry`, `JournalEntry.mood.emoji`, `JournalComposerView`.

---

### 6. NextDoseRowView.swift — Adapted from FlatNextDoseRow
```swift
struct NextDoseRowView: View {
    @Environment(\.medicationManager) private var mm
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Next dose").font(Theme.Fonts.caption2).foregroundStyle(.white.opacity(0.32))
                Text(nextDoseDayName).font(Theme.Fonts.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.88))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                DotTrackView(filled: completedDays, total: cycleDays)
                Text("Day \(completedDays) of \(cycleDays)")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
```
**Reuses**: `cycleDays`, `completedDays`, `nextDoseDate` logic from `FlatNextDoseRow` (lines 337-384).

---

### 7. DotTrackView.swift — New Reusable
```swift
struct DotTrackView: View {
    let filled: Int
    let total: Int
    var filledColor: Color = Theme.Colors.accentSecondary  // #D4537E
    var emptyColor: Color = .white.opacity(0.14)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < filled ? filledColor : emptyColor)
                    .frame(width: 24, height: 4)
            }
        }
    }
}
```

---

### 8. ActionBarView.swift — Adapted from FlatQuickActionsRow
```swift
struct ActionBarView: View {
    @Environment(\.medicationManager) private var mm
    @Binding var showingGraphDetail: Bool
    @State private var showQuickDose = false
    @State private var showJournal = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Primary: Record Dose
            ActionButton(
                icon: { CirclePlusIcon() },
                iconBg: Theme.Colors.accentSecondary.opacity(0.22),
                iconColor: Theme.Colors.accentSecondary,
                label: "Record dose",
                labelColor: Theme.Colors.accentSecondary.opacity(0.9),
                bg: Theme.Colors.accentSecondary.opacity(0.13)
            ) { showQuickDose = true }
            
            Rectangle().fill(.white.opacity(0.07)).frame(width: 0.5, height: 44)
            
            // Secondary: Journal
            ActionButton(
                icon: { SquarePenIcon() },
                iconBg: Theme.Colors.accent.opacity(0.18),
                iconColor: Theme.Colors.accent,
                label: "Journal",
                labelColor: .white.opacity(0.45),
                bg: .clear
            ) { showJournal = true }
        }
        .sheet(isPresented: $showQuickDose) { QuickDoseSheet(isPresented: $showQuickDose).environment(\.medicationManager, mm) }
        .sheet(isPresented: $showJournal) { JournalComposerView().environment(\.journalManager, jm).environment(\.medicationManager, mm) }
    }
}
```
**Reuses**: `QuickDoseSheet`, `JournalComposerView`, `.pressable` button style.

---

## HomeView.swift — New Structure
```swift
struct HomeView: View {
    @Environment(\.profileManager) private var pm
    @Environment(\.medicationManager) private var mm
    @Environment(\.journalManager) private var jm
    @State private var showingGraphDetail = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()
                
                // 1. Full-bleed Canvas graph background
                GraphBackgroundView(scrollOffset: scrollOffset)
                
                // 2. Level overlay (fixed top-left)
                if mm.isFullyConfigured {
                    LevelOverlayView()
                }
                
                // 3. Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero: greeting + name only
                        HeroView(compactHeight: true)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                        
                        Spacer(minLength: 200)  // Pushes stack to lower portion
                        
                        // Unified glass stack
                        if mm.isFullyConfigured {
                            UnifiedStackView(showingGraphDetail: $showingGraphDetail)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 40)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("homeScroll")).minY)
                    })
                }
                .coordinateSpace(name: "homeScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollOffset = $0 }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingGraphDetail) { GraphView().environment(\.medicationManager, mm) }
    }
}
```

---

## Migration Sequence (Safe, Incremental)

| Step | Action | Files |
|------|--------|-------|
| 1 | Create `GraphBackgroundView` (port `FlatGraphView` curve logic to `Canvas`) | New |
| 2 | Create `LevelOverlayView` (extract from `FlatGraphView.levelLabel`) | New |
| 3 | Create `DotTrackView` (new reusable) | New |
| 4 | Create `InsightRowView`, `MoodRowView`, `NextDoseRowView`, `ActionBarView` (adapt from existing) | New |
| 5 | Create `UnifiedStackView` (assembles rows with glass background) | New |
| 6 | Update `HomeView` to new ZStack structure | Modify |
| 7 | Slim `HeroView` (remove medication line) | Modify |
| 8 | Delete `FlatGraphView`, `MainContentView`, `LevelTrendCard`, `FlatQuickActionsRow` | Delete |
| 9 | Delete `HomeColorBackdrop` (or keep as alias) | Delete |
| 10 | Build, test on simulator, verify parallax + glass + animations | Verify |

---

## Testing Checklist

- [ ] `GraphBackgroundView` renders curve, fill, grid, labels, dose marker, future dots at 60 fps (Instruments: Core Animation → FPS)
- [ ] Parallax: background moves at 35% scroll speed, level overlay fixed
- [ ] `UnifiedStackView` shows Liquid Glass (iOS 17+) / `ultraThinMaterial` fallback (iOS 16)
- [ ] Staggered `.entrance(index:)` on each row (0.07s stagger)
- [ ] `AnimatedCounter` animates level on appear + dose change
- [ ] Dose marker dot slides in from right on new dose
- [ ] Missed dose prompt appears above stack when `hasMissedDose`
- [ ] Action buttons open `QuickDoseSheet` / `JournalComposerView`
- [ ] Dynamic Type: all text scales, layout doesn't break
- [ ] Dark/Light mode: colors adapt via `Theme.Colors` (lightHex/darkHex)
- [ ] Reduce Motion: entrances instant, counter instant
- [ ] No layout warnings in console
- [ ] Build succeeds `xcodebuild -scheme xT -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## Estimated Effort (Reuse-Optimized)

| Phase | Work | Est. Hours |
|-------|------|------------|
| 1-2 | `GraphBackgroundView` + `LevelOverlayView` (Canvas port + extraction) | 3-4 |
| 3-5 | Row components (adapt existing logic) | 3-4 |
| 6 | `UnifiedStackView` + glass background | 1-2 |
| 7 | `HomeView` restructure + `HeroView` slim | 1 |
| 8-9 | Cleanup deletions | 0.5 |
| 10 | Testing & polish | 2 |
| **Total** | | **10-13 hrs** |

---

## Key Decision: Canvas vs Path-in-View

**Use `Canvas`** for `GraphBackgroundView` because:
- Single draw pass, GPU-backed, no View tree overhead
- Easy to animate `latestDoseDotOffset` by passing as `@State` to renderer closure
- Matches Apple's "Add rich graphics to your SwiftUI app" (WWDC 2021) recommendation for complex backgrounds
- The SVG is static-ish (curve only changes on dose log) — `Canvas` is ideal

**Keep `Path` + `Shape`** for small reusable shapes (dot track, range pill, buttons) — simpler, declarative.

---

## iOS Version Target

- **Minimum**: iOS 16 (current project)
- **Glass**: `.glassBackgroundEffect` requires iOS 17+ → wrap in `if #available(iOS 17.0, *)` with `ultraThinMaterial` fallback
- **Canvas**: iOS 15+ ✅