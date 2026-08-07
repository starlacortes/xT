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
    @State private var celebrationGlowTrigger: Int = 0

    // Scrub state — bound to FlatGraphView, read by LevelOverlayView
    @State private var scrubFraction: CGFloat? = nil
    @State private var scrubValue: Double? = nil
    @State private var scrubDate: Date? = nil

    // Background depth: starts slightly darkened, then lightens.
    @State private var backgroundDepthOpacity: Double = 0.25

    // Entrance phases for cascading reveals
    @State private var homeAppeared: Bool = false

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
                                      journalEntries: journalManager.entries,
                                      scrubFraction: $scrubFraction,
                                      scrubValue: $scrubValue,
                                      scrubDate: $scrubDate)
                            .opacity(homeAppeared ? 1 : 0.3)
                            .scaleEffect(homeAppeared ? 1 : 0.97)
                    }

                    if medicationManager.isFullyConfigured {
                        LevelOverlayView(scrubValue: scrubValue, scrubDate: scrubDate)
                            .celebrationGlow(trigger: celebrationGlowTrigger)
                            .entranceScale(delay: 0.45)
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
                            .background(Color.clear.contentShape(Rectangle()))
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

            // Lighten the background veil using a gentle spring for smooth settling.
            withAnimation(.spring(duration: 1.5, bounce: 0.0)) {
                backgroundDepthOpacity = 0
            }

            // Cascade the chart → overlay entrance with staggered springs.
            withAnimation(.spring(duration: 0.8, bounce: 0.0).delay(0.15)) {
                homeAppeared = true
            }
        }
        .onChange(of: medicationManager.doseRecordedCount) { _, newCount in
            guard newCount > lastRecordedCount else { return }
            lastRecordedCount = newCount

            // Delay celebration so the recording sheet has time to finish
            // dismissing first. Without this, the confetti runs behind the sheet
            // and is invisible to the user. The delay is per-flow (each sheet
            // dismisses on its own schedule) — read once, then reset to the
            // default so it doesn't leak into the next dose recorded elsewhere.
            let delay = medicationManager.celebrationDelay
            medicationManager.celebrationDelay = MedicationManager.defaultCelebrationDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                confettiTrigger &+= 1
                celebrationGlowTrigger &+= 1
                celebrateDose = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    celebrateDose = false
                }
            }
        }
    }
}

// MARK: - Dose Celebration Confetti

/// Full-screen confetti burst played when a dose is recorded.
/// Particles fan out from the centre of `size`, drift downward, then fade.
/// Re-mount (via `.id`) to replay. Uses spring-based animations for
/// a more natural, physical scatter per WWDC23 recommendations.
private struct HomeConfettiBurst: View {
    let size: CGSize

    private let particleCount = 28

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

/// A single confetti dot: fans out on a random heading, falls slightly,
/// shrinks and fades. Uses spring bursts for a livelier, more natural feel.
private struct HomeConfettiParticle: View {
    let index: Int
    let total: Int

    @State private var opacity: Double = 1
    @State private var scale: Double = 0.25
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var diameter: CGFloat = .random(in: 4...8)
    @State private var shapeSeed: Int = Int.random(in: 0...2)

    private var color: Color {
        index.isMultiple(of: 3) ? Theme.Colors.accent
            : index.isMultiple(of: 2) ? Theme.Colors.accentSecondary
            : Color(lightHex: "#F4A8C0", darkHex: "#F4A8C0")
    }

    var body: some View {
        confettiShape
            .fill(color.opacity(opacity))
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .onAppear {
                let spread = (.pi * 2) / Double(max(total, 1))
                let angle = (Double(index) * spread) + Double.random(in: -spread/2...spread/2)
                let radius = Double.random(in: 70...200)
                let gravity = Double.random(in: 35...100)

                withAnimation(.spring(duration: Double.random(in: 0.6...1.0), bounce: Double.random(in: 0.15...0.35))
                    .delay(Double.random(in: 0...0.18))) {
                    offset = CGSize(width: cos(angle) * radius,
                                    height: sin(angle) * radius + gravity)
                    scale = 0
                    opacity = 0
                    rotation = Double.random(in: -720...720)
                }
            }
    }

    private var confettiShape: AnyShape {
        switch shapeSeed {
        case 0: AnyShape(Circle())
        case 1: AnyShape(RoundedRectangle(cornerRadius: 1.5))
        default: AnyShape(Capsule())
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

#if DEBUG
#Preview {
    SpoofPreview {
        HomeView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.journalManager, JournalManager.shared)
    }
}
#endif
