//
//  OnboardingView+StepsEarly.swift
//  xT
//
//  Steps 1-3: welcome (incl. iCloud restore), medication path, and HRT experience.
//  (Split from OnboardingView.swift — same `OnboardingView`, different file.)
//

import SwiftUI

extension OnboardingView {

    // MARK: - Step 1: Welcome
    var welcomeStep: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()
                Text("xT")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.95))
                Text("Hormone therapy tracking")
                    .font(.title3)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: 12) {
                    primaryButton("Begin") { advanceStep() }
                    if UserDefaults.standard.bool(forKey: "icloudSyncEnabled") {
                        Button("Restore from iCloud") {
                            Task { await restoreFromiCloud() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            if isRestoringFromiCloud {
                ZStack {
                    Theme.Gradients.brand
                        .opacity(0.85)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.Colors.OnAccent.primary)
                            .scaleEffect(1.3)
                        Text("Checking iCloud…")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
                    }
                }
                .transition(.opacity)
            }
        }
        .alert("No iCloud Data Found", isPresented: $showRestoreNotFoundAlert) {
            Button("Set Up Manually") { }
        } message: {
            Text("No existing data was found in iCloud. Complete the setup to get started.")
        }
    }

    func restoreFromiCloud() async {
        withAnimation { isRestoringFromiCloud = true }
        // Allow CloudKit's initial sync a moment to populate the local store
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run { medicationManager.reloadAllFromStore() }
        withAnimation {
            isRestoringFromiCloud = false
            if medicationManager.selectedMedication != nil {
                onboardingComplete?()
            } else {
                showRestoreNotFoundAlert = true
            }
        }
    }

    // MARK: - Step 2: Medication Type
    var pathStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("What hormone are you taking?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                pathCard(
                    title: "Estrogen‑based HRT",
                    subtitle: "Estradiol — feminizing hormone therapy",
                    isSelected: selectedType == "Estrogen"
                ) { selectType("Estrogen", defaultDose: 2.0) }

                pathCard(
                    title: "Testosterone‑based HRT",
                    subtitle: "Testosterone — masculinizing hormone therapy",
                    isSelected: selectedType == "Testosterone"
                ) { selectType("Testosterone", defaultDose: 40.0) }
            }
            .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue", disabled: selectedType.isEmpty) { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 3: HRT Experience
    var experienceStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("How long have you been on HRT?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                choiceCard(title: "Just starting", isSelected: !hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = false }
                }
                choiceCard(title: "I've been on it", isSelected: hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = true }
                }
            }
            .padding(.horizontal, 40)

            if hasBeenOnHRT {
                HStack(spacing: 12) {
                    durationStepper(text: "^[\(hrtDurationYears) year](inflect: true)",
                                    value: $hrtDurationYears, range: 0...20)
                    durationStepper(text: "^[\(hrtDurationMonths) month](inflect: true)",
                                    value: $hrtDurationMonths, range: 1...11)
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: hasBeenOnHRT)
    }
}
