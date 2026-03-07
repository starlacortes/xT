//
//  OnboardingView.swift
//  xT
//

import SwiftUI
import SwiftData

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct OnboardingView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.modelContext) private var modelContext

    var onboardingComplete: (() -> Void)? = nil

    @State private var selectedTypeIndex: Int? = nil
    @State private var selectedMethodIndex: Int? = nil

    var body: some View {
        VStack {
            // Header
            Text("Welcome to xT")
                .font(.title)
                .padding(.top, 100)

            Text("Let's get started.")
                .padding(.top, 20)

            Text("Choose your medication:")
                .padding(.top, 167)

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

                // Update selection in MedicationManager
                if let methodIndex = selectedMethodIndex,
                   methodIndex < MedicationManager.AdministrationMethod.allCases.count {
                    let method = MedicationManager.AdministrationMethod.allCases[methodIndex]
                    medicationManager.updateSelection(type: type, method: method)
                }
            }

            // Administration method picker
            if let typeIdx = selectedTypeIndex,
               typeIdx < MedicationManager.MedicationType.allCases.count {
                let medicationType = MedicationManager.MedicationType.allCases[typeIdx]

                Text("Choose your administration method:")

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
                    guard let raw = newValue,
                          raw < MedicationManager.AdministrationMethod.allCases.count else { return }
                    
                    if let method = MedicationManager.AdministrationMethod.allCases[safe: raw],
                       let type = MedicationManager.MedicationType.allCases[safe: typeIdx] {
                        medicationManager.updateSelection(type: type, method: method)
                    }
                }
            }

            // Next button
            if let typeIdx = selectedTypeIndex,
               typeIdx < MedicationManager.MedicationType.allCases.count,
               let type = MedicationManager.MedicationType.allCases[safe: typeIdx],
               let methodIdx = selectedMethodIndex,
               methodIdx < MedicationManager.AdministrationMethod.allCases.count,
               let method = MedicationManager.AdministrationMethod.allCases[safe: methodIdx] {

                Button(action: {
                    medicationManager.updateSelection(type: type, method: method)
                    onboardingComplete?()
                }) {
                    Text("Next")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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

