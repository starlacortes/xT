//
//  SettingsLabsView.swift
//  xT
//
//  Settings → Labs & Records (ST1). The measurement record side: blood tests
//  with the labs chart, the personal range screen (ST7), dose history, the dose
//  record (ST11, replacing the old "Adherence & history"), screenings, and the
//  dose-intensity insights toggle. Rows were moved, not rewritten.
//

import SwiftUI

struct SettingsLabsView: View {
    @Environment(\.medicationManager) var medicationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                LabsGroup
                InsightsGroup
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Labs & Records")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Labs & history

    private var LabsGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Labs & history", emphasis: .accent)
            SettingsGroup {
                NavigationLink {
                    BloodTestHistoryView()
                } label: {
                    SettingsRow(icon: "drop.fill",
                                title: "Blood tests",
                                subtitle: bloodTestHistorySubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                NavigationLink {
                    YourRangeView()
                } label: {
                    SettingsRow(icon: "target",
                                title: "Your range",
                                subtitle: nil) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                NavigationLink {
                    DoseRecordView()
                } label: {
                    SettingsRow(icon: "chart.line.uptrend.xyaxis",
                                title: "Dose record",
                                subtitle: doseRecordSubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                NavigationLink {
                    DoseHistoryView()
                } label: {
                    SettingsRow(icon: "clock.arrow.circlepath",
                                title: "Dose history",
                                subtitle: doseHistorySubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)

                SettingsGroupDivider()

                NavigationLink {
                    ScreeningHistoryView()
                } label: {
                    SettingsRow(icon: "heart.text.square",
                                title: "Screenings",
                                subtitle: screeningHistorySubtitle) {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Insights

    private var InsightsGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Insights", emphasis: .accent)
            SettingsGroup {
                HStack(spacing: Theme.Spacing.card) {
                    SettingsIconTile(icon: "gauge.with.dots.needle.33percent")

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Dose intensity insights")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(medicationManager.showDoseIntensityInsights
                             ? "On — personalised dose intensity shown"
                             : "Off — use clinical defaults")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    SettingsToggle(isOn: Binding(
                        get: { medicationManager.showDoseIntensityInsights },
                        set: {
                            medicationManager.showDoseIntensityInsights = $0
                            medicationManager.persistUserPreferences()
                            medicationManager.refreshState()
                        }
                    ))
                }
                .padding(.horizontal, Theme.Spacing.card)
                .padding(.vertical, Theme.Spacing.md)
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Subtitles

    private var bloodTestHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.bloodTestHistory.count
        if count == 0 { return "No blood tests logged yet" }
        return LocalizedStringResource(
            "^[\(count) blood test](inflect: true) logged",
            comment: "Settings row subtitle counting logged blood tests"
        )
    }

    private var doseRecordSubtitle: LocalizedStringResource {
        guard medicationManager.isFullyConfigured else {
            return LocalizedStringResource(
                "No medication configured",
                comment: "Settings row subtitle when dose record data is unavailable"
            )
        }
        return LocalizedStringResource(
            "Regimen history and dose intensity",
            comment: "Settings row subtitle for the dose record screen"
        )
    }

    private var doseHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.doseHistory.count
        if count == 0 { return "No doses recorded yet" }
        return LocalizedStringResource(
            "Review and correct ^[\(count) dose](inflect: true)",
            comment: "Settings row subtitle counting doses that need review"
        )
    }

    private var screeningHistorySubtitle: LocalizedStringResource {
        let count = medicationManager.screeningRecords.count
        if count == 0 { return "No screenings logged yet" }
        return LocalizedStringResource(
            "^[\(count) screening](inflect: true) logged",
            comment: "Settings row subtitle counting logged health screenings"
        )
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            SettingsLabsView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
