//
//  BloomView.swift
//  xT
//
//  Flat Bloom layout — mirrors the home screen design language.
//  Hero header floats on the system background; sections separated
//  by hairline dividers instead of stacked colored cards.
//

import SwiftUI

struct BloomView: View {
    @Environment(\.medicationManager) private var medicationManager

    private var engine: BloomContentEngine {
        let cycleDay: Int = {
            guard let last = medicationManager.lastDoseDate,
                  let methodStr = medicationManager.selectedAdministrationMethod,
                  let adm = MedicationManager.AdministrationMethod(rawValue: methodStr) else { return 1 }
            let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return (elapsed % adm.frequencyDays) + 1
        }()
        return BloomContentEngine(
            medication: medicationManager.selectedMedication ?? "Estrogen",
            method: medicationManager.selectedAdministrationMethod ?? "Injectable",
            months: medicationManager.monthsOnHRT,
            currentLevel: medicationManager.estimatedRecentLevels(days: 1).last?.value,
            dayOfCycle: cycleDay
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    BloomHeroHeader(engine: engine)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .entrance(delay: 0)

                    if let insight = engine.hormoneInsight {
                        bloomDivider()
                        BloomHormoneRow(insight: insight, medication: engine.medication)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .entrance(delay: 0.08)
                    }

                    bloomDivider()
                    BloomChangesRow(changes: engine.unlockedChanges)
                        .padding(.vertical, 18)
                        .entrance(delay: 0.12)

                    bloomDivider()
                    BloomBodySection(systems: engine.bodySystems)
                        .entrance(delay: 0.16)

                    bloomDivider()
                    BloomMilestonesSection(milestones: engine.upcomingMilestones)
                        .entrance(delay: 0.20)
                        .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground).ignoresSafeArea())
        }
    }

    private func bloomDivider() -> some View {
        Divider().opacity(0.5)
    }
}

// MARK: - Hero Header

struct BloomHeroHeader: View {
    let engine: BloomContentEngine

    private var cleanTitle: String {
        engine.timelineTitle
            .replacingOccurrences(of: " ✦", with: "")
            .replacingOccurrences(of: "✦", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(engine.timelineSubtitle)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Color.secondary)

            Text(cleanTitle)
                .font(.system(size: 40, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(
                    LinearGradient(
                        colors: Theme.Gradients.brandColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            HStack(spacing: 6) {
                Text(engine.medication)
                Text("·")
                    .foregroundStyle(Color.secondary.opacity(0.5))
                Text(engine.method)
            }
            .font(Theme.Fonts.footnote)
            .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hormone Row

struct BloomHormoneRow: View {
    let insight: BloomHormoneInsight
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HORMONE LEVELS")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(0.8)
                Spacer()
                Text(insight.rangeLabel)
                    .font(Theme.Fonts.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(insight.rangePalette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(insight.rangePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                AnimatedCounter(value: insight.level)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                Text(insight.unit)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Color.secondary)
            }

            Text(insight.bodyDescription)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Changes Row

struct BloomChangesRow: View {
    let changes: [BloomChange]

    private var unlockedCount: Int { changes.filter(\.unlocked).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CHANGES UNLOCKED")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
                Text("\(unlockedCount) of \(changes.count)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(changes) { change in
                        HStack(spacing: 5) {
                            Image(systemName: change.unlocked ? "checkmark" : "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(change.label)
                                .font(Theme.Fonts.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(
                            change.unlocked ? Theme.Colors.Bloom.cycle.base : Color.secondary
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            change.unlocked
                                ? Theme.Colors.Bloom.cycle.surface
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 1)
            }
        }
    }
}

// MARK: - Body Systems Section

struct BloomBodySection: View {
    let systems: [BloomBodySystem]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YOUR BODY")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            ForEach(Array(systems.enumerated()), id: \.element.id) { index, system in
                if index > 0 {
                    Divider()
                        .opacity(0.5)
                        .padding(.horizontal, 22)
                }
                BloomBodySystemRow(system: system)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }
        }
    }
}

struct BloomBodySystemRow: View {
    let system: BloomBodySystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fillFraction: CGFloat = 0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(system.palette.surface)
                    .frame(width: 38, height: 38)
                Image(systemName: sfSymbol(for: system.icon))
                    .font(.system(size: 16))
                    .foregroundStyle(system.palette.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(system.title)
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(system.progressLabel)
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(system.subtitle)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(system.palette.progress)
                            .frame(width: geo.size.width * fillFraction, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 2)
            }
        }
        .onAppear {
            if reduceMotion {
                fillFraction = system.progressFraction
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                    fillFraction = system.progressFraction
                }
            }
        }
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

// MARK: - Milestones Section

struct BloomMilestonesSection: View {
    let milestones: [BloomMilestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMING UP")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            VStack(spacing: 10) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    BloomMilestoneRow(milestone: milestone)
                        .entrance(index: index)
                }
            }
            .padding(.horizontal, 22)
        }
    }
}

struct BloomMilestoneRow: View {
    let milestone: BloomMilestone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 36, height: 36)
                Image(systemName: sfSymbol(for: milestone.icon))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(milestone.title)
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let badge = milestone.badge {
                        Text(badge)
                            .font(Theme.Fonts.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Text(milestone.description)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.card)
        .background(Color(.systemBackground))
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
