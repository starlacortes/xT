//
//  SettingsRowKit.swift
//  xT
//
//  The grouped-list vocabulary shared by every settings-style screen.
//
//  These were previously `private` helpers inside SettingsView, so the four other
//  settings screens each reinvented some subset of them — three separate `sectionLabel`
//  implementations and nine copies of the card container. Promoting them here lets every
//  settings screen share one row metric, one icon tile and one card treatment.
//

import SwiftUI

// MARK: - Section

/// An accent-labelled group of rows, fenced by hairline dividers.
struct SettingsSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(text: label, emphasis: .accent)
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.bottom, Theme.Spacing.row)

            Divider().opacity(0.5)
            content()
            Divider().opacity(0.5)
        }
    }
}

// MARK: - Row

/// A settings row: icon tile, title, optional subtitle, and trailing accessory.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var iconBackground: Color
    var iconColor: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.card) {
            SettingsIconTile(icon: icon, background: iconBackground, color: iconColor)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, Theme.Spacing.Gutter.screen)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, iconBackground: Color, iconColor: Color,
         title: String, subtitle: String? = nil) {
        self.init(icon: icon, iconBackground: iconBackground, iconColor: iconColor,
                  title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Icon tile

/// The 32×32 rounded tile holding a row's SF Symbol.
struct SettingsIconTile: View {
    let icon: String
    let background: Color
    let color: Color

    static let side: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(background)
                .frame(width: Self.side, height: Self.side)
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Divider

/// A row separator inset to line up with row *text* rather than the icon tile.
struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, Theme.Spacing.Gutter.screen
                     + SettingsIconTile.side
                     + Theme.Spacing.card)
    }
}

// MARK: - Card

extension View {
    /// The standard opaque settings card: padded content on a rounded system background.
    func settingsCard(padding: CGFloat = Theme.Spacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            SettingsSection(label: "Medication") {
                SettingsRow(icon: "pills.fill",
                            iconBackground: Theme.Colors.accent.opacity(0.15),
                            iconColor: Theme.Colors.accent,
                            title: "Type & method",
                            subtitle: "Estrogen · Injectable")
                SettingsRowDivider()
                SettingsRow(icon: "calendar",
                            iconBackground: Theme.Colors.accentSecondary.opacity(0.15),
                            iconColor: Theme.Colors.accentSecondary,
                            title: "Dose schedule",
                            subtitle: "Every 7 days")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(text: "Rotation")
                Text("Zones rest for 14 days before reuse.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .settingsCard()
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
        }
        .padding(.vertical, Theme.Spacing.xl)
    }
    .background(Color(.secondarySystemBackground))
}
#endif
