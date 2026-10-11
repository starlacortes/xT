//
//  OnboardingView+Components.swift
//  xT
//
//  Shared card, button, stepper, and photo-button builders used by the onboarding steps.
//  (Split from OnboardingView.swift — same `OnboardingView`, different file.)
//

import SwiftUI

extension OnboardingView {

    // MARK: - Card Components
    func pathCard(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(Theme.Fonts.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    func choiceCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    func aaCard(title: String, subtitle: String, choice: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { antiAndrogenChoice = choice }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(Theme.Fonts.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Spacer()
                    if antiAndrogenChoice == choice {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(antiAndrogenChoice == choice ? Theme.Colors.Time.skin.base.opacity(0.25) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(antiAndrogenChoice == choice ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    func reviewRow(label: String, value: String) -> some View {
        Group {
            HStack {
                Text(label)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                Spacer()
                Text(value)
                    .font(Theme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
                .overlay(Theme.Colors.OnAccent.primary.opacity(0.1))
                .padding(.leading, 16)
        }
    }

    // MARK: - Buttons
    func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.headline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.OnAccent.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(disabled ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.accent.opacity(0.8))
                        .shadow(color: disabled ? .clear : Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                )
        }
        .disabled(disabled)
    }

    func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }

    /// `text` is built by the caller rather than assembled from a noun parameter:
    /// automatic grammar agreement needs the noun as a literal in the pattern, so
    /// "^[\(n) \(noun)](inflect: true)" cannot inflect and would read "1 Years".
    func durationStepper(text: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 8) {
            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(Theme.Colors.OnAccent.primary)
            Text(text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1))
    }

    func photoBtn(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
                Text(label)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
            }
            .frame(width: 70, height: 70)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
        }
    }
}
