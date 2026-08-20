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
                    months: months,
                    isTestosterone: isTestosterone,
                    tenureTier: TenureTier(months: months),
                    bodySystemDetail: resolvedBodySystemDetail(for: regionKey),
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

    // MARK: - Body system detail resolution

    /// Maps a tapped region to the BodySystemKey whose detail supplements it,
    /// then materialises the detail from a minimal engine. Returns nil for regions
    /// whose content is fully self-contained (E chest, T abdomen).
    ///
    /// Mapping per spec Phase 2:
    ///   E head → moodAndMind,  E hips/thighs/glutes/abdomen → bodyShape,  E chest → nil
    ///   T chest/thighs/hips/glutes → muscleStrength,  T abdomen/head → nil
    private func resolvedBodySystemDetail(for regionKey: TimeRegionKey) -> TimeBodySystemDetail? {
        guard let systemKey = bodySystemKey(for: regionKey) else { return nil }
        return minimalEngine.bodySystemDetail(for: systemKey)
    }

    private func bodySystemKey(for regionKey: TimeRegionKey) -> BodySystemKey? {
        if isTestosterone {
            switch regionKey {
            case .chest, .thighs, .hips, .glutes: return .muscleStrength
            case .abdomen, .head:                  return nil
            }
        } else {
            switch regionKey {
            case .head:                            return .moodAndMind
            case .hips, .thighs, .glutes, .abdomen: return .bodyShape
            case .chest:                           return nil
            }
        }
    }

    /// Minimal engine for body-system detail lookup only.
    /// Uses activeMonthsOnHRT for correct tenureTier; other fields aren't
    /// accessed by bodySystemDetail and are set to safe defaults.
    private var minimalEngine: TimeContentEngine {
        TimeContentEngine(
            medication: isTestosterone ? "Testosterone" : "Estrogen",
            method: medicationManager.selectedAdministrationMethod ?? "Injectable",
            months: months,
            currentLevel: nil,
            dayOfCycle: 1,
            activeMonthsOnHRT: months,
            ageAtStart: nil,
            screeningLog: nil,
            showDoseIntensity: false,
            adherenceRate: nil,
            cyclePosition: .midCycle,
            regimenSegments: [],
            onTimeStreak: 0,
            relativeDoseIntensity: 1.0,
            doseIntensityNote: nil,
            bloodTestSchedulingText: "",
            suggestedBloodTestMonth: nil,
            cycleLengthDays: 7
        )
    }
}
