import SwiftUI

// MARK: - Region Detail View (Phase 3)
//
// Full-screen overlay reached by tapping a region on the 3-D body diagram.
// Absorbs RegionInfoPanel and MindInfoPanel — both are superseded by this view.
// Opens from the trailing edge via .transition(.move(edge: .trailing).combined(with: .opacity)).

struct TimeRegionDetailView: View {
    let regionKey: TimeRegionKey
    /// The matching BodyRegion from the medication-appropriate array; nil for .head.
    let region: BodyRegion?
    /// The full array of mind sub-regions (pfc/hippocampus/amygdala/synaptic).
    let mindRegions: [BodyRegion]
    let months: Int
    let isTestosterone: Bool
    let tenureTier: TenureTier
    /// Pre-resolved body system detail, or nil when the region has no supplement.
    let bodySystemDetail: TimeBodySystemDetail?
    @Binding var selectedBrainRegion: String?
    let onClose: () -> Void

    private var isMind: Bool { regionKey == .head }

    private var activeRegion: BodyRegion? {
        isMind
            ? mindRegions.first { $0.key == selectedBrainRegion }
            : region
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                if isMind {
                    brainChipRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                heroSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                overviewSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                if let detail = bodySystemDetail {
                    deepDiveSection(detail: detail)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
        .padding(.trailing, 12)
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(regionKey.title)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)

                if let phaseLabel = currentPhaseLabel {
                    Text(phaseLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
    }

    private var currentPhaseLabel: String? {
        if isMind {
            return activeRegion?.phaseLabel(at: months)
        }
        return region?.phaseLabel(at: months)
    }

    // MARK: Brain sub-region chips (mind only)

    private var brainChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mindRegions) { r in
                    Button {
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
    }

    // MARK: Hero section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let heroText = currentHeroText
            Text(heroText)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentHeroText: String {
        if isMind {
            if let active = activeRegion {
                return active.focusText(at: months) ?? active.phaseText(at: months)
            }
            return isTestosterone
                ? TimeBodyRegions.mindInsightT(months: months)
                : TimeBodyRegions.mindInsight(months: months)
        }
        guard let r = region else { return "" }
        return r.focusText(at: months) ?? r.phaseText(at: months)
    }

    // MARK: Overview section

    @ViewBuilder
    private var overviewSection: some View {
        let text = currentOverview
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("About this region")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var currentOverview: String {
        if isMind {
            return activeRegion?.overview
                ?? (isTestosterone
                    ? TimeBodyRegions.mindRegionsT.first?.overview ?? ""
                    : TimeBodyRegions.mindRegions.first?.overview ?? "")
        }
        return region?.overview ?? ""
    }

    // MARK: Deep-dive section (body system detail)

    @ViewBuilder
    private func deepDiveSection(detail: TimeBodySystemDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailDivider()

            detailBlock(
                label: "Your timeline",
                text: detail.timelineText
            )

            detailBlock(
                label: "What to expect",
                text: detail.whatToExpect
            )

            if let note = deepeningOrMaintenanceNote(detail: detail) {
                detailBlock(
                    label: tenureTier >= .t5Settled ? "Long-term" : "At this stage",
                    text: note
                )
            }
        }
    }

    private func deepeningOrMaintenanceNote(detail: TimeBodySystemDetail) -> String? {
        if tenureTier >= .t5Settled { return detail.maintenanceNote }
        if tenureTier == .t4Deepening { return detail.deepeningNote }
        return nil
    }

    private func detailBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Hairline divider

private struct DetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }
}
