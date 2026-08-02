//
//  ActionBarView.swift
//  xT
//
//  Action bar: Record dose (primary) + Journal (secondary).
//  Adapted from FlatQuickActionsRow button layout + QuickDoseSheet/JournalComposerView.
//

import SwiftUI

struct ActionBarView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager

    @State private var showingQuickDoseSheet = false
    @State private var showingJournalComposer = false

    private var doseMissed: Bool {
        medicationManager.isFullyConfigured && medicationManager.hasMissedDose
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                showingQuickDoseSheet = true
            } label: {
                ActionButtonContent(
                    icon: { RecordDoseIcon() },
                    iconBackground: Theme.Colors.accentSecondary.opacity(0.22),
                    iconForeground: Theme.Colors.accentSecondary,
                    label: "Record dose",
                    labelColor: Theme.Colors.accentSecondary.opacity(0.9),
                    background: Theme.Colors.accentSecondary.opacity(0.13)
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Theme.Colors.border.opacity(0.35))
                .frame(width: 0.5, height: 44)

            Button {
                showingJournalComposer = true
            } label: {
                ActionButtonContent(
                    icon: { JournalIcon() },
                    iconBackground: Theme.Colors.accent.opacity(0.18),
                    iconForeground: Theme.Colors.accent,
                    label: "Journal",
                    labelColor: Theme.Colors.textTertiary,
                    background: .clear
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingQuickDoseSheet) {
            QuickDoseSheet(isPresented: $showingQuickDoseSheet)
                .environment(\.medicationManager, medicationManager)
        }
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Action Button Content

private struct ActionButtonContent: View {
    let icon: () -> AnyView
    let iconBackground: Color
    let iconForeground: Color
    let label: String
    let labelColor: Color
    let background: Color

    init<I: View>(
        icon: @escaping () -> I,
        iconBackground: Color,
        iconForeground: Color,
        label: String,
        labelColor: Color,
        background: Color
    ) {
        self.icon = { AnyView(icon()) }
        self.iconBackground = iconBackground
        self.iconForeground = iconForeground
        self.label = label
        self.labelColor = labelColor
        self.background = background
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 30, height: 30)

                icon()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(iconForeground)
            }

            Text(label)
                .font(Theme.Fonts.caption2)
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        
    }
}

// MARK: - Icons

private struct RecordDoseIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.accentSecondary, lineWidth: 1.2)
                .frame(width: 12, height: 12)

            Path { path in
                path.move(to: CGPoint(x: 7.5, y: 4.5))
                path.addLine(to: CGPoint(x: 7.5, y: 7.5))
                path.addLine(to: CGPoint(x: 9.5, y: 9))
            }
            .stroke(Theme.Colors.accentSecondary, lineWidth: 1.2)
            .frame(width: 15, height: 15)
        }
    }
}

private struct JournalIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Theme.Colors.accent, lineWidth: 1.2)
                .frame(width: 10, height: 10)

            Path { path in
                path.move(to: CGPoint(x: 5, y: 5.5))
                path.addLine(to: CGPoint(x: 10, y: 5.5))
                path.move(to: CGPoint(x: 5, y: 7.5))
                path.addLine(to: CGPoint(x: 9, y: 7.5))
                path.move(to: CGPoint(x: 5, y: 9.5))
                path.addLine(to: CGPoint(x: 7.5, y: 9.5))
            }
            .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 1, lineCap: .round))
            .frame(width: 15, height: 15)
        }
    }
}

#if DEBUG
#Preview {
    ActionBarView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
        .padding()
        .background(Theme.Colors.glassTint)
}
#endif
