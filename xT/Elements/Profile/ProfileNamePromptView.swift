//
//  ProfileNamePromptView.swift
//  xT
//
//  One-shot sheet asking for a profile name after an iCloud restore that
//  couldn't carry the name over. The stored name is encrypted with a
//  device-local keychain key, so a wiped/reinstalled/new device reads it
//  back as "no name" — this collects a replacement under the new key.
//

import SwiftUI

struct ProfileNamePromptView: View {
    @Environment(\.profileManager) var profileManager
    @Binding var isPresented: Bool
    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                Text("Set your name")
                    .font(Theme.Fonts.title2)
                    .fontWeight(.semibold)

                Text("Your data is restored, but your profile name couldn't be carried over for privacy. Set it again below.")
                    .font(Theme.Fonts.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)

                TextField("Your name", text: $name)
                    .font(Theme.Fonts.body)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Color.secondary.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .submitLabel(.done)
                    .onSubmit { save() }

                VStack(spacing: Theme.Spacing.sm) {
                    Button("Save") { save() }
                        .asAccentButton()
                        .disabled(trimmedName.isEmpty)
                    Button("Later") { isPresented = false }
                        .buttonStyle(.plain)
                        .font(Theme.Fonts.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.xxl)
            }
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.lg)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func save() {
        // updateProfileName validates (1–50 chars) and persists — under the
        // current device's key this time.
        guard profileManager.updateProfileName(trimmedName) else { return }
        isPresented = false
    }
}

#if DEBUG
#Preview {
    ProfileNamePromptView(isPresented: .constant(true))
        .environment(\.profileManager, ProfileManager.shared)
}
#endif
