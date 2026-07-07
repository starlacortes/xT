//
//  HomeView.swift
//  xT
//
//  Flat home layout. HeroView bleeds into FlatGraphView, then the card
//  stack — everything lives on the system background surface, with a
//  soft parallaxed color wash behind the top of the scroll.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingGraphDetail = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground).ignoresSafeArea()

                HomeColorBackdrop(scrollOffset: scrollOffset)

                ScrollView {
                    VStack(spacing: 0) {
                        HeroView()

                        if medicationManager.isFullyConfigured {
                            FlatGraphView(showingGraphDetail: $showingGraphDetail)
                                .padding(.top, 18)
                                .entrance(delay: 0.22)
                        }

                        MainContentView(showingGraphDetail: $showingGraphDetail)
                            .padding(.horizontal, 22)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                    .readScrollOffset(in: "homeScroll", binding: $scrollOffset)
                }
            }
            .coordinateSpace(.named("homeScroll"))
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingGraphDetail) {
            GraphView()
                .environment(\.medicationManager, medicationManager)
        }
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
