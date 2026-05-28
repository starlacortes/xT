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
    @Environment(\.authenticationManager) private var authManager

    // State for dose management
    @State private var selectedDoseDate = Date()
    @State private var showConfirmation = false
    @State private var showDoseRecorder = false

    // Context detection
    var isFromSettings: Bool

    init(isFromSettings: Bool = false) {
        self.isFromSettings = isFromSettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with profile info
                HStack {
                    Image(uiImage: profileManager.getCurrentProfileImage())
                        .resizable()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text("Hello, \(profileManager.profileDisplayName)")
                            .font(.title2)
                            .bold()

                        if medicationManager.isFullyConfigured {
                            Text("Taking \(medicationManager.medicationDisplayInfo)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Quick record dose button
                    Button(action: {
                        recordCurrentDose()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
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
            authManager.recordActivity()
            selectedDoseDate = medicationManager.lastDoseDate ?? Date()
        }
        .alert("Dose Recorded", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your dose has been recorded successfully!")
        }
    }

    // MARK: - Subviews

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication Status")
                .font(.headline)

            if medicationManager.isFullyConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text(medicationManager.getConfigurationSummary())
                        .font(.body)
                }
            } else if medicationManager.isPartiallyConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text(medicationManager.getConfigurationSummary())
                        .font(.body)
                }
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)

                    Text("Not configured")
                        .font(.body)
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
                    color: .blue,
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
                .font(.headline)

            // Date picker for dose recording
            VStack(spacing: 12) {
                Text("Select dose date:")
                    .font(.subheadline)

                DatePicker("", selection: $selectedDoseDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding(.vertical, 8)

                Text("Next dose will be: \(medicationManager.calculateNextDoseDate(from: selectedDoseDate), style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: {
                    recordDose()
                }) {
                    Text("Record Dose on Selected Date")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: icon)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.body)
                .bold()
                .foregroundColor(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func recordCurrentDose() {
        medicationManager.recordDose(on: Date())
        showConfirmation = true
        selectedDoseDate = Date()
    }

    private func recordDose() {
        medicationManager.recordDose(on: selectedDoseDate)
        showConfirmation = true
    }
}

// MARK: - Preview

#Preview {
    UnifiedScheduleView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
}