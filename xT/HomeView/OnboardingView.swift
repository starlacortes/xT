//
//  OnboardingView.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Onboarding flow with profile and medication setup
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

    @State private var selectedTypeIndex: Int? = nil
    @State private var selectedMethodIndex: Int? = nil
    @State private var onboardingStep: Int = 0
    @State private var profileName: String = ""
    @State private var showImagePicker: Bool = false
    @State private var showCamera: Bool = false

    var body: some View {
        VStack {
            // Progress indicator
            HStack {
                ForEach(0..<2) { step in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(onboardingStep == step ? Theme.accentColor : Theme.tertiaryTextColor.opacity(0.3))
                        .scaleEffect(onboardingStep == step ? 1.2 : 1.0)
                }
            }
            .padding(.top, 16)

            if onboardingStep == 0 {
                // Profile setup step
                profileSetupView
            } else {
                // Medication setup step
                medicationSetupView
            }
        }
    }

    // MARK: - Profile Setup View
    private var profileSetupView: some View {
        VStack {
            // Header
            Text("Welcome to xT")
                .font(.title)
                .padding(.top, 100)

            Text("Let's set up your profile.")
                .padding(.top, 20)

            // Profile image
            Button(action: {
                showImagePicker = true
            }) {
                Image(uiImage: profileManager.getCurrentProfileImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Theme.accentColor, lineWidth: 3)
                    )
                    .padding(.top, 40)
            }

            Text("Tap to add photo")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)

            // Name field
            TextField("Your Name (optional)", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .padding(.top, 20)

            // Image source options
            HStack(spacing: 20) {
                Button(action: {
                    showImagePicker = true
                }) {
                    VStack {
                        Image(systemName: "photo")
                            .font(.title2)
                        Text("Library")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(Theme.accentColor.opacity(0.1))
                    .cornerRadius(Theme.smallCornerRadius)
                }

                Button(action: {
                    showCamera = true
                }) {
                    VStack {
                        Image(systemName: "camera")
                            .font(.title2)
                        Text("Camera")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(Theme.accentColor.opacity(0.1))
                    .cornerRadius(Theme.smallCornerRadius)
                }
            }
            .padding(.top, 20)

            // Skip/Continue buttons
            HStack(spacing: 20) {
                Button(action: {
                    // Skip profile setup
                    onboardingStep = 1
                }) {
                    Text("Skip")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.tertiaryTextColor.opacity(0.2))
                        .foregroundColor(Theme.accentColor)
                        .cornerRadius(Theme.smallCornerRadius)
                }

                Button(action: {
                    // Save profile info and continue
                    if !profileName.isEmpty {
                        profileManager.updateProfileName(profileName)
                    }
                    onboardingStep = 1
                }) {
                    Text("Continue")
                        .asAccentButton()
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)

            Spacer()
        }
        .padding(.horizontal)
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .photoLibrary)
                .onDisappear {
                    showImagePicker = false
                }
        }
        .sheet(isPresented: $showCamera) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .camera)
                .onDisappear {
                    showCamera = false
                }
        }
        .onChange(of: profileManager.selectedPhotoItem) {
            profileManager.handlePhotoSelection()
        }
    }

    // MARK: - Medication Setup View
    private var medicationSetupView: some View {
        VStack {
            // Header
            Text("Welcome to xT")
                .font(.title)
                .padding(.top, 100)

            Text("Let's get started.")
                .padding(.top, 20)

            Text("Choose your medication:")
                .padding(.top, 40)

            // Medication type picker
            Picker("Medication Type", selection: $selectedTypeIndex) {
                ForEach(0..<MedicationManager.MedicationType.allCases.count, id: \.self) { index in
                    let type = MedicationManager.MedicationType.allCases[index]
                    Text(type.rawValue)
                        .tag(index as Int?)
                }
            }
            .padding()
            .pickerStyle(.segmented)
            .onChange(of: selectedTypeIndex) { _, newValue in
                guard let raw = newValue,
                      raw < MedicationManager.MedicationType.allCases.count else { return }

                let type = MedicationManager.MedicationType.allCases[raw]

                // Select first available method for this medication type
                if let firstMethod = medicationManager.availableMethods(for: type).first {
                    selectedMethodIndex = MedicationManager.AdministrationMethod.allCases.firstIndex(of: firstMethod)
                }

                // Update selection in MedicationManager using simplified method
                if let methodIndex = selectedMethodIndex {
                    medicationManager.configureMedication(
                        typeIndex: raw,
                        methodIndex: methodIndex
                    )
                }
            }

            // Administration method picker
            if let typeIdx = selectedTypeIndex,
               typeIdx < MedicationManager.MedicationType.allCases.count {
                let medicationType = MedicationManager.MedicationType.allCases[typeIdx]

                Text("Choose your administration method:")
                    .padding(.top, 20)

                Picker("Administration Method", selection: $selectedMethodIndex) {
                    ForEach(0..<medicationManager.availableMethods(for: medicationType).count, id: \.self) { index in
                        let method = medicationManager.availableMethods(for: medicationType)[index]
                        Text(method.rawValue)
                            .tag(index as Int?)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 93)
                .frame(width: 360)
                .onAppear {
                    if selectedMethodIndex == nil,
                       let first = medicationManager.availableMethods(for: medicationType).first {
                        selectedMethodIndex = MedicationManager.AdministrationMethod.allCases.firstIndex(of: first)
                    }
                }
                .onChange(of: selectedMethodIndex) { _, newValue in
                    guard let methodIndex = newValue else { return }
                    medicationManager.configureMedication(
                        typeIndex: typeIdx,
                        methodIndex: methodIndex
                    )
                }
            }

            // Next button
            if let typeIdx = selectedTypeIndex,
               let methodIdx = selectedMethodIndex {

                Button(action: {
                    medicationManager.configureMedication(
                        typeIndex: typeIdx,
                        methodIndex: methodIdx
                    )
                    onboardingComplete?()
                }) {
                    Text("Finish")
                        .asAccentButton()
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 40)
            }

            Spacer()
        }
        .padding(.horizontal)
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
}