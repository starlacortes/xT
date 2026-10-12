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
//  Tier 4d (ST8): the old swatch cluster is replaced by `ThemeSpecimenView`
//  — a miniature window of real app chrome over sample data — plus a
//  Day/Night preview pair, quick stops from `Theme.Seed.stops`, and a mono
//  readout row. The readout and reset live in the host screens; the picker
//  owns the specimen, the day/night pills, the band and the stops.
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var isDragging = false
    @State private var previewScheme: ColorScheme = .light

    private let bandHeight: CGFloat = 56
    private let thumbSize: CGFloat = 34

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            specimenBlock
            hueBand
            quickStops
        }
    }

    // MARK: - Specimen + Day/Night (ST8)

    private var specimenBlock: some View {
        VStack(spacing: Theme.Spacing.md) {
            ThemeSpecimenView(preview: previewScheme)

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    withAnimation(Theme.Motion.instant) { previewScheme = .light }
                } label: {
                    Pill(text: "Day", style: previewScheme == .light ? .active : .neutral)
                }
                .buttonStyle(.pressable)

                Button {
                    withAnimation(Theme.Motion.instant) { previewScheme = .dark }
                } label: {
                    Pill(text: "Night", style: previewScheme == .dark ? .active : .neutral)
                }
                .buttonStyle(.pressable)
            }
        }
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

    /// Paper knob with an ink hairline and an accent core (ST8): it rides on
    /// top of every hue in the band as it drags, so the paper ring keeps it
    /// visible against all of them.
    private var thumb: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.cardSurface)
                .frame(width: thumbSize, height: thumbSize)
            Circle()
                .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                .frame(width: thumbSize, height: thumbSize)
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

    // MARK: - Quick stops (ST8)

    /// Eight circles at the shared `seed.stops` hues — the same list the
    /// alternate icons use (I2). Tapping snaps the hue; the nearest stop
    /// shows the accent ring.
    private var quickStops: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ForEach(Theme.Seed.stops, id: \.self) { stop in
                Button {
                    themeManager.seedHue = stop
                    themeManager.commitSeedHue()
                } label: {
                    Circle()
                        .fill(accentColor(hue: stop))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().strokeBorder(
                                isNearestStop(stop) ? Theme.Colors.accent : Theme.Colors.border,
                                lineWidth: isNearestStop(stop) ? 2 : Theme.Line.hairline
                            )
                            .frame(width: 34, height: 34)
                        )
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("\(Int(stop.rounded())) degrees")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func isNearestStop(_ stop: Double) -> Bool {
        // Circular distance — 350° and 10° are neighbours.
        let delta = abs(themeManager.seedHue - stop)
        let distance = min(delta, 360 - delta)
        return distance <= 22.5 // half a stop step
    }

    private func accentColor(hue: Double) -> Color {
        let lch = ThemeEngine.clampToGamut(ThemeEngine.OKLCH(L: 0.6225, C: 0.1666, H: hue))
        return ThemeEngine.srgb(fromOKLCH: lch)
    }
}

#if DEBUG
#Preview {
    ThemePickerView()
        .padding()
        .environment(\.themeManager, ThemeManager.shared)
}
#endif
