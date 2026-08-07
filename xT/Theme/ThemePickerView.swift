//
//  ThemePickerView.swift
//  xT
//
//  Shared by the onboarding theme step and Settings → Appearance. A custom
//  hue "band" doubles as both the control and its own preview: the capsule
//  track is filled with the actual OKLCH hue sweep (same L/C as the accent
//  recipe), so there's no separate swatch needed to show what a hue looks
//  like — dragging the thumb along the band already shows it. A plain
//  `DragGesture` drives it rather than `Slider`, so `accessibilityValue` /
//  `accessibilityAdjustableAction` below are load-bearing, not decorative —
//  they're what stands in for `Slider`'s built-in VoiceOver support.
//  Persistence is debounced to drag-end via `commitSeedHue()`.
//
//  The preview cluster below is deliberately self-contained (an accent
//  button, two Time cards) rather than including "chrome" text of its own —
//  those elements already guarantee their own contrast via `ThemePalette`'s
//  repair pass, so they read correctly regardless of what page background
//  this view is dropped onto (the colorful onboarding gradient vs. a plain
//  Settings background). The caller supplies its own title/subtitle text
//  in whatever color suits its own background. Its outlined container uses
//  `cardSurface`/`border` — not `OnAccent` — for the same reason: those
//  tokens are calibrated for content sitting on the brand gradient
//  specifically, while this box has to read correctly on *either* background.
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var isDragging = false

    private let bandHeight: CGFloat = 56
    private let thumbSize: CGFloat = 34

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            previewCluster
            hueBand
        }
    }

    // MARK: - Preview

    /// A little "set" of mock app controls, framed like a product shot so it
    /// reads as a group rather than loose elements floating in the picker.
    private var previewCluster: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                timeSwatch(label: "Mind", palette: Theme.Colors.Time.mind)
                timeSwatch(label: "Cycle", palette: Theme.Colors.Time.cycle)
                timeSwatch(label: "Body", palette: Theme.Colors.Time.body)
            }

            // Tappable but inert — this is a swatch of what a button looks
            // like in the app's chosen color, not a real action.
            Button(action: {}) {
                Text("xT")
                    .asAccentButton()
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(Theme.Colors.border, lineWidth: Theme.Colors.hairlineWidth)
        )
        .animation(Theme.Motion.instant, value: themeManager.seedHue)
    }

    private func timeSwatch(label: String, palette: Theme.Colors.TimePalette) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(palette.base)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(palette.text)
        }
        .padding(.horizontal, Theme.Spacing.row)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .timeCard(palette)
    }

    // MARK: - Hue band

    private var hueBand: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            Capsule()
                .fill(Self.hueBandGradient)
                .overlay(
                    Capsule().strokeBorder(Theme.Colors.border, lineWidth: Theme.Colors.hairlineWidth)
                )
                .overlay(alignment: .topLeading) {
                    thumb
                        .position(x: thumbX(trackWidth: trackWidth), y: bandHeight / 2)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(trackWidth: trackWidth))
        }
        .frame(height: bandHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Theme hue")
        .accessibilityValue("\(Int(themeManager.seedHue.rounded())) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: themeManager.seedHue = min(360, themeManager.seedHue + 10)
            case .decrement: themeManager.seedHue = max(0, themeManager.seedHue - 10)
            default: break
            }
            themeManager.commitSeedHue()
        }
    }

    private func dragGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging { withAnimation(Theme.Motion.instant) { isDragging = true } }
                let fraction = min(max(value.location.x / trackWidth, 0), 1)
                themeManager.seedHue = fraction * 360
            }
            .onEnded { _ in
                withAnimation(Theme.Motion.instant) { isDragging = false }
                themeManager.commitSeedHue()
            }
    }

    /// A plain white knob (not an `OnAccent` token) is deliberate — unlike
    /// the preview cluster, this rides directly on top of every hue in the
    /// band as it drags, so it needs to stay visible against all of them
    /// rather than being tuned for one background.
    private var thumb: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: thumbSize, height: thumbSize)
                .themeShadow(Theme.Shadows.floating)
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: thumbSize - 10, height: thumbSize - 10)
        }
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .animation(Theme.Motion.pop, value: isDragging)
    }

    private func thumbX(trackWidth: CGFloat) -> CGFloat {
        let fraction = themeManager.seedHue / 360
        return max(thumbSize / 2, min(trackWidth - thumbSize / 2, fraction * trackWidth))
    }

    /// The full selectable hue sweep at the accent recipe's light L/C
    /// (`accentRecipe` in `ThemeManager.swift`), gamut-clamped per stop —
    /// this is what makes the band itself the color preview. Independent of
    /// `seedHue`, so it's built once rather than recomputed per drag tick.
    private static let hueBandGradient: LinearGradient = {
        let stopCount = 36
        let stops = (0...stopCount).map { i -> Gradient.Stop in
            let hue = Double(i) / Double(stopCount) * 360
            let lch = ThemeEngine.clampToGamut(ThemeEngine.OKLCH(L: 0.6225, C: 0.1666, H: hue))
            return Gradient.Stop(color: ThemeEngine.srgb(fromOKLCH: lch), location: Double(i) / Double(stopCount))
        }
        return LinearGradient(gradient: Gradient(stops: stops), startPoint: .leading, endPoint: .trailing)
    }()
}

#if DEBUG
#Preview {
    ThemePickerView()
        .padding()
        .environment(\.themeManager, ThemeManager.shared)
}
#endif
