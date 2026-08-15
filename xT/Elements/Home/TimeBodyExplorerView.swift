//
//  TimeBodyExplorerView.swift
//  xT
//
//  The Time screen's single interactive whole-body diagram. Hosts the SceneKit
//  `TimeBodyDiagramView` full-bleed and overlays the selected region's title and
//  timeline/phase content — on the right for body regions, and upper-centre for
//  the head/Mind (whose 3-D model drops to the bottom of the screen).
//

import SwiftUI

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
                // Near-black "space" backdrop, faintly hued toward the user's
                // theme accent — constant in both appearances so the
                // constellation skin always reads as stars against a night sky.
                // TimeView lays the same backdrop under the whole screen; this
                // keeps the explorer self-contained (e.g. in previews).
                ZStack {
                    Color.black
                    themeManager.palette.accent.opacity(0.07)
                }
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
        case .head:
            MindInfoPanel(
                regions: mindRegionData,
                months: months,
                selectedBrainRegion: $selectedBrainRegion,
                isTestosterone: isTestosterone,
                onClose: { withAnimation(.easeInOut(duration: 0.3)) { selectedRegion = nil } }
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        case .some(let region):
            if let data = bodyRegionData.first(where: { $0.key == region.bodyRegionKey }) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RegionInfoPanel(
                        title: region.title,
                        region: data,
                        months: months,
                        isTestosterone: isTestosterone,
                        onClose: { withAnimation(.easeInOut(duration: 0.3)) { selectedRegion = nil } }
                    )
                    .frame(width: width * 0.63)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
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
}

// MARK: - Body region panel (right side)

private struct RegionInfoPanel: View {
    let title: String
    let region: BodyRegion
    let months: Int
    let isTestosterone: Bool
    let onClose: () -> Void

    private var stats: [(value: String, label: String, sub: String)] {
        isTestosterone ? TimeBodyRegions.bodyStatsT(months: months) : TimeBodyRegions.bodyStats(months: months)
    }

    var body: some View {
        // Hug the content (no ScrollView) so the card is only as tall as its text.
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            Text(region.phaseLabel(at: months))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(region.focusText(at: months) ?? region.phaseText(at: months))
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Match stats by region-key prefix (not the display title), so
            // renaming a title can't drop the stat, while key-derived labels
            // like "Abdomen Shift" still match the "abdomen" region.
            if let stat = stats.first(where: { $0.label.range(of: region.key, options: [.caseInsensitive, .anchored]) != nil }) {
                statRow(stat)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.trailing, 12)
    }

    private func statRow(_ stat: (value: String, label: String, sub: String)) -> some View {
        HStack(spacing: 12) {
            Text(stat.value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(stat.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(stat.sub)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Mind panel (upper centre)

private struct MindInfoPanel: View {
    let regions: [BodyRegion]
    let months: Int
    @Binding var selectedBrainRegion: String?
    let isTestosterone: Bool
    let onClose: () -> Void

    private var selected: BodyRegion? {
        regions.first { $0.key == selectedBrainRegion }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mind")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            // Brain sub-region chips.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(regions) { r in
                        Button {
                            // No withAnimation here: cross-fading the detail text
                            // below ghosts the old and new copy over each other.
                            selectedBrainRegion = (selectedBrainRegion == r.key) ? nil : r.key
                        } label: {
                            Text(r.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedBrainRegion == r.key ? Color.white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(selectedBrainRegion == r.key
                                                   ? Color.accentColor
                                                   : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selected {
                Text(selected.phaseLabel(at: months))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(selected.focusText(at: months) ?? selected.phaseText(at: months))
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(isTestosterone
                     ? TimeBodyRegions.mindInsightT(months: months)
                     : TimeBodyRegions.mindInsight(months: months))
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
