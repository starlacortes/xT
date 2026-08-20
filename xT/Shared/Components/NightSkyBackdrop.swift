//
//  NightSkyBackdrop.swift
//  xT
//
//  Near-black "space" backdrop, faintly hued toward the user's theme accent —
//  constant in both appearances so the constellation starfield always sits on
//  a night sky. Used by the Time screen and its body explorer.
//

import SwiftUI

struct NightSkyBackdrop: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ZStack {
            Color.black
            themeManager.palette.accent.opacity(0.07)
        }
    }
}
