//
//  Theme.swift
//  xT
//
//  Created by Cline on 4/27/2026.
//  Central theme file for consistent styling across the app
//

import SwiftUI

struct Theme {
    // Colors
    static let accentColor = Color("AccentColor")
    static let cardBackground = Color(.systemBackground).opacity(0.8)
    static let glassBackground = Color(.systemBackground).opacity(0.6)
    static let borderColor = Color.white.opacity(0.2)

    // Corner Radii
    static let smallCornerRadius: CGFloat = 12
    static let mediumCornerRadius: CGFloat = 20
    static let largeCornerRadius: CGFloat = 24

    // Semantic Colors
    static let successColor = Color.green
    static let warningColor = Color.orange
    static let errorColor = Color.red
    static let infoColor = Color.blue
    static let secondaryTextColor = Color.secondary
    static let tertiaryTextColor = Color.gray
}

// MARK: - View Modifiers
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.mediumCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                    .stroke(Theme.borderColor, lineWidth: 1)
            )
    }
}

struct AccentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.accentColor)
            .foregroundColor(.white)
            .cornerRadius(Theme.mediumCornerRadius)
    }
}

// MARK: - Extensions for Easy Use
extension View {
    func asGlassCard() -> some View {
        self.modifier(GlassCardModifier())
    }

    func asAccentButton() -> some View {
        self.modifier(AccentButtonModifier())
    }
}