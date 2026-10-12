//
//  Motion.swift
//  xT
//
//  Reusable motion building blocks that bring screens to life: a staggered
//  entrance modifier, a tactile button style, an animated count-up number,
//  and directional entrance variants.
//  Everything here honors the Reduce Motion accessibility setting.
//

import SwiftUI

// MARK: - Entrance Direction

enum EntranceDirection {
    case up
    case down
    case leading
    case trailing

    var offset: CGSize {
        switch self {
        case .up:       CGSize(width: 0, height: 16)
        case .down:     CGSize(width: 0, height: -16)
        case .leading:  CGSize(width: -16, height: 0)
        case .trailing: CGSize(width: 16, height: 0)
        }
    }
}

// MARK: - Entrance

/// Fades and lifts a view into place on appear. Stack delays with `.entrance(index:)`
/// to make a column of cards cascade in.
struct EntranceModifier: ViewModifier {
    let delay: Double
    let direction: EntranceDirection
    let scaleOnEntrance: Bool
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : direction.offset.width,
                    y: shown ? 0 : direction.offset.height)
            .scaleEffect(shown ? 1 : (scaleOnEntrance ? 0.92 : 1))
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(Theme.Motion.settle.delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// Animate this view in from below with a fade + lift. Uses the modern
    /// `settle` spring (duration: 0.55, bounce: 0.0) for natural deceleration.
    func entrance(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay, direction: .up, scaleOnEntrance: false))
    }

    /// Animate this view in, staggered by its position in a stack.
    func entrance(index: Int) -> some View {
        modifier(EntranceModifier(delay: Double(index) * Theme.Motion.stagger, direction: .up, scaleOnEntrance: false))
    }

    /// Animate this view in from a specific direction with a spring settle.
    func entrance(delay: Double = 0, from direction: EntranceDirection) -> some View {
        modifier(EntranceModifier(delay: delay, direction: direction, scaleOnEntrance: false))
    }

    /// Animate this view in with a scale+fade — feels like it "grows" into place.
    /// Good for hero elements and overlays that should feel emergent.
    func entranceScale(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay, direction: .up, scaleOnEntrance: true))
    }
}

// MARK: - Pressable

/// Gives buttons a springy press-down with a light haptic — makes taps feel physical.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        PressableLabel(configuration: configuration, scale: scale)
    }

    /// Nested view so the style can react to `accessibilityReduceMotion`
    /// (a `ButtonStyle` struct can't observe `@Environment` directly).
    private struct PressableLabel: View {
        let configuration: ButtonStyleConfiguration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let pressed = configuration.isPressed
            // Reduce Motion: drop the scale choreography, keep only the opacity dim.
            configuration.label
                .scaleEffect(reduceMotion ? 1 : (pressed ? scale : 1))
                .opacity(pressed ? 0.92 : 1)
                .animation(reduceMotion ? nil : Theme.Motion.snappy, value: pressed)
                .onChange(of: pressed) { _, isPressed in
                    if isPressed {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Animated Counter

/// A number that counts up to its value on appear and rolls smoothly when it changes.
struct AnimatedCounter: View {
    let value: Double
    var duration: Double = 0.9
    var format: (Double) -> String = { "\(Int($0.rounded()))" }

    @State private var displayed: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CountingText(value: displayed, format: format)
            .onAppear {
                if reduceMotion {
                    displayed = value
                } else {
                    withAnimation(.easeOut(duration: duration)) { displayed = value }
                }
            }
            .onChange(of: value) { _, newValue in
                if reduceMotion {
                    displayed = newValue
                } else {
                    withAnimation(.easeOut(duration: duration * 0.7)) { displayed = newValue }
                }
            }
    }
}

/// Interpolates its numeric value so the rendered text animates frame by frame.
private struct CountingText: View, Animatable {
    var value: Double
    var format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

// The dose-celebration glow (CelebrationGlowModifier) retired with the Home rebuild
// (X19): the curve morphing into its new point is the celebration, with a success
// haptic, so there is no separate glow modifier to apply.
