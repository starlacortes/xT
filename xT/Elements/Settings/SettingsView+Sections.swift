//
//  SettingsView+Sections.swift
//  xT
//
//  The five scroll sections (Medication & Body, Health & history, App settings,
//  About, Reset) plus the personal-target editor and its persistence helpers.
//  (Split from SettingsView.swift — same `SettingsView`, different file.)
//

import SwiftUI

extension SettingsView {

    // MARK: - Medication & Body

    var currentRouteClass: RouteClass {
        RouteClass.from(method: medicationManager.selectedAdministrationMethod ?? "")
    }

    var settingsMedicationBodySection: some View {
        settingsSection(label: "Medication & Body") {
            Button {
                showingTypeMethodSheet = true
            } label: {
                settingsRowContent(
                    icon: "pills.fill",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Type & method",
                    subtitle: medicationManager.medicationDisplayInfo,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            Button {
                showingDoseScheduleSheet = true
            } label: {
                settingsRowContent(
                    icon: "flask",
                    iconBg: Theme.Colors.Time.mind.surface,
                    iconColor: Theme.Colors.Time.mind.base,
                    title: "Dose & frequency",
                    subtitle: nextDoseSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            HStack(spacing: 14) {
                settingsIconView(icon: "calendar.badge.clock",
                                 bg: Theme.Colors.Time.body.surface,
                                 color: Theme.Colors.Time.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HRT start date")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(hrtStartSubtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DatePicker("", selection: Binding(
                    get: { medicationManager.hrtStartDate ?? Date() },
                    set: { newValue in
                        medicationManager.hrtStartDate = newValue
                        medicationManager.refreshState()
                    }
                ), in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale.current)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            settingsDivider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    settingsIconView(icon: "figure.stand", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Body silhouette")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(.primary)
                        Text("Silhouette used in the 3D body picker")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Picker("", selection: Binding(
                    get: { medicationManager.bodyTypeRaw },
                    set: { medicationManager.bodyTypeRaw = $0 }
                )) {
                    ForEach(BodyType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 50)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)

            if currentRouteClass != .oral {
                settingsDivider()

                NavigationLink(destination: PreferredZonesListView()) {
                    settingsRowContent(
                        icon: "star",
                        iconBg: Theme.Colors.accent.opacity(0.13),
                        iconColor: Theme.Colors.accent,
                        title: "Preferred zones",
                        subtitle: "Favoured injection & application sites",
                        trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                    )
                }
                .buttonStyle(.plain)

                settingsDivider()

                NavigationLink(destination: AvoidZonesEditorView()) {
                    settingsRowContent(
                        icon: "exclamationmark.shield",
                        iconBg: Theme.Colors.warning.opacity(0.13),
                        iconColor: Theme.Colors.warning,
                        title: "Avoid zones",
                        subtitle: avoidZonesSubtitle,
                        trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                    )
                }
                .buttonStyle(.plain)

                settingsDivider()

                Button {
                    UserDefaults.standard.set(false, forKey: "hasSeenRecommendedZonesInfo")
                } label: {
                    settingsRowContent(
                        icon: "lightspectral.horizontal",
                        iconBg: Theme.Colors.accent.opacity(0.13),
                        iconColor: Theme.Colors.accent,
                        title: "Re-show recommended zones",
                        subtitle: "Show the clinical zones info overlay again",
                        trailing: { EmptyView() }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Health & History Section

    var settingsHealthHistorySection: some View {
        settingsSection(label: "Health & history") {
            // Dose-intensity insights toggle
            HStack(spacing: 14) {
                settingsIconView(icon: "gauge.with.dots.needle.33percent",
                                 bg: Theme.Colors.Time.mind.surface,
                                 color: Theme.Colors.Time.mind.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose intensity insights")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(medicationManager.showDoseIntensityInsights ? "On — personalised dose intensity shown" : "Off — use clinical defaults")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { medicationManager.showDoseIntensityInsights },
                    set: {
                        medicationManager.showDoseIntensityInsights = $0
                        medicationManager.persistUserPreferences()
                        medicationManager.refreshState()
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())

            settingsDivider()

            // Toggle to enable custom targets
            HStack(spacing: 14) {
                settingsIconView(icon: "target", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use personal targets")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(useCustomTargets ? targetSummary : "Use clinical defaults")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $useCustomTargets)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
                    .onChange(of: useCustomTargets) { _, enabled in
                        if enabled { saveTherapeuticTargets() } else { clearTherapeuticTargets() }
                    }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())

            if useCustomTargets {
                settingsDivider()

                // Trough Min
                targetValueRow(label: "Trough lower bound",
                               value: $targetTroughMin,
                               unit: medicationUnit,
                               range: 0...9999,
                               description: "Your target floor at trough time")

                settingsDivider()

                // Trough Max
                targetValueRow(label: "Trough upper bound",
                               value: $targetTroughMax,
                               unit: medicationUnit,
                               range: min(targetTroughMin + 1, 9999)...9999,
                               description: "Your target ceiling at trough time")

                settingsDivider()

                // Peak Ceiling
                targetValueRow(label: "Peak ceiling",
                               value: $targetPeakCeiling,
                               unit: medicationUnit,
                               range: min(targetTroughMax, 9999)...9999,
                               description: "Upper safety limit near peak")

                settingsDivider()

                // Info footer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setting a range lets xT report where an estimate falls relative to it. Without one, xT shows the estimate on its own.")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }

            settingsDivider()

            NavigationLink(destination: AdherenceView()) {
                settingsRowContent(
                    icon: "chart.line.uptrend.xyaxis",
                    iconBg: Theme.Colors.Time.body.surface,
                    iconColor: Theme.Colors.Time.body.base,
                    title: "Adherence & history",
                    subtitle: adherenceSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: DoseHistoryView()) {
                settingsRowContent(
                    icon: "clock.arrow.circlepath",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Dose history",
                    subtitle: doseHistorySubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: BloodTestHistoryView()) {
                settingsRowContent(
                    icon: "drop.fill",
                    iconBg: Theme.Colors.Time.skin.surface,
                    iconColor: Theme.Colors.Time.skin.base,
                    title: "Blood test history",
                    subtitle: bloodTestHistorySubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: ScreeningHistoryView()) {
                settingsRowContent(
                    icon: "heart.text.square",
                    iconBg: Theme.Colors.Time.mind.surface,
                    iconColor: Theme.Colors.Time.mind.base,
                    title: "Screenings",
                    subtitle: screeningHistorySubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            NavigationLink(destination: DataExportView()) {
                settingsRowContent(
                    icon: "square.and.arrow.up",
                    iconBg: Theme.Colors.Time.cycle.surface,
                    iconColor: Theme.Colors.Time.cycle.base,
                    title: "Export data",
                    subtitle: "CSV or JSON — dose history, journal, blood tests",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
        }
        .keyboardDoneToolbar { targetFieldFocused = false }
    }

    var targetSummary: LocalizedStringResource {
        "Trough \(Int(targetTroughMin))–\(Int(targetTroughMax)) \(medicationUnit) · Peak ceiling \(Int(targetPeakCeiling)) \(medicationUnit)"
    }

    var medicationUnit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    @ViewBuilder
    func targetValueRow(label: String, value: Binding<Double>, unit: String,
                                 range: ClosedRange<Double>, description: String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .focused($targetFieldFocused)
                    .submitLabel(.done)
                    .onChange(of: value.wrappedValue) { _, newVal in
                        // Clamp to range
                        if newVal < range.lowerBound { value.wrappedValue = range.lowerBound }
                        if newVal > range.upperBound { value.wrappedValue = range.upperBound }
                        saveTherapeuticTargets()
                    }

                Text(unit)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    func saveTherapeuticTargets() {
        guard useCustomTargets else { return }
        let target = MedicationManager.TherapeuticTarget(
            troughMin: targetTroughMin,
            troughMax: targetTroughMax,
            peakCeiling: targetPeakCeiling
        )
        medicationManager.userTherapeuticTarget = target
        medicationManager.refreshState()
    }

    func clearTherapeuticTargets() {
        medicationManager.userTherapeuticTarget = nil
        medicationManager.refreshState()
    }

    // MARK: - App Settings Section

    var settingsAppSection: some View {
        settingsSection(label: "App settings") {
            HStack(spacing: 14) {
                settingsIconView(icon: "bell.fill", bg: Theme.Colors.Time.body.surface, color: Theme.Colors.Time.body.base)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose reminders")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(doseRemindersEnabled ? formatDoseReminderSubtitle : "Off")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $doseRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture { if doseRemindersEnabled { showingDoseTimePicker = true } }

            settingsDivider()

            HStack(spacing: 14) {
                settingsIconView(icon: "book.fill", bg: Theme.Colors.Time.cycle.surface, color: Theme.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Journal reminders")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(journalRemindersEnabled ? formatJournalReminderSubtitle : "Off")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $journalRemindersEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture { if journalRemindersEnabled { showingJournalTimePicker = true } }

            settingsDivider()

            NavigationLink(destination: ThemeSettingsView()) {
                settingsRowContent(
                    icon: "paintbrush.fill",
                    iconBg: Theme.Colors.accent.opacity(0.13),
                    iconColor: Theme.Colors.accent,
                    title: "Theme",
                    subtitle: "Choose the app's color",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)

            settingsDivider()

            settingsRowContent(
                icon: "icloud",
                iconBg: Theme.Colors.Time.cycle.surface,
                iconColor: Theme.Colors.Time.cycle.base,
                title: "iCloud Sync",
                subtitle: icloudSyncEnabled ? "Data syncs across your devices" : "Data stays on this device only",
                trailing: {
                    Toggle("", isOn: $icloudSyncEnabled)
                        .labelsHidden()
                        .onChange(of: icloudSyncEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "icloudSyncEnabled")
                            showingRestartAlert = true
                        }
                }
            )
            .alert("Restart Required", isPresented: $showingRestartAlert) {
                Button("OK") { }
            } message: {
                Text("This change will take effect the next time you open xT.")
            }

            if icloudSyncEnabled {
                settingsDivider()

                Button {
                    Task { await restoreFromiCloud() }
                } label: {
                    settingsRowContent(
                        icon: "icloud.and.arrow.down",
                        iconBg: Theme.Colors.Time.cycle.surface,
                        iconColor: Theme.Colors.Time.cycle.base,
                        title: "Restore from iCloud",
                        subtitle: "Download your data from iCloud",
                        trailing: {
                            if cloudActivity == .restoring {
                                ProgressView().controlSize(.small)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .disabled(cloudActivity != nil)

                settingsDivider()

                Button {
                    Task { await syncNow() }
                } label: {
                    settingsRowContent(
                        icon: "arrow.triangle.2.circlepath.icloud",
                        iconBg: Theme.Colors.Time.cycle.surface,
                        iconColor: Theme.Colors.Time.cycle.base,
                        title: "Sync Now",
                        subtitle: "Upload changes and refresh from iCloud",
                        trailing: {
                            if cloudActivity == .syncing {
                                ProgressView().controlSize(.small)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .disabled(cloudActivity != nil)
            }

            settingsDivider()

            NavigationLink(destination: AppLockSettingsView()) {
                settingsRowContent(
                    icon: "lock.fill",
                    iconBg: Theme.Colors.neutralSurface,
                    iconColor: Theme.Colors.textSecondary,
                    title: "App lock",
                    subtitle: privacyLockSubtitle,
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
        }
    }

    var privacyLockSubtitle: LocalizedStringResource {
        let biometric = authManager.biometricType().description
        let timeout = authManager.timeoutLabel
        return "\(biometric) · \(timeout) timeout"
    }

    // MARK: - About Section

    var settingsAboutSection: some View {
        settingsSection(label: "About") {
            settingsRowContent(
                icon: "info.circle.fill",
                iconBg: Theme.Colors.neutralSurface,
                iconColor: Theme.Colors.textSecondary,
                title: "Version",
                subtitle: nil,
                trailing: { Text("0.9").font(.system(size: 13)).foregroundStyle(.secondary) }
            )
#if DEBUG
            settingsDivider()
            NavigationLink(destination: DeveloperSettingsView()) {
                settingsRowContent(
                    icon: "wrench.and.screwdriver",
                    iconBg: Theme.Colors.neutralSurface,
                    iconColor: Theme.Colors.textSecondary,
                    title: "Developer",
                    subtitle: "Tools & test options",
                    trailing: { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.secondary) }
                )
            }
            .buttonStyle(.plain)
#endif
        }
    }

    // MARK: - Reset Section

    var settingsResetSection: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            Button(role: .destructive, action: { showingResetAlert = true }) {
                settingsRowContent(
                    icon: "trash.fill",
                    iconBg: Theme.Colors.error.opacity(0.1),
                    iconColor: Theme.Colors.error,
                    title: "Reset app data",
                    subtitle: nil,
                    trailing: { EmptyView() }
                )
            }
            .buttonStyle(.plain)
            Divider().opacity(0.5)
        }
    }
}
