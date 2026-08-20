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

                overlay(width: geo.size.width)
            }
        }
        .onChange(of: selectedRegion) { _, new in
            if new != .head { selectedBrainRegion = nil }
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
    private func overlay(width: CGFloat) -> some View {
        switch selectedRegion {
        case .none:
            if !hintDismissed {
                restingHint
                    .transition(.opacity)
            }
        case .some(let regionKey):
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                TimeRegionDetailView(
                    regionKey: regionKey,
                    region: regionKey.isMind ? nil : bodyRegionData.first { $0.key == regionKey.bodyRegionKey },
                    mindRegions: mindRegionData,
                    context: journeyContext,
                    selectedBrainRegion: $selectedBrainRegion,
                    onClose: { withAnimation(.easeInOut(duration: 0.3)) { selectedRegion = nil } }
                )
                .frame(width: width * 0.82)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
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
