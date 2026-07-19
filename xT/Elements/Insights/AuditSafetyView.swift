//
//  AuditSafetyView.swift
//  xT
//
//  Phase 2 Research Dashboard — Adherence & Safety Audit.
//  Displays adherence rate trend, missed-dose heatmap, and SAE flags.
//

import SwiftUI

struct AuditSafetyView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.researchInsightsManager) private var insightsManager

    @State private var adherenceTrend: [AdherenceTrendPoint] = []
    @State private var heatmapCells: [HeatmapCell] = []
    @State private var saeFlags: [SAEFlag] = []

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
                    // Adherence trend
                    adherenceTrendSection
                        .padding(.top, 24)
                        .padding(.horizontal, 22)

                    sectionDivider()
                        .padding(.vertical, 24)

                    // Missed dose heatmap
                    heatmapSection
                        .padding(.horizontal, 22)

                    sectionDivider()
                        .padding(.vertical, 24)

                    // SAE Flags
                    saeSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 48)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Text("ADHERENCE & SAFETY AUDIT")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.2)

            Text("Monitor dosing consistency and potential adverse signals")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Configure your medication to enable audit tracking.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Adherence Trend

    private var adherenceTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY ADHERENCE TREND (12 MONTHS)")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if adherenceTrend.isEmpty {
                Text("Not enough dose history to compute trend.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                adherenceChart
            }

            // Summary metrics
            if !adherenceTrend.isEmpty {
                adherenceSummary
                    .padding(.top, 8)
            }
        }
    }

    private var adherenceChart: some View {
        GeometryReader { geo in
            let w = geo.size.width - 40
            let h: CGFloat = 100

            let rates = adherenceTrend.map(\.rate)
            let minR: Double = 0
            let maxR: Double = 1.0

            Path { path in
                let count = adherenceTrend.count
                guard count > 1 else { return }

                for (i, pt) in adherenceTrend.enumerated() {
                    let x = CGFloat(i) / CGFloat(count - 1) * w
                    let y = h - CGFloat(pt.rate - minR) / CGFloat(maxR - minR) * h
                    let point = CGPoint(x: x + 20, y: y)

                    if i == 0 {
                        path.move(to: point)
                    } else {
                        let prevX = CGFloat(i - 1) / CGFloat(count - 1) * w + 20
                        let prevY = h - CGFloat(adherenceTrend[i - 1].rate - minR) / CGFloat(maxR - minR) * h
                        let ctrl1 = CGPoint(x: prevX + (point.x - prevX) * 0.4, y: prevY)
                        let ctrl2 = CGPoint(x: prevX + (point.x - prevX) * 0.6, y: point.y)
                        path.addCurve(to: point, control1: ctrl1, control2: ctrl2)
                    }
                }
            }
            .stroke(
                AngularGradient(
                    colors: [Theme.Colors.error, Theme.Colors.warning, Theme.Colors.success],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 100)
    }

    private var adherenceSummary: some View {
        let overallRate = medicationManager.adherenceRate ?? 0
        let recent6Months = adherenceTrend.suffix(26)  // ~26 weeks in 6 months
        let recent6Rate = recent6Months.map(\.rate).reduce(0, +) / max(Double(recent6Months.count), 1)
        let isImproving = recent6Rate > overallRate

        return HStack(spacing: 12) {
            statPill(
                icon: "calendar.badge.clock",
                color: Theme.Colors.Time.mind.base,
                value: "\(String(format: "%.0f", overallRate * 100))%",
                label: "Overall 12-month adherence"
            )

            statPill(
                icon: isImproving ? "arrow.up.right" : "arrow.down.right",
                color: isImproving ? Theme.Colors.success : Theme.Colors.warning,
                value: "\(String(format: "%.0f", recent6Rate * 100))%",
                label: "Recent 6-month"
            )

            statPill(
                icon: "flame",
                color: Theme.Colors.warning,
                value: "\(medicationManager.onTimeStreak)",
                label: "On-time streak"
            )
        }
    }

    private func statPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        HeatmapView(
            cells: heatmapCells,
            title: "MISSED DOSE HEATMAP (WEEKDAY × MONTH)"
        )
    }

    // MARK: - SAE Flags

    private var saeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAFETY FLAGS")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if saeFlags.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.Colors.success)
                        .font(.system(size: 16))
                    Text("No safety concerns detected from available data.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                ForEach(saeFlags) { flag in
                    saeFlagCard(flag)
                }
            }
        }
    }

    private func saeFlagCard(_ flag: SAEFlag) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: flag.severity.icon)
                .font(.system(size: 16))
                .foregroundStyle(flag.severity.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(flag.source)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(flag.severity.color)

                Text(flag.message)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.primary)
                    .lineSpacing(2)

                Text(flag.date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(flag.severity.color.opacity(0.08))
        )
    }

    // MARK: - Data Refresh

    private func refreshData() {
        let doses = medicationManager.doseHistory.filter { $0.isActive && $0.medicationType == (medicationManager.selectedMedication ?? "") }
        let frequencyDays = dosingIntervalDays

        adherenceTrend = insightsManager.buildAdherenceTrend(doses: doses, frequencyDays: frequencyDays)
        heatmapCells = insightsManager.buildMissedDoseHeatmap(doses: doses)

        let bloodTests = medicationManager.bloodTestHistory
        let hormoneType = medicationManager.selectedMedication ?? "Estrogen"
        saeFlags = insightsManager.flagPotentialSAEs(bloodTests: bloodTests, hormoneType: hormoneType)
    }

    private var dosingIntervalDays: Int {
        if let custom = medicationManager.customFrequencyDays, custom > 0 { return custom }
        if let methodStr = medicationManager.selectedAdministrationMethod,
           let method = MedicationManager.AdministrationMethod(rawValue: methodStr) {
            return method.frequencyDays
        }
        return 7
    }

    // MARK: - Helpers

    private func sectionDivider() -> some View {
        Divider().opacity(0.3)
            .padding(.horizontal, 22)
    }
}

#Preview {
    AuditSafetyView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.researchInsightsManager, ResearchInsightsManager.shared)
}