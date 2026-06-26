//  HybridStatusCard.swift
//  xT

import SwiftUI

struct HybridStatusCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var showingGraphDetail: Bool
    @State private var dotsShown = false

    var body: some View {
        VStack(spacing: 16) {
            // Top Section: Hormone Level & Trend
            VStack(alignment: .leading, spacing: 12) {
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

                if let currentLevel = medicationManager.currentHormoneLevel?.value {
                    HStack(spacing: 12) {
                        // Icon badge
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.Bloom.cycle.surface)
                                .frame(width: 36, height: 36)

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
                                AnimatedCounter(value: currentLevel)
                                    .font(.system(size: 22))
                                    .fontWeight(.medium)
                                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                                    .contentTransition(.numericText())

                                Text("pg/mL")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

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
                }

                MiniTrendGraph()
                    .frame(height: 80)
            }

            Divider()
                .background(Theme.Colors.border)

            // Bottom Section: Dose Streak & Next Dose
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next dose")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        if let next = medicationManager.nextDoseDate {
                            Text(nextDoseLabel(next))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if onTrack {
                        Text("On track")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.Bloom.mind.base)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.Bloom.mind.surface)
                            .overlay(
                                Capsule().stroke(Theme.Colors.Bloom.mind.border, lineWidth: 0.5)
                            )
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 5) {
                    ForEach(0..<cycleDays, id: \.self) { index in
                        Circle()
                            .fill(index < completedDays ? Theme.Colors.accent : Color(UIColor.systemGray5))
                            .overlay(
                                Circle().stroke(
                                    index < completedDays ? Theme.Colors.Bloom.cycle.border : Color(UIColor.systemGray4),
                                    lineWidth: 0.5
                                )
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotsShown ? 1 : 0.1)
                            .opacity(dotsShown ? 1 : 0)
                            .animation(Theme.Motion.snappy.delay(0.3 + Double(index) * 0.06), value: dotsShown)
                    }

                    Text("\(completedDays) of \(cycleDays) days")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .onAppear { dotsShown = true }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private var cycleDays: Int {
        guard let method = medicationManager.selectedAdministrationMethod,
              let adm = MedicationManager.AdministrationMethod(rawValue: method) else { return 7 }
        return adm.frequencyDays
    }

    private var completedDays: Int {
        guard let last = medicationManager.lastDoseDate else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return min(elapsed + 1, cycleDays)
    }

    private var onTrack: Bool {
        !medicationManager.hasMissedDose
    }

    private func nextDoseLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        if days == 0 { return "Today · \(formatted)" }
        if days == 1 { return "Tomorrow · \(formatted)" }
        return "In \(days) days · \(formatted)"
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
    HybridStatusCard(showingGraphDetail: .constant(false))
        .padding()
        .background(Theme.Gradients.brand)
        .environment(\.medicationManager, MedicationManager.shared)
}
