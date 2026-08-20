import SwiftUI

// MARK: - Region Detail View
//
// Full-screen overlay reached by tapping a region on the 3-D body diagram.
// Absorbs RegionInfoPanel and MindInfoPanel — both are superseded by this view.
// Opens from the trailing edge via .transition(.move(edge: .trailing).combined(with: .opacity)).
//
// Slot structure per `docs/App design/TIME_CARD_PERSONALIZATION.md` §6:
//
//   NOW      always      what this tissue is doing this month
//   INSIGHT  always      mechanism while the region is moving, fact when it isn't
//   ABOUT    pending     the region's overview, until its clock starts
//
// The three tier-level blocks that used to sit below ("Your timeline", "What to
// expect", "Long-term") are gone. They were keyed to tenure rather than to the
// region, so all four estrogen body regions rendered the same fifty words.

struct TimeRegionDetailView: View {
    let regionKey: TimeRegionKey
    /// The matching BodyRegion from the medication-appropriate array; nil for .head.
    let region: BodyRegion?
    /// The full array of mind sub-regions (pfc/hippocampus/amygdala/synaptic).
    let mindRegions: [BodyRegion]
    let context: JourneyContext
    @Binding var selectedBrainRegion: String?
    let onClose: () -> Void

    private var isMind: Bool { regionKey == .head }

    private var month: Int { context.month }

    private var activeRegion: BodyRegion? {
        isMind
            ? mindRegions.first { $0.key == selectedBrainRegion }
            : region
    }

    /// Resolved slot content for whichever region the card is currently showing.
    private var slots: RegionCardSlots {
        RegionCardSlots(
            region: activeRegion,
            context: context,
            mindFallback: isMind && activeRegion == nil
                ? (context.isTestosterone
                    ? TimeBodyRegions.mindInsightT(months: month)
                    : TimeBodyRegions.mindInsight(months: month))
                : nil
        )
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

                Text(slots.now)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, slots.insight == nil && slots.about == nil ? 24 : 18)

                if let insight = slots.insight {
                    Text(insight)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.bottom, slots.about == nil ? 24 : 18)
                }

                if let about = slots.about {
                    aboutSection(about)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
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

                if let phaseLabel = activeRegion?.phaseLabel(at: month) {
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

    // MARK: About (shown only while the region's clock hasn't started)

    private func aboutSection(_ text: String) -> some View {
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

// MARK: - Slot resolution

/// Picks the copy for each card slot from a region and a `JourneyContext`.
///
/// Phase A wiring: NOW draws the banded month fact, INSIGHT draws the region's
/// phase copy, and the two never render the same string. Phase B replaces
/// INSIGHT's source with the mechanism and fact banks and the deterministic
/// month-rotating selector — the slot contract here doesn't change.
struct RegionCardSlots {
    let now: String
    let insight: String?
    let about: String?

    init(region: BodyRegion?, context: JourneyContext, mindFallback: String?) {
        guard let region else {
            now = mindFallback ?? ""
            insight = nil
            about = nil
            return
        }

        let month = context.month
        let banded = region.focusText(at: month)
        let phaseCopy = region.phaseText(at: month)

        now = banded ?? phaseCopy
        // When no band is authored for this month the phase copy has already
        // been spent on NOW; showing it again would be the duplication this
        // restructure exists to remove.
        insight = banded == nil ? nil : phaseCopy
        about = region.phase(at: month) == .pending ? region.overview : nil
    }
}
