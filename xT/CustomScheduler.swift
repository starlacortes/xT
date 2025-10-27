//
//  CustomScheduler.swift
//  xT
//
//  Created by Starla Cortes on 9/27/25.
//

import SwiftUI

struct CustomScheduler: View {
    @StateObject private var medicationManager = MedicationManager.shared // Shared instance

    // For future dose calculations (example)
    @State private var lastDoseDate = Date()
    @State private var nextDoseDate: Date?

    // State variable to hold the text from the TextField
    @State private var doseDayCount: String = ""

    var body: some View {
        VStack (spacing:20){
            Text("Custom Scheduler")
                .font(.title)

            Text("Your selected medication:")
                .font(.headline)

            Text(medicationManager.medicationName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            // Button to manually schedule a dosage (example)
            Button("Schedule") {
                // You can update medicationManager.medicationName here with medicationNameInput
            }

            Group {
                HStack {
                    Text("I take this every:")
                        .font(.headline)
                        .padding(.leading, 20)
                    
                    Picker("Enter number ranging from 1-30", selection: $doseDayCount) {
                        ForEach(1...30, id: \.self) { number in
                            Text("\(number)")
                        }
                    }
                    .frame(width: 100)
                }
                

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

                if let nextDate = nextDoseDate {
                    Text("Next dose date:")
                        .font(.headline)
                        .padding(.top, 20)

                    Text(nextDate, style: .date)
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }

            // Debug information (can be removed in production)
            VStack {
                Text("Matrix coordinates: \(medicationManager.currentCoordinates.row), \(medicationManager.currentCoordinates.column)")
                    .font(.caption)
                    .foregroundColor(.gray)

                if let type = medicationManager.selectedMedicationType,
                   let method = medicationManager.selectedAdministrationMethod {
                    Text("Selected: \(type.displayName) (\(method.displayName))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 40)

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
        }
    }
}

#Preview {
    CustomScheduler()
}
