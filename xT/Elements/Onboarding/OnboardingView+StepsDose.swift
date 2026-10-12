//
//  OnboardingView+StepsDose.swift
//  xT
//
//  Steps 4-6: method & ester, concentration, and dose & timing — plus the method/ester cards and hints.
//  (Split from OnboardingView.swift — same `OnboardingView`, different file.)
//

import SwiftUI

extension OnboardingView {

    // MARK: - Step 4: Method & Ester
    var medicationStep: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                Text("How do you take it?")
                    .font(Theme.Fonts.serifTitle)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    .padding(.top, Theme.Spacing.xxxl)

                // Method cards
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(MedicationManager.AdministrationMethod.allCases, id: \.rawValue) { method in
                        methodCard(method)
                    }
                }
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                // Ester selection — only for injectables
                if selectedMethod == "Injectable" {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Which ester?")
                            .font(Theme.Fonts.eyebrow)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                        esterList
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: selectedMethod)
                }

                // Frequency selector
                if !selectedMethod.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Dosing frequency")
                            .font(Theme.Fonts.eyebrow)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                        
                        HStack {
                            Stepper("Every \(selectedFrequency) days", value: $selectedFrequency, in: 1...30)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 40)
                HStack(spacing: 16) {
                    secondaryButton("Back") { previousStep() }
                    primaryButton("Continue", disabled: selectedMethod.isEmpty || (selectedMethod == "Injectable" && selectedEster.isEmpty)) {
                        // Auto-select default concentration before advancing
                        if selectedConcentration <= 0 {
                            autoSelectConcentration(for: selectedEster)
                        }
                        advanceStep()
                    }
                }
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .padding(.bottom, Theme.Spacing.Gutter.onboarding)
            }
        }
    }

    // MARK: - Step 5: Concentration Selection (NEW)
    var concentrationStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()
            Text("What's your vial concentration?")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Text("Look for a number followed by 'mg/mL' on your vial or box.\nFor example, a 200 mg/5 mL vial is 40 mg/mL.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            concentrationPickerList
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue", disabled: selectedConcentration <= 0) { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
    }

    var concentrationPickerList: some View {
        VStack(spacing: Theme.Spacing.md) {
            let concentrations = MedicationManager.commonConcentrations(forEster: selectedEster)
            ForEach(concentrations.filter { $0 > 0 }, id: \.self) { conc in
                concentrationRow(conc)
            }
            customConcentrationRow
            if showCustomConcentration {
                customConcentrationField
            }
        }
    }

    func concentrationRow(_ conc: Double) -> some View {
        let isSelected = selectedConcentration == conc && !showCustomConcentration
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedConcentration = conc
                showCustomConcentration = false
            }
        } label: {
            HStack {
                Text("\(String(format: "%.0f", conc)) mg/mL")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if isMostCommonConcentration(conc) {
                    Text("· most common")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Fonts.icon)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.13) : Theme.Colors.appBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.accent : Theme.Colors.border, lineWidth: Theme.Line.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    var customConcentrationRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCustomConcentration = true
                customConcentrationText = ""
            }
        } label: {
            HStack {
                Text("Custom")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if showCustomConcentration {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Fonts.icon)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(showCustomConcentration ? Theme.Colors.accent.opacity(0.13) : Theme.Colors.appBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(showCustomConcentration ? Theme.Colors.accent : Theme.Colors.border, lineWidth: Theme.Line.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    var customConcentrationField: some View {
        HStack {
            TextField("mg/mL", text: $customConcentrationText)
                .keyboardType(.decimalPad)
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.appBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                )
                .onChange(of: customConcentrationText) { _, new in
                    if let val = Double(new), val > 0 {
                        selectedConcentration = val
                    }
                }
            Text("mg/mL")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    func isMostCommonConcentration(_ conc: Double) -> Bool {
        switch selectedEster {
        case "Valerate (EV)": return conc == 40
        case "Cypionate (EC)": return conc == 5
        case "Cypionate (TC)", "Enanthate (TE)": return conc == 200
        default: return false
        }
    }

    // MARK: - Step 6: Dose & Timing (Enhanced with mg/mL toggle)
    var doseStep: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Text("What's your dose?")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            // mg / mL segmented control
            Picker("Dose Unit", selection: $doseUnit) {
                Text("mg").tag("mg")
                Text("mL").tag("mL")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            // Dose entry
            VStack(spacing: Theme.Spacing.row) {
                if doseUnit == "mg" {
                    // mg mode
                    HStack(spacing: Theme.Spacing.md) {
                        Stepper("", value: $doseDecimal, in: 0.1...500, step: 0.1)
                            .labelsHidden()
                            .tint(Theme.Colors.accent)

                        TextField("", text: $doseText)
                            .keyboardType(.decimalPad)
                            .font(Theme.Fonts.numeric)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.appBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                            )
                            .focused($doseFieldFocused)
                            .onChange(of: doseDecimal) { _, new in
                                if doseUnit == "mg" { doseText = String(format: "%.1f", new) }
                            }
                            .onChange(of: doseFieldFocused) { _, focused in
                                if !focused, doseUnit == "mg" {
                                    if let val = Double(doseText), val > 0 {
                                        doseDecimal = val
                                        updateMlFromMg()
                                    } else {
                                        doseText = String(format: "%.1f", doseDecimal)
                                    }
                                }
                            }
                            .keyboardDoneToolbar { doseFieldFocused = false }

                        Text("mg")
                            .font(Theme.Fonts.serifTitle)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                    // Computed volume display
                    let volume = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                    Text("= \(String(format: "%.3f", volume)) mL (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                    // Volume warning
                    if let warning = MedicationManager.volumeNote(for: volume, ester: selectedEster) {
                        volumeWarningBanner(warning)
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    }

                } else {
                    // mL mode
                    HStack(spacing: Theme.Spacing.md) {
                        Stepper("", value: $mlAmount, in: 0.01...10, step: 0.01)
                            .labelsHidden()
                            .tint(Theme.Colors.accentSecondary)

                        TextField("", text: $mlText)
                            .keyboardType(.decimalPad)
                            .font(Theme.Fonts.numeric)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.appBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                            )
                            .focused($doseFieldFocused)
                            .onChange(of: mlAmount) { _, new in
                                if doseUnit == "mL" {
                                    mlText = String(format: "%.2f", new)
                                    doseDecimal = new * selectedConcentration
                                    doseText = String(format: "%.1f", doseDecimal)
                                }
                            }
                            .onChange(of: doseFieldFocused) { _, focused in
                                if !focused, doseUnit == "mL" {
                                    if let val = Double(mlText), val > 0 {
                                        mlAmount = val
                                        doseDecimal = val * selectedConcentration
                                        doseText = String(format: "%.1f", doseDecimal)
                                    } else {
                                        mlText = String(format: "%.2f", mlAmount)
                                    }
                                }
                            }
                            .keyboardDoneToolbar { doseFieldFocused = false }

                        Text("mL")
                            .font(Theme.Fonts.serifTitle)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                    // Computed mg display
                    let computedMg = mlAmount * selectedConcentration
                    Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                    // Volume warning
                    if let warning = MedicationManager.volumeNote(for: mlAmount, ester: selectedEster) {
                        volumeWarningBanner(warning)
                            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    }
                }

                // Quick dose chips
                quickDoseChips
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                    .padding(.top, Theme.Spacing.sm)
            }

            // Concentration adjustment (inline)
            VStack(spacing: 6) {
                Text("Vial concentration")
                    .font(Theme.Fonts.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                concentrationQuickPicker
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            }

            // Last dose date
            VStack(spacing: Theme.Spacing.sm) {
                Text("When was your last dose?")
                    .font(Theme.Fonts.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                DatePicker("", selection: $lastDoseDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            }

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
        .onAppear {
            updateMlFromMg()
        }
    }

    var concentrationQuickPicker: some View {
        let concentrations = MedicationManager.commonConcentrations(forEster: selectedEster)
            .filter { $0 > 0 }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(concentrations, id: \.self) { conc in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedConcentration = conc
                            showCustomConcentration = false
                            updateMlFromMg()
                        }
                    } label: {
                        Pill(text: "\(String(format: "%.0f", conc))",
                             style: selectedConcentration == conc && !showCustomConcentration ? .active : .neutral)
                    }
                }
                // Custom chip
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCustomConcentration = true
                    }
                } label: {
                    Pill(text: "Custom", style: showCustomConcentration ? .active : .neutral)
                }
            }
        }
    }

    func volumeWarningBanner(_ message: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.warning)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.Colors.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.warning.opacity(0.4), lineWidth: Theme.Line.hairline)
        )
    }

    var quickDoseChips: some View {
        let doses: [Double] = {
            if doseUnit == "mg" {
                return selectedType == "Estrogen" ? [0.5, 1, 2, 4, 6] : [20, 40, 60, 80, 100]
            } else {
                return selectedType == "Estrogen" ? [0.05, 0.1, 0.15, 0.2, 0.3] : [0.1, 0.2, 0.3, 0.4, 0.5]
            }
        }()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(doses, id: \.self) { dose in
                    quickDoseChip(dose)
                }
            }
        }
    }

    func quickDoseChip(_ dose: Double) -> some View {
        let isSelected = doseUnit == "mg" ? (doseDecimal == dose) : (mlAmount == dose)
        let label = doseUnit == "mg" ? String(format: "%.0f", dose) : String(format: "%.2f", dose)

        return Button {
            withAnimation(Theme.Motion.quick) {
                if doseUnit == "mg" {
                    doseDecimal = dose
                    doseText = String(format: "%.1f", dose)
                } else {
                    mlAmount = dose
                    mlText = String(format: "%.2f", dose)
                    doseDecimal = dose * selectedConcentration
                    doseText = String(format: "%.1f", doseDecimal)
                }
            }
        } label: {
            Pill(text: label, style: isSelected ? .active : .neutral)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Methods
    func methodCard(_ method: MedicationManager.AdministrationMethod) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMethod = method.rawValue
                selectedFrequency = method.frequencyDays
                if method != .injectable { selectedEster = "" }
                // Default ester comes from the manager's single source — the two
                // hand-paired raw strings here ("Valerate (EV)" / "Cypionate (TC)")
                // had already drifted once (T used the estrogen "EC" casing).
                if method == .injectable && selectedEster.isEmpty {
                    let def = MedicationManager.defaultEsterInfo(for: selectedType)
                    selectedEster = def.name
                    autoSelectConcentration(for: def.name)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(method.rawValue)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(frequencyHint(for: method))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if selectedMethod == method.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Fonts.icon)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedMethod == method.rawValue ? Theme.Colors.accent.opacity(0.13) : Theme.Colors.appBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedMethod == method.rawValue ? Theme.Colors.accent : Theme.Colors.border, lineWidth: Theme.Line.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
    }

    var esterList: some View {
        let items: [(name: String, tHalf: Double, tPeak: Double, calibrated: Bool)] = {
            // `injectableCases` excludes the Oral/Transdermal route pseudo-esters, which
            // must never appear here — this list is only shown for the Injectable route.
            if selectedType == "Estrogen" {
                return MedicationEster.injectableCases.map {
                    ($0.rawValue, $0.halfLifeDays, $0.timeToPeakDays, $0.isTmaxCalibrated)
                }
            } else {
                return TestosteroneEster.injectableCases.map {
                    ($0.rawValue, $0.halfLifeDays, $0.timeToPeakDays, $0.isTmaxCalibrated)
                }
            }
        }()

        return VStack(spacing: Theme.Spacing.row) {
            ForEach(items, id: \.name) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEster = item.name
                        autoSelectConcentration(for: item.name)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(item.name)
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(esterSubtitle(tHalf: item.tHalf, tPeak: item.tPeak, calibrated: item.calibrated))
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if selectedEster == item.name {
                            Image(systemName: "checkmark.circle.fill")
                                .font(Theme.Fonts.icon)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(selectedEster == item.name ? Theme.Colors.accent.opacity(0.13) : Theme.Colors.appBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(selectedEster == item.name ? Theme.Colors.accent : Theme.Colors.border, lineWidth: Theme.Line.hairline)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
            }
        }
    }

    func frequencyHint(for method: MedicationManager.AdministrationMethod) -> LocalizedStringResource {
        switch method {
        case .injectable: return "Typical cycle: 7 days"
        case .cream: return "Applied daily"
        case .oral: return "Taken daily"
        }
    }

    /// Subtitle for a row in the ester picker.
    ///
    /// Replaces a `halfLife × 1.44` approximation that ignored the elimination rate
    /// entirely and so ran 2–44× long (TU read "Peaks day 29" against a modeled
    /// 0.66 d). Peak day now comes from `timeToPeakDays`, the same exact Bateman
    /// t_max the graph and `expectedTimeToPeak(for:)` use.
    ///
    /// Esters whose Tmax is not yet calibrated (TP alone since 2026-08-02 — still on
    /// the placeholder 2 h `ke`, see OPEN_CONCERNS.md §3) deliberately show no peak
    /// day. TE and TU now show one: 2 d and 7 d. Their
    /// computed value is right for the constants but wrong about the drug, and this
    /// is the screen where someone *chooses* an ester, so a confidently-wrong
    /// sub-day peak is worse than no peak at all.
    func esterSubtitle(tHalf: Double, tPeak: Double, calibrated: Bool) -> String {
        let halfLife = "Half‑life ~\(String(format: "%.1f", tHalf)) days"
        // `isFinite` is belt-and-braces: transdermal's t_max is NaN (ke is infinite on
        // that route) and `Int(Double.nan)` traps. It can't reach here today — the list
        // is built from `injectableCases` and transdermal is not calibrated — but a
        // trap in onboarding is a bad way to find out that changed.
        guard calibrated, tPeak.isFinite else { return "\(halfLife) · peak timing pending calibration" }
        // Every calibrated injectable peaks at ≥1.8 d, but floor at 1 anyway so a
        // future fast ester can never render "Peaks day 0".
        let day = max(1, Int(tPeak.rounded()))
        return "\(halfLife) · Peaks day \(day)"
    }
}
