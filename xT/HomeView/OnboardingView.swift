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
    @State private var profileName: String = ""
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var opacity: Double = 0

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Soft gradient background
            Theme.globalBackgroundGradient
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
                    .fill(Theme.accentColor.opacity(0.8))
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
                .foregroundColor(.white.opacity(0.95))
                .padding(.bottom, 8)

            Text("Welcome to your journey")
                .font(.title3)
                .fontWeight(.regular)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Spacer()

            // Begin button with soft glow
            Button(action: { advanceStep() }) {
                Text("Begin")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.accentColor.opacity(0.8))
                            .shadow(color: Theme.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
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
                featureRow(icon: "pills.fill", text: "Track your medication", color: Theme.accentColor.opacity(0.7))
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Understand your levels", color: Theme.secondaryAccentColor.opacity(0.6))
                featureRow(icon: "heart.fill", text: "Feel supported", color: Theme.bloomCycleColor.opacity(0.7))
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
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            Text(text)
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }

    // MARK: - Step 3: Profile (Optional, Gentle)
    private var profileStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("This is your space")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 8)

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
                .foregroundColor(.white.opacity(0.6))

            // Name field with subtle styling
            VStack(alignment: .leading, spacing: 8) {
                TextField("Your name", text: $profileName)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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

            Spacer()

            // Navigation with skip option
            HStack(spacing: 16) {
                Button(action: { previousStep() }) {
                    Text("Back")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
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
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.accentColor.opacity(0.8))
                        )
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .camera)
        }
        .onChange(of: profileManager.selectedPhotoItem) {
            profileManager.handlePhotoSelection()
        }
    }

    private func photoOptionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
            )
        }
    }

    // MARK: - Step 4: Medication Setup (Simplified)
    private var medicationStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Let's set up your tracking")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Medication types as soft, rounded cards
            VStack(spacing: 12) {
                Text("Medication type")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(0..<MedicationManager.MedicationType.allCases.count, id: \.self) { index in
                    let type = MedicationManager.MedicationType.allCases[index]
                    medicationTypeCard(type: type, index: index)
                }
            }
            .padding(.horizontal, 40)

            // Administration method
            if let typeIdx = selectedTypeIndex,
               typeIdx < MedicationManager.MedicationType.allCases.count {
                let medicationType = MedicationManager.MedicationType.allCases[typeIdx]

                VStack(spacing: 12) {
                    Text("Administration method")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(0..<medicationManager.availableMethods(for: medicationType).count, id: \.self) { index in
                        let method = medicationManager.availableMethods(for: medicationType)[index]
                        let globalMethodIndex = MedicationManager.AdministrationMethod.allCases.firstIndex(of: method)
                        
                        administrationMethodCard(
                            method: method,
                            index: globalMethodIndex ?? index,
                            isSelected: selectedMethodIndex == globalMethodIndex
                        )
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            // Navigation buttons
            if selectedTypeIndex != nil && selectedMethodIndex != nil {
                HStack(spacing: 16) {
                    Button(action: { previousStep() }) {
                        Text("Back")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }

                    Button(action: {
                        if let typeIdx = selectedTypeIndex,
                           let methodIdx = selectedMethodIndex {
                            let medicationType = MedicationManager.MedicationType.allCases[typeIdx]
                            let medicationMethod = MedicationManager.AdministrationMethod.allCases[methodIdx]
                            medicationManager.configureMedication(
                                type: medicationType,
                                method: medicationMethod,
                                firstDoseDate: Date()
                            )
                            completeOnboarding()
                        }
                    }) {
                        Text("You're all set")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.accentColor.opacity(0.8))
                                    .shadow(color: Theme.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
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
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
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
                
                // Select first available method for this medication type
                if let firstMethod = medicationManager.availableMethods(for: type).first {
                    selectedMethodIndex = MedicationManager.AdministrationMethod.allCases.firstIndex(of: firstMethod)
                }
            }
        }) {
            HStack {
                Text(type.rawValue)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if selectedTypeIndex == index {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTypeIndex == index ? Theme.accentColor.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedTypeIndex == index ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func administrationMethodCard(method: MedicationManager.AdministrationMethod, index: Int, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMethodIndex = index
            }
        }) {
            HStack {
                Text(method.rawValue)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.secondaryAccentColor.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Navigation Buttons (for steps 2-3)
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: { previousStep() }) {
                    Text("Back")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }

            Button(action: { advanceStep() }) {
                Text(currentStep == 1 ? "Continue" : "Next")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.accentColor.opacity(0.8))
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
