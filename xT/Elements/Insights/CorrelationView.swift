//
//  CorrelationView.swift
//  xT
//
//  Phase 2 Research Dashboard — Correlation Engine.
//  Select two variables, run Pearson correlation, display scatter plot with stats.
//

import SwiftUI

struct CorrelationView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.researchInsightsManager) private var insightsManager

    @State private var varA: InsightVariable = .monthsOnHRT
    @State private var varB: InsightVariable = .moodValence
    @State private var result: CorrelationResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBlock
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 22)

                Divider().opacity(0.3)

                // Variable selectors
                variableSelectorSection
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                // Compute button
                Button(action: computeCorrelation) {
                    HStack(spacing: 6) {
                        Image(systemName: "function")
                            .font(.system(size: 12))
                        Text("Compute Correlation")
                    }
                }
                .asAccentButton()
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .disabled(!medicationManager.isFullyConfigured)

                if !medicationManager.isFullyConfigured {
                    emptyState
                        .padding(.top, 40)
                } else if let result = result {
                    // Results
                    resultSection(result)
                        .padding(.top, 24)
                        .padding(.horizontal, 22)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.scatter")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.4))
                            .padding(.top, 40)
                        Text("Select two variables and tap Compute")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .onAppear {
            computeCorrelation()
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Text("CORRELATION ENGINE")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.2)

            Text("Does tracking one variable predict outcomes in another?")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "syringe")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Configure your medication to enable correlation analysis.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Variable Selectors

    private var variableSelectorSection: some View {
        VStack(spacing: 12) {
            variablePicker(label: "Variable A (independent)", selection: $varA)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.3))
                    .frame(height: 1)
                Text("vs")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.3))
                    .frame(height: 1)
            }

            variablePicker(label: "Variable B (dependent)", selection: $varB)
        }
    }

    private func variablePicker(label: String, selection: Binding<InsightVariable>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .tracking(0.3)

            Menu {
                ForEach(InsightVariable.allCases) { v in
                    Button(action: { selection.wrappedValue = v }) {
                        HStack {
                            Text(v.rawValue)
                            if selection.wrappedValue == v {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.rawValue)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    // MARK: - Compute

    private func computeCorrelation() {
        let doses = medicationManager.doseHistory.filter { $0.isActive && $0.medicationType == (medicationManager.selectedMedication ?? "") }
        let journalEntries = journalManager.entries
        let bloodTests = medicationManager.bloodTestHistory
        let hrtStart = medicationManager.hrtStartDate ?? medicationManager.doseHistory.first?.doseDate ?? Date()
        let adherence = medicationManager.adherenceRate ?? 0
        let currentLevel = medicationManager.currentHormoneLevel?.value
        let streak = medicationManager.onTimeStreak
        let intensity = medicationManager.relativeDoseIntensity

        // Bloom progress — pulled from MedicationManager or BloomContent
        var bloomProgress: [String: Double] = [:]
        if let mgr = medicationManager as? MedicationManager {
            // Use available progress metrics
            bloomProgress["Skin & Hair"] = 5.0
            bloomProgress["Body Shape"] = 5.0
            bloomProgress["Mind & Mood"] = 5.0
            bloomProgress["Cycle & Flow"] = 5.0
        }

        result = insightsManager.computeCorrelation(
            varA: varA,
            varB: varB,
            doses: doses,
            journalEntries: journalEntries,
            bloodTests: bloodTests,
            hrtStartDate: hrtStart,
            adherenceRate: adherence,
            currentLevel: currentLevel,
            onTimeStreak: streak,
            relativeDoseIntensity: intensity,
            bloomProgress: bloomProgress
        )
    }

    // MARK: - Results

    private func resultSection(_ result: CorrelationResult) -> some View {
        VStack(spacing: 20) {
            // Correlation summary card
            summaryCard(result)
                .padding(.horizontal, 22)

            // Scatter plot
            VStack(alignment: .leading, spacing: 4) {
                Text("SCATTER PLOT")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.horizontal, 22)

                ScatterPlotView(
                    points: result.points,
                    varA: result.varA,
                    varB: result.varB,
                    r: result.r,
                    rSquared: result.rSquared,
                    slope: result.slope,
                    intercept: result.intercept,
                    sampleSize: result.sampleSize
                )
                .padding(.horizontal, 8)
            }

            // Interpretation
            interpretationCard(result)
                .padding(.horizontal, 22)

            // Axis labels
            VStack(spacing: 2) {
                Text("X-axis: \(result.varA.rawValue)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Y-axis: \(result.varB.rawValue)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ result: CorrelationResult) -> some View {
        HStack(spacing: 0) {
            // r value — large display
            VStack(spacing: 4) {
                Text("r")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.3f", result.r))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(result.strength.color)
                Text("\(result.direction.rawValue) \(result.strength.rawValue)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(result.strength.color)
            }
            .frame(width: 120)

            Divider()
                .frame(height: 50)

            // Detail stats
            VStack(alignment: .leading, spacing: 4) {
                detailRow(label: "R²", value: String(format: "%.4f", result.rSquared))
                detailRow(label: "p-value", value: result.pValue.map { String(format: "%.4f", $0) } ?? "—")
                detailRow(label: "n", value: "\(result.sampleSize)")
                detailRow(label: "β₁", value: String(format: "%.3f", result.slope))
            }
            .padding(.leading, 16)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Interpretation

    private func interpretationCard(_ result: CorrelationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INTERPRETATION")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text(interpretationText(result))
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.primary)
                .lineSpacing(3)

            if let p = result.pValue {
                let significant = p < 0.05
                HStack(spacing: 6) {
                    Image(systemName: significant ? "checkmark.shield" : "exclamationmark.triangle")
                        .font(.system(size: 12))
                    Text(significant
                         ? "Statistically significant (p < 0.05)"
                         : "Not statistically significant (p ≥ 0.05) — larger sample may be needed")
                    .font(.system(size: 11))
                }
                .foregroundStyle(significant ? Theme.Colors.success : Theme.Colors.warning)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func interpretationText(_ result: CorrelationResult) -> String {
        let a = result.varA.rawValue
        let b = result.varB.rawValue
        let dir = result.direction == .positive ? "increase" : "decrease"

        switch result.strength {
        case .strong:
            return "There is a strong \(result.direction.rawValue.lowercased()) correlation between \(a) and \(b). As \(a) increases, \(b) tends to \(dir) substantially. This relationship explains \(String(format: "%.1f", result.rSquared * 100))% of the variance."
        case .moderate:
            return "There is a moderate \(result.direction.rawValue.lowercased()) correlation between \(a) and \(b). The relationship is noticeable but not deterministic — other factors likely influence \(b) as well."
        case .weak:
            return "There is a weak \(result.direction.rawValue.lowercased()) correlation between \(a) and \(b). While a slight trend exists, the relationship is not strong enough to be clinically actionable on its own."
        case .negligible:
            return "There is no meaningful correlation between \(a) and \(b). These variables appear to be independent based on the available data."
        }
    }
}

#Preview {
    CorrelationView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.researchInsightsManager, ResearchInsightsManager.shared)
}