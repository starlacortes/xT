//
//  AccentButton.swift
//  xT
//
//  Full-width primary action button used by the dose-recording flows:
//  white medium-weight headline over the rose accent fill at 80% opacity,
//  16pt vertical padding, Theme's medium corner radius. (The existing
//  `asAccentButton()` modifier is the OnAccent/onboarding variant — full
//  accent fill, large radius — and does not match this style.)
//
//  The disabled state swaps the accent fill for a tertiary fill.
//

import SwiftUI

struct AccentActionButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Theme.Fonts.headline.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(isDisabled ? Color(.tertiarySystemFill) : Theme.Colors.accent.opacity(0.8)))
        }
        .disabled(isDisabled)
    }
}
