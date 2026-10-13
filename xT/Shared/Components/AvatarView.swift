//
//  AvatarView.swift
//  xT
//
//  The profile avatar (element S8). Flush on the paper — "what is", never a card.
//
//  Draws the placeholder in SwiftUI (an accent disc with a `person.fill` glyph in
//  `OnAccent`) so it tracks the chosen hue live, replacing `ProfileManager`'s static
//  200×200 `renderPlaceholder` UIImage. The ring is a single `Theme.Line.hairline`
//  in the `line` ink-alpha — no 2/3 pt rings, no gradient ring, no shadow (ST2).
//
//  Four canonical sizes are named so call sites read intent rather than magic
//  numbers: a settings row (56), a header (72), the centered Settings hero (88),
//  the editor (112).
//

import SwiftUI

struct AvatarView: View {
    /// The user's own photo, if chosen. `nil` draws the live-hue placeholder.
    let image: UIImage?
    /// Diameter in points. Use `AvatarView.Size` for the canonical sizes.
    var size: CGFloat = Size.row

    enum Size {
        static let row: CGFloat = 56
        static let header: CGFloat = 72
        static let settingsHero: CGFloat = 88
        static let editor: CGFloat = 112
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
        )
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Theme.Colors.accent)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.46))
                .foregroundStyle(Theme.Colors.OnAccent.primary)
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: Theme.Spacing.lg) {
        AvatarView(image: nil, size: AvatarView.Size.row)
        AvatarView(image: nil, size: AvatarView.Size.header)
        AvatarView(image: nil, size: AvatarView.Size.editor)
    }
    .padding(Theme.Spacing.Gutter.screen)
    .background(Theme.Colors.appBackground)
}
#endif
