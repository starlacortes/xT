//
//  ChartWindowPicker.swift
//  xT
//
//  The Home curve's window control (X12c): the ester-tuned cycle view, a
//  90-day trend, or everything logged. Sits flush top-right, the readout's
//  twin at the other corner of the same band — chips on paper, like the
//  phase strip's.
//
//  Setting the mode persists it device-locally and resamples `recentLevels`;
//  FlatGraphView's own onChange then morphs the curve to the new window, and
//  the lab rings (H6) widen to whatever the window now covers. The phase strip
//  below stays cycle-scoped either way — it is never x-aligned to the chart
//  (X11), whatever the window.
//

import SwiftUI

struct ChartWindowPicker: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(PKChartWindow.WindowMode.allCases) { mode in
                Button {
                    medicationManager.chartWindowMode = mode
                } label: {
                    Pill(text: mode.label,
                         style: medicationManager.chartWindowMode == mode ? .active : .neutral)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.accessibilityLabel)
                .accessibilityAddTraits(
                    mode == medicationManager.chartWindowMode ? [.isSelected] : []
                )
            }
        }
    }
}

private extension PKChartWindow.WindowMode {

    /// The chip label. Natural case, like the notification preset pills — the
    /// mono `pill` role carries the register (X31 rule).
    var label: String {
        switch self {
        case .cycle:
            String(localized: "Cycle",
                   comment: "Home chart window chip: the ester-tuned cycle view")
        case .days90:
            String(localized: "90 D",
                   comment: "Home chart window chip: the 90-day trend view. Keep short — it is a chip.")
        case .all:
            String(localized: "All",
                   comment: "Home chart window chip: everything logged")
        }
    }

    /// What VoiceOver reads — the chip's "90 D" is a visual compromise the
    /// label shouldn't inherit.
    var accessibilityLabel: String {
        switch self {
        case .cycle:
            String(localized: "Cycle window",
                   comment: "Accessibility label for the Cycle chart-window chip")
        case .days90:
            String(localized: "90 days",
                   comment: "Accessibility label for the 90-day chart-window chip")
        case .all:
            String(localized: "All time",
                   comment: "Accessibility label for the All-time chart-window chip")
        }
    }
}

#if DEBUG
#Preview {
    ChartWindowPicker()
        .environment(\.medicationManager, MedicationManager.shared)
}
#endif
