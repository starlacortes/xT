//
//  ChartWindowPicker.swift
//  xT
//
//  The Home curve's window control (X12c): the ester-tuned cycle view or the
//  past two weeks. Sits flush top-right, the readout's
//  twin at the other corner of the same band, kept clear of it by a measured
//  trailing inset — chips on paper.
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
                        // The chip itself stays small; the 44pt frame is the tap
                        // zone. The band sits flush against the top edge, where a
                        // chip-sized target is genuinely hard to hit.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
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
        case .fortnight:
            String(localized: "2 W",
                   comment: "Home chart window chip: the two-week view. Keep short — it is a chip.")
        }
    }

    /// What VoiceOver reads — the chip's "2 W" is a visual compromise the
    /// label shouldn't inherit.
    var accessibilityLabel: String {
        switch self {
        case .cycle:
            String(localized: "Cycle window",
                   comment: "Accessibility label for the Cycle chart-window chip")
        case .fortnight:
            String(localized: "Two weeks",
                   comment: "Accessibility label for the two-week chart-window chip")
        }
    }
}

#if DEBUG
#Preview {
    ChartWindowPicker()
        .environment(\.medicationManager, MedicationManager.shared)
}
#endif
