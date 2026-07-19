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

    // MARK: - Constants

    private static let parallaxRate: CGFloat = 0.35
    private static let roseBlobSize: CGFloat = 460
    private static let lavenderBlobSize: CGFloat = 420

    var body: some View {
        ZStack {
            // Rose blob — upper leading, echoes the "lower level" end of the
            // graph's color ramp.
            RadialGradient(
                colors: [
                    Theme.Colors.levelLow.opacity(0.30),
                    Theme.Colors.levelLow.opacity(0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 260
            )
            .frame(width: Self.roseBlobSize, height: Self.roseBlobSize)
            .offset(x: -160, y: -190)

            // Lavender blob — upper trailing, echoes the "higher level" end.
            RadialGradient(
                colors: [
                    Theme.Colors.levelHigh.opacity(0.24),
                    Theme.Colors.levelHigh.opacity(0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 240
            )
            .frame(width: Self.lavenderBlobSize, height: Self.lavenderBlobSize)
            .offset(x: 190, y: -70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .offset(y: parallaxOffset)
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.15), value: scrollOffset)
    }

    /// Background drifts at roughly 35% of scroll speed, so it reads as
    /// sitting a little further back than the content in front of it.
    private var parallaxOffset: CGFloat {
        min(0, scrollOffset) * Self.parallaxRate
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        HomeColorBackdrop(scrollOffset: 0)
    }
}