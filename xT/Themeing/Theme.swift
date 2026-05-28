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
    static let accentColor = Color(hex: "#D4537E") // Rose - primary accent
    static let secondaryAccentColor = Color(hex: "#534AB7") // Lavender
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

    // Bloom Semantic Colors
    static let bloomMindColor = Color(hex: "#534AB7")      // Purple
    static let bloomSkinColor = Color(hex: "#0F6E56")      // Teal
    static let bloomBodyColor = Color(hex: "#854F0B")      // Amber
    static let bloomCycleColor = Color(hex: "#D4537E")     // Pink
    static let bloomMindLightColor = Color(hex: "#EEEDFE") // Light Purple
    static let bloomSkinLightColor = Color(hex: "#E1F5EE") // Light Teal
    static let bloomBodyLightColor = Color(hex: "#FAEEDA") // Light Amber
    static let bloomCycleLightColor = Color(hex: "#FBEAF0") // Light Pink
    static let bloomMindBorderColor = Color(hex: "#CECBF6") // Purple Border
    static let bloomSkinBorderColor = Color(hex: "#9FE1CB") // Teal Border
    static let bloomBodyBorderColor = Color(hex: "#FAC775") // Amber Border
    static let bloomCycleBorderColor = Color(hex: "#F4C0D1") // Pink Border

    // Background Gradient
    static let globalBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.93, green: 0.57, blue: 0.69), Color(red: 0.69, green: 0.66, blue: 0.92)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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