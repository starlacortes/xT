//
//  HomeView.swift
//  xT
//
//  The Home screen on Isocline paper (elements H1, H10). Three layers compose over the
//  paper ground: the hero curve fills the safe area, the flush readout sits top-left, and
//  one overlay card (with the phase strip above it) docks above the tab bar. The curve's
//  `plotInsets` are driven by the measured heights of the readout and the bottom block, so
//  the data line always clears both — and reflows with a `settle` spring as the dose state
//  changes the card's height (H1).
//
//  The dark gradient canvas, the darkening veil, the dose-celebration confetti, and the
//  readout celebration glow all retire here (F4, X19): the curve morphing into its new
//  point is the celebration, with a single success haptic.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Scrub state — bound to FlatGraphView, read by HomeReadout.
    @State private var scrubFraction: CGFloat? = nil
    @State private var scrubValue: Double? = nil
    @State private var scrubDate: Date? = nil

    // Measured block heights → the curve's plot insets (H1).
    @State private var readoutBlockHeight: CGFloat = 0
    @State private var bottomBlockHeight: CGFloat = 0

    @State private var lastRecordedCount: Int = 0

    @ScaledMetric private var minHorizontalPad: CGFloat = 18
    @ScaledMetric private var maxHorizontalPad: CGFloat = 60

    /// Clearance between the data line and each block.
    private let plotClearance: CGFloat = 12

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isWide = horizontalSizeClass == .regular || geo.size.width > 500
                let proportionalPad = min(max(geo.size.width * 0.095, minHorizontalPad), maxHorizontalPad)
                let hPad = isWide ? max(40, proportionalPad) : proportionalPad

                ZStack(alignment: .top) {
                    Theme.Colors.appBackground
                        .ignoresSafeArea()

                    if medicationManager.isFullyConfigured {
                        configuredHome(hPad: hPad)
                    } else {
                        setupPrompt(isWide: isWide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onPreferenceChange(ReadoutBlockHeightKey.self) { readoutBlockHeight = $0 }
        .onPreferenceChange(OverlayCardHeightKey.self) { bottomBlockHeight = $0 }
        .onAppear {
            medicationManager.refreshState()
            lastRecordedCount = medicationManager.doseRecordedCount
        }
        .onChange(of: medicationManager.doseRecordedCount) { _, newCount in
            guard newCount > lastRecordedCount else { return }
            lastRecordedCount = newCount
            // X19: the curve morph (driven by FlatGraphView's onChange of the data) is the
            // celebration. A single success haptic marks the moment; no confetti, no glow.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Configured home

    private func configuredHome(hPad: CGFloat) -> some View {
        let insets = EdgeInsets(top: readoutBlockHeight + plotClearance,
                                leading: 0,
                                bottom: bottomBlockHeight + plotClearance,
                                trailing: 0)
        return ZStack(alignment: .top) {
            FlatGraphView(plotInsets: insets,
                          scrubFraction: $scrubFraction,
                          scrubValue: $scrubValue,
                          scrubDate: $scrubDate)

            // Flush readout, top-left.
            VStack {
                HomeReadout(scrubValue: scrubValue, scrubDate: scrubDate)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, hPad)
                    .padding(.top, Theme.Spacing.sm)
                    .background(heightReader(ReadoutBlockHeightKey.self))
                Spacer(minLength: 0)
            }

            // Phase strip + overlay card, docked above the tab bar.
            VStack(spacing: Theme.Spacing.sm) {
                Spacer(minLength: 0)
                PhaseStripView()
                HomeOverlayCard()
                    .padding(.horizontal, hPad)
            }
            .padding(.bottom, Theme.Spacing.sm)
            .background(heightReader(OverlayCardHeightKey.self))
        }
    }

    // MARK: - Setup prompt (unconfigured)

    private func setupPrompt(isWide: Bool) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "pills.fill")
                .font(Theme.Fonts.largeTitle)
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Set up your medication")
                .font(Theme.Fonts.title2)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Add your medication details to see hormone levels, insights, and dose tracking.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
        }
        .padding(.vertical, Theme.Spacing.section)
        .frame(maxWidth: isWide ? 760 : .infinity)
    }

    // MARK: - Height measurement

    private func heightReader<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        GeometryReader { proxy in
            Color.clear.preference(key: key, value: proxy.size.height)
        }
    }
}

// MARK: - Preference keys (H1)

/// Height of the flush readout block — the curve's top plot inset.
private struct ReadoutBlockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Height of the phase strip + overlay card block — the curve's bottom plot inset. Tracks
/// the card's live height as the dose state changes (H1).
private struct OverlayCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        HomeView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
