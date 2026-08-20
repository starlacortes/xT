//
//  HairlineDivider.swift
//  xT
//
//  One parameterized hairline separator: Theme border at given opacity,
//  0.5pt tall (the Theme hairline width) by default.
//

import SwiftUI

struct HairlineDivider: View {
    var color: Color = Theme.Colors.border
    var opacity: Double = 0.35
    var height: CGFloat = Theme.Colors.hairlineWidth

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(height: height)
    }
}
