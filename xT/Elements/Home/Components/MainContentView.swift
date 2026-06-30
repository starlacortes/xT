//
//  MainContentView.swift
//  xT
//
//  Flat section stack below the graph. Hairline dividers separate sections
//  instead of glass cards. Inline types: FlatQuickActionsRow, FlatInsightRow,
//  FlatNextDoseRow, JournalHomeRow.
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Missed dose prompt — urgent, always first when present
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .padding(.bottom, 20)
                    .transition(.opacity)
                    .entrance(index: 0)
            }

            // Quick actions — two-column flat row
            FlatQuickActionsRow()
                .entrance(index: 1)

            flatDivider()

            // Contextual health insight
            if medicationManager.isFullyConfigured {
                FlatInsightRow()
                    .padding(.vertical, 18)
                    .entrance(index: 2)

                flatDivider()
            }

            // Journal row — always present (empty state or today's entry)
            JournalHomeRow()
                .padding(.vertical, 18)
                .entrance(index: 3)

            flatDivider()

            // Next dose dot-tracker
            if medicationManager.isFullyConfigured {
                FlatNextDoseRow()
                    .padding(.vertical, 18)
                    .entrance(index: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: medicationManager.hasMissedDose)
    }

    private func flatDivider() -> some View {
        Divider()
            .opacity(0.5)
    }
}

// MARK: - Flat Quick Actions Row

struct FlatQuickActionsRow: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingDoseConfirmation = false

    private var doseMissed: Bool {
        medicationManager.isFullyConfigured && medicationManager.hasMissedDose
    }

    var body: some View {
        HStack(spacing: 0) {
            // Dose — left
            flatAction(
                icon: "checkmark.circle.fill",
                label: "Record dose",
                iconColor: doseMissed ? Theme.Colors.Bloom.cycle.base : Theme.Colors.Bloom.skin.base,
                iconBg: doseMissed ? Theme.Colors.Bloom.cycle.surface : Theme.Colors.Bloom.skin.surface
            ) {
                medicationManager.recordDose(on: Date())
                showingDoseConfirmation = true
            }

            flatVerticalDivider()

            // Schedule — right
            NavigationLink(destination: UnifiedScheduleView()) {
                flatActionContent(
                    icon: "calendar",
                    label: "Schedule",
                    iconColor: Theme.Colors.Bloom.mind.base,
                    iconBg: Theme.Colors.Bloom.mind.surface
                )
            }
            .buttonStyle(.pressable)
        }
        .padding(.vertical, 18)
        .alert("Dose recorded", isPresented: $showingDoseConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your dose has been logged for today.")
        }
    }

    private func flatAction(
        icon: String,
        label: String,
        iconColor: Color,
        iconBg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            flatActionContent(icon: icon, label: label, iconColor: iconColor, iconBg: iconBg)
        }
        .buttonStyle(.pressable)
    }

    private func flatActionContent(
        icon: String,
        label: String,
        iconColor: Color,
        iconBg: Color
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(iconColor)
            }

            Text(label)
                .font(Theme.Fonts.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func flatVerticalDivider() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 0.5, height: 52)
    }
}

// MARK: - Flat Insight Row

struct FlatInsightRow: View {
    @Environment(\.medicationManager) private var medicationManager

    private var insightText: String {
        guard let level = medicationManager.currentHormoneLevel?.value else {
            return "Log doses to see personalized insights."
        }
        if level < 100 {
            return "Your levels look low — consider a check-in with your provider."
        } else if level < 200 {
            return "Great! Your hormone levels are in the optimal range. Keep up with your current schedule."
        } else {
            return "Levels are running high. Monitor for symptoms and check in if needed."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSIGHT")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(0.8)

            Text(insightText)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Journal Home Row

struct JournalHomeRow: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingJournalComposer = false

    private var todayEntry: JournalEntry? {
        guard let last = journalManager.lastEntry,
              Calendar.current.isDateInToday(last.date) else { return nil }
        return last
    }

    var body: some View {
        Group {
            if let entry = todayEntry {
                // 80:20 split — preview left, new entry icon right
                HStack(spacing: 0) {
                    JournalCardView(entry: entry, showBackground: false)
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 0.5, height: 44)

                    Button {
                        showingJournalComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.6))
                            .frame(width: 56, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .background(Theme.Colors.Bloom.skin.surface.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            } else {
                // Full-width new entry button
                Button {
                    showingJournalComposer = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.55))

                        Text("new entry…")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.Colors.accent.opacity(0.55))

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.Colors.Bloom.skin.surface.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Flat Next Dose Row

struct FlatNextDoseRow: View {
    @Environment(\.medicationManager) private var medicationManager

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEXT DOSE")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)

                Spacer()

                if let next = medicationManager.nextDoseDate {
                    Text(nextLabel(next))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<cycleDays, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < completedDays ? Theme.Colors.accent : Color.primary.opacity(0.12))
                        .frame(width: 22, height: 4)
                }
                Spacer()
            }
        }
    }

    private func nextLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let fmt = date.formatted(date: .abbreviated, time: .omitted)
        if days == 0 { return "Today · \(fmt)" }
        if days == 1 { return "Tomorrow · \(fmt)" }
        return "In \(days) days · \(fmt)"
    }
}

#Preview {
    MainContentView(showingGraphDetail: .constant(false))
        .padding(.horizontal, 22)
        .padding(.vertical)
        .background(Color(.systemBackground))
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
