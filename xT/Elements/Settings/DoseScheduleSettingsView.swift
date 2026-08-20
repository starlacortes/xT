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

    @State private var rotationWindowInjection: Int
    @State private var rotationWindowTopical: Int
    @State private var rotationWindowPatch: Int

    /// Display unit for the dose-amount picker. `defaultDoseAmount` is always
    /// stored in mg (the canonical unit `MedicationManager.defaultDoseAmount`
    /// and `DoseRecord.doseAmount` use); `mL` is a display preference for
    /// injections, converted via the resolved vial concentration. Persisted
    /// locally so the user's last choice round-trips across opens.
    @State private var doseUnit: String

    /// Vial concentration used for the mg↔mL conversion in the dose-amount
    /// picker. Only meaningful for injections; pulled from the manager's
    /// resolved default chain.
    @State private var concentration: Double

    private let medicationName: String

    init() {
        let mgr = MedicationManager.shared
        _customFrequencyDays = State(initialValue: mgr.customFrequencyDays ?? Self.defaultFrequencyDays(for: mgr.selectedAdministrationMethod))
        _defaultDoseAmount = State(initialValue: mgr.defaultDoseAmount ?? Self.defaultDose(for: mgr.selectedMedication, method: mgr.selectedAdministrationMethod))
        _defaultInjectionTime = State(initialValue: mgr.defaultInjectionTime ?? Self.defaultTime())
        _rotationWindowInjection = State(initialValue: mgr.rotationWindowInjection)
        _rotationWindowTopical = State(initialValue: mgr.rotationWindowTopical)
        _rotationWindowPatch = State(initialValue: mgr.rotationWindowPatch)

        let route = RouteClass.from(method: mgr.selectedAdministrationMethod ?? "")
        let storedUnit = UserDefaults.standard.string(forKey: Self.doseUnitKey) ?? "mg"
        _doseUnit = State(initialValue: route == .injection ? storedUnit : "mg")
        _concentration = State(initialValue: mgr.defaultConcentrationMgPerMl ?? Self.defaultConcentration(for: mgr.selectedMedication))

        medicationName = mgr.selectedMedication ?? "Medication"
    }

    @State private var showAvoidZones = false

    private var currentRouteClass: RouteClass {
        RouteClass.from(method: medicationManager.selectedAdministrationMethod ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    frequencySection
                    doseAmountSection
                    injectionTimeSection
                    if currentRouteClass != .oral {
                        rotationSafetySection
                        avoidZonesSection
                        preferredZonesSection
                    }
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
            SheetSectionLabel(text: "Dosing Interval")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every ^[\(customFrequencyDays) day](inflect: true)")
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
                    .fill(Theme.Colors.appBackground)
            )
        }
    }

    // MARK: - Dose Amount Section

    private var doseAmountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Default Dose Amount")

            VStack(spacing: 12) {
                HStack {
                    Text(verbatim: displayAmountString)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(displayUnitLabel)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if currentRouteClass == .injection {
                    Picker("Dose Unit", selection: $doseUnit) {
                        Text("mg").tag("mg")
                        Text("mL").tag("mL")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: doseUnit) { _, newUnit in
                        UserDefaults.standard.set(newUnit, forKey: Self.doseUnitKey)
                        // `defaultDoseAmount` is always in mg and the picker tags
                        // are mg values, so the underlying selection stays valid
                        // across a unit switch — only the row labels change. No
                        // re-snapping needed.
                    }
                }

                Picker("Dose amount", selection: $defaultDoseAmount) {
                    ForEach(doseAmounts, id: \.self) { amount in
                        Text(verbatim: formatAmountRow(amount)).tag(amount)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)

                if currentRouteClass == .injection {
                    Text(injectionConversionLabel)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.appBackground)
            )
        }
    }

    // MARK: - Injection Time Section

    private var injectionTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Default Time of Day")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeLabel)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(timeSectionHelper)
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
                    .fill(Theme.Colors.appBackground)
            )
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Preview")

            VStack(spacing: 10) {
                previewRow(
                    label: "Next dose",
                    value: Text(verbatim: previewNextDoseString)
                )
                Divider()
                previewRow(
                    label: "Schedule",
                    value: Text(LocalizedStringResource(
                        "Every ^[\(customFrequencyDays) day](inflect: true)",
                        comment: "Dosing interval, e.g. 'Every 7 days'"
                    ))
                )
                Divider()
                previewRow(
                    label: "Default dose",
                    value: Text(verbatim: previewDoseString)
                )
                Divider()
                previewRow(
                    label: "Time",
                    value: Text(verbatim: timeLabel)
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.appBackground)
            )
        }
    }

    /// `value` is a `Text` so the caller picks the right Text initializer:
    /// `Text(verbatim: str)` for already-formatted plain strings (times, dose
    /// amounts, dates), and `Text(LocalizedStringResource("^[…](inflect: true)"))`
    /// for values carrying Markdown grammar that needs to be parsed.
    private func previewRow(label: String, value: Text) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Spacer()
            value
                .font(Theme.Fonts.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private var timeLabel: String {
        AppDateFormatters.time.string(from: defaultInjectionTime)
    }

    /// Adaptive helper text for the "Default Time of Day" section. For daily
    /// routes (cream/oral) the time-of-day is the dominant scheduling cue; for
    /// weekly injections the day-of-week matters and the time is secondary.
    private var timeSectionHelper: String {
        switch currentRouteClass {
        case .injection:
            return "Pre-fills the time when recording a dose. The day-of-week follows your last dose plus the interval above."
        case .topical, .patch:
            return "Pre-fills the time when recording a daily application"
        case .oral:
            return "Pre-fills the time when recording a daily dose"
        }
    }


    private func formatDate(_ date: Date) -> String {
        let f = AppDateFormatters.monthDay
        return f.string(from: date)
    }

    // MARK: - Dose amount display & conversion

    /// Whether the dose-amount picker is showing mL (only true for injections).
    private var showingML: Bool {
        currentRouteClass == .injection && doseUnit == "mL"
    }

    /// The numeric value in the currently selected display unit.
    /// `defaultDoseAmount` is always stored in mg; for mL display we divide by
    /// the resolved vial concentration.
    private var displayedAmount: Double {
        guard showingML, concentration > 0 else { return defaultDoseAmount }
        return defaultDoseAmount / concentration
    }

    /// The big number shown at the top of the dose-amount section.
    private var displayAmountString: String {
        if showingML {
            return AppNumberFormatters.volume.string(displayedAmount)
        }
        return AppNumberFormatters.dose.string(defaultDoseAmount)
    }

    /// The unit label shown next to the big number.
    private var displayUnitLabel: String {
        showingML ? "mL" : "mg"
    }

    /// Wheel-picker row text for a given mg tag value, in the current display unit.
    private func formatAmountRow(_ amountMg: Double) -> String {
        if showingML, concentration > 0 {
            let mL = amountMg / concentration
            return "\(AppNumberFormatters.volume.string(mL)) mL"
        }
        return "\(AppNumberFormatters.dose.string(amountMg)) mg"
    }

    /// The "= X mL @ Y mg/mL" caption under the picker for injections.
    private var injectionConversionLabel: String {
        if showingML {
            return "= \(AppNumberFormatters.dose.string(defaultDoseAmount)) mg @ \(AppNumberFormatters.concentration.string(concentration)) mg/mL"
        }
        let volume = MedicationManager.computedVolume(doseMg: defaultDoseAmount, concentrationMgPerMl: concentration)
        return "= \(AppNumberFormatters.volume.string(volume)) mL @ \(AppNumberFormatters.concentration.string(concentration)) mg/mL"
    }

    /// Route- and unit-aware list of selectable amounts (in mg, the canonical
    /// storage unit). Granularity and range adapt to the route so that:
    ///   - injections expose sub-mL volumes (0.05 mg steps at 40 mg/mL → 0.00125 mL)
    ///     and the usual 0.5 mg…200 mg mg range,
    ///   - topical/patch expose the small fractions of a mg those routes use,
    ///   - oral exposes 0.1 mg…40 mg.
    ///
    /// The list is in mg because `defaultDoseAmount` is in mg; the row label
    /// converts to mL for display when the mL toggle is on.
    private var doseAmounts: [Double] {
        let route = currentRouteClass
        let isTestosterone = medicationManager.selectedMedication == "Testosterone"
        switch route {
        case .injection:
            // 0.05 mg granularity covers 0.05…10 mg (so 0.3 mL at 40 mg/mL = 12 mg
            // is reachable in mg, and 0.05 mL steps at 200 mg/mL = 10 mg reach it too),
            // then 1 mg steps up to 400 mg for larger testosterone depot doses.
            var amounts: [Double] = []
            for i in stride(from: 0.05, through: 10.0, by: 0.05) { amounts.append(i) }
            for i in stride(from: 10.5, through: 400.0, by: 0.5) { amounts.append(i) }
            return amounts
        case .topical:
            // Estradiol gel/cream: 0.01…5 mg. Testosterone gel: 5…100 mg.
            if isTestosterone {
                var amounts: [Double] = []
                for i in stride(from: 5.0, through: 100.0, by: 2.5) { amounts.append(i) }
                return amounts
            }
            var amounts: [Double] = []
            for i in stride(from: 0.01, through: 1.0, by: 0.01) { amounts.append(i) }
            for i in stride(from: 1.25, through: 5.0, by: 0.25) { amounts.append(i) }
            return amounts
        case .patch:
            // Estradiol patch: 0.025…0.1 mg/day release. Testosterone patch: 1…8 mg/day.
            if isTestosterone {
                return Array(stride(from: 1.0, through: 8.0, by: 0.5))
            }
            return Array(stride(from: 0.025, through: 0.2, by: 0.005))
        case .oral:
            // Estradiol oral: 0.5…8 mg. Testosterone oral (rare): 10…40 mg.
            if isTestosterone {
                return Array(stride(from: 10.0, through: 40.0, by: 2.5))
            }
            var amounts: [Double] = []
            for i in stride(from: 0.25, through: 4.0, by: 0.25) { amounts.append(i) }
            for i in stride(from: 4.5, through: 8.0, by: 0.5) { amounts.append(i) }
            return amounts
        }
    }

    // MARK: - Live preview values

    /// "Next dose" preview that reflects the *in-flight* `customFrequencyDays`
    /// edit, not the stale persisted `nextDoseDate`. Recomputes from
    /// `lastDoseDate` + the new interval the same way `saveChanges` will.
    private var previewNextDoseString: String {
        guard let last = medicationManager.lastDoseDate else {
            return "No dose scheduled"
        }
        let next = Calendar.current.date(byAdding: .day, value: customFrequencyDays, to: last) ?? Date()
        return formatDate(next)
    }

    /// Route-aware "Default dose" preview string, in the current display unit.
    private var previewDoseString: String {
        if showingML, concentration > 0 {
            let mL = defaultDoseAmount / concentration
            return "\(AppNumberFormatters.volume.string(mL)) mL"
        }
        return "\(AppNumberFormatters.dose.string(defaultDoseAmount)) mg"
    }

    private static func defaultFrequencyDays(for method: String?) -> Int {
        guard let method = method,
              let adminMethod = MedicationManager.AdministrationMethod(rawValue: method) else {
            return 7
        }
        return adminMethod.frequencyDays
    }

    /// Route- and medication-aware default dose in mg.
    ///
    /// Replaces the medication-only branch that returned 2.0 for everything
    /// non-testosterone, which gave a 2 mg default to a 0.05 mg estradiol gel
    /// and a 2 mg default to a 1 mg oral estradiol tablet. The values below
    /// are common starting prescriptions, not therapeutic recommendations —
    /// the user (or their provider) sets the real value.
    private static func defaultDose(for type: String?, method: String?) -> Double {
        let isTestosterone = (type == "Testosterone")
        let route = RouteClass.from(method: method ?? "")
        switch route {
        case .injection:
            return isTestosterone ? PKConstants.defaultTestosteroneDoseMg : PKConstants.referenceEstrogenDoseMg
        case .topical:
            // Estradiol gel/cream is dosed in fractions of a mg of active E2;
            // transdermal testosterone gel is dosed in tens of mg.
            return isTestosterone ? 25.0 : 0.05
        case .patch:
            return isTestosterone ? 2.5 : 0.05
        case .oral:
            return isTestosterone ? 25.0 : 1.0
        }
    }

    /// Default vial concentration used for the mg↔mL conversion preview when
    /// no prior dose has recorded one. Mirrors `+Dosing.defaultConcentrationMgPerMl`.
    private static func defaultConcentration(for type: String?) -> Double {
        if type == "Testosterone" {
            return PKConstants.referenceTestosteroneConcentrationMgPerMl
        }
        return PKConstants.referenceEstrogenConcentrationMgPerMl
    }

    private static func defaultTime() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    /// UserDefaults key for the dose-amount display unit (mg/mL) preference.
    private static let doseUnitKey = "mm.doseScheduleDisplayUnit"

    // MARK: - Rotation Safety Section

    private var rotationSafetySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Rotation Safety Windows")

            Text("How many days before you can reuse the same administration site.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                switch currentRouteClass {
                case .injection:
                    rotationPickerRow(routeClass: .injection,
                                      displayName: "Injection (IM/SubQ)",
                                      value: $rotationWindowInjection,
                                      options: [7, 14, 21, 30])
                case .topical:
                    rotationPickerRow(routeClass: .topical,
                                      displayName: "Topical (Gel/Cream)",
                                      value: $rotationWindowTopical,
                                      options: [3, 5, 7, 10])
                case .patch:
                    rotationPickerRow(routeClass: .patch,
                                      displayName: "Patch",
                                      value: $rotationWindowPatch,
                                      options: [7, 14, 21, 30])
                case .oral:
                    EmptyView()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.appBackground)
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
            SheetSectionLabel(text: "Avoid Zones")

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
                        .fill(Theme.Colors.appBackground)
                )
            }
        }
    }

    private var avoidZonesSubtitle: LocalizedStringResource {
        let count = medicationManager.avoidZones.count
        if count == 0 { return "No zones marked" }
        return LocalizedStringResource(
            "^[\(count) zone](inflect: true) marked",
            comment: "Subtitle counting marked body zones"
        )
    }

    // MARK: - Preferred Administration Zones Section

    private var preferredZonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Preferred Administration Zones")

            NavigationLink(destination: PreferredZonesListView()) {
                HStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preferred zones")
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(.primary)
                        Text("Favoured sites per medication & route")
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
                        .fill(Theme.Colors.appBackground)
                )
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        let oldFrequency = medicationManager.customFrequencyDays
        let frequencyChanged = oldFrequency != customFrequencyDays

        medicationManager.customFrequencyDays = customFrequencyDays
        medicationManager.defaultDoseAmount = defaultDoseAmount
        medicationManager.defaultInjectionTime = defaultInjectionTime
        medicationManager.rotationWindowInjection = rotationWindowInjection
        medicationManager.rotationWindowTopical = rotationWindowTopical
        medicationManager.rotationWindowPatch = rotationWindowPatch

        // `refreshState()` does NOT recompute `nextDoseDate` — only `addDose`,
        // `updateSelection`, `softDeleteDose`, and `loadUserPreferences` do.
        // When the user changes the dosing interval here, `nextDoseDate` was
        // left stale, so the home screen's "Next dose" weekday and the
        // notification schedule kept the old interval. Mirror what
        // `updateSelection` does: re-anchor on `lastDoseDate` with the new
        // frequency.
        if frequencyChanged, let last = medicationManager.lastDoseDate {
            let next = medicationManager.calculateNextDoseDate(from: last)
            medicationManager.nextDoseDate = next
        }

        medicationManager.persistUserPreferences()
        medicationManager.refreshState()
        dismiss()
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        DoseScheduleSettingsView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
