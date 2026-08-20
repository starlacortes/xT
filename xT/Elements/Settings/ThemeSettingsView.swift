//
//  ThemeSettingsView.swift
//  xT
//
//  Settings → Appearance. Same `ThemePickerView` used in onboarding, so
//  changing the theme here behaves identically (live, drag-to-preview).
//

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var showingResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Choose a color")
                        .font(Theme.Fonts.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Drag to retint the whole app. Every color stays readable — contrast is checked automatically as you drag.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)

                ThemePickerView()
                    .padding(.horizontal, Theme.Spacing.Gutter.screen)

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Text("Reset to default")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.error)
                }
                .buttonStyle(.plain)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset to the default theme?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { themeManager.resetToDefault() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environment(\.themeManager, ThemeManager.shared)
    }
}
#endif
