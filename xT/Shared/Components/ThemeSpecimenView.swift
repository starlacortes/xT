//
//  ThemeSpecimenView.swift
//  xT
//
//  The Appearance hue specimen (element S11). A near-square window (1 : 1.08) of
//  sample app chrome that follows the hue dial, so the picker shows the app in the
//  chosen color rather than an abstract swatch. Shared by Settings → Appearance (ST8)
//  and onboarding (O1).
//
//  It is **composed from the real primitives at their real sizes** (readout role,
//  range band + curve + now point, phase `Pill`s, a dose `paperCard` with the one
//  `ActionPill`, chips, a `SettingsIconTile`, a `Toggle`, the "I." mark) over a static
//  `SpecimenSample` fixture — never a screenshot, never the user's own numbers.
//
//  Day/Night is previewed by scoping `\.colorScheme` to this view alone; the host owns
//  the "Day" · "Night" `Pill`s. Dynamic Type is capped at `.large` — it's a preview,
//  not a live surface.
//

import SwiftUI

/// Static sample data for the specimen. Deliberately generic — not tied to any
/// persona or the user's real medication.
enum SpecimenSample {
    static let readout = "128"
    static let unit = "pg/mL"
    static let provenance = "MODELLED · 2D AGO"
    static let phases = ["Rise", "Peak", "Trough"]
    static let chips = ["Within range", "Due in 2d"]
    /// Normalised curve points (x, y in 0…1). A single rise-and-settle sweep.
    static let curve: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.70), CGPoint(x: 0.18, y: 0.34),
        CGPoint(x: 0.38, y: 0.22), CGPoint(x: 0.60, y: 0.40),
        CGPoint(x: 0.82, y: 0.58), CGPoint(x: 1.00, y: 0.50)
    ]
    /// Range band as a normalised y-interval (lower, upper).
    static let band: (lower: CGFloat, upper: CGFloat) = (0.30, 0.62)
    /// The now point along the curve.
    static let now = CGPoint(x: 0.60, y: 0.40)
}

struct ThemeSpecimenView: View {
    /// The color scheme to render the sample in — the host's Day/Night selection.
    var preview: ColorScheme = .light

    /// `components.specimen.aspect` — height ÷ width, per the tokens.
    private static let aspect: CGFloat = 1.08

    var body: some View {
        content
            .environment(\.colorScheme, preview)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .background(specimenShape.fill(Theme.Colors.appBackground))
            .clipShape(specimenShape)
            .overlay(specimenShape.strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline))
            .aspectRatio(1 / Self.aspect, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Preview of the app in the chosen hue"))
    }

    private var specimenShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.specimen, style: .continuous)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            readoutBlock
            curveBlock
            phaseStrip
            doseCard
            footerRow
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Readout

    private var readoutBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SpecimenSample.provenance)
                .eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(SpecimenSample.readout)
                    .font(Theme.Fonts.readout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(SpecimenSample.unit)
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monoLabel()
            }
        }
    }

    // MARK: - Curve

    private var curveBlock: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // A nested `func` can't live inside a ViewBuilder closure, so the
            // mapping is a captured closure over `w`/`h` instead.
            let point = { (p: CGPoint) -> CGPoint in CGPoint(x: p.x * w, y: p.y * h) }

            ZStack {
                // Neutral range band — a quiet reference, never a pass/fail color (H5).
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.08))
                    .frame(height: (SpecimenSample.band.upper - SpecimenSample.band.lower) * h)
                    .position(x: w / 2,
                              y: (SpecimenSample.band.lower + SpecimenSample.band.upper) / 2 * h)

                // The sweep.
                Path { path in
                    let pts = SpecimenSample.curve.map(point)
                    path.move(to: pts[0])
                    for p in pts.dropFirst() { path.addLine(to: p) }
                }
                .stroke(Theme.Colors.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Concentric now point.
                let now = point(SpecimenSample.now)
                Circle().fill(Theme.Colors.accent.opacity(0.25)).frame(width: 14, height: 14).position(now)
                Circle().fill(Theme.Colors.accent).frame(width: 6, height: 6).position(now)
            }
        }
        .frame(height: 64)
    }

    // MARK: - Phase strip

    private var phaseStrip: some View {
        HStack(spacing: Theme.Spacing.tiny) {
            ForEach(Array(SpecimenSample.phases.enumerated()), id: \.offset) { index, phase in
                Pill(text: phase, style: index == 1 ? .active : .neutral)
            }
        }
    }

    // MARK: - Dose card + chips

    private var doseCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.tiny) {
                ForEach(SpecimenSample.chips, id: \.self) { chip in
                    Pill(text: chip)
                }
            }
            ActionPill(title: "Log Dose", systemImage: "syringe") {}
                .allowsHitTesting(false)
        }
        .paperCard(padding: Theme.Spacing.md, radius: Theme.Radius.md)
    }

    // MARK: - Footer: icon tile · toggle · the mark

    private var footerRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            SettingsIconTile(icon: "paintbrush.fill")

            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .tint(Theme.Colors.accent)
                .allowsHitTesting(false)

            Spacer()

            // Stand-in for the "I." app icon — the serif mark on the brand ground.
            Text(verbatim: "I.")
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.OnAccent.primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Theme.Colors.accent)
                )
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: Theme.Spacing.md) {
        ThemeSpecimenView(preview: .light)
        ThemeSpecimenView(preview: .dark)
    }
    .padding(Theme.Spacing.Gutter.screen)
    .background(Theme.Colors.appBackground)
}
#endif
