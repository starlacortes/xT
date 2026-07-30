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

    // Celebration state
    @State private var celebrateDose: Bool = false
    @State private var lastRecordedCount: Int = 0
    @State private var confettiTrigger: Int = 0

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
                        HomeConfettiBurst(size: geo.size)
                            .id(confettiTrigger)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .allowsHitTesting(false)
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
            confettiTrigger &+= 1
            celebrateDose = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                celebrateDose = false
            }
        }
    }
}

// MARK: - Dose Celebration Confetti

/// Full-screen confetti burst played when a dose is recorded.
/// Particles fan out from the centre of `size`, drift downward, then fade.
/// Re-mount (via `.id`) to replay.
private struct HomeConfettiBurst: View {
    let size: CGSize

    private let particleCount = 24

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                HomeConfettiParticle(index: index, total: particleCount)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A single confetti dot: fans out on a random heading, falls slightly, shrinks and fades.
private struct HomeConfettiParticle: View {
    let index: Int
    let total: Int

    @State private var opacity: Double = 1
    @State private var scale: Double = 0.3
    @State private var offset: CGSize = .zero
    @State private var diameter: CGFloat = .random(in: 5...9)

    /// Alternate palette colours so the burst reads as confetti, not a single-hue puff.
    private var color: Color {
        index.isMultiple(of: 2) ? Theme.Colors.accent : Theme.Colors.accentSecondary
    }

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .offset(offset)
            .onAppear {
                // Evenly spread the base heading, then jitter so the ring never looks mechanical.
                let spread = (.pi * 2) / Double(max(total, 1))
                let angle = (Double(index) * spread) + Double.random(in: -spread / 2...spread / 2)
                let radius = Double.random(in: 60...170)
                let gravity = Double.random(in: 30...90)

                withAnimation(.easeOut(duration: Double.random(in: 0.9...1.1))
                    .delay(Double.random(in: 0...0.14))) {
                    offset = CGSize(width: cos(angle) * radius,
                                    height: sin(angle) * radius + gravity)
                    scale = 0
                    opacity = 0
                }
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
