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
// The card is dated. Everything above NEXT is a claim about this month, and the
// month is stated in the header rather than left to the screen behind the panel
// — see §12. That is what makes month 11 legible as a different card from month
// 10 in the common case where the two share a NOW band and differ only in the
// insight underneath it.
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

    /// Category palette. The mind reads in its own hue; every body region shares
    /// the body hue, so moving between them doesn't recolour the whole panel.
    private var palette: Theme.Colors.TimePalette {
        isMind ? Theme.Colors.Time.mind : Theme.Colors.Time.body
    }

    /// The name of what the card is actually describing. Selecting a brain chip
    /// changes the subject, so the title has to follow it — it used to stay on
    /// "Mind" while every word underneath was about the hippocampus.
    private var title: String {
        isMind ? (activeRegion?.label ?? regionKey.title) : regionKey.title
    }

    private var icon: String {
        activeRegion?.icon ?? "brain.head.profile"
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
            // One spacing value between slots. The prose block sets its own,
            // tighter, internal spacing — that difference is what groups NOW
            // and INSIGHT into a single passage.
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header

                if isMind {
                    brainChipRow
                }

                prose

                if let next = slots.next {
                    nextSection(next)
                }

                if let about = slots.about {
                    aboutSection(about)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(palette.border.opacity(0.35), lineWidth: Theme.Colors.hairlineWidth)
        )
        .padding(.trailing, Theme.Spacing.md)
        // The Time screen's backdrop is near-black in both appearances, so the
        // panel is a dark surface whatever the system setting is. Without this,
        // Light Mode resolves `.primary` to near-black over a dark blur and the
        // material's own tint to the wrong side of the ground.
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                iconTile

                VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
                    Text(title)
                        .font(Theme.Fonts.title2.weight(.bold))
                        .tracking(-0.4)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    monthLine
                }

                Spacer(minLength: Theme.Spacing.sm)

                closeButton
            }

            rule
        }
    }

    private var iconTile: some View {
        Image(systemName: icon)
            .font(Theme.Fonts.icon)
            .foregroundStyle(palette.base)
            .frame(width: 38, height: 38)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .stroke(palette.border.opacity(0.5), lineWidth: Theme.Colors.hairlineWidth)
            )
            .accessibilityHidden(true)
    }

    /// Month first, phase second, both present-tense. The phase pill carries the
    /// region's own clock — "Developing", "Begins month 9" — never a position
    /// relative to a peak.
    private var monthLine: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("Month \(month)")
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.base)

            if let phase = activeRegion?.phaseLabel(at: month) {
                Text(phase)
                    .font(Theme.Fonts.pill)
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(palette.surface, in: Capsule())
                    .overlay(
                        Capsule().stroke(palette.border.opacity(0.6),
                                         lineWidth: Theme.Colors.hairlineWidth)
                    )
            }
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.border.opacity(0.4))
            .frame(height: Theme.Colors.hairlineWidth)
    }

    // MARK: Brain sub-region chips (mind only)

    private var brainChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(mindRegions) { r in
                    let isSelected = (selectedBrainRegion == r.key)
                    Button {
                        withAnimation(Theme.Motion.quick) {
                            selectedBrainRegion = isSelected ? nil : r.key
                        }
                    } label: {
                        Text(r.label)
                            .font(Theme.Fonts.detail)
                            .foregroundStyle(isSelected ? palette.text : Color.primary.opacity(0.75))
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 7)
                            .background(isSelected ? palette.surface : Color.primary.opacity(0.07),
                                        in: Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? palette.border : Color.clear,
                                                 lineWidth: Theme.Colors.hairlineWidth)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            // The chip strokes sit on the stack's edge; without this they clip.
            .padding(.vertical, 1)
        }
    }

    // MARK: Prose (NOW + INSIGHT)

    /// NOW and INSIGHT set as two paragraphs of one passage — same face, same
    /// size, same weight, same colour, and a tighter gap between them than the
    /// gap that separates either from anything else on the card.
    ///
    /// The insight is not a callout, a footnote or a "did you know". On a month
    /// where the tissue copy is unchanged from last month, it is the part that
    /// moved, and it only reads that way if it reads as ordinary text.
    private var prose: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            paragraph(slots.now)

            if let insight = slots.insight {
                paragraph(insight)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.body)
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Next (shown when a named landmark is within two years)

    /// The only forward-looking slot, and deliberately the quietest thing on the
    /// card. The rule above it marks a change of kind: everything higher up is
    /// true now, and this is where the median lands.
    private func nextSection(_ marker: RegionMarker) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            rule
                .padding(.bottom, Theme.Spacing.sm)

            Text("Next")
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.base)

            Text(marker.name)
                .font(Theme.Fonts.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(marker.note)
                .font(Theme.Fonts.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: About (shown only while the region's clock hasn't started)

    private func aboutSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            Text("About this region")
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.base)

            Text(text)
                .font(Theme.Fonts.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .stroke(palette.border.opacity(0.4), lineWidth: Theme.Colors.hairlineWidth)
        )
        .accessibilityElement(children: .combine)
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

// MARK: - Preview

#if DEBUG
private struct RegionCardPreview: View {
    let regionKey: TimeRegionKey
    let month: Int
    @State private var brainRegion: String?

    init(regionKey: TimeRegionKey, month: Int, brainRegion: String? = nil) {
        self.regionKey = regionKey
        self.month = month
        _brainRegion = State(initialValue: brainRegion)
    }

    var body: some View {
        ZStack {
            NightSkyBackdrop()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                TimeRegionDetailView(
                    regionKey: regionKey,
                    region: regionKey.bodyRegionKey.flatMap { key in
                        TimeBodyRegions.bodyRegions.first { $0.key == key }
                    },
                    mindRegions: TimeBodyRegions.mindRegions,
                    context: JourneyContext(track: .estrogen, month: month),
                    selectedBrainRegion: $brainRegion,
                    onClose: {}
                )
                .frame(width: 320)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

#Preview("Chest · month 11") {
    RegionCardPreview(regionKey: .chest, month: 11)
}

#Preview("Chest · month 84") {
    RegionCardPreview(regionKey: .chest, month: 84)
}

#Preview("Mind · hippocampus") {
    RegionCardPreview(regionKey: .head, month: 11, brainRegion: "hippocampus")
}
#endif
