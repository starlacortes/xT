//
//  HomeView.swift
//  xT
//
//  Unified home layout: full-bleed animated FlatGraphView background,
//  level overlay, and scrollable unified glass stack.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Celebration iris state
    @State private var celebrateDose: Bool = false
    @State private var lastRecordedCount: Int = 0

    // Scrub state — bound to FlatGraphView, read by LevelOverlayView
    @State private var scrubFraction: CGFloat? = nil
    @State private var scrubValue: Double? = nil
    @State private var scrubDate: Date? = nil

    // Background depth: starts slightly darkened, then lightens.
    @State private var backgroundDepthOpacity: Double = 0.25

    // Scalable metrics
    @ScaledMetric private var minHorizontalPad: CGFloat = 18
    @ScaledMetric private var maxHorizontalPad: CGFloat = 60

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isWide = horizontalSizeClass == .regular || geo.size.width > 500

                let proportionalPad = min(max(geo.size.width * 0.095, minHorizontalPad), maxHorizontalPad)
                let hPad = isWide ? max(40, proportionalPad) : proportionalPad

                ZStack(alignment: .top) {
                    HomeGradientBackground()
                        .ignoresSafeArea()

                    // Darkening veil that fades out as the chart comes to life.
                    Color.black.opacity(backgroundDepthOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    if medicationManager.isFullyConfigured {
                        FlatGraphView(dataRegionFraction: 0.55,
                                      scrubFraction: $scrubFraction,
                                      scrubValue: $scrubValue,
                                      scrubDate: $scrubDate)
                    }

                    if medicationManager.isFullyConfigured {
                        LevelOverlayView(scrubValue: scrubValue)
                    }

                    if celebrateDose {
                        if #available(iOS 17.0, *) {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .phaseAnimator(
                                    IrisPhase.allCases
                                ) { _, phase in
                                    Circle()
                                        .stroke(Color.primary.opacity(phase.ringOpacity),
                                                lineWidth: phase.ringWidth)
                                        .frame(width: phase.diameter, height: phase.diameter)
                                        .blur(radius: phase.blur)
                                } animation: { phase in
                                    switch phase {
                                    case .appear: return nil
                                    case .expand: return .spring(response: 0.5, dampingFraction: 0.65)
                                    case .vanish: return .easeOut(duration: 0.35)
                                    }
                                }
                                .allowsHitTesting(false)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay(alignment: .bottom) {
                    if medicationManager.isFullyConfigured {
                        UnifiedStackView()
                            .padding(.horizontal, hPad)
                            .padding(.bottom, Theme.Spacing.sm)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "pills.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

                            Text("Set up your medication")
                                .font(Theme.Fonts.title2)
                                .foregroundStyle(.primary)

                            Text("Add your medication details to see hormone levels, insights, and dose tracking.")
                                .font(Theme.Fonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.vertical, 60)
                        .frame(maxWidth: isWide ? 760 : .infinity)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            medicationManager.refreshState()
            lastRecordedCount = medicationManager.doseRecordedCount

            // Lighten the background over the same period as the chart entrance.
            withAnimation(.easeOut(duration: 1.5)) {
                backgroundDepthOpacity = 0
            }
        }
        .onChange(of: medicationManager.doseRecordedCount) { _, newCount in
            guard newCount > lastRecordedCount else { return }
            lastRecordedCount = newCount
            medicationManager.refreshState()
            celebrateDose = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                celebrateDose = false
            }
        }
    }
}

// MARK: - Iris Celebration Phases

private enum IrisPhase: CaseIterable, Equatable {
    case appear, expand, vanish

    var diameter: CGFloat {
        switch self {
        case .appear: return 10
        case .expand:  return 280
        case .vanish:  return 340
        }
    }

    var ringWidth: CGFloat {
        switch self {
        case .appear: return 1.5
        case .expand:  return 0.8
        case .vanish:  return 0.3
        }
    }

    var ringOpacity: CGFloat {
        switch self {
        case .appear: return 0.25
        case .expand:  return 0.12
        case .vanish:  return 0
        }
    }

    var blur: CGFloat {
        switch self {
        case .appear: return 0
        case .expand:  return 4
        case .vanish:  return 8
        }
    }
}

// MARK: - Background Gradient

/// Full-bleed gradient background — dark purple gradient with ambient rose/purple glows.
private struct HomeGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Theme.Colors.Graph.baseTop,
                    Theme.Colors.Graph.baseMid,
                    Theme.Colors.Graph.baseDark
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Theme.Colors.Graph.topGlow.opacity(0.22), location: 0),
                    .init(color: Theme.Colors.Graph.topGlow.opacity(0), location: 1)
                ]),
                startPoint: .top,
                endPoint: UnitPoint(x: 0, y: 0.5)
            )

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Theme.Colors.Graph.rightGlow.opacity(0.18), location: 0),
                    .init(color: Theme.Colors.Graph.rightGlow.opacity(0), location: 1)
                ]),
                startPoint: .trailing,
                endPoint: .leading
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SpoofPreview {
        HomeView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.journalManager, JournalManager.shared)
    }
}
