//
//  HomeColorBackdrop.swift
//  xT
//
//  Soft, parallaxed rose→lavender color wash that sits behind the hero
//  and graph area on Home. Purely decorative — ignores hit testing —
//  and fades out naturally by the time the card stack begins, since the
//  blobs are anchored near the top of the scroll content.
//

import SwiftUI

struct HomeColorBackdrop: View {
    /// Raw scroll offset (minY of the scrolled content in the "homeScroll"
    /// coordinate space). Negative as the user scrolls down.
    var scrollOffset: CGFloat

    var body: some View {
        ZStack {
            // Rose blob — upper leading, echoes the "lower level" end of the
            // graph's color ramp.
            RadialGradient(
                colors: [
                    Theme.Colors.accent.opacity(0.30),
                    Theme.Colors.accent.opacity(0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 260
            )
            .frame(width: 460, height: 460)
            .offset(x: -160, y: -190)

            // Lavender blob — upper trailing, echoes the "higher level" end.
            RadialGradient(
                colors: [
                    Theme.Colors.accentSecondary.opacity(0.24),
                    Theme.Colors.accentSecondary.opacity(0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 240
            )
            .frame(width: 420, height: 420)
            .offset(x: 190, y: -70)
        }
        .offset(y: parallaxOffset)
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.15), value: scrollOffset)
    }

    /// Background drifts at roughly 35% of scroll speed, so it reads as
    /// sitting a little further back than the content in front of it.
    private var parallaxOffset: CGFloat {
        min(0, scrollOffset) * 0.35
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        HomeColorBackdrop(scrollOffset: 0)
    }
}
