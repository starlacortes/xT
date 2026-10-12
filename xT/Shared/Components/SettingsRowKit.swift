//
//  SettingsRowKit.swift
//  xT
//
//  The grouped-list vocabulary shared by every settings-style screen (ST4).
//
//  Tier 4d rework. The kit is now the Isocline row vocabulary:
//  - `SettingsGatewayCard` — the four gateway cards on the Settings root (ST1);
//  - `SettingsGroup` — a `paperCard` of rows on sub-screens, with dividers
//    inset past the row glyph;
//  - `SettingsRow` — icon tile + title + subtitle + trailing slot, localized
//    throughout (X31);
//  - `SettingsIconTile` — the single-accent tile (S7): accent fill at
//    `components.tile.fillOpacity`, accent glyph. No color parameters.
//
//  `SettingsSection`, `SettingsRowDivider` and `settingsCard` were retired with
//  the old flush list; `SheetSectionLabel` stays — the sheets use it above their
//  ghost outlines.
//

import SwiftUI

// MARK: - Gateway card (ST1)

/// One of the four gateway cards on the Settings root: accent tile, sans title,
/// a live mono subtitle, a chevron. The whole card is the link.
struct SettingsGatewayCard<Destination: View>: View {
    let icon: String
    let title: LocalizedStringResource
    /// Live mono summary line, e.g. `ESTRADIOL VALERATE · 4.0 MG Q7D` (ST5).
    /// Already-assembled plain strings pass through `Text(verbatim:)` below, so
    /// callers format numbers before they get here.
    var subtitle: LocalizedStringResource? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.card) {
                SettingsIconTile(icon: icon)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Fonts.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .monoLabel()
                    }
                }

                Spacer()

                chevron
            }
            .padding(Theme.Spacing.card)
            .paperCard(radius: Theme.Radius.lg)
        }
        .buttonStyle(.pressable)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(Theme.Fonts.caption.weight(.medium))
            .foregroundStyle(Theme.Colors.textTertiary)
    }
}

// MARK: - Grouped card of rows (ST4)

/// A `paperCard` holding a column of rows, separated by hairlines inset to line
/// up with row *text* (past the icon tile). Applied to the rows only; the screen
/// owns the section label and the screen gutter.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .paperCard(padding: 0, radius: Theme.Radius.lg)
    }
}

// MARK: - Row

/// A settings row: icon tile, title, optional subtitle, and trailing accessory.
///
/// `title` and `subtitle` are `LocalizedStringResource` (not `String`) so that
/// localization keys are extracted and Markdown grammar in the localized value —
/// most importantly `^[…](inflect: true)` for automatic plural agreement — is
/// parsed by `Text(_:LocalizedStringResource)`. Passing a `String` variable
/// would route through `Text(_:StringProtocol)`, which is verbatim.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var title: LocalizedStringResource
    var subtitle: LocalizedStringResource? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.card) {
            SettingsIconTile(icon: icon)

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
        .padding(.horizontal, Theme.Spacing.card)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// The standard trailing accessory for push rows.
struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(Theme.Fonts.caption.weight(.medium))
            .foregroundStyle(Theme.Colors.textTertiary)
    }
}

/// The one toggle treatment (ST4): accent tint, hidden label. The row's own
/// title/subtitle carry the accessibility label; the `Toggle` itself is muted.
struct SettingsToggle: View {
    let isOn: Binding<Bool>

    var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .tint(Theme.Colors.accent)
    }
}

// MARK: - Icon tile

/// The 32×32 rounded tile holding a row's SF Symbol — the single accent
/// treatment (S7): accent fill at `fillOpacity`, accent glyph, no parameters.
struct SettingsIconTile: View {
    let icon: String

    static let side: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.accent.opacity(0.13))
                .frame(width: Self.side, height: Self.side)
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.accent)
        }
    }
}

// MARK: - Group divider

/// A separator inside a `SettingsGroup`, inset past the icon tile so it lines
/// up with row text. Apply via `SettingsGroupRow`'s automatic layout instead of
/// hand-placing these.
struct SettingsGroupDivider: View {
    var body: some View {
        HairlineDivider(inset: Theme.Spacing.card + SettingsIconTile.side + Theme.Spacing.card)
    }
}

// MARK: - Sheet section label

/// The larger footnote-weight uppercase label used inside the type/method and
/// dose-schedule sheets — deliberately distinct from the caption2 `SectionHeader`
/// on the main Settings page. Both sheets carried byte-identical copies.
///
/// Localized (X31): the text parameter is a `LocalizedStringResource`.
struct SheetSectionLabel: View {
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(Theme.Fonts.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.section) {
            SectionHeader(text: "Labs & Records")
            SettingsGroup {
                SettingsRow(icon: "drop.fill",
                            title: "Blood tests",
                            subtitle: "2 labs · last 14 d ago") {
                    SettingsChevron()
                }
                SettingsGroupDivider()
                SettingsRow(icon: "chart.line.uptrend.xyaxis",
                            title: "Dose record",
                            subtitle: nil) {
                    SettingsChevron()
                }
                SettingsGroupDivider()
                SettingsRow(icon: "target",
                            title: "Dose intensity insights",
                            subtitle: nil) {
                    SettingsToggle(isOn: .constant(true))
                }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
        }
        .padding(.vertical, Theme.Spacing.xl)
    }
    .background(Theme.Colors.appBackground)
}
#endif
