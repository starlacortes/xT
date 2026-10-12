//
//  IsoclineMarkView.swift
//  xT
//
//  The mark renderings (element S9), drawn over F7's fixed outlines. The logo's
//  shape never changes — only how it's rendered:
//
//    • ink       solid fill (ink by default, or a caller-supplied color)
//    • hairline  stroke-only engraving at `Theme.Line.engrave`
//    • emboss    inkless relief (after Omar Rayo's intaglios): paper on paper,
//                read only through a light edge and a shadow edge
//
//  Under Reduce Transparency, emboss falls back to hairline (the relief reads
//  entirely through its translucent edges, so it can't survive the setting).
//
//  Uses: lock screen (O2), onboarding welcome (O1), About/Acknowledgements
//  header, the stealth icon artwork (I3).
//

import SwiftUI

struct IsoclineMarkView: View {

    enum Mark {
        /// The "I." mark.
        case mark
        /// The full "ISOCLINE" wordmark.
        case wordmark
    }

    enum Rendering {
        /// Solid fill.
        case ink
        /// Stroke-only engraving.
        case hairline
        /// Paper-on-paper relief. Reduce Transparency falls back to hairline.
        case emboss
    }

    let mark: Mark
    var rendering: Rendering = .ink
    /// Fill/stroke color for ink and hairline. Ignored by emboss, which is
    /// paper on paper by definition.
    var color: Color = Theme.Colors.textPrimary

    var body: some View {
        // Emboss draws two offset copies of the shape; its offsets are a
        // fraction of the drawing size, so they must know the laid-out frame.
        GeometryReader { geo in
            embossBody(in: geo.size)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Pieces

    private var shape: some Shape {
        mark == .mark ? AnyShape(IsoclineMark()) : AnyShape(IsoclineWordmark())
    }

    /// The master aspect ratio (width / height), from the viewBoxes F7 emits.
    private var aspect: CGFloat {
        let vb = mark == .mark ? IsoclineMarkPaths.markViewBox : IsoclineMarkPaths.wordmarkViewBox
        return vb.width / vb.height
    }

    private var effectiveRendering: Rendering {
        if rendering == .emboss, reduceTransparency { return .hairline }
        return rendering
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: - Emboss

    /// Paper on paper, read only through its edges: a light copy offset up-left
    /// (white at .85), a dark copy offset down-right (ink at .16), and the paper
    /// face on top — the same three-pass recipe as `build_isocline_marks.py`
    /// and the SVG masters, with `logo.emboss.depthRatio` (1.2% of width)
    /// resolving to the point-scale offset.
    @ViewBuilder
    private func embossBody(in size: CGSize) -> some View {
        if effectiveRendering == .emboss {
            let depth = size.width * 0.012
            ZStack {
                shape
                    .fill(Color.white.opacity(0.85))
                    .offset(x: -depth, y: -depth)
                shape
                    .fill(Theme.Colors.textPrimary.opacity(0.16))
                    .offset(x: depth, y: depth)
                shape
                    .fill(Theme.Colors.appBackground)
            }
        } else {
            renderFlat(effectiveRendering)
        }
    }

    @ViewBuilder
    private func renderFlat(_ r: Rendering) -> some View {
        switch r {
        case .ink:
            shape.fill(color)
        case .hairline:
            shape.stroke(color, lineWidth: Theme.Line.engrave)
        case .emboss:
            EmptyView() // unreachable — effectiveRendering never passes .emboss here
        }
    }
}

#if DEBUG
#Preview("Mark renderings") {
    VStack(spacing: Theme.Spacing.section) {
        HStack(spacing: Theme.Spacing.xxl) {
            IsoclineMarkView(mark: .mark, rendering: .ink)
                .frame(width: 72)
            IsoclineMarkView(mark: .mark, rendering: .hairline)
                .frame(width: 72)
            IsoclineMarkView(mark: .mark, rendering: .emboss)
                .frame(width: 72)
        }
        IsoclineMarkView(mark: .wordmark, rendering: .ink)
            .frame(maxWidth: 280)
    }
    .padding(Theme.Spacing.section)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.appBackground)
}

#Preview("On night paper") {
    IsoclineMarkView(mark: .mark, rendering: .emboss)
        .frame(width: 120)
        .padding(Theme.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.appBackground)
        .environment(\.colorScheme, .dark)
}
#endif
