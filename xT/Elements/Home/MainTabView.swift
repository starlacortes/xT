//
//  MainTabView.swift
//  xT
//
//  Created by Cline on 3/10/26.
//

import SwiftUI

struct MainTabView: View {
    @Environment(\.appRouter) private var router

    var body: some View {
        // iOS 26 `Tab(value:)` with a selection binding (N1). The router owns the
        // selection so a notification route can switch tabs after unlock (N2).
        TabView(selection: Bindable(router).tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }

            Tab("Journal", systemImage: "book", value: AppTab.journal) {
                JournalView()
            }

            Tab("Time", systemImage: "wand.and.stars", value: AppTab.time) {
                TimeView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.Colors.accent)
        // `tabBarMinimizeBehavior` stays off for v1 (N1): Home doesn't scroll and the
        // Journal floating pill would have to track a minimized bar.
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        MainTabView()
            .environment(\.appRouter, AppRouter())
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.profileManager, ProfileManager.shared)
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.notificationManager, NotificationManager.shared)
            .environment(\.authenticationManager, AuthenticationManager.shared)
    }
}
#endif
