//
//  DosageView.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//

import SwiftUI

struct DosageView: View {
    // Use the MedicationManager from the environment
    @Environment(\.medicationManager) private var medicationManager: MedicationManager

    var body: some View {
        VStack (alignment: .center, spacing: 20) {
            Text("Dosage View")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(20)


            VStack() {


                Text("Your selected medication:")
                    .font(.headline)

                Text(medicationManager.medicationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text("Select Dosing:")
                    .font(.headline)
                    .padding(.top)

                NavigationLink(destination: SchedulerView()) {
                    Text("Standard dosage: " + medicationManager.dosageInfo)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }

                NavigationLink(destination: ContentView()) {
                    Text("Custom dosage")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }
            }.padding(.top, 200)
            Spacer()
        }
        .padding(.horizontal)
        .navigationTitle("Dosage")
    }
}
#Preview {
    DosageView()
}
