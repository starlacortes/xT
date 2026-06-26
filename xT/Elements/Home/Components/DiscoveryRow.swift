//
//  DiscoveryRow.swift
//  xT
//
//  Created by Cline on 6/23/26.
//  Horizontal scrolling discovery row for supplemental content
//

import SwiftUI

struct DiscoveryRow: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discover")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if medicationManager.isFullyConfigured {
                        HealthInsightCard()
                            .frame(width: 280)
                    }

                    // Placeholder for future discovery cards
                    DiscoveryPlaceholderCard(
                        title: "Wellness Tips",
                        subtitle: "Personalized suggestions for your journey",
                        icon: "lightbulb",
                        color: Theme.Colors.Bloom.mind.base
                    )
                    .frame(width: 200)

                    DiscoveryPlaceholderCard(
                        title: "Community Stories",
                        subtitle: "Read experiences from others",
                        icon: "person.2",
                        color: Theme.Colors.Bloom.cycle.base
                    )
                    .frame(width: 200)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct DiscoveryPlaceholderCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

#Preview {
    DiscoveryRow()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding(.vertical)
        .background(Theme.Gradients.brand)
}