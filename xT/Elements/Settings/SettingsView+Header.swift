//
//  SettingsView+Header.swift
//  xT
//
//  Profile header block and the 2x2 quick-access card grid.
//  (Split from SettingsView.swift — same `SettingsView`, different file.)
//

import SwiftUI

extension SettingsView {

    // MARK: - Profile Header Block

    var profileHeaderBlock: some View {
        HStack(spacing: 16) {
            if let img = profileManager.profilePhoto {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.Gradients.brand)
                    .frame(width: 56, height: 56)
            }

            Text(profileManager.profileDisplayName.isEmpty ? profileManager.profileName : profileManager.profileDisplayName)
                .font(Theme.Fonts.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(destination: ProfileEditorView()) {
                Text("Edit Profile")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 40)
        .padding(.bottom, 28)
    }

    // MARK: - Quick Access Cards

    var quickAccessCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                quickCard(icon: "pills.fill",
                          iconBg: Theme.Colors.Time.cycle.surface,
                          iconColor: Theme.Colors.Time.cycle.base,
                          title: "Medication",
                          subtitle: medicationManager.medicationDisplayInfo) {
                    showingTypeMethodSheet = true
                }
                .buttonStyle(.pressable)

                quickCard(icon: "flask",
                          iconBg: Theme.Colors.Time.mind.surface,
                          iconColor: Theme.Colors.Time.mind.base,
                          title: "Schedule",
                          subtitle: nextDoseSubtitle) {
                    showingDoseScheduleSheet = true
                }
                .buttonStyle(.pressable)
            }

            HStack(spacing: 12) {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    quickCard(icon: "paintbrush.fill",
                              iconBg: Theme.Colors.accent.opacity(0.13),
                              iconColor: Theme.Colors.accent,
                              title: "Theme",
                              subtitle: "Choose the app's color")
                }
                .buttonStyle(.pressable)

                NavigationLink {
                    AppLockSettingsView()
                } label: {
                    quickCard(icon: "lock.fill",
                              iconBg: Theme.Colors.neutralSurface,
                              iconColor: Theme.Colors.textSecondary,
                              title: "App lock",
                              subtitle: privacyLockSubtitle)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 22)
        .entrance(delay: 0.08)
    }

    func quickCardContent(icon: String, iconBg: Color, iconColor: Color,
                                  title: String, subtitle: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }

    func quickCard(icon: String, iconBg: Color, iconColor: Color,
                           title: String, subtitle: LocalizedStringResource,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickCardContent(icon: icon, iconBg: iconBg, iconColor: iconColor,
                             title: title, subtitle: subtitle)
        }
    }

    func quickCard(icon: String, iconBg: Color, iconColor: Color,
                           title: String, subtitle: LocalizedStringResource) -> some View {
        quickCardContent(icon: icon, iconBg: iconBg, iconColor: iconColor,
                         title: title, subtitle: subtitle)
    }
}
