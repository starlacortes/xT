//
//  ContentView.swift
//  xT
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.profileManager) private var profileManager
    @Environment(\.authenticationManager) private var authManager
    @Environment(\.notificationManager) private var notificationManager
    @State private var showOnboarding = false
    @State private var showProfileNamePrompt = false

    /// App-wide navigation state (N2). Owned here so routing survives tab switches
    /// and notification deep links.
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            Theme.Colors.appBackground
                .ignoresSafeArea()

            if hasCompletedOnboarding {
                MainTabView()
                    .environment(\.appRouter, router)
            } else {
                Color.clear
            }
        }
        // A notification route only applies once the lock screen clears (N2).
        .onChange(of: notificationManager.pendingRoute) { _, _ in applyPendingRoute() }
        .onChange(of: authManager.showAuthentication) { _, _ in applyPendingRoute() }
        .onAppear {
            let defaults = UserDefaults.standard
            let hasMedicationData = defaults.string(forKey: "selectedMedication") != nil

            if !hasCompletedOnboarding && hasMedicationData {
                hasCompletedOnboarding = true
            } else if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            if !newValue {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onboardingComplete: {
                // A successful restore may have delivered data with no readable
                // profile name (the stored name is encrypted with a device-local
                // key). Consume the one-shot flag and, once Home appears, ask
                // for a name.
                let needsNamePrompt = UserDefaults.standard.bool(forKey: CloudSyncService.profileNamePromptPendingKey)
                UserDefaults.standard.removeObject(forKey: CloudSyncService.profileNamePromptPendingKey)

                hasCompletedOnboarding = true
                showOnboarding = false
                if needsNamePrompt && profileManager.profileName.isEmpty {
                    // Wait out the cover dismissal, or the sheet collides with it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showProfileNamePrompt = true
                    }
                }
            })
        }
        .sheet(isPresented: $showProfileNamePrompt) {
            ProfileNamePromptView(isPresented: $showProfileNamePrompt)
        }
        // Full-screen lock overlay — shown whenever the manager requires auth.
        // interactiveDismissDisabled prevents any gesture from bypassing the lock.
        .fullScreenCover(isPresented: Binding(
            get: { authManager.showAuthentication },
            set: { authManager.showAuthentication = $0 }
        )) {
            AuthenticationView(reason: "Access your health data")
                .interactiveDismissDisabled(true)
        }
    }

    /// Translate a pending notification route into router intents — but only once the
    /// lock screen is down, so a reminder tapped on a locked phone lands correctly
    /// after unlock (N2).
    private func applyPendingRoute() {
        guard let route = notificationManager.pendingRoute,
              !authManager.showAuthentication else { return }

        switch route {
        case .logDose:
            router.tab = .home
            router.presentRecordDose = true
        case .journal:
            router.tab = .journal
            router.journalScrollToTop = true
        }
        notificationManager.consumePendingRoute()
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.authenticationManager, AuthenticationManager.shared)
        .environment(\.notificationManager, NotificationManager.shared)
}
#endif
