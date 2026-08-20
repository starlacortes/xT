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
//   NEXT     conditional the next named landmark, when one is within two years
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
            // One spacing value for the whole stack. The slots are conditional,
            // so per-slot bottom padding would need a branch per combination.
            VStack(alignment: .leading, spacing: 18) {
                headerRow

                if isMind {
                    brainChipRow
                }

                slotText(slots.now)

                if let insight = slots.insight {
                    slotText(insight)
                }

                if let next = slots.next {
                    nextSection(next)
                }

                if let about = slots.about {
                    aboutSection(about)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
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

    // MARK: Slot body copy

    /// NOW and INSIGHT render identically. That is the point: the second is not
    /// an aside, a callout or a footnote, it is the card's normal content for a
    /// month when the progression line has not moved.
    private func slotText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Next (shown when a named landmark is within two years)

    private func nextSection(_ marker: RegionMarker) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(marker.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            slotText(marker.note)
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
/// NOW comes from the region's own band grid, re-cut in Phase C so band width
/// tracks the region's clock rather than the calendar — a month wide where it
/// is moving fastest, a year wide where it is being maintained. Bands start at
/// `startMonth`, so a region whose clock hasn't started falls through to the
/// pending sentence and shows ABOUT instead.
///
/// INSIGHT comes from the region's insight bank and rotates every month. That
/// is what makes month 11 differ from month 10 while NOW holds still. It draws
/// the mechanism behind the change while the region is moving and a fact about
/// the region when it isn't — `ChangeRate` picks, and either bank answers if
/// the other has nothing eligible for this month.
///
/// NEXT is the only forward-looking slot, and it renders only when a named
/// landmark falls inside the horizon. ABOUT is the region's overview, and it
/// earns the space only while the region's clock has not started.
struct RegionCardSlots {
    let now: String
    let insight: String?
    let next: RegionMarker?
    let about: String?

    init(region: BodyRegion?, context: JourneyContext, mindFallback: String?) {
        guard let region else {
            now = mindFallback ?? ""
            insight = nil
            next = nil
            about = nil
            return
        }

        let month = context.month
        let phase = region.phase(at: month)

        now = region.focusText(at: month) ?? region.pendingText
        insight = TimeRegionInsights.insight(
            track: context.track,
            key: region.key,
            month: month,
            rate: region.changeRate(at: month)
        )
        next = TimeRegionMarkers.next(
            track: context.track,
            key: region.key,
            month: month,
            phase: phase
        )
        about = phase == .pending ? region.overview : nil
    }
}
