//
//  SchedulerView.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//

import SwiftUI
import SwiftData

struct SchedulerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    // Use the MedicationManager from the environment
    @Environment(\.medicationManager) private var medicationManager
    
    // For future dose calculations (example)
    @State private var lastDoseDate = Date()
    @State private var nextDoseDate: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Scheduler")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Your selected medication:")
                .font(.headline)
            
            Text(medicationManager.medicationName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // Show recommended dosage information
            Text("Recommended dosage:")
                .font(.headline)
                .padding(.top, 20)
            
            Text(medicationManager.dosageInfo)
                .font(.body)
                .foregroundColor(.green)
            
            // Dose calculation UI (example for future functionality)
            Group {
                Text("Last dose date:")
                    .font(.headline)
                    .padding(.top, 20)
                
                DatePicker("", selection: $lastDoseDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .frame(height: 120)
                    .onChange(of: lastDoseDate) { oldValue, newValue in
                        nextDoseDate = medicationManager.calculateNextDoseDate(from: newValue)
                    }
                
                Button("Record Dose") {
                    medicationManager.recordDose(on: lastDoseDate)
                    // Refresh dates
                    lastDoseDate = medicationManager.lastDoseDate ?? Date()
                    nextDoseDate = medicationManager.nextDoseDate
                }
                .padding(.top, 10)
                
                if let nextDate = nextDoseDate {
                    Text("Next dose date:")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    Text(nextDate, style: .date)
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }
            
            // Debug information (can be removed in production)
            VStack {
                Text("Selected medication: \(medicationManager.selectedMedication ?? "None")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Selected method: \(medicationManager.selectedAdministrationMethod ?? "None")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Initialize dates from medication manager
            lastDoseDate = medicationManager.lastDoseDate ?? Date()
            nextDoseDate = medicationManager.nextDoseDate
        }
        NavigationLink(destination: HomeView()) {
            Text("Let's Go")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 40)
        }
        .simultaneousGesture(TapGesture().onEnded {
            medicationManager.recordDose(on: lastDoseDate)
        })
    }
}

#Preview {
    SchedulerView()
}

// Commented out code preserved from original file
//        List {
//            ForEach(items) { item in
//                NavigationLink {
//                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
//                } label: {
//                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                }
//            }
//            .onDelete(perform: deleteItems)
//        }
//        
//        .toolbar {
//#if os(iOS)
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
//#endif
//            ToolbarItem {
//                Button(action: addItem) {
//                    Label("Add Item", systemImage: "plus")
//                }
//            }
//        }
//    }
//    
//    
//    private func addItem() {
//        withAnimation {
//            let newItem = Item(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }
//    
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
//}
        
