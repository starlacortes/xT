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

    @AppStorage("mm.rotationWindow_injection") private var rotationWindowInjection: Int = 14
    @AppStorage("mm.rotationWindow_topical") private var rotationWindowTopical: Int = 7
    @AppStorage("mm.rotationWindow_patch") private var rotationWindowPatch: Int = 30

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

        if let data = UserDefaults.standard.data(forKey: userPreferredZonesKey),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            _userPreferredZones = State(initialValue: decoded)
        } else {
            _userPreferredZones = State(initialValue: [:])
        }
    }

    @State private var showAvoidZones = false

    private let userPreferredZonesKey = "mm.userPreferredZones"
    @State private var userPreferredZones: [String: [String]] = [:]

    private var medicationRouteCombos: [(medication: String, routeClass: RouteClass)] {
        let medications = ["Estrogen", "Testosterone", "Progesterone"]
        let routes = RouteClass.allCases.filter { $0 != .oral }
        var combos: [(String, RouteClass)] = []
        for med in medications {
            for route in routes {
                combos.append((med, route))
            }
        }
        return combos
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    frequencySection
                    doseAmountSection
                    injectionTimeSection
                    rotationSafetySection
                    avoidZonesSection
                    preferredZonesSection
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

    // MARK: - Rotation Safety Section

    private var rotationSafetySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Rotation Safety Windows")

            Text("How many days before you can reuse the same administration site.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                rotationPickerRow(routeClass: .injection,
                                  displayName: "Injection (IM/SubQ)",
                                  value: $rotationWindowInjection,
                                  options: [7, 14, 21, 30])
                Divider().padding(.leading, 52)
                rotationPickerRow(routeClass: .topical,
                                  displayName: "Topical (Gel/Cream)",
                                  value: $rotationWindowTopical,
                                  options: [3, 5, 7, 10])
                Divider().padding(.leading, 52)
                rotationPickerRow(routeClass: .patch,
                                  displayName: "Patch",
                                  value: $rotationWindowPatch,
                                  options: [7, 14, 21, 30])
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color(.systemBackground))
            )
        }
    }

    private func rotationPickerRow(routeClass: RouteClass, displayName: String, value: Binding<Int>, options: [Int]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: routeClass.iconName)
                .font(.title3)
                .foregroundStyle(routeClass.tintColor)
                .frame(width: 28)

            Text(displayName)
                .font(Theme.Fonts.callout)
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: value) {
                ForEach(options, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .pickerStyle(.menu)
            .tint(routeClass.tintColor)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Avoid Zones Section

    private var avoidZonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Avoid Zones")

            NavigationLink(destination: AvoidZonesEditorView()) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.warning)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Avoid Zones")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(.primary)
                        Text(avoidZonesSubtitle)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }

    private var avoidZonesSubtitle: String {
        let count = medicationManager.avoidZones.count
        if count == 0 { return "No zones marked" }
        return "\(count) zone\(count == 1 ? "" : "s") marked"
    }

    // MARK: - Preferred Administration Zones Section

    private var preferredZonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Preferred Administration Zones")

            VStack(spacing: 0) {
                ForEach(Array(medicationRouteCombos.enumerated()), id: \.offset) { idx, combo in
                    let count = preferredZonesCount(
                        medication: combo.medication,
                        routeClass: combo.routeClass
                    )
                    NavigationLink(destination: PreferredZonesEditorView(
                        medication: combo.medication,
                        routeClass: combo.routeClass,
                        onSave: { zones in
                            let key = "\(combo.medication)|\(combo.routeClass.rawValue)"
                            userPreferredZones[key] = zones
                            if let data = try? JSONEncoder().encode(userPreferredZones) {
                                UserDefaults.standard.set(data, forKey: userPreferredZonesKey)
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: combo.routeClass.iconName)
                                .font(.title3)
                                .foregroundStyle(combo.routeClass.tintColor)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(combo.medication) — \(combo.routeClass.displayName)")
                                    .font(Theme.Fonts.callout)
                                    .foregroundStyle(.primary)
                                Text("\(count) \(count == 1 ? "zone" : "zones")")
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.systemBackground))
                        )
                    }

                    if idx < medicationRouteCombos.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func preferredZonesCount(medication: String, routeClass: RouteClass) -> Int {
        let key = "\(medication)|\(routeClass.rawValue)"
        if let userZones = userPreferredZones[key], !userZones.isEmpty {
            return userZones.count
        }
        return BodySketchData.preferredZones(medication: medication, routeClass: routeClass).count
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
