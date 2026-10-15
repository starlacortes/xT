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
    @Environment(\.appRouter) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Scrub state — bound to FlatGraphView, read by HomeReadout.
    @State private var scrubFraction: CGFloat? = nil
    @State private var scrubValue: Double? = nil
    @State private var scrubDate: Date? = nil

    // Measured block heights → the curve's plot insets (H1).
    @State private var readoutBlockHeight: CGFloat = 0
    @State private var bottomBlockHeight: CGFloat = 0

    // Measured picker width → the readout block's trailing clearance, so the
    // eyebrow never slides under the flush-top-right chips (X12c).
    @State private var pickerWidth: CGFloat = 0

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
        .onPreferenceChange(PickerWidthKey.self) { pickerWidth = $0 }
        .onAppear {
            medicationManager.refreshState()
        }
        // X19: the curve morph (driven by FlatGraphView's onChange of the data) is the
        // celebration. A single success haptic marks the moment; no confetti, no glow.
        // `.sensoryFeedback` honors the system haptic setting for us (H13 step 6).
        .sensoryFeedback(.success, trigger: medicationManager.doseRecordedCount)
        // The one record-dose sheet (H13). Both the card's Log Dose button and a
        // notification route (N2) raise it through the router.
        .sheet(isPresented: Bindable(router).presentRecordDose) {
            QuickDoseSheet(isPresented: Bindable(router).presentRecordDose)
                .environment(\.medicationManager, medicationManager)
        }
    }

    // MARK: - Configured home

    private func configuredHome(hPad: CGFloat) -> some View {
        let insets = EdgeInsets(top: readoutBlockHeight + plotClearance,
                                leading: 0,
                                bottom: bottomBlockHeight + plotClearance
                                    + HomeLayout.dayAxisHeight,
                                trailing: 0)
        return ZStack(alignment: .top) {
            FlatGraphView(plotInsets: insets,
                          scrubFraction: $scrubFraction,
                          scrubValue: $scrubValue,
                          scrubDate: $scrubDate)

            // Flush readout, top-left — its eyebrow row is kept clear of the
            // picker's share of the band by the measured trailing clearance.
            VStack {
                HomeReadout(scrubValue: scrubValue, scrubDate: scrubDate,
                            trailingClearance: pickerWidth + Theme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, hPad)
                    .padding(.top, Theme.Spacing.md)
                    .background(heightReader(ReadoutBlockHeightKey.self))
                Spacer(minLength: 0)
            }

            // Window picker (X12c), flush top-right — the readout's twin at
            // the other corner of the same band. Its measured width becomes the
            // readout's trailing clearance; the curve's top inset clears both.
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    ChartWindowPicker()
                        .background(widthReader(PickerWidthKey.self))
                }
                .padding(.horizontal, hPad)
                .padding(.top, Theme.Spacing.md)
                Spacer(minLength: 0)
            }

            // Phase strip + overlay card, docked above the tab bar.
            VStack(spacing: Theme.Spacing.sm) {
                Spacer(minLength: 0)
                // The measured container holds only the strip + card. The docking
                // Spacer stays outside it: a Spacer expands to whatever height the
                // ZStack proposes, so measuring the outer VStack reported the
                // whole screen as the block's height. That bottom inset then
                // pushed `plotBottom` to its `plotTop + 1` floor and the curve
                // drew into a one-point band — flat regardless of the data (H1).
                VStack(spacing: Theme.Spacing.sm) {
                    // Stationary columns share the card's margins (H9).
                    PhaseStripView()
                        .padding(.horizontal, hPad)
                    HomeOverlayCard()
                        .padding(.horizontal, hPad)
                }
                .background(heightReader(OverlayCardHeightKey.self))
            }
            .padding(.bottom, Theme.Spacing.sm)
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

    private func widthReader<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        GeometryReader { proxy in
            Color.clear.preference(key: key, value: proxy.size.width)
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

/// Width of the chart-window picker — the readout block's trailing clearance, so the
/// eyebrow never slides under the flush-top-right chips (X12c).
private struct PickerWidthKey: PreferenceKey {
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
