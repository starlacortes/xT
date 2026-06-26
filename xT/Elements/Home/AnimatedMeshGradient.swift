//
//  AnimatedMeshGradient.swift
//  xT
//
//  Created by Cline on 6/23/26.
//  Fluid, animated mesh gradient background
//

import SwiftUI

struct AnimatedMeshGradient: View {
    @State private var phase: CGFloat = 0
    @State private var scale: CGFloat = 1.0

    let colors: [Color]
    let duration: Double

    init(colors: [Color] = Theme.Gradients.brandColors, duration: Double = 10.0) {
        self.colors = colors
        self.duration = duration
    }

    var body: some View {
            GeometryReader { geometry in
            // Create a mesh-like pattern with multiple overlapping gradients
            ZStack {
                // Base gradient
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.8)

                // Animated wave pattern 1
                WavePattern(
                    phase: phase,
                    scale: scale,
                    color: colors[0].opacity(0.3),
                    frequency: 0.01,
                    amplitude: 20
                )

                // Animated wave pattern 2
                WavePattern(
                    phase: phase + 0.5,
                    scale: scale * 1.2,
                    color: colors[1].opacity(0.3),
                    frequency: 0.015,
                    amplitude: 25
                )

                // Subtle noise texture
                NoiseTexture()
                    .opacity(0.1)
            }
            .drawingGroup() // Improve performance
            .onAppear {
                withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                    scale = 1.1
                }
            }
        }
    }
}

struct WavePattern: View {
    let phase: CGFloat
    let scale: CGFloat
    let color: Color
    let frequency: CGFloat
    let amplitude: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height

                // Draw multiple sine waves
                for i in 0..<5 {
                    let yOffset = CGFloat(i) * height / 6
                    var path = Path()

                    path.move(to: CGPoint(x: 0, y: yOffset))

                    for x in stride(from: 0, through: width, by: 5) {
                        let relativeX = x / width
                        let wave = sin(CGFloat(relativeX * .pi * 2 * frequency + phase)) * amplitude
                        let y = yOffset + wave
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    context.stroke(path, with: .color(color), lineWidth: 2)
                }
            }
        }
    }
}

struct NoiseTexture: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height

                // Create a subtle noise pattern
                for _ in 0..<100 {
                    let x = CGFloat.random(in: 0..<width)
                    let y = CGFloat.random(in: 0..<height)
                    let size = CGFloat.random(in: 1..<3)
                    let opacity = CGFloat.random(in: 0.05..<0.15)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size)),
                        with: .color(Color.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

#Preview {
    AnimatedMeshGradient()
        .frame(width: 400, height: 600)
}