//
//  SelectableOptionRow.swift
//  xT
//
//  A tappable "title + subtitle + checkmark" option row.
//
//  Eight near-identical copies of this row existed across the app: `typeCard`,
//  `methodCard` and `esterCard` in TypeMethodSettingsView, and `pathCard`, `choiceCard`,
//  `aaCard`, `methodCard` and the `esterList` rows in OnboardingView. They differed only
//  in the bound field and — for Onboarding, which sits on the brand gradient — the
//  surface treatment. Both treatments are available here via `Style`.
//

import SwiftUI

struct SelectableOptionRow: View {

    enum Style {
        /// On a standard system background — Settings and other opaque screens.
        case surface
        /// On the brand gradient — the Onboarding flow.
        case onAccent
    }

    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var style: Style = .surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.card) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(titleColor)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Theme.Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Fonts.icon)
                        .foregroundStyle(checkmarkColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Style resolution

    private var titleColor: Color {
        switch style {
        case .surface:  return Theme.Colors.textPrimary
        case .onAccent: return Theme.Colors.OnAccent.primary
        }
    }

    private var subtitleColor: Color {
        switch style {
        case .surface:  return Theme.Colors.textSecondary
        case .onAccent: return Theme.Colors.OnAccent.tertiary
        }
    }

    private var checkmarkColor: Color {
        switch style {
        case .surface:  return Theme.Colors.accent
        case .onAccent: return Theme.Colors.OnAccent.primary
        }
    }

    private var fill: Color {
        switch style {
        case .surface:
            return isSelected ? Theme.Colors.accent.opacity(0.1) : Color(.systemBackground)
        case .onAccent:
            return Theme.Colors.OnAccent.fill.opacity(isSelected ? 1.6 : 1)
        }
    }

    private var stroke: Color {
        switch style {
        case .surface:
            return isSelected ? Theme.Colors.accent.opacity(0.3) : .clear
        case .onAccent:
            return isSelected ? Theme.Colors.OnAccent.strokeSelected : Theme.Colors.OnAccent.stroke
        }
    }
}

#Preview("Surface") {
    VStack(spacing: Theme.Spacing.sm) {
        SelectableOptionRow(title: "Injectable", subtitle: "Typical cycle: 7 days",
                            isSelected: true) {}
        SelectableOptionRow(title: "Cream", subtitle: "Applied daily",
                            isSelected: false) {}
    }
    .padding(Theme.Spacing.Gutter.screen)
    .background(Color(.secondarySystemBackground))
}

#Preview("On accent") {
    VStack(spacing: Theme.Spacing.sm) {
        SelectableOptionRow(title: "Estrogen", subtitle: "Feminizing HRT",
                            isSelected: true, style: .onAccent) {}
        SelectableOptionRow(title: "Testosterone", subtitle: "Masculinizing HRT",
                            isSelected: false, style: .onAccent) {}
    }
    .padding(Theme.Spacing.Gutter.onboarding)
    .background(Theme.Gradients.brand)
}
