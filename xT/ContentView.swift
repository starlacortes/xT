//
//  ContentView.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    // Use the MedicationManager from the environment
    @StateObject private var medicationManager = MedicationManager.shared
    
    // Local state for UI
    @State private var selectedTypeIndex: Int? = nil
    @State private var selectedMethodIndex: Int? = nil

    var body: some View {
        NavigationSplitView {
            VStack {
//                Image("logo")
                Text("Welcome to xT")
                    .font(.title)
                    .padding(.top, 100)
                Text("Let's get started.")
                    .padding(.top, 20)
                Text("Choose your medication:")
                    .padding(.top, 167)
            
                // Medication Type Picker (Row selection)
                Picker("Medication Type", selection: $selectedTypeIndex) {
                    ForEach(MedicationManager.MedicationType.allCases, id: \.rawValue) { type in
                        Text(type.displayName).tag(type.rawValue as Int?)
                    }
                }
                .padding()
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedTypeIndex) { oldValue, newValue in
                    if let newIndex = newValue {
                        if let type = MedicationManager.MedicationType(rawValue: newIndex) {
                            // Auto-select the first available administration method when medication type changes
                            if let firstMethod = medicationManager.availableMethods(for: type).first {
                                selectedMethodIndex = firstMethod.rawValue
                            }
                        }
                    }
                }
                
                // Only show administration method picker if a medication type is selected
                if selectedTypeIndex != nil, 
                   let medicationType = MedicationManager.MedicationType(rawValue: selectedTypeIndex!) {

                    Text("Choose your administration method:")
                    
                    // Administration Method Picker (Column selection)
                    Picker("Administration Method", selection: $selectedMethodIndex) {
                        // Only show available methods for the selected medication
                        ForEach(medicationManager.availableMethods(for: medicationType), id: \.rawValue) { method in
                            Text(method.displayName).tag(method.rawValue as Int?)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 93)
                    .frame(width: 360)
                    // Initialize method selection if it's nil but methods are available
                    .onAppear {
                        if selectedMethodIndex == nil {
                            if let firstMethod = medicationManager.availableMethods(for: medicationType).first {
                                selectedMethodIndex = firstMethod.rawValue
                            }
                        }
                    }
                }
                
                // Show Next button if medication type is selected (method will be auto-selected)
                if let typeIndex = selectedTypeIndex,
                   let type = MedicationManager.MedicationType(rawValue: typeIndex) {
                    
                    let methodToUse = selectedMethodIndex ?? medicationManager.availableMethods(for: type).first?.rawValue
                    
                    if let methodIndex = methodToUse,
                       let method = MedicationManager.AdministrationMethod(rawValue: methodIndex) {
                        
                        NavigationLink(destination: DosageView()) {
                            Text("Next")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            // Ensure selectedMethodIndex is set before updating the manager
                            if selectedMethodIndex == nil {
                                selectedMethodIndex = methodIndex
                            }
                            // Update the MedicationManager with the selected values
                            medicationManager.updateSelection(type: type, method: method)
                        })
                        .padding(.vertical, 40.0)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
        } detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
