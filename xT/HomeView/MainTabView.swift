//
//  MainTabView.swift
//  xT
//
//  Created by Cline on 3/10/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }
                .tag(1)

            BloomView()
                .tabItem {
                    Label("Bloom", systemImage: "sparkles")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .tabViewStyle(.automatic)
        // .tabBarMinimizeBehavior(.onScrollDown) - iOS 26+ API, disabled for compatibility
    }
}

#Preview {
    MainTabView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}