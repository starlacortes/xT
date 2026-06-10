//
//  BloomView.swift
//  xT
//
//  The Bloom tab — personalized HRT insights, body system cards,
//  and upcoming milestones tailored to the user's medication and progress.
//

import SwiftUI

struct BloomView: View {
    @Environment(\.medicationManager) private var medicationManager

    private var engine: BloomContentEngine {
        BloomContentEngine(
            medication: medicationManager.selectedMedication ?? "Estrogen",
            method: medicationManager.selectedAdministrationMethod ?? "Injectable",
            months: medicationManager.monthsOnHRT,
            currentLevel: medicationManager.estimatedRecentLevels(days: 1).last?.value
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BloomTimelineHeader(engine: engine)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    BloomSectionLabel(text: "Happening right now")
                        .padding(.horizontal)

                    if let insight = engine.hormoneInsight {
                        BloomHormoneCard(insight: insight, medication: engine.medication)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }

                    BloomBodySystemGrid(systems: engine.bodySystems)
                        .padding(.horizontal)

                    BloomSectionLabel(text: "Coming up for you")
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        ForEach(engine.upcomingMilestones) { milestone in
                            BloomMilestoneCard(milestone: milestone)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Bloom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Bloom")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Your body, your journey ✦")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Section Label

struct BloomSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Timeline Header Card

struct BloomTimelineHeader: View {
    let engine: BloomContentEngine

    private var unlockedCount: Int { engine.unlockedChanges.filter(\.unlocked).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.timelineSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#993556"))
                    Text(engine.timelineTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#72243E"))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(engine.medication)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#72243E"))
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#993556"))
                    Text(engine.method)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#72243E"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#F4C0D1"))
                .cornerRadius(20)
            }

            Text("Changes unlocked so far")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#993556"))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(engine.unlockedChanges) { change in
                    BloomChangeChip(change: change)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#FBEAF0"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#F4C0D1"), lineWidth: 0.5)
        )
    }
}

struct BloomChangeChip: View {
    let change: BloomChange

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: change.unlocked ? "checkmark" : "clock")
                .font(.system(size: 11))
                .foregroundColor(change.unlocked ? Color(hex: "#0F6E56") : Color(hex: "#5F5E5A"))
            Text(change.label)
                .font(.system(size: 11))
                .foregroundColor(change.unlocked ? Color(hex: "#72243E") : Color(hex: "#444441"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(change.unlocked ? Color.white : Color(hex: "#F1EFE8"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(change.unlocked ? Color(hex: "#F4C0D1") : Color(hex: "#D3D1C7"), lineWidth: 0.5)
        )
    }
}

// MARK: - Hormone Level Card

struct BloomHormoneCard: View {
    let insight: BloomHormoneInsight
    let medication: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(insight.rangePalette.iconBorder, lineWidth: 0.5))
                Image(systemName: "drop")
                    .font(.system(size: 24))
                    .foregroundColor(insight.rangePalette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your \(medication.lowercased()) right now")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(insight.rangePalette.title)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(insight.level))")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(insight.rangePalette.title)
                    Text(insight.unit)
                        .font(.system(size: 12))
                        .foregroundColor(insight.rangePalette.accent)
                    Text(insight.rangeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(insight.rangePalette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(insight.rangePalette.surface)
                        .cornerRadius(10)
                }

                Text(insight.bodyDescription)
                    .font(.system(size: 12))
                    .foregroundColor(insight.rangePalette.accent)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(insight.rangePalette.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(insight.rangePalette.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Body System Grid

struct BloomBodySystemGrid: View {
    let systems: [BloomBodySystem]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(systems) { system in
                BloomBodySystemCard(system: system)
            }
        }
    }
}

struct BloomBodySystemCard: View {
    let system: BloomBodySystem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(system.palette.iconBorder, lineWidth: 0.5))
                Image(systemName: sfSymbol(for: system.icon))
                    .font(.system(size: 26))
                    .foregroundColor(system.palette.accent)
            }
            .padding(.bottom, 10)

            Text(system.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(system.palette.title)
                .padding(.bottom, 3)

            Text(system.subtitle)
                .font(.system(size: 11))
                .foregroundColor(system.palette.accent)
                .lineLimit(2)
                .lineSpacing(1)
                .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.6))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(system.palette.progress)
                        .frame(width: geo.size.width * system.progressFraction, height: 5)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 4)

            Text(system.progressLabel)
                .font(.system(size: 10))
                .foregroundColor(system.palette.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(system.palette.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(system.palette.border, lineWidth: 0.5)
        )
    }

    private func sfSymbol(for name: String) -> String {
        switch name {
        case "brain":              return "brain.head.profile"
        case "sparkles":           return "sparkles"
        case "body-scan":          return "figure.stand"
        case "heart-rate-monitor": return "waveform.path.ecg"
        case "microphone":         return "mic"
        case "test-pipe":          return "flask"
        case "clock":              return "clock"
        default:                   return "circle"
        }
    }
}

// MARK: - Milestone Card

struct BloomMilestoneCard: View {
    let milestone: BloomMilestone

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(milestone.palette.surface)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(milestone.palette.iconBorder, lineWidth: 0.5))
                Image(systemName: sfSymbol(for: milestone.icon))
                    .font(.system(size: 24))
                    .foregroundColor(milestone.palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(milestone.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let badge = milestone.badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(milestone.palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(milestone.palette.surface)
                        .cornerRadius(10)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func sfSymbol(for name: String) -> String {
        switch name {
        case "clock":     return "clock"
        case "test-pipe": return "flask"
        default:          return "star"
        }
    }
}

// MARK: - Preview

#Preview {
    BloomView()
        .environment(\.medicationManager, MedicationManager.shared)
}