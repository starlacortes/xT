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

    private var isScrubbing: Bool { scrubValue != nil }

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

                if let level = level {
                    HStack(spacing: 8) {
                        Text(unitLabel(level))
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(isScrubbing ? accent : Theme.Colors.Graph.levelTextSecondary)

                        // Hide the status moniker while the user is scrubbing.
                        if !isScrubbing {
                            RangePill(text: statusLabel(level), color: statusColor(level))
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
        .animation(.easeOut(duration: 0.15), value: scrubValue)
    }

    // MARK: - Derived from manager's classification
    
    /// The primary status keyword extracted from the manager's range string.
    /// e.g. "On Target · Mid-cycle" → "On Target"
    private func statusLabel(_ level: HormoneLevel) -> String {
        let status = level.range.components(separatedBy: " · ").first ?? level.range
        // Simplify verbose safety labels for the pill
        if status.contains("Safety Check") { return "Safety Check" }
        if status.contains("Sub-Therapeutic") { return "Sub-Therapeutic" }
        if status.hasPrefix("Low (Spiro") { return "Low" }
        return status
    }

    private func unitLabel(_ level: HormoneLevel) -> String {
        let hormone = medicationManager.selectedMedication ?? ""
        return "\(level.unit) · \(hormone)"
    }
    
    private func statusColor(_ level: HormoneLevel) -> Color {
        let status = level.range.components(separatedBy: " · ").first ?? ""
        if status.contains("On Target")             { return Theme.Colors.success }
        if status.contains("Slightly")              { return Theme.Colors.accent }
        if status.contains("Critically") || status.contains("Safety") || status.contains("Supraphysiological") || status.contains("Sub-Therapeutic") {
            return Theme.Colors.error
        }
        if status.contains("Very Low") || status.contains("High") || status.contains("Low") {
            return Theme.Colors.warning
        }
        return Theme.Colors.accent
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

#Preview {
    ZStack {
        Theme.Colors.glassTint.ignoresSafeArea()
        LevelOverlayView(scrubValue: 284)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
