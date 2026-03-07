//
//  ScheduleView.swift
//  xT
//
//  Created by Starla Cortes on 2/11/26.
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.medicationManager) private var medicationManager

    @State private var lastDoseDate: Date? = nil
    @State private var nextDoseDate: Date? = nil

    // MARK: - Actions

    private func recordCurrentDose() {
        medicationManager.recordDose(on: Date())
        // Update dates from the manager directly
        lastDoseDate = medicationManager.lastDoseDate
        nextDoseDate = medicationManager.nextDoseDate
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Medication Schedule")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 8)

                // Medication Info
                Text("You're taking \(medicationManager.medicationName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)

                // Card container
                VStack(alignment: .leading, spacing: 20) {
                    // Last dose section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Dose")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let last = lastDoseDate {
                            Text("\(last.formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                                .bold()
                        } else {
                            Text("No dose recorded yet")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )

                    // Next dose section
                    if let nextDate = nextDoseDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next Dose")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("\(nextDate, style: .date)")
                                .font(.body)
                                .bold()
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Schedule not set yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(spacing: 12) {
                                NavigationLink {
                                    SchedulerView()
                                } label: {
                                    Text("Set Schedule")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Button(action: recordCurrentDose) {
                                    Text("Record Dose")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Schedule")
        .onAppear {
            // Update dates from the manager directly
            lastDoseDate = medicationManager.lastDoseDate
            nextDoseDate = medicationManager.nextDoseDate
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    ScheduleView()
}
