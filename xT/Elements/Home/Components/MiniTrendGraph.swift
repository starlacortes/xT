//
//  MiniTrendGraph.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Mini trend graph component
//

import SwiftUI

struct MiniTrendGraph: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawProgress: CGFloat = 0
    @State private var pulse = false

    var body: some View {
        GeometryReader { geometry in
            let points = medicationManager.recentLevels
            let minValue = points.map { $0.value }.min() ?? 0
            let maxValue = points.map { $0.value }.max() ?? 1
            let valueRange = maxValue - minValue

            ZStack(alignment: .bottomLeading) {
                // Gradient fill
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(points.count - 1))
                        let y = valueRange > 0 ?
                            geometry.size.height - CGFloat((point.value - minValue) / valueRange) * geometry.size.height :
                            geometry.size.height / 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    // Close the path for gradient fill
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Theme.Colors.accent.opacity(0.18),
                        Theme.Colors.accent.opacity(0)
                    ]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .opacity(drawProgress)

                // Trend line — draws itself left to right on appear
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(points.count - 1))
                        let y = valueRange > 0 ?
                            geometry.size.height - CGFloat((point.value - minValue) / valueRange) * geometry.size.height :
                            geometry.size.height / 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .trim(from: 0, to: drawProgress)
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Current point marker — fades in after the line draws, with a soft pulse
                if let currentPoint = points.last {
                    let x = geometry.size.width - 10
                    let y = valueRange > 0 ?
                        geometry.size.height - CGFloat((currentPoint.value - minValue) / valueRange) * geometry.size.height :
                        geometry.size.height / 2

                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accent.opacity(0.35))
                            .frame(width: 10, height: 10)
                            .scaleEffect(pulse ? 2.2 : 1)
                            .opacity(pulse ? 0 : 0.6)

                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 10, height: 10)
                    }
                    .position(x: x, y: y)
                    .scaleEffect(drawProgress >= 1 ? 1 : 0)
                    .animation(Theme.Motion.snappy, value: drawProgress >= 1)
                }
            }
            .onAppear {
                if reduceMotion {
                    drawProgress = 1
                    return
                }
                withAnimation(.easeInOut(duration: 1.0)) { drawProgress = 1 }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(1.0)) {
                    pulse = true
                }
            }
        }
    }
}

#Preview {
    MiniTrendGraph()
        .frame(height: 122)
        .environment(\.medicationManager, MedicationManager.shared)
}