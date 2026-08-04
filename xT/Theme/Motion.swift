//
//  Motion.swift
//  xT
//
//  Reusable motion building blocks that bring screens to life: a staggered
//  entrance modifier, a tactile button style, an animated count-up number,
//  a celebration glow modifier, and directional entrance variants.
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

// MARK: - Celebration Glow

/// A subtle pulse-glow that plays when a celebratory event occurs.
/// Uses PhaseAnimator (iOS 17+) for a multi-phase bloom → settle effect.
///
/// Usage:
/// ```swift
/// YourView()
///     .celebrationGlow(trigger: celebrationCount, color: .accent)
/// ```
struct CelebrationGlowModifier: ViewModifier {
    let trigger: Int
    let color: Color

    func body(content: Content) -> some View {
        content
            .phaseAnimator(CelebrationPhase.allCases, trigger: trigger) { content, phase in
                content
                    .scaleEffect(phase.scale)
                    .shadow(color: color.opacity(phase.glowOpacity),
                            radius: phase.glowRadius)
            } animation: { phase in
                switch phase {
                case .idle:    Theme.Motion.instant
                case .bloom:   Animation.spring(duration: 0.35, bounce: 0.2)
                case .settle:  Theme.Motion.settle
                }
            }
    }
}

private enum CelebrationPhase: CaseIterable {
    case idle
    case bloom
    case settle

    var scale: CGFloat {
        switch self {
        case .idle:   1.0
        case .bloom:  1.08
        case .settle: 1.0
        }
    }

    var glowOpacity: CGFloat {
        switch self {
        case .idle:   0
        case .bloom:  0.35
        case .settle: 0
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .idle:   0
        case .bloom:  24
        case .settle: 0
        }
    }
}

extension View {
    /// Apply a celebratory glow pulse triggered by `trigger` value changes.
    /// Uses PhaseAnimator for a bloom → settle effect.
    func celebrationGlow(trigger: Int, color: Color = Theme.Colors.accent) -> some View {
        modifier(CelebrationGlowModifier(trigger: trigger, color: color))
    }
}
