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
                    .font(Theme.Fonts.title3)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: 14) {
                    primaryButton("Begin") { advanceStep() }
                    restoreLink
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            // Compact overlay box while restore runs — blocks the Begin and
            // restore controls without taking over the whole step.
            if isRestoringFromiCloud {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.Colors.accent)
                            .scaleEffect(1.2)
                        Text("Restoring from iCloud…")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .background(Theme.Colors.appBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
                }
                .transition(.opacity)
            }
        }
        .alert("No iCloud Data Found", isPresented: $showRestoreNotFoundAlert) {
            Button("Set Up Manually") { }
        } message: {
            Text("No existing data was found in iCloud. Complete the setup to get started.")
        }
        .alert("Turn On iCloud Sync?", isPresented: $showTurnOnSyncAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Turn On") {
                // Enabling sync must attach CloudKit to a store file with no
                // local-only deletion history — the post-reset file would
                // replay its deletes as tombstones and wipe the very iCloud
                // data we're restoring. Build a fresh CloudKit-backed store
                // under a temporary file name and swap live, then restore
                // immediately — no restart.
                UserDefaults.standard.set(true, forKey: "icloudSyncEnabled")
                rebuildCloudContainer(.freshCloudKit)
                Task { await restoreFromiCloud() }
            }
        } message: {
            Text("Restoring from iCloud requires iCloud Sync. Turn it on now and your data will restore automatically.")
        }
    }

    private var restoreLink: some View {
        Button {
            // A fresh install has no stored preference yet, but its container
            // is CloudKit-backed from launch, so restore can run immediately.
            // Only an explicit "off" choice blocks it.
            if UserDefaults.standard.object(forKey: "icloudSyncEnabled") == nil
                || UserDefaults.standard.bool(forKey: "icloudSyncEnabled") {
                Task { await restoreFromiCloud() }
            } else {
                showTurnOnSyncAlert = true
            }
        } label: {
            Text("Restore from iCloud")
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
                .underline()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Checks iCloud for your existing data")
    }

    func restoreFromiCloud() async {
        withAnimation { isRestoringFromiCloud = true }
        let restored = await CloudSyncService.restoreFromiCloud()
        withAnimation {
            isRestoringFromiCloud = false
            if restored {
                // Restoring implies consent to sync — record the preference so
                // the mid-onboarding consent sheet doesn't ask again.
                UserDefaults.standard.set(true, forKey: "icloudSyncEnabled")
                // The restored profile name may be unreadable on this device
                // (it's encrypted with a device-local keychain key), so ask
                // for a replacement once Home appears.
                if ProfileManager.shared.profileName.isEmpty {
                    UserDefaults.standard.set(true, forKey: CloudSyncService.profileNamePromptPendingKey)
                }
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
                .font(Theme.Fonts.title2)
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
                .font(Theme.Fonts.title2)
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
