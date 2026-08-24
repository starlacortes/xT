import SwiftUI

// MARK: - Region Detail View
//
// Detail card reached by tapping a region on the 3-D body diagram.
// Absorbs RegionInfoPanel and MindInfoPanel — both are superseded by this view.
// Position and entrance are the caller's (`TimeBodyExplorerView`): the card
// is presented in a native sheet in `.stage` framing and slides in from the
// trailing edge in `.profile`.
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

/// Reports the natural height of the card's content (header + slots + their
/// padding) so the caller can set the sheet's expanded detent to fit the text
/// instead of always filling the screen. The background geometry is attached to
/// the padded content stack, which lays out at its ideal height inside the
/// ScrollView regardless of the viewport's height — so the value is stable
/// whether the sheet is at its standard or expanded height.
struct TimeCardContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

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

    /// Height of the soft fade at the card's bottom edge. Kept small so it
    /// reads as a finish on the edge, not a large vignette over the content.
    private let bottomFadeHeight: CGFloat = 28

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
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TimeCardContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
        }
        // Soften the bottom edge so scrolling content dissolves into the card
        // rather than being cut off by a hard line. The mask sits above the
        // glass surface, so only the content fades. A fixed-height fade keeps
        // the effect identical whatever height the sheet resolves to.
        .mask(
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bottomFadeHeight)
            }
        )
        // Palette-tinted glass panel inside the sheet's own liquid glass — the
        // same `.glassEffect` idiom as `Theme.GlassCardModifier`, so the card
        // keeps its Time category identity on the system surface.
        .glassEffect(.regular.tint(palette.base.opacity(0.12)),
                     in: .rect(cornerRadius: Theme.Radius.xl))
        // Screen-edge padding is the caller's: the Time explorer pads the card
        // trailing in `.profile` framing and horizontal+bottom in `.stage`.
        // The Time screen's backdrop is near-black in both appearances, so the
        // panel is a dark surface whatever the system setting is. Without this,
        // Light Mode resolves `.primary` to near-black over dark glass and the
        // glass's own tint to the wrong side of the ground.
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // The icon tile is decorative (accessibilityHidden) and consumes
                // ~50pt of horizontal space the title needs in the narrow
                // `.profile` card, so it only renders in `.stage` framing where
                // the card spans the full width.
                if regionKey.framing == .stage {
                    iconTile
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
                    Text(title)
                        .font(Theme.Fonts.title2.weight(.bold))
                        .tracking(-0.4)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    monthLine
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                // `.stage` cards dismiss by swipe (the sheet's drag indicator
                // hints it), so the explicit close button only remains on the
                // `.profile` (thighs) card, which has no drag-dismiss gesture.
                if regionKey.framing == .profile {
                    closeButton
                }
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
        // The month eyebrow and the phase pill sit side by side in the
        // full-width `.stage` card, but the narrow `.profile` card can't fit
        // both on one line — an HStack there wraps each label character by
        // character. Stack them for `.profile`, and pin every label to a
        // single line so a long phase ("Begins month 9") never breaks apart.
        let layout = regionKey.framing == .profile
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.tiny))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.tiny))

        return layout {
            Text("Month \(month)")
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(palette.base)
                .fixedSize()

            if let phase = activeRegion?.phaseLabel(at: month) {
                Text(phase)
                    .font(Theme.Fonts.pill)
                    .foregroundStyle(palette.text)
                    .fixedSize()
                    .padding(.horizontal, Theme.Spacing.tiny)
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

#Preview("Thighs · month 11") {
    RegionCardPreview(regionKey: .thighs, month: 11)
}
#endif
