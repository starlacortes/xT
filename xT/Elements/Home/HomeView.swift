//
//  HomeView.swift
//  xT
//
//  Flat home layout. HeroView bleeds into FlatGraphView, then the card
//  stack — everything lives on the system background surface.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingGraphDetail = false

    var body: some View {
        NavigationStack {
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
            }
            .coordinateSpace(.named("homeScroll"))
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground).ignoresSafeArea())
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
