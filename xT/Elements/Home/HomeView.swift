//
//  HomeView.swift
//  xT
//
//  Redesigned home view. The gradient hero replaces the old HeaderView.
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
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                }
            }
            
            .navigationBarHidden(true)
            .background(Theme.globalBackgroundGradient.ignoresSafeArea())
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
