//
//  LongitudinalTrendView.swift
//  xT
//
//  Phase 2 Research Dashboard — Longitudinal Trend Analysis.
//  Select a body system, view progress line graph over months on HRT,
//  with milestone annotations and optional PK level overlay.
//

import SwiftUI

struct LongitudinalTrendView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.researchInsightsManager) private var insightsManager

    @State private var selectedSystem: String = "Skin & Hair"
    @State private var showPKOverlay: Bool = false
    @State private var trendSeries: [TrendSeries] = []

    private let systemOptions = ["Skin & Hair", "Body Shape", "Mind & Mood", "Cycle & Flow"]

    /// Time milestone annotations keyed to system name.
    private let milestones: [String: [(label: String, months: Double)]] = [
        "Skin & Hair": [
            ("Softer skin begins", 1.5),
            ("Oil reduction", 3),
            ("Full skin changes", 6),
        ],
        "Body Shape": [
            ("Breast growth begins", 2),
            ("Fat redistribution", 4),
            ("Body shape settles", 12),
        ],
        "Mind & Mood": [
            ("Mood stabilization", 2),
            ("Emotional range shift", 4),
            ("Mood pattern stable", 8),
        ],
        "Cycle & Flow": [
            ("Libido changes begin", 2),
            ("Cycle adaptation", 4),
            ("Cycle stabilized", 8),
        ],
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBlock
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 22)

                Divider().opacity(0.3)

                if !medicationManager.isFullyConfigured {
                    emptyState
                        .padding(.top, 40)
                } else {
                    // System selector
                    systemPickerSection
                        .padding(.horizontal, 22)
                        .padding(.top, 20)

                    // PK overlay toggle
                    Toggle(isOn: $showPKOverlay) {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.accentSecondary)
                            Text("Overlay estimated hormone levels")
                                .font(Theme.Fonts.caption)
                        }
                    }
                    .tint(Theme.Colors.accentSecondary)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                    // Trend chart
                    if !trendSeries.isEmpty {
                        trendChartSection
                            .padding(.top, 20)
                            .padding(.horizontal, 22)
                    } else {
                        noDataState
                            .padding(.top, 40)
                    }

                    // Milestone legend
                    milestoneLegend
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .onAppear {
            refreshTrends()
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Text("LONGITUDINAL TRENDS")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.2)

            Text("How your body systems change over time on HRT")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Configure your medication and log journal entries to see longitudinal trends.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - No Data

    private var noDataState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Log more journal entries to see \(selectedSystem.lowercased()) trends over time.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - System Picker

    private var systemPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BODY SYSTEM")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .tracking(0.3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(systemOptions, id: \.self) { system in
                        Button(action: {
                            selectedSystem = system
                            refreshTrends()
                        }) {
                            Text(system)
                                .font(Theme.Fonts.caption)
                                .fontWeight(selectedSystem == system ? .semibold : .regular)
                                .foregroundStyle(selectedSystem == system ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedSystem == system
                                              ? systemColor(for: system)
                                              : Color(.secondarySystemBackground))
                                )
                        }
                    }
                }
            }
        }
    }

    private func systemColor(for system: String) -> Color {
        switch system {
        case "Skin & Hair": return Theme.Colors.Time.skin.base
        case "Body Shape":  return Theme.Colors.Time.body.base
        case "Mind & Mood": return Theme.Colors.Time.mind.base
        case "Cycle & Flow": return Theme.Colors.Time.cycle.base
        default:            return Theme.Colors.accent
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(selectedSystem.uppercased()) PROGRESS")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            TrendLineChart(
                series: trendSeries,
                xAxisLabel: "Months on HRT",
                showMilestones: true,
                milestones: milestones[selectedSystem] ?? []
            )
        }
    }

    // MARK: - Milestone Legend

    private var milestoneLegend: some View {
        let systemMilestones = milestones[selectedSystem] ?? []
        guard !systemMilestones.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("MILESTONES")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                ForEach(systemMilestones, id: \.label) { m in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.Colors.accent.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(m.label)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("~\(String(format: "%.0f", m.months)) months")
                            .font(Theme.Fonts.micro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }

    // MARK: - Data Refresh

    private func refreshTrends() {
        let journalEntries = journalManager.entries
        let hrtStart = medicationManager.hrtStartDate ?? medicationManager.doseHistory.first?.doseDate ?? Date()

        var timeProgress: [String: Double] = [
            "Skin & Hair": 5.0,
            "Body Shape": 5.0,
            "Mind & Mood": 5.0,
            "Cycle & Flow": 5.0,
        ]

        // Build all trend series
        var allSeries = insightsManager.buildLongitudinalTrends(
            journalEntries: journalEntries,
            hrtStartDate: hrtStart,
            timeProgress: timeProgress
        )

        // Filter to selected system
        allSeries = allSeries.filter { $0.name == selectedSystem }

        // Optionally add PK overlay
        if showPKOverlay, let points = medicationManager.recentLevels as? [MedicationManager.EstimatedPoint] {
            let pkPoints = points.map { pt in
                let months = Calendar.current.dateComponents([.month], from: hrtStart, to: pt.date).month ?? 0
                // Scale: normalize PK level to 1-10 scale for overlay
                let ceiling: Double = medicationManager.selectedMedication == "Testosterone" ? 1200 : 600
                let scaledValue = min((pt.value / ceiling) * 10, 10)
                return TrendPoint(
                    date: pt.date,
                    value: max(0.5, scaledValue),
                    label: nil,
                    monthsOnHRT: Double(max(0, months))
                )
            }

            allSeries.append(TrendSeries(
                name: "Est. Hormone Level (scaled)",
                points: pkPoints,
                color: Theme.Colors.accentSecondary.opacity(0.6),
                unit: ""
            ))
        }

        trendSeries = allSeries
    }
}

#Preview {
    LongitudinalTrendView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.researchInsightsManager, ResearchInsightsManager.shared)
}