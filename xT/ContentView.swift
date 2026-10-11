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
    @State private var showOnboarding = false
    @State private var showProfileNamePrompt = false

    var body: some View {
        ZStack {
            Theme.Colors.appBackground
                .ignoresSafeArea()

            if hasCompletedOnboarding {
                MainTabView()
            } else {
                Color.clear
            }
        }
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
}

#if DEBUG
#Preview {
    ContentView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.authenticationManager, AuthenticationManager.shared)
}
#endif
