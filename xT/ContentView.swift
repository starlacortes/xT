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
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if hasCompletedOnboarding {
                HomeView()
            } else {
                onboardingWithCompletion
            }
        }
        .onAppear {
            // Debug: Print current onboarding status
            print("Onboarding status: \(hasCompletedOnboarding)")

            // Check if this is a fresh install by looking for any saved data
            let defaults = UserDefaults.standard
            let hasMedicationData = defaults.string(forKey: "selectedMedication") != nil
            let hasProfileData = defaults.string(forKey: "profileName") != nil || defaults.data(forKey: "profileImageData") != nil

            // Only skip onboarding if we have existing medication data
            if !hasCompletedOnboarding && hasMedicationData {
                hasCompletedOnboarding = true
                print("Skipping onboarding - existing medication data found")
            } else if !hasCompletedOnboarding {
                print("Showing onboarding - no existing data")
            }
        }
    }

    private var onboardingWithCompletion: some View {
        OnboardingView(onboardingComplete: {
            // Clear navigation stack and show home view
            navigationPath.removeLast(navigationPath.count)
            hasCompletedOnboarding = true
            print("Onboarding completed")
        })
        .onDisappear {
            // Mark onboarding as completed when user leaves the screen
            if !hasCompletedOnboarding {
                hasCompletedOnboarding = true
                print("Onboarding marked as completed on disappear")
            }
        }
    }
}
