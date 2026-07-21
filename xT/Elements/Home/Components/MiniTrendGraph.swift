//
//  MiniTrendGraph.swift
//  xT
//
//  Compact trend graph used in small cards.  Cubic-bezier curve with
//  animated draw-in, gradient fill, and a pulsing endpoint marker.
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
            let values = points.map(\.value)
            let w = geometry.size.width
            let h = geometry.size.height

            graphContent(values: values, w: w, h: h)
                .onAppear {
                    if reduceMotion {
                        drawProgress = 1
                    } else {
                        withAnimation(.easeInOut(duration: 1.0)) { drawProgress = 1 }
                        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(1.0)) {
                            pulse = true
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func graphContent(values: [Double], w: CGFloat, h: CGFloat) -> some View {
        if values.isEmpty {
            Color.clear.frame(width: w, height: h)
        } else if values.count == 1 {
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 8, height: 8)
                .position(x: w / 2, y: h / 2)
        } else {
            let (minV, _, range) = CurveLayout.valueBounds(values)

            ZStack(alignment: .bottomLeading) {
                AnimatableFillShape(
                    values: AnimatableVector(values: values),
                    minV: minV,
                    range: range
                )
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.accent.opacity(0.18),
                            Theme.Colors.accent.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(drawProgress)

                AnimatableCurveShape(
                    values: AnimatableVector(values: values),
                    minV: minV,
                    range: range
                )
                .trim(from: 0, to: drawProgress)
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                endpointDot(values: values, minV: minV, range: range, w: w, h: h)
            }
        }
    }

    private func endpointDot(values: [Double], minV: Double, range: Double,
                             w: CGFloat, h: CGFloat) -> some View {
        guard let last = values.last else { return AnyView(EmptyView()) }
        let x = w - 10
        let y = CurveLayout.yPos(value: last, min: minV, range: range, height: h)

        return AnyView(
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
        )
    }
}

#Preview {
    MiniTrendGraph()
        .frame(height: 122)
        .environment(\.medicationManager, MedicationManager.shared)
}
