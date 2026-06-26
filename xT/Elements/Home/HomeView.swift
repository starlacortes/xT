//
//  HomeView.swift
//  xT
//
//  Home tab. HeroView goes full-bleed; MainContentView gets consistent
//  horizontal padding from here so child cards don't double-pad.
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

                    MainContentView(showingGraphDetail: $showingGraphDetail)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
            .coordinateSpace(.named("homeScroll"))
            .toolbar(.hidden, for: .navigationBar)
            .background(AnimatedMeshGradient().ignoresSafeArea())
        }
        .sheet(isPresented: $showingGraphDetail) {
            GraphView()
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
