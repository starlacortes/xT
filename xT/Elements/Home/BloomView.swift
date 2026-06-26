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
                        .padding(.top, Theme.Spacing.sm)
                        .entrance(delay: 0)

                    BloomSectionLabel(text: "Happening right now")
                        .padding(.horizontal)

                    if let insight = engine.hormoneInsight {
                        BloomHormoneCard(insight: insight, medication: engine.medication)
                            .padding(.horizontal)
                            .padding(.bottom, Theme.Spacing.sm)
                            .entrance(delay: 0.08)
                    }

                    BloomBodySystemGrid(systems: engine.bodySystems)
                        .padding(.horizontal)

                    BloomSectionLabel(text: "Coming up for you")
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        ForEach(Array(engine.upcomingMilestones.enumerated()), id: \.element.id) { index, milestone in
                            BloomMilestoneCard(milestone: milestone)
                                .entrance(index: index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle("Bloom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Bloom")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(.primary)
                        Text("Your body, your journey ✦")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
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
            .font(Theme.Fonts.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.sm)
    }
}

#Preview {
    BloomSectionLabel(text: "Section Title")
}

// MARK: - Timeline Header Card

struct BloomTimelineHeader: View {
    let engine: BloomContentEngine

    // Dark rose title — readable on cycle surface in both modes
    private static let cycleTitle = Color(lightHex: "#72243E", darkHex: "#F4A8C0")

    private var unlockedCount: Int { engine.unlockedChanges.filter(\.unlocked).count }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.timelineSubtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.Bloom.cycle.base)
                    Text(engine.timelineTitle)
                        .font(Theme.Fonts.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.cycleTitle)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(engine.medication)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.cycleTitle)
                    Text("·")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Theme.Colors.Bloom.cycle.base)
                    Text(engine.method)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.cycleTitle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.Bloom.cycle.border)
                .clipShape(Capsule())
            }

            Text("Changes unlocked so far")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.Bloom.cycle.base)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(engine.unlockedChanges) { change in
                    BloomChangeChip(change: change)
                }
            }
        }
        .padding(Theme.Spacing.card)
        .background(Theme.Colors.Bloom.cycle.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.Bloom.cycle.border, lineWidth: 0.5)
        )
    }
}

struct BloomChangeChip: View {
    let change: BloomChange

