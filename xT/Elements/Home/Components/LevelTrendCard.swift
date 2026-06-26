//
//  LevelTrendCard.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Combined level and trend card component
//

import SwiftUI

struct LevelTrendCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Header with title and action
            HStack {
                Text("Hormone level")
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {
                    showingGraphDetail = true
                }) {
                    Text("View all")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Current level info
            if let currentLevel = medicationManager.currentHormoneLevel?.value {
                HStack(spacing: 12) {
                    // Icon badge
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.Bloom.cycle.surface)
                            .frame(width: 36, height: 79)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Colors.Bloom.cycle.base)
                    }

                    // Level info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("current level")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Text("\(Int(currentLevel))")
                                .font(.system(size: 22))
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.Colors.accent.opacity(0.8))

                            Text("pg/mL")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            // Range indicator
                            let rangeText = getHormoneRangeText(level: currentLevel)
                            let rangeColor = getHormoneRangeColor(level: currentLevel)

                            Text(rangeText)
                                .font(.system(size: 11))
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(rangeColor.opacity(0.2))
                                .foregroundStyle(rangeColor)
                                .cornerRadius(Theme.Radius.sm)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 8)
            }

            // 7-day trend graph
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

    private func getHormoneRangeText(level: Double) -> String {
        if level < 50 { return "Very low" }
        else if level < 100 { return "Low" }
        else if level < 200 { return "Optimal" }
        else if level < 500 { return "High" }
        else { return "Very high" }
    }

    private func getHormoneRangeColor(level: Double) -> Color {
        if level < 100 { return Theme.Colors.Bloom.body.base }
        else if level < 200 { return Theme.Colors.success }
        else { return Theme.Colors.Bloom.cycle.base }
    }
}

#Preview {
    LevelTrendCard(showingGraphDetail: .constant(false))
        .environment(\.medicationManager, MedicationManager.shared)
}