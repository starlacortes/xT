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
        }
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
