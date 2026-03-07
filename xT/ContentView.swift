//
//  ContentView.swift
//  xT
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.medicationManager) private var medicationManager
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
            // Optional: auto-skip if dose dates exist
            if !hasCompletedOnboarding {
                let dates = medicationManager.loadDoseDatesLegacy()
                if dates.last != nil || dates.next != nil {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    private var onboardingWithCompletion: some View {
        OnboardingView(onboardingComplete: {
            // Clear navigation stack and show home view
            navigationPath.removeLast(navigationPath.count)
            hasCompletedOnboarding = true
        })
        .onDisappear {
            // Mark onboarding as completed when user leaves the screen
            hasCompletedOnboarding = true
        }
    }
}