    private static let cycleTitle = Color(lightHex: "#72243E", darkHex: "#F4A8C0")

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: change.unlocked ? "checkmark" : "clock")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(change.unlocked ? Theme.Colors.Bloom.skin.base : Theme.Colors.textTertiary)
            Text(change.label)
                .font(Theme.Fonts.caption2)
                .foregroundStyle(change.unlocked ? Self.cycleTitle : Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(change.unlocked ? Color(.systemBackground) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    change.unlocked ? Theme.Colors.Bloom.cycle.border : Color(UIColor.separator).opacity(0.5),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Hormone Level Card

struct BloomHormoneCard: View {
    let insight: BloomHormoneInsight
    let medication: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(insight.rangePalette.iconBorder, lineWidth: 0.5))
                Image(systemName: "drop")
                    .font(.system(size: 24))
                    .foregroundStyle(insight.rangePalette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your \(medication.lowercased()) right now")
                    .font(Theme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(insight.rangePalette.title)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    AnimatedCounter(value: insight.level)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(insight.rangePalette.title)
                        .contentTransition(.numericText())
                    Text(insight.unit)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(insight.rangePalette.accent)
                    Text(insight.rangeLabel)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(insight.rangePalette.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(insight.rangePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }

                Text(insight.bodyDescription)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(insight.rangePalette.accent)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.card)
        .background(insight.rangePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
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
            spacing: Theme.Spacing.sm
        ) {
            ForEach(Array(systems.enumerated()), id: \.element.id) { index, system in
                BloomBodySystemCard(system: system)
                    .entrance(index: index)
            }
        }
    }
}

struct BloomBodySystemCard: View {
    let system: BloomBodySystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fillFraction: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(system.palette.iconBorder, lineWidth: 0.5))
                Image(systemName: sfSymbol(for: system.icon))
                    .font(.system(size: 26))
                    .foregroundStyle(system.palette.accent)
            }
            .padding(.bottom, 10)

            Text(system.title)
                .font(Theme.Fonts.footnote)
                .fontWeight(.medium)
                .foregroundStyle(system.palette.title)
                .padding(.bottom, 3)

            Text(system.subtitle)
                .font(Theme.Fonts.caption2)
                .foregroundStyle(system.palette.accent)
                .lineLimit(2)
                .lineSpacing(1)
                .padding(.bottom, Theme.Spacing.sm)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.6))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(system.palette.progress)
                        .frame(width: geo.size.width * fillFraction, height: 5)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 4)
            .onAppear {
                if reduceMotion {
                    fillFraction = system.progressFraction
                } else {
                    withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                        fillFraction = system.progressFraction
                    }
                }
            }

            Text(system.progressLabel)
                .font(Theme.Fonts.micro)
                .foregroundStyle(system.palette.accent)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(system.palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
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
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(milestone.palette.surface)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(milestone.palette.iconBorder, lineWidth: 0.5))
                Image(systemName: sfSymbol(for: milestone.icon))
                    .font(.system(size: 24))
                    .foregroundStyle(milestone.palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(Theme.Fonts.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(milestone.description)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let badge = milestone.badge {
                    Text(badge)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(milestone.palette.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(milestone.palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.card)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
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

// MARK: - Previews for Subviews

#Preview("BloomTimelineHeader") {
    let engine = BloomContentEngine(
        medication: "Estrogen",
        method: "Injectable",
        months: 6,
        currentLevel: 150.0
    )
    return BloomTimelineHeader(engine: engine)
}

#Preview("BloomChangeChip") {
    BloomChangeChip(change: BloomChange(label: "Skin softening", unlocked: true))
}

#Preview("BloomHormoneCard") {
    let insight = BloomHormoneInsight(
        level: 150.0,
        unit: "pg/mL",
        rangeLabel: "Optimal",
        bodyDescription: "Your hormone levels are in the optimal range for your current stage.",
        rangePalette: BloomPalette(
            surface: Theme.Colors.Bloom.skin.surface,
            border: Theme.Colors.Bloom.skin.border,
            accent: Theme.Colors.Bloom.skin.base,
            title: Theme.Colors.Bloom.skin.base,
            progress: Theme.Colors.Bloom.skin.base,
            iconBorder: Theme.Colors.Bloom.skin.border
        )
    )
    BloomHormoneCard(insight: insight, medication: "Estrogen")
}

#Preview("BloomBodySystemGrid") {
    let systems = [
        BloomBodySystem(
            title: "Skin",
            subtitle: "Softening and hydration",
            icon: "sparkles",
            palette: BloomPalette(
                surface: Theme.Colors.Bloom.cycle.surface,
                border: Theme.Colors.Bloom.cycle.border,
                accent: Theme.Colors.Bloom.cycle.base,
                title: Theme.Colors.Bloom.cycle.base,
                progress: Theme.Colors.Bloom.cycle.base,
                iconBorder: Theme.Colors.Bloom.cycle.border
            ),
            progressFraction: 0.75,
            progressLabel: "75% complete"
        ),
        BloomBodySystem(
            title: "Mood",
            subtitle: "Emotional regulation",
            icon: "brain",
            palette: BloomPalette(
                surface: Theme.Colors.Bloom.skin.surface,
                border: Theme.Colors.Bloom.skin.border,
                accent: Theme.Colors.Bloom.skin.base,
                title: Theme.Colors.Bloom.skin.base,
                progress: Theme.Colors.Bloom.skin.base,
                iconBorder: Theme.Colors.Bloom.skin.border
            ),
            progressFraction: 0.50,
            progressLabel: "50% complete"
        )
    ]
    BloomBodySystemGrid(systems: systems)
}

#Preview("BloomBodySystemCard") {
    let system = BloomBodySystem(
        title: "Skin",
        subtitle: "Softening and hydration",
        icon: "sparkles",
        palette: BloomPalette(
            surface: Theme.Colors.Bloom.cycle.surface,
            border: Theme.Colors.Bloom.cycle.border,
            accent: Theme.Colors.Bloom.cycle.base,
            title: Theme.Colors.Bloom.cycle.base,
            progress: Theme.Colors.Bloom.cycle.base,
            iconBorder: Theme.Colors.Bloom.cycle.border
        ),
        progressFraction: 0.75,
        progressLabel: "75% complete"
    )
    BloomBodySystemCard(system: system)
        .frame(width: 180)
}

#Preview("BloomMilestoneCard") {
    let milestone = BloomMilestone(
        title: "3 Months",
        description: "You may start noticing changes in skin texture and emotional regulation.",
        icon: "clock",
        palette: BloomPalette(
            surface: Theme.Colors.Bloom.cycle.surface,
            border: Theme.Colors.Bloom.cycle.border,
            accent: Theme.Colors.Bloom.cycle.base,
            title: Theme.Colors.Bloom.cycle.base,
            progress: Theme.Colors.Bloom.cycle.base,
            iconBorder: Theme.Colors.Bloom.cycle.border
        ),
        badge: "Upcoming"
    )
    BloomMilestoneCard(milestone: milestone)
        .frame(width: 300)
}
