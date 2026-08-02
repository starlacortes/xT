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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(Theme.Colors.accent)
        .tabViewStyle(.automatic)
        // .tabBarMinimizeBehavior(.onScrollDown) - iOS 26+ API, disabled for compatibility
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        MainTabView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.profileManager, ProfileManager.shared)
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.notificationManager, NotificationManager.shared)
            .environment(\.authenticationManager, AuthenticationManager.shared)
    }
}
#endif
