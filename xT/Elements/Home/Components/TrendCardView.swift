//
//  TrendCardView.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Trend card component
//

import SwiftUI

struct TrendCardView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("7-day trend")
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                 NavigationLink(destination: GraphView(isFullScreen: true)) {
                     Text("View all")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Mini trend graph
            MiniTrendGraph()
                .frame(height: 122)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    TrendCardView()
}