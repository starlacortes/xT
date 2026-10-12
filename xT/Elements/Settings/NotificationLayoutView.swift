//
//  NotificationLayoutView.swift
//  xT
//
//  Settings → Medication & Dose → Reminders → Reminder layout (NT1 · X35).
//
//  Four presets (Discreet is the default), a title picker with an own-words
//  field, per-field toggles, and a live preview. The preview is rendered by the
//  same `NotificationContentBuilder` the scheduler uses, fed sample data, so
//  what you see is what arrives — iOS draws the real banner, this is the mock.
//
//  Everything saves through `NotificationManager.setLayout(_:)`, which persists
//  and reschedules, so the change applies to the next reminder without a relaunch.
//

import SwiftUI

struct NotificationLayoutView: View {
    @Environment(\.notificationManager) private var notificationManager
    @Environment(\.appIconManager) private var appIconManager

    @State private var layout = NotificationLayout.discreet
    /// Kept apart from the layout so switching away from own words and back does
    /// not lose what was typed.
    @State private var ownWords = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                previewSection
                presetSection
                if layout.preset == .custom {
                    customSection
                }
                noteSection
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Reminder layout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            layout = notificationManager.layout
            if case .own(let words) = layout.title { ownWords = words }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Preview", emphasis: .accent)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                banner(
                    title: NotificationContentBuilder.title(for: layout),
                    body: NotificationContentBuilder.body(for: .sample, layout: layout),
                    action: NotificationContentBuilder.actionTitle(for: layout)
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Previews hidden while locked")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    banner(
                        title: String(localized: "Isocline",
                                      comment: "App name shown on a notification whose previews are hidden"),
                        body: String(localized: "Reminder",
                                     comment: "Placeholder body shown when notification previews are hidden"),
                        action: nil
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: Theme.Spacing.lg)
        }
    }

    /// A stand-in for iOS's own banner. The system draws the real glass; this mock
    /// shows the copy and the layout only.
    private func banner(title: String, body: String, action: String?) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            appIcon

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(verbatim: "ISOCLINE")
                        .font(Theme.Fonts.micro)
                        .monoLabel()
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Text("now")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(body)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if let action {
                    Text(String(localized: "Press and hold: \(action)",
                                comment: "Caption in the notification layout preview naming the action button"))
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
        )
    }

    /// iOS always draws the *current* app icon in a banner's header (U19), so
    /// the mock shows the same shipped artwork the icon picker previews
    /// with — including Discreet, which is the point of pairing the two.
    private var appIcon: some View {
        Image(appIconManager.current.previewAssetName)
            .resizable()
            .frame(width: 38, height: 38)
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Layout", emphasis: .accent)

            FlowLayout(spacing: Theme.Spacing.tiny) {
                ForEach(NotificationLayout.Preset.allCases) { preset in
                    Button {
                        select(preset)
                    } label: {
                        Pill(text: String(localized: preset.displayName),
                             style: layout.preset == preset ? .active : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Custom editor

    private var customSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.section) {
            titlePicker
            fieldsEditor
        }
    }

    private var titlePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Title", emphasis: .accent)

            FlowLayout(spacing: Theme.Spacing.tiny) {
                ForEach(NotificationLayout.Title.selectable, id: \.self) { option in
                    Button {
                        setTitle(option)
                    } label: {
                        Pill(text: titleLabel(for: option),
                             style: layout.title == option ? .active : .neutral)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    setTitle(.own(ownWords))
                } label: {
                    Pill(text: String(localized: "Your own words…",
                                      comment: "Title option in the notification layout editor"),
                         style: isOwnWordsSelected ? .active : .neutral)
                }
                .buttonStyle(.plain)
            }

            if isOwnWordsSelected {
                ownWordsField
            }
        }
    }

    private var ownWordsField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            TextField(String(localized: "Your words",
                             comment: "Placeholder for the notification layout's own-words field"),
                      text: ownWordsBinding)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.md)
                .paperCard(padding: 0)

            Text("\(ownWords.count)/\(NotificationLayout.ownWordsMaxLength)")
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var fieldsEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Fields", emphasis: .accent)

            SettingsGroup {
                ForEach(NotificationLayout.Field.allCases) { field in
                    toggleRow(label: field.displayName, isOn: fieldBinding(field))
                    SettingsGroupDivider()
                }

                toggleRow(
                    label: "Log dose button",
                    subtitle: "Otherwise the button reads “Open”",
                    isOn: actionBinding
                )
            }
        }
    }

    private func toggleRow(label: LocalizedStringResource,
                           subtitle: LocalizedStringResource? = nil,
                           isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.card) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(label)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            SettingsToggle(isOn: isOn)
        }
        .padding(.horizontal, Theme.Spacing.card)
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("iOS always shows the app's name and icon above a reminder, so pair Discreet with the Discreet icon.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Own words stay on this device — they are never synced or exported.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - State helpers

    private var isOwnWordsSelected: Bool {
        if case .own = layout.title { return true }
        return false
    }

    private var ownWordsBinding: Binding<String> {
        Binding(
            get: { ownWords },
            set: { newValue in
                ownWords = String(newValue.prefix(NotificationLayout.ownWordsMaxLength))
                layout.title = .own(ownWords)
                persist()
            }
        )
    }

    private func titleLabel(for option: NotificationLayout.Title) -> String {
        let probe = NotificationLayout(preset: .custom, title: option,
                                       fields: [], actionLogsDose: false)
        return NotificationContentBuilder.title(for: probe)
    }

    private func fieldBinding(_ field: NotificationLayout.Field) -> Binding<Bool> {
        Binding(
            get: { layout.fields.contains(field) },
            set: { isOn in
                if isOn { layout.fields.insert(field) } else { layout.fields.remove(field) }
                persist()
            }
        )
    }

    private var actionBinding: Binding<Bool> {
        Binding(
            get: { layout.actionLogsDose },
            set: { layout.actionLogsDose = $0; persist() }
        )
    }

    private func select(_ preset: NotificationLayout.Preset) {
        // Entering Custom seeds from the current preset so a tweak starts where
        // the person already was, rather than from scratch.
        layout = preset == .custom ? layout.asCustom() : NotificationLayout.preset(preset)
        persist()
    }

    private func setTitle(_ title: NotificationLayout.Title) {
        layout.title = title
        persist()
    }

    private func persist() {
        notificationManager.setLayout(layout)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NotificationLayoutView()
            .environment(\.notificationManager, NotificationManager.shared)
    }
}
#endif
