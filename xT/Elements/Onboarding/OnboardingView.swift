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
    @Environment(\.themeManager) private var themeManager

    var onboardingComplete: (() -> Void)? = nil

    // MARK: - Step State
    @State private var currentStep: Int = 0
    @State private var opacity: Double = 0

    // iCloud restore
    @State private var isRestoringFromiCloud = false
    @State private var showRestoreNotFoundAlert = false
    
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
    
    // Step 8 — body type (backed by medicationManager for CloudKit sync)

    // Step 9 — profile
    @State private var profileName: String = ""
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false

    // Step 6b — injection/application site (body picker)
    @State private var selectedSiteLabels3D: [String] = []
    @State private var tapPositions: [String: BodyModel3DView.HitPosition] = [:]
    /// Marks taps that land on the body but outside any clinical zone.
    @State private var noZoneTaps = NoZoneTapTracker()
    /// Live camera yaw in radians, used to record which side of the body was tapped.
    @State private var cameraYaw: Float = 0
    @State private var bodySnapAngle: BodySnapAngle = .front
    @State private var bodySnapNonce: Int = 0
    @State private var selectedInjectionSites: [InjectionSite] = []

    private var isRouteShowsBodyPicker: Bool {
        RouteClass.from(method: selectedMethod) != .oral
    }

    private var totalStepCount: Int {
        isRouteShowsBodyPicker ? 12 : 11
    }
    
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
                        case 6: injectionSiteStep
                        case 7: antiAndrogenStep
                        case 8: bodyTypeStep
                        case 9: profileStep
                        case 10: themeStep
                        case 11: reviewStep
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
                    .fill(Theme.Colors.OnAccent.primary.opacity(0.3))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalStepCount), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()
                Text("xT")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.95))
                Text("Hormone therapy tracking")
                    .font(.title3)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: 12) {
                    primaryButton("Begin") { advanceStep() }
                    if UserDefaults.standard.bool(forKey: "icloudSyncEnabled") {
                        Button("Restore from iCloud") {
                            Task { await restoreFromiCloud() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            if isRestoringFromiCloud {
                ZStack {
                    Theme.Gradients.brand
                        .opacity(0.85)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.Colors.OnAccent.primary)
                            .scaleEffect(1.3)
                        Text("Checking iCloud…")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
                    }
                }
                .transition(.opacity)
            }
        }
        .alert("No iCloud Data Found", isPresented: $showRestoreNotFoundAlert) {
            Button("Set Up Manually") { }
        } message: {
            Text("No existing data was found in iCloud. Complete the setup to get started.")
        }
    }

    private func restoreFromiCloud() async {
        withAnimation { isRestoringFromiCloud = true }
        // Allow CloudKit's initial sync a moment to populate the local store
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run { medicationManager.reloadAllFromStore() }
        withAnimation {
            isRestoringFromiCloud = false
            if medicationManager.selectedMedication != nil {
                onboardingComplete?()
            } else {
                showRestoreNotFoundAlert = true
            }
        }
    }

    // MARK: - Step 2: Medication Type
    private var pathStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("What hormone are you taking?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                    durationStepper(text: "^[\(hrtDurationYears) year](inflect: true)",
                                    value: $hrtDurationYears, range: 0...20)
                    durationStepper(text: "^[\(hrtDurationMonths) month](inflect: true)",
                                    value: $hrtDurationMonths, range: 1...11)
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
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
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
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 40)
                        
                        HStack {
                            Stepper("Every \(selectedFrequency) days", value: $selectedFrequency, in: 1...30)
                                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Look for a number followed by 'mg/mL' on your vial or box.\nFor example, a 200 mg/5 mL vial is 40 mg/mL.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
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
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                if isMostCommonConcentration(conc) {
                    Text("· most common")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.4))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
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
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                Spacer()
                if showCustomConcentration {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(showCustomConcentration ? Theme.Colors.accentSecondary.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(showCustomConcentration ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var customConcentrationField: some View {
        HStack {
            TextField("mg/mL", text: $customConcentrationText)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.OnAccent.primary.opacity(0.15))
                )
                .onChange(of: customConcentrationText) { _, new in
                    if let val = Double(new), val > 0 {
                        selectedConcentration = val
                    }
                }
            Text("mg/mL")
                .font(.body)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.OnAccent.primary.opacity(0.15))
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
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { doseFieldFocused = false }
                                }
                            }

                        Text("mg")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    // Computed volume display
                    let volume = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                    Text("= \(String(format: "%.3f", volume)) mL (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
                        .padding(.horizontal, 40)

                    // Volume warning
                    if let warning = MedicationManager.volumeNote(for: volume, ester: selectedEster) {
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
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.OnAccent.primary.opacity(0.15))
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
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { doseFieldFocused = false }
                                }
                            }

                        Text("mL")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    // Computed mg display
                    let computedMg = mlAmount * selectedConcentration
                    Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
                        .padding(.horizontal, 40)

                    // Volume warning
                    if let warning = MedicationManager.volumeNote(for: mlAmount, ester: selectedEster) {
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
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)

                concentrationQuickPicker
                    .padding(.horizontal, 40)
            }

            // Last dose date
            VStack(spacing: 8) {
                Text("When was your last dose?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
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
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedConcentration == conc && !showCustomConcentration ? Theme.Colors.accentSecondary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedConcentration == conc && !showCustomConcentration ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.2), lineWidth: 1)
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
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showCustomConcentration ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.2), lineWidth: 1)
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Step 6: Injection / Application Site (Body Picker)

    private var injectionSiteStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Where did you take it?")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Tap on the body model to mark your injection site.\nYou can rotate the model with the arrows below.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()

            BodyModel3DView(
                heatMapData: [:],
                avoidZones: [],
                preferredZones: bodyPickerPreferredZones,
                recommendedZones: bodyPickerRecommendedZones,
                selectedSites: $selectedSiteLabels3D,
                maxSelections: 1,
                bodyType: BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral,
                snapAngle: bodySnapAngle,
                snapNonce: bodySnapNonce,
                onTapZone: { _, _ in },
                tapPositions: $tapPositions,
                onPreTap: { _, _ in },
                onNoZoneTap: { point in
                    noZoneTaps.record(at: point)
                },
                onYawChange: { yaw in
                    cameraYaw = yaw
                }
            )
            .noZoneMarkers($noZoneTaps.taps)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .padding(.horizontal, 40)
            .frame(height: 320)

            bodyPickerOrbitControls
                .padding(.top, 12)

            if let zone = selectedSiteLabels3D.first {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.Colors.accentSecondary)
                    Text(zone)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Button {
                        selectedSiteLabels3D.removeAll()
                        tapPositions.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.accentSecondary.opacity(0.2))
                )
                .padding(.top, 12)
            } else {
                Text("Tap the model to mark your site")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.4))
                    .padding(.top, 12)
            }

            Spacer()

            HStack(spacing: 16) {
                secondaryButton("Skip for now") {
                    selectedSiteLabels3D.removeAll()
                    tapPositions.removeAll()
                    advanceStep()
                }
                primaryButton("Continue", disabled: selectedSiteLabels3D.isEmpty) {
                    commitInjectionSites()
                    advanceStep()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)

            Spacer()
                .frame(height: 20)
        }
    }

    private var bodyPickerOrbitControls: some View {
        HStack(spacing: 16) {
            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + angles.count - 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach([BodySnapAngle.front, .back], id: \.rawValue) { angle in
                    Button {
                        bodySnapAngle = angle
                        bodySnapNonce += 1
                    } label: {
                        Text(angle.label)
                            .font(.subheadline.weight(bodySnapAngle == angle ? .semibold : .regular))
                            .foregroundStyle(bodySnapAngle == angle
                                             ? Theme.Colors.accent
                                             : Theme.Colors.OnAccent.primary.opacity(0.6))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bodySnapAngle == angle
                                          ? Theme.Colors.accent.opacity(0.25)
                                          : Color.clear)
                            )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))

            Spacer()

            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }
        }
        .padding(.horizontal, 40)
    }

    private var bodyPickerPreferredZones: Set<String> {
        let routeClass = RouteClass.from(method: selectedMethod)
        return Set(ZoneCentroidStore.preferredZones(medication: selectedType, routeClass: routeClass))
    }

    private var bodyPickerRecommendedZones: Set<String> {
        let routeClass = RouteClass.from(method: selectedMethod)
        return Set(ZoneCentroidStore.recommendedZones(for: routeClass))
    }

    private func commitInjectionSites() {
        guard !selectedSiteLabels3D.isEmpty else { return }
        let now = lastDoseDate
        // Derived from the live camera yaw, not the snap-angle selection: a user can free-pan
        // to the back without changing the selected snap angle.
        let derivedViewContext = ZoneCentroidStore.viewContext(from: cameraYaw)
        let routeClass = RouteClass.from(method: selectedMethod)
        selectedInjectionSites = selectedSiteLabels3D.map { zoneLabel in
            let pos = tapPositions[zoneLabel]
            return InjectionSite(
                zoneLabel: zoneLabel,
                bodyRegion: ZoneCentroidStore.shared.region(for: zoneLabel) ?? "unknown",
                viewContext: derivedViewContext,
                worldPosition: pos.map { (x: $0.worldX, y: $0.worldY, z: $0.worldZ) },
                viewNormal: pos.map { (x: $0.normalX, y: $0.normalY, z: $0.normalZ) },
                lastUsedDate: now,
                durationDays: routeClass.defaultDurationDays,
                routeClass: routeClass.rawValue
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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

    // MARK: - Step 8: Body Silhouette
    private var bodyTypeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Choose a body silhouette")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("This changes the 3D injection-site picker. You can update this anytime in Settings.")
                .font(.callout)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                ForEach(BodyType.allCases) { type in
                    pathCard(
                        title: type.displayName,
                        subtitle: type.subtitle,
                        isSelected: medicationManager.bodyTypeRaw == type.rawValue
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            medicationManager.bodyTypeRaw = type.rawValue
                        }
                    }
                }
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

    // MARK: - Step 9: Profile
    private var profileStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Personalize your space")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .padding(.bottom, 8)

            // Photo
            Button { showImagePicker = true } label: {
                Image(uiImage: profileManager.getCurrentProfileImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.Colors.OnAccent.primary.opacity(0.6), lineWidth: 2))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            Text("Tap to add photo")
                .font(.caption)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))

            // Name
            TextField("Your name", text: $profileName)
                .font(.body)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1))
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
        .photosPicker(isPresented: $showImagePicker, selection: Binding(get: { profileManager.selectedPhotoItem }, set: { profileManager.selectedPhotoItem = $0 }), matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: Binding(get: { profileManager.profileImageData }, set: { profileManager.profileImageData = $0 }))
        }
        .onChange(of: profileManager.selectedPhotoItem) { _, _ in profileManager.handlePhotoSelection() }
    }

    // MARK: - Step 10: Choose your theme
    private var themeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Make it yours")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.secondary)
                .padding(.bottom, 4)
            Text("Drag to pick a color for the whole app. You can always change this later in Settings.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.OnAccent.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ThemePickerView()
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 11: Review & Start
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Here's your setup")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
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
                    reviewRow(label: "Body silhouette", value: (BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral).displayName)
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.OnAccent.primary.opacity(0.12))
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
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func choiceCard(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
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
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Spacer()
                    if antiAndrogenChoice == choice {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(antiAndrogenChoice == choice ? Theme.Colors.Time.skin.base.opacity(0.25) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(antiAndrogenChoice == choice ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func reviewRow(label: String, value: String) -> some View {
        Group {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
                .overlay(Theme.Colors.OnAccent.primary.opacity(0.1))
                .padding(.leading, 16)
        }
    }

    // MARK: - Buttons
    private func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.OnAccent.primary)
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
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }

    /// `text` is built by the caller rather than assembled from a noun parameter:
    /// automatic grammar agreement needs the noun as a literal in the pattern, so
    /// "^[\(n) \(noun)](inflect: true)" cannot inflect and would read "1 Years".
    private func durationStepper(text: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 8) {
            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(Theme.Colors.OnAccent.primary)
            Text(text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1))
    }

    private func photoBtn(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.8))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.7))
            }
            .frame(width: 70, height: 70)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
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
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Text(frequencyHint(for: method))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
                }
                Spacer()
                if selectedMethod == method.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedMethod == method.rawValue ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedMethod == method.rawValue ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var esterList: some View {
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
                                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                            Text(esterSubtitle(tHalf: item.tHalf, tPeak: item.tPeak, calibrated: item.calibrated))
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
                        }
                        Spacer()
                        if selectedEster == item.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(selectedEster == item.name ? Theme.Colors.accentSecondary.opacity(0.3) : Theme.Colors.OnAccent.primary.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .stroke(selectedEster == item.name ? Theme.Colors.OnAccent.primary.opacity(0.5) : Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1)
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
    private func esterSubtitle(tHalf: Double, tPeak: Double, calibrated: Bool) -> String {
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

    private var hrtSummary: String {
        if !hasBeenOnHRT { return "Just starting" }
        var parts: [String] = []
        if hrtDurationYears > 0 { parts.append("\(hrtDurationYears) yr") }
        if hrtDurationMonths > 0 { parts.append("\(hrtDurationMonths) mo") }
        return parts.joined(separator: " ") + " on HRT"
    }

    private func advanceStep() {
        var nextStep = currentStep + 1
        if currentStep == 5 && !isRouteShowsBodyPicker {
            nextStep = 7
        }
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep = nextStep
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        }
    }

    private func previousStep() {
        var prevStep = currentStep - 1
        if currentStep == 7 && !isRouteShowsBodyPicker {
            prevStep = 5
        }
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep = prevStep
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

        // Determine ester label.
        //
        // Fixed 2026‑07‑31: non-injectable routes stored the raw method name, so a cream
        // dose was saved with ester "Cream" — which matches no case in either ester enum.
        // The PK engine's transdermal branch then failed its `MedicationEster(rawValue:)`
        // lookup and fell through to a hardcoded scaling constant of 8000, roughly 52×
        // the calibrated transdermal value, for every user who onboarded onto a cream.
        // Users who set the same route from Settings stored "Transdermal" and were fine.
        // Store the pseudo-ester the engine actually resolves to, so record and model agree.
        let esterLabel: String = {
            if medMethod == .injectable {
                return selectedEster.isEmpty ? medMethod.rawValue : selectedEster
            }
            return MedicationManager.effectiveEsterName(ester: selectedEster, route: medMethod.rawValue)
        }()

        // Configure medication
        medicationManager.updateSelection(type: medType, method: medMethod)

        // Determine final dose in mg (already computed correctly from whichever mode)
        let finalMg = doseDecimal
        
        // Determine concentration to store (nil for non-injectable or if not set)
        let finalConcentration: Double? = (medMethod == .injectable && selectedConcentration > 0) ? selectedConcentration : nil

        // Log first dose with concentration + injection sites (from body picker step)
        medicationManager.addDose(
            date: lastDoseDate,
            type: medType.rawValue,
            ester: esterLabel,
            method: medMethod.rawValue,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration,
            injectionSites: selectedInjectionSites
        )

        // Save custom frequency from onboarding stepper
        medicationManager.customFrequencyDays = selectedFrequency

        // Save default concentration directly into the existing UserPreferences record
        // (these are read-once fields, not tracked as in-memory manager state)
        if let context = medicationManager.modelContext,
           let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
            if selectedType == "Estrogen" {
                prefs.defaultEstrogenConcentration = finalConcentration
            } else {
                prefs.defaultTestosteroneConcentration = finalConcentration
            }
            try? context.save()
        }
        medicationManager.persistUserPreferences()

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

#if DEBUG
#Preview {
    OnboardingView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.themeManager, ThemeManager.shared)
}
#endif
