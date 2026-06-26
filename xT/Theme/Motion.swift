//
//  Motion.swift
//  xT
//
//  Reusable motion building blocks that bring screens to life: a staggered
//  entrance modifier, a tactile button style, and an animated count-up number.
//  Everything here honors the Reduce Motion accessibility setting.
//

import SwiftUI

// MARK: - Entrance

/// Fades and lifts a view into place on appear. Stack delays with `.entrance(index:)`
/// to make a column of cards cascade in.
struct EntranceModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(Theme.Motion.entrance.delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// Animate this view in with an explicit delay.
    func entrance(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay))
    }

    /// Animate this view in, staggered by its position in a stack.
    func entrance(index: Int) -> some View {
        modifier(EntranceModifier(delay: Double(index) * Theme.Motion.stagger))
    }
}

// MARK: - Pressable

/// Gives buttons a springy press-down with a light haptic — makes taps feel physical.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
