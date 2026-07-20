//
//  HomeView.swift
//  xT
//
//  Flat home layout. HeroView bleeds into FlatGraphView, then the card
//  stack — everything lives on the system background surface, with a
//  soft parallaxed colour wash behind the top of the scroll.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showingGraphDetail = false
    @State private var scrollOffset: CGFloat = 0

    // -- Celebration iris state --
    @State private var celebrateDose: Bool = false
    @State private var lastRecordedCount: Int = 0

    // -- Scalable metrics (grow with Dynamic Type, capped for accessibility) --
    @ScaledMetric private var minHorizontalPad: CGFloat = 18
    @ScaledMetric private var maxHorizontalPad: CGFloat = 60
    @ScaledMetric private var graphHeightCompact: CGFloat = 170
    @ScaledMetric private var graphHeightRegular: CGFloat = 200

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let compactHeight = geo.size.height < 700
                let isWide = horizontalSizeClass == .regular || geo.size.width > 500

                // --- Dynamic horizontal padding ---
                let proportionalPad = min(max(geo.size.width * 0.095, minHorizontalPad), maxHorizontalPad)
                let hPad = isWide ? max(40, proportionalPad) : proportionalPad

                ZStack(alignment: .top) {
                    Color(.systemBackground).ignoresSafeArea()

                    HomeColorBackdrop(scrollOffset: scrollOffset)

                    ScrollView {
                        VStack(spacing: 0) {
                            HeroView(compactHeight: compactHeight, isWide: isWide, horizontalPadding: hPad)

                            if medicationManager.isFullyConfigured {
                                FlatGraphView(
                                    showingGraphDetail: $showingGraphDetail,
                                    compactHeight: compactHeight,
                                    graphHeight: isWide ? graphHeightRegular : graphHeightCompact
                                )
                                .padding(.top, 18)
                                .entrance(delay: 0.22)
                            }

                            MainContentView(showingGraphDetail: $showingGraphDetail, isWide: isWide)
                                .padding(.horizontal, hPad)
                                .padding(.top, 20)
                                .padding(.bottom, 40)
                        }
                        .frame(maxWidth: isWide ? 760 : .infinity)
                        .frame(maxWidth: .infinity)
                        .readScrollOffset(in: "homeScroll", binding: $scrollOffset)
                    }

                    // Celebration iris overlay — expands from center on dose recorded
                    if celebrateDose {
                        Color.clear
                            .phaseAnimator(
                                IrisPhase.allCases,
                                trigger: celebrateDose
                            ) { _, phase in
                                Circle()
                                    .stroke(Color.primary.opacity(phase.ringOpacity),
                                            lineWidth: phase.ringWidth)
                                    .frame(width: phase.diameter, height: phase.diameter)
                                    .blur(radius: phase.blur)
                            } animation: { phase in
                                switch phase {
                                case .appear:
                                    return nil  // snapshot current state
                                case .expand:
                                    return .spring(response: 0.5, dampingFraction: 0.65)
                                case .vanish:
                                    return .easeOut(duration: 0.35)
                                }
                            }
                            .allowsHitTesting(false)  // don't block taps
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .coordinateSpace(.named("homeScroll"))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingGraphDetail) {
            GraphView()
                .environment(\.medicationManager, medicationManager)
        }
        .onAppear {
            medicationManager.refreshState()
            lastRecordedCount = medicationManager.doseRecordedCount
        }
        // Reactive refresh: fire when a new dose is recorded anywhere
        .onChange(of: medicationManager.doseRecordedCount) { newCount in
            guard newCount > lastRecordedCount else { return }
            lastRecordedCount = newCount
            medicationManager.refreshState()
            // Trigger celebration iris
            celebrateDose = true
            // Reset after animation completes (~1s)
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

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
