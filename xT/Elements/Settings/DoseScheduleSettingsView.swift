//
//  DoseScheduleSettingsView.swift
//  xT
//
//  Configure dosing frequency, default amount, and injection time from Settings.
//

import SwiftUI

struct DoseScheduleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.medicationManager) private var medicationManager

    @State private var customFrequencyDays: Int
    @State private var defaultDoseAmount: Double
    @State private var defaultInjectionTime: Date

    private let doseAmounts: [Double] = {
        var amounts: [Double] = []
        for i in stride(from: 0.5, through: 10.0, by: 0.5) { amounts.append(i) }
        for i in stride(from: 11.0, through: 200.0, by: 1.0) { amounts.append(i) }
        return amounts
    }()

    private let doseUnit: String
    private let medicationName: String

    init() {
        let mgr = MedicationManager.shared
        _customFrequencyDays = State(initialValue: mgr.customFrequencyDays ?? Self.defaultFrequencyDays(for: mgr.selectedAdministrationMethod))
        _defaultDoseAmount = State(initialValue: mgr.defaultDoseAmount ?? Self.defaultDose(for: mgr.selectedMedication))
        _defaultInjectionTime = State(initialValue: mgr.defaultInjectionTime ?? Self.defaultTime())

        doseUnit = mgr.selectedMedication == "Testosterone" ? "mg" : "mg"
        medicationName = mgr.selectedMedication ?? "Medication"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    frequencySection
                    doseAmountSection
                    injectionTimeSection
                    previewSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dose Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Dosing Interval")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every \(customFrequencyDays) \(customFrequencyDays == 1 ? "day" : "days")")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text("Default is \(Self.defaultFrequencyDays(for: medicationManager.selectedAdministrationMethod)) days for \(medicationManager.selectedAdministrationMethod ?? "selected") method")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Stepper(
                    "",
                    value: $customFrequencyDays,
                    in: 1...30
                )
                .labelsHidden()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
        }
    }

    // MARK: - Dose Amount Section

    private var doseAmountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Default Dose Amount")

            VStack(spacing: 12) {
                HStack {
                    Text(String(format: "%.1f", defaultDoseAmount))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(doseUnit)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Picker("Dose amount", selection: $defaultDoseAmount) {
                    ForEach(doseAmounts, id: \.self) { amount in
                        Text(String(format: "%.1f mg", amount)).tag(amount)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
        }
    }

    // MARK: - Injection Time Section

    private var injectionTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Default Time of Day")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeLabel)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text("Pre-fills the time when recording a dose")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DatePicker(
                    "",
                    selection: $defaultInjectionTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Preview")

            VStack(spacing: 10) {
                previewRow(
                    label: "Next dose",
                    value: medicationManager.nextDoseDate.map { formatDate($0) } ?? "No dose scheduled"
                )
                Divider()
                previewRow(
                    label: "Schedule",
                    value: "Every \(customFrequencyDays) \(customFrequencyDays == 1 ? "day" : "days")"
                )
                Divider()
                previewRow(
                    label: "Default dose",
                    value: "\(String(format: "%.1f", defaultDoseAmount)) \(doseUnit)"
                )
                Divider()
                previewRow(
                    label: "Time",
                    value: timeLabel
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
        }
    }

    private func previewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Fonts.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private var timeLabel: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: defaultInjectionTime)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private static func defaultFrequencyDays(for method: String?) -> Int {
        guard let method = method,
              let adminMethod = MedicationManager.AdministrationMethod(rawValue: method) else {
            return 7
        }
        return adminMethod.frequencyDays
    }

    private static func defaultDose(for type: String?) -> Double {
        type == "Testosterone" ? 40.0 : 2.0
    }

    private static func defaultTime() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - Save

    private func saveChanges() {
        medicationManager.customFrequencyDays = customFrequencyDays
        medicationManager.defaultDoseAmount = defaultDoseAmount
        medicationManager.defaultInjectionTime = defaultInjectionTime
        medicationManager.persistUserPreferences()
        medicationManager.refreshState()
        dismiss()
    }
}
