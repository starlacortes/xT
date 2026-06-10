//
//  HomeView.swift
//  xT
//
//  Created by Starla Cortes on 8/5/25.
//  Redesigned home view with modern mobile interface
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
                HomeContentView(showingGraphDetail: $showingGraphDetail)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .background(Theme.globalBackgroundGradient)
        .sheet(isPresented: $showingGraphDetail) {
            GraphView()
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Home Content View
struct HomeContentView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Phone mockup container
            VStack(spacing: 0) {
                StatusBarView()

                HeaderView(showingGraphDetail: $showingGraphDetail)

                 MainContentView(showingGraphDetail: $showingGraphDetail)
                     .padding(.top, 14)
            }
            .background(Theme.globalBackgroundGradient)
            .cornerRadius(16)
            .padding(16)
        }
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}