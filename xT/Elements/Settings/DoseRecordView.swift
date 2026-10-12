//
//  DoseRecordView.swift
//  xT
//
//  Settings → Labs & Records → Dose record (ST11, X30). Replaces the old
//  `AdherenceView`: the 140pt rate ring and the "consecutive on-schedule
//  doses" / "since a missed dose" streak cards are gone — a ring gauge and a
//  streak read as a score to protect. What remains is the record itself:
//  a month grid of dose dots (the J2 dot vocabulary), a plain count line,
//  the regimen timeline, and dose intensity. `MedicationManager`'s adherence
//  and streak computations are untouched — just no longer rendered.
//

import SwiftUI

struct DoseRecordView: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                if medicationManager.isFullyConfigured {
                    monthGridSection

                    countLine

                    HairlineDivider()

                    regimenTimelineSection

                    HairlineDivider()

                    doseIntensitySection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Dose record")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Month grid

    /// A calendar month of dose dots, reusing the J2 vocabulary: a filled dot
    /// for a day with a taken dose, nothing otherwise. No color verdicts.
    private var monthGridSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(monthLabel)
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()

            // Days of the most recent 4 weeks, one dot per day, seven per row.
            let days = takenDaysByDayStart
            let leading = firstWeekdayOffset
            let total = leading + days.count

            let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 7)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(0..<total, id: \.self) { slot in
                    if slot < leading {
                        Color.clear.frame(width: 10, height: 10)
                    } else {
                        let day = days[slot - leading]
                        Circle()
                            .fill(day.taken ? Theme.Colors.accent : Theme.Colors.border)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Day-start keys for the last 28 days, oldest first, with a taken flag.
    private var takenDaysByDayStart: [(start: Date, taken: Bool)] {
        let cal = Calendar.current
        let taken = Set(
            medicationManager.doseHistory
                .filter { $0.isActive && $0.doseStatus == DoseStatus.taken.rawValue }
                .map { cal.startOfDay(for: $0.doseDate) }
        )
        return (0..<28).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date()))
        }
        .map { day in (start: day, taken: taken.contains(day)) }
    }

    /// Empty cells so the first dot lands on its weekday column.
    private var firstWeekdayOffset: Int {
        guard let first = takenDaysByDayStart.first else { return 0 }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: first.start)
        let firstWeekday = cal.firstWeekday
        return (weekday - firstWeekday + 7) % 7
    }

    private var monthLabel: String {
        takenDaysByDayStart.last?.start.formatted(.dateTime.month(.wide).year()) ?? ""
    }

    // MARK: - Count line

    /// A plain line — `11 doses recorded in the last 90 days` — not a percentage,
    /// not a rate, not a streak.
    private var countLine: some View {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let selected = medicationManager.selectedMedication ?? ""
        let count = medicationManager.doseHistory
            .filter { $0.isActive && $0.doseStatus == DoseStatus.taken.rawValue }
            .filter { $0.doseDate >= cutoff }
            .count
        _ = selected // count is regimen-wide; the selected medication isn't a filter here
        return Text(LocalizedStringResource(
            "^[\(count) dose](inflect: true) recorded in the last 90 days",
            comment: "Plain count line on the dose record screen"
        ))
        .font(Theme.Fonts.detail)
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(Theme.Fonts.icon)
                .imageScale(.large)
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("No medication configured")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Set up your medication in Settings to see your dose record.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Regimen timeline (kept)

    private var regimenTimelineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Regimen history")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()

            if medicationManager.regimenTransitionHistory.isEmpty {
                Text("Not enough dose history to show regimen changes yet.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(medicationManager.regimenTransitionHistory.reversed()) { segment in
                    regimenSegmentCard(segment)
                }
            }
        }
    }

    private func regimenSegmentCard(_ segment: MedicationManager.RegimenSegment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            HStack {
                Text(dateRangeLabel(from: segment.startDate, to: segment.endDate))
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monoLabel()

                Spacer()

                if segment.endDate == nil {
                    Text("Current")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.accent)
                        .monoLabel()
                }
            }

            HStack(spacing: Theme.Spacing.xxs) {
                Text(verbatim: segment.ester)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(verbatim: "·")
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text(verbatim: "\(AppNumberFormatters.dose.string(segment.doseAmount)) mg")
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            HStack(spacing: Theme.Spacing.xxs) {
                Text(verbatim: segment.administrationMethod)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                if let conc = segment.concentrationMgPerMl {
                    Text(verbatim: "·")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(verbatim: "@ \(AppNumberFormatters.concentration.string(conc)) mg/mL")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ghostCard()
    }

    // MARK: - Dose intensity (kept)

    private var doseIntensitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Dose intensity")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()

            let intensity = medicationManager.relativeDoseIntensity

            VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Theme.Radius.hairline)
                            .fill(Theme.Colors.border)
                            .frame(height: 6)

                        let fillWidth = min(CGFloat(intensity) / 2.0, 1.0) * geo.size.width
                        RoundedRectangle(cornerRadius: Theme.Radius.hairline)
                            .fill(Theme.Colors.accent)
                            .frame(width: fillWidth, height: 6)

                        // Marker at 1.0 (standard dose)
                        Rectangle()
                            .fill(Theme.Colors.textSecondary.opacity(0.4))
                            .frame(width: 2, height: 14)
                            .position(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                    }
                }
                .frame(height: 14)

                HStack {
                    Text(verbatim: "0.5×")
                        .font(Theme.Fonts.statLabel)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    Text("Standard")
                        .font(Theme.Fonts.statLabel)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    Text(verbatim: "2.0×+")
                        .font(Theme.Fonts.statLabel)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // The multiplier is the fact; a band label on top of it only
                // grades the user's regimen.
                Text(verbatim: "\(AppNumberFormatters.multiplier.string(intensity))× reference dose")
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let disclaimer = medicationManager.doseIntensityNote {
                    Text(disclaimer)
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func dateRangeLabel(from start: Date, to end: Date?) -> String {
        let startStr = AppDateFormatters.monthDayYear.string(from: start)
        let endStr = end.map { AppDateFormatters.monthDayYear.string(from: $0) }
            ?? String(localized: "Present", comment: "End of a date range that has not ended yet")
        return "\(startStr) – \(endStr)"
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            DoseRecordView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
