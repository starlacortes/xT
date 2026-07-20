//
//  OnboardingView.swift
//  xT
//
//  Redesigned by Cline on 6/30/2026.
//  9-step progressive onboarding with concentration-aware dose logging.
//

import SwiftUI
import SwiftData
import PhotosUI

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct OnboardingView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.profileManager) private var profileManager

    var onboardingComplete: (() -> Void)? = nil

    // MARK: - Step State
    @State private var currentStep: Int = 0
    @State private var opacity: Double = 0
    
    // Step 2 — medication type
    @State private var selectedType: String = ""
    
    // Step 3 — HRT experience
    @State private var hasBeenOnHRT: Bool = false
    @State private var hrtDurationMonths: Int = 1
    @State private var hrtDurationYears: Int = 0
    
    // Step 4 — method + ester + frequency
    @State private var selectedMethod: String = ""
    @State private var selectedEster: String = ""
    @State private var selectedFrequency: Int = 7

    // Step 5 — vial concentration (NEW)
    @State private var selectedConcentration: Double = 40.0
    @State private var customConcentrationText: String = ""
    @State private var showCustomConcentration: Bool = false
    
    // Step 6 — dose + timing (enhanced with mg/mL toggle)
    @State private var doseUnit: String = "mg"
    @State private var doseDecimal: Double = 2.0
    @State private var doseText: String = "2.0"
    @State private var mlAmount: Double = 0.05
    @State private var mlText: String = "0.05"
    @State private var lastDoseDate: Date = Date()
    @FocusState private var doseFieldFocused: Bool
    
    // Step 7 — anti-androgens
    @State private var antiAndrogenChoice: String = "None"
    
    // Step 8 — profile
    @State private var profileName: String = ""
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false

    private let totalSteps = 9
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Theme.Gradients.brand
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 32)
                    .padding(.horizontal, 40)

                ZStack {
                    Group {
                        switch currentStep {
                        case 0: welcomeStep
                        case 1: pathStep
                        case 2: experienceStep
                        case 3: medicationStep
                        case 4: concentrationStep
                        case 5: doseStep
                        case 6: antiAndrogenStep
                        case 7: profileStep
                        case 8: reviewStep
                        default: EmptyView()
                        }
                    }
                    .opacity(opacity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1.0 }
        }
        .onChange(of: selectedEster) { _, newEster in
            // Auto-select default concentration when ester changes
            autoSelectConcentration(for: newEster)
        }
        .onChange(of: selectedConcentration) { _, _ in
            updateMlFromMg()
        }
        .onChange(of: doseDecimal) { _, _ in
            updateMlFromMg()
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("xT")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.95))
            Text("Welcome to your journey")
                .font(.title3)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
            primaryButton("Begin") { advanceStep() }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: Medication Type
    private var pathStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("What hormone are you taking?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                pathCard(
                    title: "Estrogen‑based HRT",
                    subtitle: "Estradiol — feminizing hormone therapy",
                    isSelected: selectedType == "Estrogen"
                ) { selectType("Estrogen", defaultDose: 2.0) }

                pathCard(
                    title: "Testosterone‑based HRT",
                    subtitle: "Testosterone — masculinizing hormone therapy",
                    isSelected: selectedType == "Testosterone"
                ) { selectType("Testosterone", defaultDose: 40.0) }
            }
            .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue", disabled: selectedType.isEmpty) { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 3: HRT Experience
    private var experienceStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("How long have you been on HRT?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                choiceCard(title: "Just starting", isSelected: !hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = false }
                }
                choiceCard(title: "I've been on it", isSelected: hasBeenOnHRT) {
                    withAnimation { hasBeenOnHRT = true }
                }
            }
            .padding(.horizontal, 40)

            if hasBeenOnHRT {
                HStack(spacing: 12) {
                    durationStepper(label: "Years", value: $hrtDurationYears, range: 0...20)
                    durationStepper(label: "Months", value: $hrtDurationMonths, range: 1...11)
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: hasBeenOnHRT)
    }

    // MARK: - Step 4: Method & Ester
    private var medicationStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("How do you take it?")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 32)

                // Method cards
                VStack(spacing: 12) {
                    ForEach(MedicationManager.AdministrationMethod.allCases, id: \.rawValue) { method in
                        methodCard(method)
                    }
                }
                .padding(.horizontal, 40)

                // Ester selection — only for injectables
                if selectedMethod == "Injectable" {
                    VStack(spacing: 12) {
                        Text("Which ester?")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 40)

                        esterList
                            .padding(.horizontal, 40)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: selectedMethod)
                }

                // Frequency selector
                if !selectedMethod.isEmpty {
                    VStack(spacing: 8) {
                        Text("Dosing frequency")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 40)
                        
                        HStack {
                            Stepper("Every \(selectedFrequency) days", value: $selectedFrequency, in: 1...30)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 40)
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
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Step 5: Concentration Selection (NEW)
    private var concentrationStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What's your vial concentration?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Look for a number followed by 'mg/mL' on your vial or box.\nFor example, a 200 mg/5 mL vial is 40 mg/mL.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            concentrationPickerList
                .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue", disabled: selectedConcentration <= 0) { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var concentrationPickerList: some View {
        VStack(spacing: 12) {
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

    private func concentrationRow(_ conc: Double) -> some View {
        let isSelected = selectedConcentration == conc && !showCustomConcentration
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedConcentration = conc
                showCustomConcentration = false
            }
        } label: {
            HStack {
                Text("\(String(format: "%.0f", conc)) mg/mL")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                if isMostCommonConcentration(conc) {
                    Text("· most common")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var customConcentrationRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCustomConcentration = true
                customConcentrationText = ""
            }
        } label: {
            HStack {
                Text("Custom")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if showCustomConcentration {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(showCustomConcentration ? Theme.Colors.accentSecondary.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(showCustomConcentration ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var customConcentrationField: some View {
        HStack {
            TextField("mg/mL", text: $customConcentrationText)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Color.white.opacity(0.15))
                )
                .onChange(of: customConcentrationText) { _, new in
                    if let val = Double(new), val > 0 {
                        selectedConcentration = val
                    }
                }
            Text("mg/mL")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func isMostCommonConcentration(_ conc: Double) -> Bool {
        switch selectedEster {
        case "Valerate (EV)": return conc == 40
        case "Cypionate (EC)": return conc == 5
        case "Cypionate (TC)", "Enanthate (TE)": return conc == 200
        default: return false
        }
    }

    // MARK: - Step 6: Dose & Timing (Enhanced with mg/mL toggle)
    private var doseStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("What's your dose?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 40)

            // mg / mL segmented control
            Picker("Dose Unit", selection: $doseUnit) {
                Text("mg").tag("mg")
                Text("mL").tag("mL")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            // Dose entry
            VStack(spacing: 10) {
                if doseUnit == "mg" {
                    // mg mode
                    HStack(spacing: 12) {
                        Stepper("", value: $doseDecimal, in: 0.1...500, step: 0.1)
                            .labelsHidden()
                            .tint(Theme.Colors.accent)

                        TextField("", text: $doseText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .focused($doseFieldFocused)
                            .onChange(of: doseText) { _, new in
                                if let val = Double(new) { doseDecimal = val }
                            }
                            .onChange(of: doseDecimal) { _, new in
                                if doseUnit == "mg" { doseText = String(format: "%.1f", new) }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { doseFieldFocused = false }
                                }
                            }

                        Text("mg")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    // Computed volume display
                    let volume = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                    Text("= \(String(format: "%.3f", volume)) mL (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 40)

                    // Volume warning
                    if let warning = MedicationManager.volumeWarning(for: volume, ester: selectedEster) {
                        volumeWarningBanner(warning)
                            .padding(.horizontal, 40)
                    }

                } else {
                    // mL mode
                    HStack(spacing: 12) {
                        Stepper("", value: $mlAmount, in: 0.01...10, step: 0.01)
                            .labelsHidden()
                            .tint(Theme.Colors.accentSecondary)

                        TextField("", text: $mlText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .focused($doseFieldFocused)
                            .onChange(of: mlText) { _, new in
                                if let val = Double(new) { mlAmount = val }
                            }
                            .onChange(of: mlAmount) { _, new in
                                if doseUnit == "mL" {
                                    mlText = String(format: "%.2f", new)
                                    doseDecimal = new * selectedConcentration
                                    doseText = String(format: "%.1f", doseDecimal)
                                }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { doseFieldFocused = false }
                                }
                            }

                        Text("mL")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    // Computed mg display
                    let computedMg = mlAmount * selectedConcentration
                    Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 40)

                    // Volume warning
                    if let warning = MedicationManager.volumeWarning(for: mlAmount, ester: selectedEster) {
                        volumeWarningBanner(warning)
                            .padding(.horizontal, 40)
                    }
                }

                // Quick dose chips
                quickDoseChips
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }

            // Concentration adjustment (inline)
            VStack(spacing: 6) {
                Text("Vial concentration")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)

                concentrationQuickPicker
                    .padding(.horizontal, 40)
            }

            // Last dose date
            VStack(spacing: 8) {
                Text("When was your last dose?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)

                DatePicker("", selection: $lastDoseDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(Theme.Colors.accentSecondary)
                    .padding(.horizontal, 40)
            }

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            updateMlFromMg()
        }
    }

    private var concentrationQuickPicker: some View {
        let concentrations = MedicationManager.commonConcentrations(forEster: selectedEster)
            .filter { $0 > 0 }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(concentrations, id: \.self) { conc in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedConcentration = conc
                            showCustomConcentration = false
                            updateMlFromMg()
                        }
                    } label: {
                        Text("\(String(format: "%.0f", conc))")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedConcentration == conc && !showCustomConcentration ? Theme.Colors.accentSecondary.opacity(0.5) : Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedConcentration == conc && !showCustomConcentration ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                // Custom chip
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCustomConcentration = true
                    }
                } label: {
                    Text("Custom")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showCustomConcentration ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func volumeWarningBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Color.yellow.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var quickDoseChips: some View {
        let doses: [Double] = {
            if doseUnit == "mg" {
                return selectedType == "Estrogen" ? [0.5, 1, 2, 4, 6] : [20, 40, 60, 80, 100]
            } else {
                return selectedType == "Estrogen" ? [0.05, 0.1, 0.15, 0.2, 0.3] : [0.1, 0.2, 0.3, 0.4, 0.5]
            }
        }()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(doses, id: \.self) { dose in
                    quickDoseChip(dose)
                }
            }
        }
    }

    private func quickDoseChip(_ dose: Double) -> some View {
        let isSelected = doseUnit == "mg" ? (doseDecimal == dose) : (mlAmount == dose)
        let label = doseUnit == "mg" ? String(format: "%.0f", dose) : String(format: "%.2f", dose)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
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
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Theme.Colors.accent.opacity(0.5) : Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Step 7: Anti-Androgens
    private var antiAndrogenStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Are you taking any other medications?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                aaCard(title: "None", subtitle: "I only take my hormone", choice: "None")
                aaCard(title: "Spironolactone", subtitle: "Common anti‑androgen — can slightly increase estrogen clearance", choice: "Spiro")
                aaCard(title: "Cyproterone / GnRH agonist", subtitle: "Suppresses testosterone production", choice: "Other AA")
                aaCard(title: "Finasteride / Dutasteride", subtitle: "5α‑reductase inhibitor — blocks DHT conversion", choice: "5ARI")
            }
            .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 8: Profile
    private var profileStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Personalize your space")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 8)

            // Photo
            Button { showImagePicker = true } label: {
                Image(uiImage: profileManager.getCurrentProfileImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            Text("Tap to add photo")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            // Name
            TextField("Your name", text: $profileName)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.white.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Color.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 40)

            // Photo options
            HStack(spacing: 24) {
                photoBtn("photo", "Library") { showImagePicker = true }
                photoBtn("camera", "Camera") { showCamera = true }
            }
            .padding(.top, 8)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") {
                    if !profileName.isEmpty { profileManager.updateProfileName(profileName) }
                    advanceStep()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showImagePicker) {
            PhotosPicker(selection: Binding(get: { profileManager.selectedPhotoItem }, set: { profileManager.selectedPhotoItem = $0 }), matching: .images) { EmptyView() }
        }
        .photosPicker(isPresented: $showImagePicker, selection: Binding(get: { profileManager.selectedPhotoItem }, set: { profileManager.selectedPhotoItem = $0 }), matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: Binding(get: { profileManager.profileImageData }, set: { profileManager.profileImageData = $0 }))
        }
        .onChange(of: profileManager.selectedPhotoItem) { _, _ in profileManager.handlePhotoSelection() }
    }

    // MARK: - Step 9: Review & Start
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Here's your setup")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 32)

                VStack(spacing: 0) {
                    reviewRow(label: "Hormone", value: selectedType)
                    reviewRow(label: "Method", value: selectedMethod)
                    if !selectedEster.isEmpty {
                        reviewRow(label: "Ester", value: selectedEster)
                    }
                    let vol = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                    reviewRow(label: "Dose", value: "\(String(format: "%.1f", doseDecimal)) mg (\(String(format: "%.3f", vol)) mL @ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                    reviewRow(label: "Frequency", value: "Every \(selectedFrequency) days")
                    reviewRow(label: "Last dose", value: lastDoseDate.formatted(date: .abbreviated, time: .shortened))
                    reviewRow(label: "Experience", value: hrtSummary)
                    if antiAndrogenChoice != "None" {
                        reviewRow(label: "Other meds", value: antiAndrogenChoice)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Color.white.opacity(0.12))
                )
                .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    primaryButton("Begin Tracking") { commitOnboarding() }
                    secondaryButton("Back") { previousStep() }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Card Components
    private func pathCard(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func choiceCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func aaCard(title: String, subtitle: String, choice: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { antiAndrogenChoice = choice }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if antiAndrogenChoice == choice {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(antiAndrogenChoice == choice ? Theme.Colors.Time.skin.base.opacity(0.25) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(antiAndrogenChoice == choice ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func reviewRow(label: String, value: String) -> some View {
        Group {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
                .overlay(Color.white.opacity(0.1))
                .padding(.leading, 16)
        }
    }

    // MARK: - Buttons
    private func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(disabled ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.accent.opacity(0.8))
                        .shadow(color: disabled ? .clear : Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                )
        }
        .disabled(disabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }

    private func durationStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 8) {
            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(.white)
            Text("\(value.wrappedValue) \(label)\(value.wrappedValue == 1 ? "" : "s")")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.white.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    private func photoBtn(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 70, height: 70)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.white.opacity(0.15)))
        }
    }

    // MARK: - Methods
    private func methodCard(_ method: MedicationManager.AdministrationMethod) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMethod = method.rawValue
                selectedFrequency = method.frequencyDays
                if method != .injectable { selectedEster = "" }
                if method == .injectable && selectedType == "Estrogen" && selectedEster.isEmpty {
                    selectedEster = "Valerate (EV)"
                    autoSelectConcentration(for: "Valerate (EV)")
                } else if method == .injectable && selectedType == "Testosterone" && selectedEster.isEmpty {
                    selectedEster = "Cypionate (TC)"
                    autoSelectConcentration(for: "Cypionate (TC)")
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(frequencyHint(for: method))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if selectedMethod == method.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedMethod == method.rawValue ? Theme.Colors.accent.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedMethod == method.rawValue ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var esterList: some View {
        let items: [(name: String, tHalf: Double)] = {
            if selectedType == "Estrogen" {
                return MedicationManager.MedicationEster.allCases
                    .filter { $0 != .oral && $0 != .transdermal }
                    .map { ($0.rawValue, $0.halfLifeDays) }
            } else {
                return MedicationManager.TestosteroneEster.allCases.map { ($0.rawValue, $0.halfLifeDays) }
            }
        }()

        return VStack(spacing: 10) {
            ForEach(items, id: \.name) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEster = item.name
                        autoSelectConcentration(for: item.name)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Half‑life ~\(String(format: "%.1f", item.tHalf)) days · Peaks day \(peakDay(halfLife: item.tHalf))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        if selectedEster == item.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(selectedEster == item.name ? Theme.Colors.accentSecondary.opacity(0.3) : Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(selectedEster == item.name ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Navigation Helpers
    private func selectType(_ type: String, defaultDose: Double) {
        selectedType = type
        doseDecimal = defaultDose
        doseText = String(format: "%.1f", defaultDose)
        selectedEster = ""
        selectedMethod = ""
        showCustomConcentration = false
    }

    private func autoSelectConcentration(for ester: String) {
        let defaults = MedicationManager.commonConcentrations(forEster: ester)
        if let defaultConc = defaults.first(where: { $0 > 0 }) {
            selectedConcentration = defaultConc
        }
        showCustomConcentration = false
        customConcentrationText = ""
        updateMlFromMg()
    }

    private func updateMlFromMg() {
        guard selectedConcentration > 0 else { return }
        let vol = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
        mlAmount = vol
        mlText = String(format: "%.2f", vol)
    }

    private func frequencyHint(for method: MedicationManager.AdministrationMethod) -> String {
        switch method {
        case .injectable: return "Typical cycle: 7 days"
        case .cream: return "Applied daily"
        case .oral: return "Taken daily"
        }
    }

    private func peakDay(halfLife: Double) -> String {
        let tMax = halfLife * 1.44
        return String(format: "%.0f", tMax)
    }

    private var hrtSummary: String {
        if !hasBeenOnHRT { return "Just starting" }
        var parts: [String] = []
        if hrtDurationYears > 0 { parts.append("\(hrtDurationYears) yr") }
        if hrtDurationMonths > 0 { parts.append("\(hrtDurationMonths) mo") }
        return parts.joined(separator: " ") + " on HRT"
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep += 1
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        }
    }

    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep -= 1
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        }
    }

    private func commitOnboarding() {
        let medType = MedicationManager.MedicationType(rawValue: selectedType) ?? .estrogen
        let medMethod = MedicationManager.AdministrationMethod(rawValue: selectedMethod) ?? .injectable

        // Set HRT start date
        if hasBeenOnHRT {
            let cal = Calendar.current
            let months = hrtDurationYears * 12 + hrtDurationMonths
            medicationManager.hrtStartDate = cal.date(byAdding: .month, value: -months, to: Date())
        }

        // Set AA flags
        medicationManager.antiAndrogenInUse = antiAndrogenChoice == "Spiro" || antiAndrogenChoice == "Other AA"
        medicationManager.spironolactoneInUse = antiAndrogenChoice == "Spiro"

        // Determine ester label
        var esterLabel = medMethod.rawValue
        if medMethod == .injectable && !selectedEster.isEmpty {
            esterLabel = selectedEster
        }

        // Configure medication
        medicationManager.updateSelection(type: medType, method: medMethod)

        // Determine final dose in mg (already computed correctly from whichever mode)
        let finalMg = doseDecimal
        
        // Determine concentration to store (nil for non-injectable or if not set)
        let finalConcentration: Double? = (medMethod == .injectable && selectedConcentration > 0) ? selectedConcentration : nil

        // Log first dose with concentration
        medicationManager.addDose(
            date: lastDoseDate,
            type: medType.rawValue,
            ester: esterLabel,
            method: medMethod.rawValue,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration
        )

        // Save custom frequency from onboarding stepper
        medicationManager.customFrequencyDays = selectedFrequency

        // Save default concentration to UserPreferences for pre-fill on future doses
        if let context = medicationManager.modelContext {
            let prefs = UserPreferences(
                medicationRow: 0,
                medicationColumn: 0,
                lastDoseDate: lastDoseDate,
                nextDoseDate: medicationManager.nextDoseDate
            )
            prefs.customFrequencyDays = selectedFrequency
            if selectedType == "Estrogen" {
                prefs.defaultEstrogenConcentration = finalConcentration
            } else {
                prefs.defaultTestosteroneConcentration = finalConcentration
            }
            context.insert(prefs)
            try? context.save()
        }

        // Configure dose reminders with the selected frequency and default time (9:00 AM)
        let reminderHour = 9
        let reminderMinute = 0
        NotificationManager.shared.configureDoseReminder(
            enabled: true,
            hour: reminderHour,
            minute: reminderMinute
        )

        withAnimation(.easeInOut(duration: 0.4)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onboardingComplete?()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
}