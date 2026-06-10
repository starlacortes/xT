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
                        Theme.accentColor.opacity(0.18),
                        Theme.accentColor.opacity(0)
                    ]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                // Trend line
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
                .stroke(Theme.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Current point marker
                if let currentPoint = points.last {
                    let x = geometry.size.width - 10
                    let y = valueRange > 0 ?
                        geometry.size.height - CGFloat((currentPoint.value - minValue) / valueRange) * geometry.size.height :
                        geometry.size.height / 2

                    Circle()
                        .fill(Theme.accentColor)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
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