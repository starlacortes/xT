//
//  OnboardingView+Components.swift
//  xT
//
//  Shared card, button, stepper, and photo-button builders used by the onboarding steps.
//  (Split from OnboardingView.swift — same `OnboardingView`, different file.)
//
//  Onboarding sits on paper (O1): cards are ghost slots (hairline, no fill —
//  the page is the card), the selected state reads from an accent border and
//  checkmark, and the primary action is `ActionPill`.
//

import SwiftUI

extension OnboardingView {

    // MARK: - Card Components

    func pathCard(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SelectableOptionRow(title: title, subtitle: LocalizedStringResource(stringLiteral: subtitle),
                            isSelected: isSelected, action: action)
    }

    func choiceCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SelectableOptionRow(title: title, isSelected: isSelected, action: action)
    }

    func aaCard(title: String, subtitle: String, choice: String) -> some View {
        SelectableOptionRow(title: title, subtitle: LocalizedStringResource(stringLiteral: subtitle),
                            isSelected: antiAndrogenChoice == choice) {
            withAnimation(Theme.Motion.quick) { antiAndrogenChoice = choice }
        }
    }

    func reviewRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(value)
                    .font(Theme.Fonts.detail.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, Theme.Spacing.card)
            .padding(.vertical, Theme.Spacing.md)
            HairlineDivider()
        }
    }

    // MARK: - Buttons

    /// The primary action: an accent `ActionPill` (O1 step 5).
    func primaryButton(_ title: LocalizedStringKey, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        ActionPill(title: title, isDisabled: disabled, action: action)
    }

    /// The back / skip affordance: plain muted text, no fill.
    func secondaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
        }
        .buttonStyle(.plain)
    }

    /// `text` is built by the caller rather than assembled from a noun parameter:
    /// automatic grammar agreement needs the noun as a literal in the pattern, so
    /// "^[\(n) \(noun)](inflect: true)" cannot inflect and would read "1 Years".
    func durationStepper(text: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(Theme.Colors.accent)
            Text(text)
                .font(Theme.Fonts.numeric)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .ghostCard(radius: Theme.Radius.sm)
    }

    func photoBtn(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(Theme.Fonts.icon)
                    .imageScale(.large)
                    .foregroundStyle(Theme.Colors.accent)
                Text(label)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.accent.opacity(0.13))
            )
        }
        .buttonStyle(.plain)
    }
}
