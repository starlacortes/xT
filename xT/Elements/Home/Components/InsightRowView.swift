//
//  InsightRowView.swift
//  xT
//
//  Status-tinted insight row with an indicator dot.
//  Uses iOS 26 Liquid Glass background on iOS 26+.
//

import SwiftUI

struct InsightRowView: View {
    @Environment(\.medicationManager) private var medicationManager

    /// The estimate, stated. All wording lives in `HormoneLevelPresentation`;
    /// this view only decides whether the safety note earns a second sentence.
    private var insightText: String? {
        guard let level = medicationManager.currentHormoneLevel else { return nil }
        if let note = level.safetyNote {
            return "\(level.summaryText) \(note)"
        }
        return level.summaryText
    }

    private var statusColor: Color {
        medicationManager.currentHormoneLevel?.statusTint ?? Theme.Colors.accent
    }

    var body: some View {
        // With no doses recorded there is no estimate to report, and nothing
        // useful to say instead — the row simply doesn't appear.
        if let insightText {
            HStack(alignment: .top, spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 4)

                Text(insightText)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
    }
}

#if DEBUG
#Preview {
    InsightRowView()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Theme.Colors.glassTint)
}
#endif
