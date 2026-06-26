//
//  OnboardingView.swift
//  xT
//
//  Redesigned by Cline on 5/28/2026.
//  Warm and understated onboarding experience
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
    @Environment(\.modelContext) private var modelContext

    var onboardingComplete: (() -> Void)? = nil

    @State private var currentStep: Int = 0
    @State private var selectedTypeIndex: Int? = nil
    @State private var selectedMethodIndex: Int? = nil
    @State private var selectedEsterIndex: Int? = nil
    @State private var doseAmount: String = ""
    @State private var doseDecimal: Double = 2.0
    @State private var profileName: String = ""
    @State private var hasCompletedFirstDose: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var opacity: Double = 0
    @State private var isSyncingFromStepper = false
    @State private var isSyncingFromText = false
    @FocusState private var doseAmountFocused: Bool

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Soft gradient background
            Theme.Gradients.brand
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Subtle progress indicator
                progressBar
                    .padding(.top, 32)
                    .padding(.horizontal, 40)

                // Content area with generous spacing
                ZStack {
                    Group {
                        if currentStep == 0 {
                            welcomeStep
                        } else if currentStep == 1 {
                            featuresStep
                        } else if currentStep == 2 {
                            profileStep
                        } else {
                            medicationStep
                        }
                    }
                    .opacity(opacity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1.0
            }
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent.opacity(0.8))
                    .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step 1: Gentle Welcome
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo or app name with gentle appearance
            Text("xT")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.bottom, 8)

            Text("Welcome to your journey")
                .font(.title3)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Spacer()

            // Begin button with soft glow
            Button(action: { advanceStep() }) {
                Text("Begin")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.accent.opacity(0.8))
                            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: What We Do (Minimal)
    private var featuresStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 28) {
                featureRow(icon: "pills.fill", text: "Track your medication", color: Theme.Colors.accent.opacity(0.7))
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Understand your levels", color: Theme.Colors.accentSecondary.opacity(0.6))
                featureRow(icon: "heart.fill", text: "Feel supported", color: Theme.Colors.Bloom.cycle.base.opacity(0.7))
            }
            .padding(.horizontal, 40)

            Spacer()

            // Navigation buttons
            navigationButtons
        }
    }

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            Text(text)
                .font(.body)
                .fontWeight(.regular)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
    }

    // MARK: - Step 3: Profile (Optional, Gentle)
    private var profileStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("This is your space")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 8)
                    .padding(.top, 32)

                // Profile image with gentle pulse
                Button(action: { showImagePicker = true }) {
                    Image(uiImage: profileManager.getCurrentProfileImage())
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }

                Text("Tap to add photo")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                // Name field with subtle styling
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Your name", text: $profileName)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)

                // Photo options as soft icons
                HStack(spacing: 24) {
                    photoOptionButton(icon: "photo", label: "Library") {
                        showImagePicker = true
                    }

                    photoOptionButton(icon: "camera", label: "Camera") {
                        showCamera = true
                    }
                }
                .padding(.top, 8)

                // Navigation with skip option
                HStack(spacing: 16) {
                    Button(action: { previousStep() }) {
                        Text("Back")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }

                    Button(action: {
                        if !profileName.isEmpty {
                            profileManager.updateProfileName(profileName)
                        }
                        advanceStep()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md)
                                    .fill(Theme.Colors.accent.opacity(0.8))
                            )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotosPicker(selection: Binding(
                get: { profileManager.selectedPhotoItem },
                set: { profileManager.selectedPhotoItem = $0 }
            ), matching: .images) {
                EmptyView()
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: Binding(
            get: { profileManager.selectedPhotoItem },
            set: { profileManager.selectedPhotoItem = $0 }
        ), matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ))
        }
        .onChange(of: profileManager.selectedPhotoItem) { _, _ in
            profileManager.handlePhotoSelection()
        }
    }

    private func photoOptionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
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
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color.white.opacity(0.15))
            )
        }
    }

    // MARK: - Step 4: Medication Setup (Simplified)
    private var medicationStep: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 32) {
                    Text("Let's set up your tracking")
                        .font(.title2)
                        .fontWeight(.regular)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 32)

                    // Medication types as soft, rounded cards
                    VStack(spacing: 12) {
                        Text("Medication type")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(MedicationManager.MedicationType.allCases, id: \.self) { type in
                            medicationTypeCard(type: type, index: MedicationManager.MedicationType.allCases.firstIndex(of: type) ?? 0)
                        }
                    }
                    .padding(.horizontal, 40)
                    .id("medicationTypeSection")

                    // Administration method
                    if let typeIdx = selectedTypeIndex,
                       typeIdx < MedicationManager.MedicationType.allCases.count {
                        let medicationType = MedicationManager.MedicationType.allCases[typeIdx]

                        VStack(spacing: 12) {
                            Text("Administration method")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(medicationManager.availableMethods(for: medicationType), id: \.rawValue) { method in
                                let idx = MedicationManager.AdministrationMethod.allCases.firstIndex(of: method) ?? 0

                                administrationMethodCard(
                                    method: method,
                                    index: idx,
                                    isSelected: selectedMethodIndex == idx
                                )
                            }
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id("administrationMethodSection")
                    }

                    // Ester selection (shown when injectable method is selected)
                    if let methodIdx = selectedMethodIndex,
                       let method = MedicationManager.AdministrationMethod.allCases[safe: methodIdx],
                       method == .injectable,
                       let typeIdx = selectedTypeIndex,
                       let medicationType = MedicationManager.MedicationType.allCases[safe: typeIdx] {
                        VStack(spacing: 12) {
                            Text("Ester")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            esterCards(for: medicationType)
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id("esterSelectionSection")
                    }

                    // Dose amount
                    if selectedTypeIndex != nil && selectedMethodIndex != nil {
                        VStack(spacing: 12) {
                            Text("Dose amount")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                // Stepper for fine control
                                Stepper("", value: Binding(
                                    get: { doseDecimal },
                                    set: {
                                        isSyncingFromStepper = true
                                        doseDecimal = $0
                                        doseAmount = String(format: "%.1f", $0)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                            isSyncingFromStepper = false
                                        }
                                    }
                                ), in: 0.5...500, step: 0.5)
                                    .labelsHidden()
                                    .tint(Theme.Colors.accent)

                                // Text field showing the amount
                                TextField("", text: Binding(
                                    get: { doseAmount },
                                    set: { text in
                                        isSyncingFromText = true
                                        // Parse as double
                                        if let val = Double(text) {
                                            doseDecimal = val
                                        }
                                        doseAmount = text
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                            isSyncingFromText = false
                                        }
                                    }
                                ))
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .fill(Color.white.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .focused($doseAmountFocused)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                doseAmountFocused = false
                                            }
                                        }
                                    }

                                // Unit label
                                Text("mg")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            // Quick-select common doses
                            if let typeIdx = selectedTypeIndex,
                               let medicationType = MedicationManager.MedicationType.allCases[safe: typeIdx] {
                                commonDoses(for: medicationType)
                            }
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id("doseAmountSection")
                    }

                    // Navigation buttons
                    if selectedTypeIndex != nil && selectedMethodIndex != nil {
                        HStack(spacing: 16) {
                            Button(action: { previousStep() }) {
                                Text("Back")
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }

                            Button(action: {
                                // Wire up the completion to call addDose() with ester and dose amount
                                guard let typeIdx = selectedTypeIndex,
                                      let methodIdx = selectedMethodIndex,
                                      let medicationType = MedicationManager.MedicationType.allCases[safe: typeIdx],
                                      let medicationMethod = MedicationManager.AdministrationMethod.allCases[safe: methodIdx]
                                else { return }

                                let typeLabel = medicationType.rawValue

                                // Determine ester string if injectable
                                var esterLabel = medicationMethod.rawValue
                                if medicationMethod == .injectable, let eIdx = selectedEsterIndex {
                                    if medicationType == .estrogen,
                                       let e = MedicationManager.MedicationEster.allCases[safe: eIdx] {
                                        esterLabel = e.rawValue
                                    } else if let e = MedicationManager.TestosteroneEster.allCases[safe: eIdx] {
                                        esterLabel = e.rawValue
                                    }
                                }

                                // Parse dose amount
                                let dose: Double = {
                                    if let val = Double(doseAmount) {
                                        return val
                                    }
                                    // Fallback to stepper value
                                    return doseDecimal
                                }()

                                // Configure the medication
                                medicationManager.updateSelection(type: medicationType, method: medicationMethod)

                                // Log the first dose with actual amount and ester
                                medicationManager.addDose(
                                    date: Date(),
                                    type: typeLabel,
                                    ester: esterLabel,
                                    method: medicationMethod.rawValue,
                                    doseAmount: dose
                                )

                                hasCompletedFirstDose = true
                                completeOnboarding()
                            }) {
                                Text("You're all set")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                                            .fill(Theme.Colors.accent.opacity(0.8))
                                            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                                    )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button(action: { previousStep() }) {
                            Text("Back")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                }
                .onChange(of: selectedTypeIndex) { _, _ in
                    if selectedTypeIndex != nil {
                        withAnimation {
                            scrollProxy.scrollTo("administrationMethodSection", anchor: .top)
                        }
                    }
                }
                .onChange(of: selectedMethodIndex) { _, _ in
                    if selectedMethodIndex != nil {
                        withAnimation {
                            scrollProxy.scrollTo("doseAmountSection", anchor: .top)
                        }
                    }
                }
                .onChange(of: selectedEsterIndex) { _, _ in
                    if selectedEsterIndex != nil {
                        withAnimation {
                            scrollProxy.scrollTo("doseAmountSection", anchor: .top)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Restore previous selection
            if let type = medicationManager.selectedMedication {
                if let index = MedicationManager.MedicationType.allCases.firstIndex(where: { $0.rawValue == type }) {
                    selectedTypeIndex = index
                }
            }
            if let method = medicationManager.selectedAdministrationMethod {
                if let index = MedicationManager.AdministrationMethod.allCases.firstIndex(where: { $0.rawValue == method }) {
                    selectedMethodIndex = index
                }
            }
        }
    }

    private func medicationTypeCard(type: MedicationManager.MedicationType, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTypeIndex = index
                selectedEsterIndex = nil
                
                // Reset dose to typical range for new medication type
                doseDecimal = type == .estrogen ? 2.0 : 40.0
                doseAmount = String(format: "%.1f", doseDecimal)
                
                // Select first available method for this medication type
                if let firstMethod = medicationManager.availableMethods(for: type).first {
                    selectedMethodIndex = globalMethodIndex(for: firstMethod)
                }
            }
        }) {
            HStack {
                Text(type.rawValue)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                if selectedTypeIndex == index {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedTypeIndex == index ? Theme.Colors.accent.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedTypeIndex == index ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func administrationMethodCard(method: MedicationManager.AdministrationMethod, index: Int, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMethodIndex = globalMethodIndex(for: method)
                // Reset ester when switching methods
                if method != .injectable {
                    selectedEsterIndex = nil
                }
            }
        }) {
            HStack {
                Text(method.rawValue)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(isSelected ? Theme.Colors.accentSecondary.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Ester Selection Cards
    private func esterCards(for medicationType: MedicationManager.MedicationType) -> some View {
        let estrogenEsters = MedicationManager.MedicationEster.allCases
        let testosteroneEsters = MedicationManager.TestosteroneEster.allCases

        let allEsters: [(label: String, index: Int)]
        if medicationType == .estrogen {
            allEsters = estrogenEsters.enumerated().map { (label: $0.1.rawValue, index: $0.0) }
        } else {
            allEsters = testosteroneEsters.enumerated().map { (label: $0.1.rawValue, index: $0.0) }
        }

        return VStack(spacing: 12) {
            ForEach(allEsters, id: \.index) { item in
                esterCard(name: item.label, index: item.index, isSelected: selectedEsterIndex == item.index)
            }
        }
    }

    private func esterCard(name: String, index: Int, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedEsterIndex = index
            }
        }) {
            HStack {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
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

    // MARK: - Quick-Select Common Doses
    private func commonDoses(for medicationType: MedicationManager.MedicationType) -> some View {
        let commonDoseValues: [Double]
        if medicationType == .estrogen {
            commonDoseValues = [0.5, 1, 2, 4, 6]
        } else {
            commonDoseValues = [20, 40, 60, 80, 100]
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commonDoseValues, id: \.self) { dose in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            doseDecimal = dose
                            doseAmount = String(format: "%.1f", dose)
                        }
                    }) {
                        Text(String(format: "%.0f", dose))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(doseDecimal == dose ? Theme.Colors.accent.opacity(0.5) : Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(doseDecimal == dose ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    
    /// Maps an AdministrationMethod enum to its global index in AdministrationMethod.allCases.
    private func globalMethodIndex(for method: MedicationManager.AdministrationMethod) -> Int {
        MedicationManager.AdministrationMethod.allCases.firstIndex(of: method) ?? 0
    }

    // MARK: - Navigation Buttons (for steps 2-3)
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: { previousStep() }) {
                    Text("Back")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }

            Button(action: { advanceStep() }) {
                Text(currentStep == 1 ? "Continue" : "Next")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.accent.opacity(0.8))
                    )
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    // MARK: - Navigation Functions
    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep += 1
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }

    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep -= 1
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            opacity = 0
        }

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
