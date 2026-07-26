//
//  AdherenceView.swift
//  xT
//
//  Surfaces adherence rate, on-time streak, regimen transition timeline,
//  and dose intensity — metrics already computed by MedicationManager.
//

import SwiftUI

struct AdherenceView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.profileManager) private var profileManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerBlock
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 22)

                Divider().opacity(0.5)

                VStack(spacing: 32) {
                    // Adherence ring + stats
                    if medicationManager.isFullyConfigured {
                        adherenceRingSection
                            .padding(.top, 24)

                        sectionDivider()

                        statsGridSection

                        sectionDivider()

                        regimenTimelineSection

                        sectionDivider()

                        doseIntensitySection
                    } else {
                        emptyState
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 48)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: 8) {
            Text("ADHERENCE")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.2)

            Text(medicationManager.isFullyConfigured
                 ? "Your dosing consistency and regimen history"
                 : "Configure your medication to see adherence data")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("No medication configured")
                .font(Theme.Fonts.headline)
                .foregroundStyle(.primary)

            Text("Set up your medication in Settings to start tracking adherence and regimen history.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Adherence Ring

    private var adherenceRingSection: some View {
        VStack(spacing: 16) {
            Text("30-DAY ADHERENCE")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            let rate = medicationManager.adherenceRate ?? 0
            let isExcellent = rate >= 0.9
            let isGood = rate >= 0.75

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 140, height: 140)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(rate))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Theme.Colors.error,
                                Theme.Colors.warning,
                                Theme.Colors.success,
                                Theme.Colors.accent
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: rate)

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(rate * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(isExcellent ? "Excellent" : isGood ? "Good" : "Needs work")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(
                            isExcellent ? Theme.Colors.success :
                            isGood ? Theme.Colors.warning :
                            Theme.Colors.error
                        )
                }
            }

            // Detail text
            let takenCount = medicationManager.doseHistory
                .filter { $0.isActive && $0.medicationType == (medicationManager.selectedMedication ?? "") }
                .filter { $0.doseDate >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date() }
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .count

            let intervalDays = dosingIntervalDays
            let scheduledCount = max(1, Int(ceil(30.0 / Double(intervalDays))))

            Text("\(takenCount) of \(scheduledCount) scheduled doses taken")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        VStack(spacing: 12) {
            Text("AT A GLANCE")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(
                    icon: "flame.fill",
                    iconColor: Theme.Colors.warning,
                    value: "\(medicationManager.onTimeStreak)",
                    label: "On-time streak",
                    subtitle: "Consecutive doses"
                )

                statCard(
                    icon: "calendar.badge.exclamationmark",
                    iconColor: medicationManager.hasMissedDose ? Theme.Colors.error : Theme.Colors.success,
                    value: medicationManager.hasMissedDose
                        ? (medicationManager.daysSinceMissedDose.map { "\($0)d" } ?? "—")
                        : "0",
                    label: "Since missed",
                    subtitle: medicationManager.hasMissedDose ? "Days overdue" : "On schedule"
                )

                statCard(
                    icon: "clock.arrow.circlepath",
                    iconColor: Theme.Colors.Time.mind.base,
                    value: "\(medicationManager.monthsOnHRT)",
                    label: "Months on HRT",
                    subtitle: "Since start date"
                )

                statCard(
                    icon: "syringe.fill",
                    iconColor: Theme.Colors.Time.body.base,
                    value: "\(medicationManager.doseHistory.filter { $0.isActive && DoseStatus(rawValue: $0.doseStatus) == .taken }.count)",
                    label: "Total doses",
                    subtitle: "Lifetime recorded"
                )
            }
        }
    }

    // MARK: - Regimen Timeline

    private var regimenTimelineSection: some View {
        VStack(spacing: 14) {
            Text("REGIMEN HISTORY")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if medicationManager.regimenTransitionHistory.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("Not enough dose history to show regimen changes yet.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
            } else {
                ForEach(Array(zip(medicationManager.regimenTransitionHistory.indices,
                                  medicationManager.regimenTransitionHistory.reversed())),
                        id: \.0) { _, segment in
                    regimenSegmentCard(segment)
                }
            }
        }
    }

    private func regimenSegmentCard(_ segment: MedicationManager.RegimenSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date range
            HStack {
                Text(dateRangeLabel(from: segment.startDate, to: segment.endDate))
                    .font(Theme.Fonts.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(0.3)

                Spacer()

                if segment.endDate == nil {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Colors.success)
                        .tracking(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Ester + dose
            HStack(spacing: 4) {
                Text(segment.ester)
                    .font(Theme.Fonts.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text("\(String(format: "%.1f", segment.doseAmount)) mg")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
            }

            // Method + concentration
            HStack(spacing: 4) {
                Text(segment.administrationMethod)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                if let conc = segment.concentrationMgPerMl {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("@ \(String(format: "%.0f", conc)) mg/mL")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Concentration change indicator
            if let prevConc = segment.previousConcentrationMgPerMl,
               let currConc = segment.concentrationMgPerMl,
               abs(currConc - prevConc) > 0.1 {
                HStack(spacing: 4) {
                    Image(systemName: currConc > prevConc ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9))
                    Text("Concentration changed from \(String(format: "%.0f", prevConc)) → \(String(format: "%.0f", currConc)) mg/mL")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Theme.Colors.warning)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Dose Intensity

    private var doseIntensitySection: some View {
        VStack(spacing: 12) {
            Text("DOSE INTENSITY")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            let intensity = medicationManager.relativeDoseIntensity

            VStack(spacing: 8) {
                // Intensity bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)

                        // Filled portion — capped at 2.0 for visual scale
                        let fillWidth = min(CGFloat(intensity) / 2.0, 1.0) * geo.size.width
                        RoundedRectangle(cornerRadius: 3)
                            .fill(intensityColor(intensity))
                            .frame(width: fillWidth, height: 6)

                        // Marker at 1.0 (standard dose)
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 2, height: 14)
                            .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                    }
                }
                .frame(height: 14)

                // Labels
                HStack {
                    Text("0.5×")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Standard")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("2.0×+")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                // Current value
                HStack {
                    Text("\(String(format: "%.2f", intensity))× standard dose")
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(intensityLabel(intensity))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(intensityColor(intensity))
                }
                .padding(.top, 4)

                // Disclaimer
                if let disclaimer = medicationManager.doseIntensityDisclaimer {
                    Text(disclaimer)
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Helpers

    private func statCard(icon: String, iconColor: Color, value: String,
                          label: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(label)
                .font(Theme.Fonts.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var dosingIntervalDays: Int {
        if let custom = medicationManager.customFrequencyDays, custom > 0 { return custom }
        if let methodStr = medicationManager.selectedAdministrationMethod,
           let method = MedicationManager.AdministrationMethod(rawValue: methodStr) {
            return method.frequencyDays
        }
        return 7
    }

    private func dateRangeLabel(from start: Date, to end: Date?) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        let startStr = df.string(from: start)
        let endStr = end.map { df.string(from: $0) } ?? "Present"
        return "\(startStr) – \(endStr)"
    }

    private func intensityColor(_ intensity: Double) -> Color {
        if intensity < 0.5 { return Theme.Colors.Time.mind.base }
        if intensity > 1.5 { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    private func intensityLabel(_ intensity: Double) -> String {
        if intensity < 0.5 { return "Low" }
        if intensity < 0.8 { return "Below standard" }
        if intensity <= 1.2 { return "Standard" }
        if intensity <= 1.5 { return "Above standard" }
        return "High"
    }

    private func sectionDivider() -> some View {
        Divider().opacity(0.3)
    }
}

// MARK: - Preview

#Preview {
    SpoofPreview {
        NavigationStack {
            AdherenceView()
                .environment(\.medicationManager, MedicationManager.shared)
                .environment(\.profileManager, ProfileManager.shared)
        }
    }
}