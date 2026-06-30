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
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack {
            Theme.Gradients.brand
                .ignoresSafeArea()

            NavigationStack(path: $navigationPath) {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    onboardingWithCompletion
                }
            }
            .onAppear {
                let defaults = UserDefaults.standard
                let hasMedicationData = defaults.string(forKey: "selectedMedication") != nil

                if !hasCompletedOnboarding && hasMedicationData {
                    hasCompletedOnboarding = true
                }
            }
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

    private var onboardingWithCompletion: some View {
        OnboardingView(onboardingComplete: {
            navigationPath.removeLast(navigationPath.count)
            hasCompletedOnboarding = true
        })
        .onDisappear {
            if !hasCompletedOnboarding {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.authenticationManager, AuthenticationManager.shared)
}
