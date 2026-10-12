//
//  HomeReadout.swift
//  xT
//
//  The Home level readout (element H2). Type flush on the paper — no card, no material.
//  Replaces `LevelOverlayView`, which parked a translucent card over the curve and dodged
//  the now dot. Here the readout simply sits top-left on the paper and the curve is drawn
//  to clear it (the plot's top inset tracks this block's height, H1).
//
//  Four lines, top to bottom (§7):
//    • eyebrow   — ESTRADIOL VALERATE · DAY 3 OF 7   (MedicationDisplayFormatter)
//    • number    — the modeled level, mono 500 · 52, with its unit (mono, muted)
//    • provenance — MODELED · CALIBRATED TO YOUR LAB OF 4 MAR   (LevelProvenance → H2 copy)
//    • status / safety — AT TROUGH · WITHIN YOUR SET TROUGH, and the X10 safety pill
//
//  While scrubbing the number turns accent and the provenance line becomes the scrub time.
//

import SwiftUI

struct HomeReadout: View {
    @Environment(\.medicationManager) private var medicationManager

    /// Scrubbed value from the curve — when non-nil it overrides the current level.
    var scrubValue: Double? = nil
    /// Scrubbed date from the curve — drives the provenance line while scrubbing.
    var scrubDate: Date? = nil

    @State private var showingSafetyNote = false

    private var isScrubbing: Bool { scrubValue != nil }

    var body: some View {
        let level = medicationManager.currentHormoneLevel
        let displayValue = scrubValue ?? level?.value
        let numberColor = isScrubbing ? Theme.Colors.accent : Theme.Colors.textPrimary

        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            if let eyebrow = MedicationDisplayFormatter.readoutEyebrow(medicationManager) {
                Text(eyebrow).eyebrow()
            }

            if let displayValue {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    AnimatedCounter(value: displayValue,
                                    format: { AppNumberFormatters.hormoneLevel.string($0) })
                        .font(Theme.Fonts.readout)
                        .foregroundStyle(numberColor)

                    if let level {
                        Text(level.unit.symbol)
                            .monoLabel()
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            provenanceLine

            if !isScrubbing, let level {
                statusAndSafety(for: level)
            }
        }
        .animation(Theme.Motion.snappy, value: scrubValue)
    }

    // MARK: - Provenance

    @ViewBuilder
    private var provenanceLine: some View {
        let text: String = {
            if let scrubDate {
                return MedicationDisplayFormatter.scrubProvenanceLine(scrubDate)
            }
            return MedicationDisplayFormatter.provenanceLine(medicationManager.levelProvenance)
        }()

        Text(text)
            .statLabel()
            .foregroundStyle(isScrubbing ? Theme.Colors.accent : Theme.Colors.textSecondary)
    }

    // MARK: - Status line + safety pill

    @ViewBuilder
    private func statusAndSafety(for level: HormoneLevel) -> some View {
        // X18: the position/relation line, reserved words only, never a goal.
        if level.safety == nil, let status = statusLine(for: level) {
            Text(status)
                .statLabel()
                .foregroundStyle(Theme.Colors.textSecondary)
        }

        // X10: the one red element — gated only on a real SafetyFlag, outline, no fill.
        if level.safety != nil, let pill = level.statusPillText {
            SafetyPill(text: pill) { showingSafetyNote.toggle() }

            if showingSafetyNote, let note = level.safetyNote {
                Text(note)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Spacing.tiny)
            }
        }
    }

    /// "AT TROUGH · WITHIN YOUR SET TROUGH" — cycle position, then the user-range relation
    /// if the user set one. Either clause may be absent.
    private func statusLine(for level: HormoneLevel) -> String? {
        let phase = level.phase.phaseDescription
        let relation = level.statusPillText   // nil unless the user set a range
        switch (phase, relation) {
        case let (p?, r?): return "\(p) · \(r)"
        case let (p?, nil): return p
        case let (nil, r?): return r
        case (nil, nil):    return nil
        }
    }
}

// MARK: - Safety pill (X10)

/// The single red element in the system: a `safety`-outlined pill with a glyph, no fill.
/// Tapping surfaces the clinical note. Never gated by calibration or entitlement.
private struct SafetyPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.tiny) {
                Image(systemName: "exclamationmark.triangle")
                Text(text)
            }
            .font(Theme.Fonts.label)
            .foregroundStyle(Theme.Colors.safety)
            .padding(.horizontal, Theme.Spacing.row)
            .padding(.vertical, Theme.Spacing.tiny)
            .overlay(
                Capsule().strokeBorder(Theme.Colors.safety, lineWidth: Theme.Line.hairline)
            )
        }
        .buttonStyle(.pressable)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Theme.Colors.appBackground.ignoresSafeArea()
        HomeReadout(scrubValue: 284)
            .environment(\.medicationManager, MedicationManager.shared)
            .padding()
    }
}
#endif
