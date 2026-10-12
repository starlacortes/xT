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
            VStack(spacing: Theme.Spacing.section) {
                Spacer()
                // The wordmark's first appearance in the app (O1 step 2): the
                // fixed outline in ink — the logo is never set as live text.
                IsoclineMarkView(mark: .wordmark, rendering: .ink)
                    .frame(maxWidth: 264)
                Text("Hormone therapy tracking")
                    .font(Theme.Fonts.title3)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: Theme.Spacing.row) {
                    primaryButton("Begin") { advanceStep() }
                    restoreLink
                }
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .padding(.bottom, Theme.Spacing.Gutter.onboarding)
            }

            // Compact overlay card while restore runs — blocks the Begin and
            // restore controls without taking over the whole step.
            if isRestoringFromiCloud {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: Theme.Spacing.lg) {
                        ProgressView()
                            .tint(Theme.Colors.accent)
                            .scaleEffect(1.2)
                        Text("Restoring from iCloud…")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, Theme.Spacing.xxxl)
                    .padding(.vertical, Theme.Spacing.section)
                    .background(Theme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                    )
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
                .foregroundStyle(Theme.Colors.accent)
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
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("What hormone are you taking?")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            VStack(spacing: Theme.Spacing.row) {
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
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue", disabled: selectedType.isEmpty) { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
    }

    // MARK: - Step 3: HRT Experience
    var experienceStep: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("How long have you been on HRT?")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            VStack(spacing: Theme.Spacing.row) {
                choiceCard(title: "Just starting", isSelected: !hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = false }
                }
                choiceCard(title: "I've been on it", isSelected: hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = true }
                }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            if hasBeenOnHRT {
                HStack(spacing: Theme.Spacing.md) {
                    durationStepper(text: "^[\(hrtDurationYears) year](inflect: true)",
                                    value: $hrtDurationYears, range: 0...20)
                    durationStepper(text: "^[\(hrtDurationMonths) month](inflect: true)",
                                    value: $hrtDurationMonths, range: 1...11)
                }
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
        .animation(Theme.Motion.quick, value: hasBeenOnHRT)
    }
}
