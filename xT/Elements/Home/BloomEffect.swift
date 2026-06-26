//
//  BloomEffect.swift
//  xT
//
//  Created by Cline on 6/23/26.
//  Visual bloom effect for task completion feedback
//

import SwiftUI

struct BloomEffect: View {
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    @Binding var trigger: Bool
    let position: CGPoint

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.8),
                            Color.pink.opacity(0.6),
                            Color.purple.opacity(0.6),
                            Color.white.opacity(0.8)
                        ]),
                        center: .center
                    )
                )
                .frame(width: 200, height: 200)
                .opacity(opacity * 0.7)
                .scaleEffect(scale * 1.2)
                .blur(radius: 20)

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.pink.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 150, height: 150)
                .opacity(opacity * 0.9)
                .scaleEffect(scale)

            // Sparkle particles
            ForEach(0..<8) { i in
                SparkleParticle(delay: Double(i) * 0.1)
                    .offset(x: sparkleOffset(i).width, y: sparkleOffset(i).height)
                    .opacity(opacity)
                    .scaleEffect(scale)
            }
        }
        .position(position)
        .onChange(of: trigger) {
            if trigger {
                triggerBloomEffect()
            }
        }
    }

    private func sparkleOffset(_ index: Int) -> CGSize {
        let angle = Double(index) * (.pi * 2) / 8
        let distance = 60 + Double(index % 3) * 20
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }

    private func triggerBloomEffect() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.2
            opacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.5)) {
                scale = 0.5
                opacity = 0
            }
        }
    }
}

struct SparkleParticle: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    let delay: Double

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        scale = 1.0
                        opacity = 1.0
                        rotation = 180
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeIn(duration: 0.3)) {
                            scale = 0
                            opacity = 0
                        }
                    }
                }
            }
    }
}

struct BloomEffectModifier: ViewModifier {
    @Binding var trigger: Bool
    let position: CGPoint

    func body(content: Content) -> some View {
        ZStack {
            content
            BloomEffect(trigger: $trigger, position: position)
        }
    }
}

extension View {
    func bloomEffect(trigger: Binding<Bool>, position: CGPoint) -> some View {
        self.modifier(BloomEffectModifier(trigger: trigger, position: position))
    }
}

#Preview {
    struct BloomEffectPreview: View {
        @State private var trigger = true

        var body: some View {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack {
                    Button("Trigger Bloom") {
                        trigger = true
                    }

                    Text("Tap to see bloom effect")
                        .foregroundStyle(.white)
                }

                // Preview bloom effect
                BloomEffect(trigger: $trigger, position: CGPoint(x: 200, y: 300))
            }
        }
    }

    return BloomEffectPreview()
}
