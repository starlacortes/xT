//
//  SelectableOptionRow.swift
//  xT
//
//  A tappable "title + subtitle + checkmark" option row.
//
//  Eight near-identical copies of this row existed across the app: `typeCard`,
//  `methodCard` and `esterCard` in TypeMethodSettingsView, and `pathCard`, `choiceCard`,
//  `aaCard`, `methodCard` and the `esterList` rows in OnboardingView. They differed only
//  in the bound field. The old `.onAccent` style (Onboarding's brand-gradient era)
//  retired with the paper ground (O1).
//

import SwiftUI

struct SelectableOptionRow: View {

    enum Style {
        /// On paper — every screen since onboarding moved off the brand
        /// gradient (O1). Kept as an enum so a future ground can be added
        /// without reopening every call site.
        case surface
    }

    /// `LocalizedStringResource` (not `String`) so the title localizes (X31).
    /// Callers holding a runtime string (enum raw values) use the
    /// `init(title:…)` convenience below, which treats it as a key — a missing
    /// key renders the literal itself.
    let title: LocalizedStringResource
    /// `LocalizedStringResource?` (not `String?`) so Markdown grammar such as
    /// `^[…](inflect: true)` is parsed. A `String` variable would render
    /// verbatim and leave the inflection marker visible on screen.
    var subtitle: LocalizedStringResource? = nil
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

    // MARK: - Initializers

    /// Designated initializer. Declared explicitly because defining any init in
    /// the body suppresses the synthesized memberwise one.
    init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil,
         isSelected: Bool, style: Style = .surface, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.style = style
        self.action = action
    }

    /// For runtime titles (enum raw values like "Injectable") that can't be
    /// string literals: `LocalizedStringResource(stringLiteral:)` treats the
    /// string as a key, and a missing key renders the literal — so today's
    /// behavior is preserved while literal call sites gain extraction (X31).
    init(title: String, subtitle: LocalizedStringResource? = nil,
         isSelected: Bool, style: Style = .surface, action: @escaping () -> Void) {
        // Hoisted: an inline `LocalizedStringResource(stringLiteral: title)`
        // inside `self.init(…)` resolves against this String init (recursion).
        let resource = LocalizedStringResource(stringLiteral: title)
        self.init(title: resource,
                  subtitle: subtitle, isSelected: isSelected, style: style, action: action)
    }

    // MARK: - Style resolution

    private var titleColor: Color {
        Theme.Colors.textPrimary
    }

    private var subtitleColor: Color {
        Theme.Colors.textSecondary
    }

    private var checkmarkColor: Color {
        Theme.Colors.accent
    }

    private var fill: Color {
        isSelected ? Theme.Colors.accent.opacity(0.1) : Theme.Colors.appBackground
    }

    private var stroke: Color {
        isSelected ? Theme.Colors.accent.opacity(0.3) : .clear
    }
}

#if DEBUG
#Preview("Surface") {
    VStack(spacing: Theme.Spacing.sm) {
        SelectableOptionRow(title: "Injectable", subtitle: "Typical cycle: 7 days",
                            isSelected: true) {}
        SelectableOptionRow(title: "Cream", subtitle: "Applied daily",
                            isSelected: false) {}
    }
    .padding(Theme.Spacing.Gutter.screen)
    .background(Theme.Colors.appBackground)
}
#endif
