//
//  CloudSyncChoiceView.swift
//  xT
//
//  The iCloud consent sheet — presented inside onboarding after the profile
//  step (never as a standalone screen before onboarding).
//

import SwiftUI

struct CloudSyncChoiceView: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        ZStack {
            Theme.Gradients.brand
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "icloud")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.85))

                    Text("Your data")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.95))

                    Text("Keep your doses, journal, and settings in sync across all your devices using iCloud, or store everything locally on this device only.")
                        .font(.body)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onChoice(true)
                    } label: {
                        Text("Sync with iCloud")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.OnAccent.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md)
                                    .fill(Theme.Colors.accent.opacity(0.8))
                                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                            )
                    }

                    Button {
                        onChoice(false)
                    } label: {
                        Text("Keep on device only")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
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
