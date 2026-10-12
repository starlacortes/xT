//
//  ActionPill.swift
//  xT
//
//  The one filled control in the Isocline system (element S4): an accent-filled
//  capsule carrying `OnAccent` text. Everything else is a hairline. Two variants:
//
//    • `.inline`   — full-width primary action inside a card or form (Log Dose, Save)
//    • `.floating` — content-hugging pill that rests on the floating fade (New entry, J8)
//
//  Depth reads from the fill alone — no shadow (F10). Press feedback comes from
//  `.pressable`, which honours Reduce Motion (F6).
//
//  Supersedes `AccentActionButton` / `asAccentButton`; those remain during the
//  transition and migrate to `ActionPill` with each screen rebuild (Tier 4).
//

import SwiftUI

struct ActionPill: View {

    enum Variant {
        /// Full-width primary action.
        case inline
        /// Content-hugging floating pill.
        case floating
    }

    let title: LocalizedStringKey
    var systemImage: String? = nil
    var variant: Variant = .inline
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.tiny) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Theme.Fonts.headline.weight(.medium))
            .foregroundStyle(isDisabled ? Theme.Colors.OnAccent.disabled : Theme.Colors.OnAccent.primary)
            .frame(maxWidth: variant == .inline ? .infinity : nil)
            .padding(.vertical, variant == .inline ? Theme.Spacing.lg : Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.xl)
            .background(
                Capsule().fill(isDisabled ? Theme.Colors.neutralSurface : Theme.Colors.accent)
            )
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: Theme.Spacing.xl) {
        ActionPill(title: "Log Dose", systemImage: "syringe") {}
        ActionPill(title: "Save", isDisabled: true) {}
        ActionPill(title: "New entry", systemImage: "plus", variant: .floating) {}
    }
    .padding(Theme.Spacing.Gutter.screen)
    .background(Theme.Colors.appBackground)
}
#endif
