//
//  NextDoseRowView.swift
//  xT
//
//  Adaptive next-dose row: weekday name + dot track (normal),
//  Record button (missed 1-2 days), pulsing Record (missed >2 days),
//  expanded missed-dose prompt (>3 days).
//

import SwiftUI

// MARK: - Main View

struct NextDoseRowView: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingRecordDose = false
    @State private var isPulsing = false
    @State private var todayDotPulsing = false

    private let dotWidth: CGFloat = 24
    private let dotHeight: CGFloat = 4

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

    private var isToday: Bool { completedDays >= cycleDays }

    private var daysSinceLastDose: Int {
        guard let last = medicationManager.lastDoseDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    }

    private var nextDoseWeekday: String {
        guard let next = medicationManager.nextDoseDate else { return "—" }
        let formatter = AppDateFormatters.weekday
        return formatter.string(from: next)
    }

    private var weekdayLabel: String {
        if isToday { return "Today" }
        if daysSinceLastDose <= 4 { return "Next \(nextDoseWeekday)" }
        return nextDoseWeekday
    }

    private var missedDays: Int {
        medicationManager.daysSinceMissedDose ?? 0
    }

    private var isMissed: Bool { medicationManager.hasMissedDose && medicationManager.isFullyConfigured }

    var body: some View {
        Group {
            if isMissed && missedDays > 3 {
                missedDosePromptExpanded
            } else {
                compactRow
            }
        }
        .sheet(isPresented: $showingRecordDose) {
            RecordDoseView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if missedDays > 2 { startPulsing() }
            if isToday { startTodayPulse() }
        }
        .onChange(of: missedDays) { _, days in
            if days > 2 { startPulsing() }
        }
        .onChange(of: isToday) { _, today in
            if today {
                startTodayPulse()
            }
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private func startTodayPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            todayDotPulsing = true
        }
    }

    // MARK: - Compact Row

    private var compactRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isMissed ? "Missed dose" : "Next dose")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)

                if isMissed {
                    recordButton
                } else {
                    Text(weekdayLabel)
                        .font(Theme.Fonts.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            Spacer()

            if isMissed {
                missedDaysBadge
            } else {
                dotTrack
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    // MARK: - Record Button

    @ViewBuilder
    private var recordButton: some View {
        let baseOpacity = missedDays > 2 ? 0.22 : 0.16
        let strokeOpacity = missedDays > 2 ? 0.5 : 0.3

        Button(action: { showingRecordDose = true }) {
            Text("Record")
                .font(Theme.Fonts.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(Theme.Colors.accent.opacity(baseOpacity))
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.Colors.accent.opacity(strokeOpacity), lineWidth: 1)
                )
                .opacity(missedDays > 2 ? (isPulsing ? 1.0 : 0.6) : 1)
                .scaleEffect(missedDays > 2 ? (isPulsing ? 1.0 : 0.93) : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dot Track

    private var dotTrack: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<cycleDays, id: \.self) { i in
                dotView(for: i)
            }
        }
    }

    @ViewBuilder
    private func dotView(for index: Int) -> some View {
        let isCurrent = index == (completedDays - 1)
        let isFilled = index < completedDays

        if isCurrent && isToday {
            todayDot
        } else if isCurrent {
            currentDot
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(isFilled ? Theme.Colors.accentSecondary.opacity(0.7) : Theme.Colors.Graph.dotUnfilled)
                .frame(width: dotWidth, height: dotHeight)
        }
    }

    private var currentDot: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.Colors.accentSecondary)
            .frame(width: dotWidth, height: dotHeight)
            .shadow(color: Theme.Colors.accentSecondary.opacity(0.6), radius: 4, x: 0, y: 0)
            .shadow(color: Theme.Colors.accentSecondary.opacity(0.3), radius: 8, x: 0, y: 0)
    }

    private var todayDot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Colors.accentSecondary)
                .frame(width: dotWidth, height: dotHeight)
                .shadow(color: Theme.Colors.accentSecondary.opacity(0.8), radius: 6, x: 0, y: 0)
                .shadow(color: Theme.Colors.accentSecondary.opacity(0.4), radius: 14, x: 0, y: 0)

            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Colors.accentSecondary.opacity(0.25))
                .frame(width: dotWidth, height: dotHeight)
                .scaleEffect(todayDotPulsing ? 1.6 : 0.9)
                .opacity(todayDotPulsing ? 0 : 0.7)
        }
    }

    // MARK: - Missed Days Badge

    private var missedDaysBadge: some View {
        Text("\(missedDays)d")
            .font(Theme.Fonts.caption2.weight(.medium))
            .foregroundStyle(Theme.Colors.error)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.Colors.error.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Expanded Missed Dose Prompt (>3 days)

    private static let cycleText = Color(lightHex: "#993554", darkHex: "#F4A8C0")

    private var missedDosePromptExpanded: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.Time.cycle.surface)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.Time.cycle.border, lineWidth: 0.5)
                        )
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Self.cycleText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose not recorded")
                        .font(Theme.Fonts.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.cycleText)

                    Text("^[\(missedDays) day](inflect: true) since this dose was scheduled")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()
            }

            HStack(spacing: Theme.Spacing.md) {
                Button(action: { showingRecordDose = true }) {
                    Text("Record dose")
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Self.cycleText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.Time.cycle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.Time.cycle.border, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: UnifiedScheduleView()) {
                    Text("Adjust schedule")
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Theme.Colors.Time.mind.base)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.Time.mind.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.Time.mind.border, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.card)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NextDoseRowView()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Theme.Colors.glassTint)
}
#endif
