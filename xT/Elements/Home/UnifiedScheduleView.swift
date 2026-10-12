//
//  UnifiedScheduleView.swift
//  xT
//
//  Created by Cline on 4/16/2026.
//  Unified scheduling interface combining ScheduleView and SchedulerView functionality
//

import SwiftUI
import SwiftData

struct UnifiedScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.profileManager) private var profileManager

    // State for dose management
    @State private var selectedDoseDate = Date()
    @State private var showConfirmation = false

    // Site location state (Phase 12)
    @State private var scheduledZoneLabel: String? = nil
    @State private var scheduledSites: [InjectionSite] = []
    @State private var showFullBodyPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with profile info
                HStack {
                    AvatarView(image: profileManager.profilePhoto, size: 60)

                    VStack(alignment: .leading) {
                        Text("Hello, \(profileManager.profileDisplayName)")
                            .font(Theme.Fonts.title2)
                            .bold()

                        if medicationManager.isFullyConfigured {
                            Text("Taking \(medicationManager.medicationDisplayInfo)")
                                .font(Theme.Fonts.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Quick record dose button
                    Button(action: {
                        recordCurrentDose()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(Theme.Fonts.title)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }
                .padding(.bottom, 10)

                // Medication Status Card
                statusCard

                // Schedule Information Cards
                scheduleCards

                // Dose Management Section (expandable)
                if medicationManager.isFullyConfigured {
                    doseManagementSection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Medication Schedule")
        .background(Color(UIColor.systemBackground))
        .onAppear {
            selectedDoseDate = medicationManager.lastDoseDate ?? Date()
            medicationManager.refreshState()
        }
        .alert("Dose Recorded", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your dose has been recorded successfully!")
        }
        .sheet(isPresented: $showFullBodyPicker) {
            bodyPickerSheet
        }
    }

    // MARK: - Subviews

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication Status")
                .font(Theme.Fonts.headline)

            if medicationManager.isFullyConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text(medicationManager.getConfigurationSummary())
                        .font(Theme.Fonts.body)
                }
            } else if medicationManager.isPartiallyConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(medicationManager.getConfigurationSummary())
                        .font(Theme.Fonts.body)
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)

                    Text("Not configured")
                        .font(Theme.Fonts.body)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private var scheduleCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Next dose section
            if let nextDate = medicationManager.nextDoseDate {
                    scheduleCard(
                        title: "Next Dose",
                        value: "\(nextDate.formatted(date: .abbreviated, time: .omitted))",
                        color: .orange,
                        icon: "calendar"
                    )
            }

            // Last dose section
            if let last = medicationManager.lastDoseDate {
                scheduleCard(
                    title: "Last Dose",
                    value: "\(last.formatted(date: .abbreviated, time: .omitted))",
                    color: Theme.Colors.Time.mind.base,
                    icon: "checkmark.circle"
                )
            } else {
                scheduleCard(
                    title: "Last Dose",
                    value: "No dose recorded yet",
                    color: .gray,
                    icon: "questionmark.circle"
                )
            }

            // Schedule summary
            if medicationManager.isFullyConfigured {
                scheduleCard(
                    title: "Schedule Summary",
                    value: medicationManager.scheduleSummary,
                    color: .green,
                    icon: "clock"
                )
            }
        }
    }

    private var doseManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Doses")
                .font(Theme.Fonts.headline)

            // Date picker for dose recording
            VStack(spacing: 12) {
                Text("Select dose date:")
                    .font(Theme.Fonts.subheadline)

                DatePicker("", selection: $selectedDoseDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding(.vertical, 8)

                Text("Next dose will be: \(medicationManager.calculateNextDoseDate(from: selectedDoseDate), style: .date)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                // Optional site location disclosure (Phase 12) — only for injection routes
                if isInjectionRoute {
                    DisclosureGroup("Set this dose's location (optional)") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Zone", selection: $scheduledZoneLabel) {
                                Text("None").tag(String?.none)
                                ForEach(recentZoneLabels, id: \.self) { zone in
                                    Text(zone).tag(String?.some(zone))
                                }
                                Text("Choose on Body Map\u{2026}").tag("__body_map__")
                            }
                            .pickerStyle(.menu)
                            .onChange(of: scheduledZoneLabel) { _, newValue in
                                if newValue == "__body_map__" {
                                    showFullBodyPicker = true
                                    scheduledZoneLabel = nil
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 4)
                }

                Button(action: {
                    recordDose(on: selectedDoseDate)
                }) {
                    Text("Record Dose on Selected Date")
                        .asAccentButton()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // MARK: - Helper Methods

    private func scheduleCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(Theme.Fonts.body)
                .bold()
                .foregroundStyle(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func recordCurrentDose() {
        recordDose(on: Date())
        selectedDoseDate = Date()
    }

    private func recordDose(on date: Date) {
        guard let medType = medicationManager.selectedMedication,
              let medMethod = medicationManager.selectedAdministrationMethod else { return }
        let defaults = medicationManager.resolvedDoseDefaults(medication: medType, method: medMethod)
        medicationManager.addDose(date: date, type: medType, ester: defaults.esterName, method: medMethod, doseAmount: defaults.amountMg, concentrationMgPerMl: defaults.concentrationMgPerMl, injectionSites: scheduledSites)
        showConfirmation = true
        scheduledSites = []
    }

    // MARK: - Phase 12: Site Location Support

    private var isInjectionRoute: Bool {
        guard let method = medicationManager.selectedAdministrationMethod else { return false }
        let rc = RouteClass.from(method: method)
        return rc == .injection || rc == .topical
    }

    private var recentZoneLabels: [String] {
        let recent = medicationManager.recentlyUsedZones(withinDays: currentRouteClass.defaultRotationWindowDays)
        return Array(recent).sorted()
    }

    private var currentRouteClass: RouteClass {
        guard let method = medicationManager.selectedAdministrationMethod else { return .injection }
        return RouteClass.from(method: method)
    }

    private var bodyPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Site picker has moved to the Quick Dose sheet.")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    showFullBodyPicker = false
                } label: {
                    Text("Dismiss")
                        .font(Theme.Fonts.headline)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        UnifiedScheduleView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.profileManager, ProfileManager.shared)
    }
}
#endif