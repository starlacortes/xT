//
//  CloudSyncChoiceView.swift
//  xT
//
//  The iCloud consent sheet — presented inside onboarding after the profile
//  step (never as a standalone screen before onboarding).
//
//  Paper ground (O1), like the flow it belongs to: the mark in ink, the
//  choices as an ActionPill plus a plain secondary text button.
//

import SwiftUI

struct CloudSyncChoiceView: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        ZStack {
            Theme.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Theme.Spacing.xxl) {
                    Image(systemName: "icloud")
                        .font(Theme.Fonts.icon)
                        .imageScale(.large)
                        .foregroundStyle(Theme.Colors.accent)

                    Text("Your data")
                        .font(Theme.Fonts.serifTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Keep your doses, journal, and settings in sync across all your devices using iCloud, or store everything locally on this device only.")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    ActionPill(title: "Sync with iCloud") { onChoice(true) }
                        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                    Button {
                        onChoice(false)
                    } label: {
                        Text("Keep on device only")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, Theme.Spacing.Gutter.onboarding)
            }
        }
    }
}

#if DEBUG
#Preview {
    CloudSyncChoiceView { useCloudKit in
        print("chose iCloud: \(useCloudKit)")
    }
}
#endif
