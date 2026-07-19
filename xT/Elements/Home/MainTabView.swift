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

            TimeView()
                .tabItem {
                    Label("Time", systemImage: "wand.and.stars")
                }
                .tag(2)

            // Research tab — only when enabled via Settings → Developer.
            // In RELEASE the flag is hardwired false, so the tab never appears.
            if DeveloperSettings.shared.researchTabVisible {
                InsightsDashboardView()
                    .tabItem {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                    }
                    .tag(3)
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(Theme.Colors.accent)
        .tabViewStyle(.automatic)
        // .tabBarMinimizeBehavior(.onScrollDown) - iOS 26+ API, disabled for compatibility
    }
}

#Preview {
    MainTabView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}
