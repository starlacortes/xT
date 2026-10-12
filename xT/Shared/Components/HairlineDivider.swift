//
//  HairlineDivider.swift
//  xT
//
//  The Isocline `line` separator (element S3): the `line` ink-alpha at
//  `Theme.Line.hairline`, with an optional leading `inset` so rows can indent the
//  divider past their glyph (J4). Replaces `Divider().opacity(0.5)` everywhere.
//

import SwiftUI

struct HairlineDivider: View {
    /// Leading inset — indents the divider past a row's leading glyph (S3, J4).
    var inset: CGFloat = 0
    var color: Color = Theme.Colors.border
    /// Legacy alpha knob. The Isocline `line` color already carries its own alpha,
    /// so new call sites leave this at 1; older callers may still dim it.
    var opacity: Double = 1
    var height: CGFloat = Theme.Line.hairline

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(height: height)
            .padding(.leading, inset)
    }
}
