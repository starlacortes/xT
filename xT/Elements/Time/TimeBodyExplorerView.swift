import SwiftUI

// MARK: - Time Body Explorer

struct TimeBodyExplorerView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.themeManager) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedRegion: TimeRegionKey?
    @State private var selectedBrainRegion: String?
    /// Becomes true 3 s after the explorer first appears; hides the resting hint.
    @State private var hintDismissed = false
    /// Natural height of the open `.stage` card's content, measured by the
    /// card and reported up. The sheet's expanded detent sizes to this (plus
    /// its bottom margin) instead of always filling the screen.
    @State private var stageContentHeight: CGFloat = 0
    /// Detent selection for the `.stage` sheet. Written on region change so a
    /// newly opened sheet presents at its standard height and an open sheet
    /// snaps back to it when the tapped region changes.
    @State private var sheetDetent: PresentationDetent = .medium

    private var bodyType: BodyType {
        BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral
    }

    private var months: Int { medicationManager.activeMonthsOnHRT }

    private var isTestosterone: Bool {
        (medicationManager.selectedMedication ?? "Estrogen").localizedCaseInsensitiveContains("testosterone")
    }

    private var bodyRegionData: [BodyRegion] {
        isTestosterone ? TimeBodyRegions.bodyRegionsT : TimeBodyRegions.bodyRegions
    }

    private var mindRegionData: [BodyRegion] {
        isTestosterone ? TimeBodyRegions.mindRegionsT : TimeBodyRegions.mindRegions
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // TimeView lays the same backdrop under the whole screen; this
                // keeps the explorer self-contained (e.g. in previews).
                NightSkyBackdrop()
                    .allowsHitTesting(false)

                TimeBodyDiagramView(
                    bodyType: bodyType,
                    selectedRegion: $selectedRegion,
                    themeColor: themeManager.palette.accentSecondary,
                    activeColor: themeManager.palette.accent,
                    reduceMotion: reduceMotion
                )
                .ignoresSafeArea()

                overlay(size: geo.size)
            }
            .sheet(item: stageSheetItem) { regionKey in
                sheetContent(for: regionKey, size: geo.size)
            }
            .onChange(of: selectedRegion) { _, new in
                if new != .head { selectedBrainRegion = nil }
                // Every newly opened sheet presents at its standard height; an
                // open sheet snaps back to it when the tapped region changes,
                // and a dismissal resets it for the next presentation.
                sheetDetent = collapsedDetent(for: geo.size)
            }
        }
        .onAppear {
            // Fade the "Tap a region…" hint away after a short grace period —
            // it's an onboarding nudge, not chrome.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.4)) { hintDismissed = true }
            }
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private func overlay(size: CGSize) -> some View {
        switch selectedRegion {
        case .none:
            if !hintDismissed {
                restingHint
                    .transition(.opacity)
            }
        case .some(let regionKey):
            // `.stage` regions present through the native sheet — see
            // `sheetContent`. Only `.profile` (thighs) renders as an overlay
            // card sliding in from the trailing edge.
            if regionKey.framing == .profile {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    detailCard(for: regionKey)
                        .padding(.trailing, Theme.Spacing.md)
                        .frame(width: size.width * 0.45)
                        .frame(maxHeight: size.height * 0.65, alignment: .center)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func detailCard(for regionKey: TimeRegionKey) -> some View {
        TimeRegionDetailView(
            regionKey: regionKey,
            region: regionKey.isMind ? nil : bodyRegionData.first { $0.key == regionKey.bodyRegionKey },
            mindRegions: mindRegionData,
            context: journeyContext,
            selectedBrainRegion: $selectedBrainRegion,
            onClose: {
                // Only the `.profile` card renders this button — stage cards
                // dismiss by swipe. Clearing the selection dismisses either
                // presentation.
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                    selectedRegion = nil
                }
            }
        )
    }

    // MARK: - Stage sheet

    /// Sheet item for `.stage` regions only — `.profile` (thighs) never
    /// presents the sheet; the side card renders instead. Tapping thighs while
    /// a stage sheet is open therefore dismisses it via the binding.
    private var stageSheetItem: Binding<TimeRegionKey?> {
        Binding(
            get: { selectedRegion.flatMap { $0.framing == .stage ? $0 : nil } },
            set: { if selectedRegion != $0 { selectedRegion = $0 } }
        )
    }

    /// The `.stage` card presented as a native sheet. SwiftUI owns the drag
    /// physics — swiping up grows to the expanded detent, a pull down from
    /// expanded collapses back to the standard strip, and a decisive drag
    /// dismisses — and the background stays interactive so the body diagram
    /// keeps accepting taps at every detent.
    ///
    /// The sheet's own system glass is the card surface; the detail view
    /// renders no background of its own in `.stage` framing. iOS 26 ignores
    /// `.presentationBackground(.clear)` on sheets, so a tinted glass panel on
    /// the content would show inside the sheet's glass as a card within a card.
    @ViewBuilder
    private func sheetContent(for regionKey: TimeRegionKey, size: CGSize) -> some View {
        detailCard(for: regionKey)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            // Fresh scroll position per region — without this the ScrollView
            // can keep the previous region's offset when the item swaps.
            .id(regionKey)
            .onPreferenceChange(TimeCardContentHeightKey.self) { height in
                stageContentHeight = height
            }
            .presentationDetents(
                [collapsedDetent(for: size), expandedDetent(for: size)],
                selection: $sheetDetent
            )
            .presentationDragIndicator(.visible)
            // Plain `.enabled`, not `upThrough:` — taps behind the sheet must
            // keep landing at the expanded detent too, so a lifted model stays
            // selectable.
            .presentationBackgroundInteraction(.enabled)
            // The Time screen's backdrop is near-black in both appearances, so
            // the sheet renders dark whatever the system setting is. Without
            // this, Light Mode resolves the grabber and glass to the light
            // side of the ground.
            .environment(\.colorScheme, .dark)
    }

    /// Standard height — the detent the sheet rests at before any drag.
    private func collapsedDetent(for size: CGSize) -> PresentationDetent {
        size.height > 0 ? .height(size.height * 0.4025) : .medium
    }

    /// Detent that shows every line of the measured content: content height
    /// plus the bottom margin the sheet content wraps around it, never smaller
    /// than the strip, never past the screen. `.large` covers the frames
    /// before the first measurement lands.
    private func expandedDetent(for size: CGSize) -> PresentationDetent {
        guard size.height > 0, stageContentHeight > 0 else { return .large }
        return .height(max(size.height * 0.4025,
                           min(stageContentHeight + Theme.Spacing.md, size.height)))
    }

    private var restingHint: some View {
        VStack {
            Spacer()
            Text("Tap a region to explore your changes")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Journey context

    /// Everything the region card selects copy against. One object, one month
    /// count — see `docs/App design/TIME_CARD_PERSONALIZATION.md` §3.
    private var journeyContext: JourneyContext {
        JourneyContext(
            track: isTestosterone ? .testosterone : .estrogen,
            month: months,
            method: medicationManager.selectedAdministrationMethod,
            ageAtStart: medicationManager.ageAtHRTStart,
            adherence: medicationManager.adherenceRate,
            hasLabs: medicationManager.currentHormoneLevel != nil
        )
    }
}
