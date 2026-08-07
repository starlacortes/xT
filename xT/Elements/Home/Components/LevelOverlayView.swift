//
//  LevelOverlayView.swift
//  xT
//
//  Hormone level badge: "Estimated" → large number → unit + range pill.
//  Reads from MedicationManager.currentHormoneLevel (PK-model estimate).
//  Shifts horizontally away from the graph's peak so text and peak don't collide.
//

import SwiftUI

struct LevelOverlayView: View {
    @Environment(\.medicationManager) private var medicationManager

    /// Scrubbed value from graph interaction — when non-nil, overrides current level.
    var scrubValue: Double? = nil

    /// Scrubbed date from graph interaction — drives the relative-time label.
    var scrubDate: Date? = nil

    private var isScrubbing: Bool { scrubValue != nil }

    private var scrubTimeLabel: String? {
        guard let date = scrubDate else { return nil }
        let interval = Swift.abs(date.timeIntervalSinceNow)
        if interval < 3 * 60      { return "~now" }
        if interval < 90 * 60     { return "~\(Int(interval / 60))min" }
        if interval < 48 * 3600   { return "~\(Int((interval / 3600).rounded()))hrs" }
        return "~\(Int((interval / 86400).rounded())) days"
    }

    private var scrubTimeColor: Color {
        guard let date = scrubDate else { return .secondary }
        return date < .now ? Theme.Colors.Graph.levelTextSecondary : Theme.Colors.accent
    }

    /// Horizontal position (0…1) of the highest point across the recent-levels curve.
    private var peakFraction: CGFloat {
        let values = medicationManager.recentLevels.map(\.value)
        guard values.count > 1 else { return 0.5 }
        if let peakIdx = values.indices.max(by: { values[$0] < values[$1] }) {
            return CGFloat(peakIdx) / CGFloat(values.count - 1)
        }
        return 0.5
    }

    var body: some View {
        let displayLevel = scrubValue ?? medicationManager.currentHormoneLevel?.value
        let level = medicationManager.currentHormoneLevel
        let alignRight = peakFraction < 0.45

        let accent = Theme.Colors.accent

        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            Text("Estimated")
                .font(Theme.Fonts.caption)
                .foregroundStyle(isScrubbing ? accent : Theme.Colors.Graph.levelTextSecondary)
                .tracking(0.01)

            if let value = displayLevel {
                AnimatedCounter(value: value)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(isScrubbing ? accent : Theme.Colors.Graph.levelText)
                    .tracking(-0.04 * 52)

                if isScrubbing, let label = scrubTimeLabel {
                    Text(label)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(scrubTimeColor)
                        .tracking(0.01)
                }

                if let level = level {
                    HStack(spacing: 8) {
                        Text(unitLabel(level))
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(isScrubbing ? accent : Theme.Colors.Graph.levelTextSecondary)

                        // Hide the status pill while the user is scrubbing. It is
                        // also absent when there is nothing factual to assert —
                        // no user-set range and no threshold crossed.
                        if !isScrubbing, let pill = level.statusPillText {
                            RangePill(text: pill, color: level.statusTint)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            medicationManager.doseHistory.isEmpty
                ? AnyShapeStyle(.clear)
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .padding(.top, 56)
        .frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.075), value: scrubValue)
        .animation(.easeOut(duration: 0.075), value: scrubDate)
    }

    // MARK: - Derived from manager's classification

    private func unitLabel(_ level: HormoneLevel) -> String {
        let hormone = medicationManager.selectedMedication ?? ""
        return "\(level.unit.symbol) · \(hormone)"
    }
}

// MARK: - Range Pill

private struct RangePill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(Capsule())
    }
}

#if DEBUG
#Preview {
    ZStack {
        Theme.Colors.glassTint.ignoresSafeArea()
        LevelOverlayView(scrubValue: 284)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
