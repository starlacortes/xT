//
//  MissedDosePrompt.swift
//  xT
//
//  Created by Cline on 5/28/2026.
//  Missed dose prompt component for HomeView
//

import SwiftUI

struct MissedDosePrompt: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingRecordDose = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 12) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.92, blue: 0.94))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.96, green: 0.75, blue: 0.82), lineWidth: 0.5)
                        )

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
                }

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missed dose?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))

                    if let days = medicationManager.daysSinceMissedDose {
                        Text("Your dose was due \(days) day\(days == 1 ? "" : "s") ago")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Record dose now button
                Button(action: {
                    showingRecordDose = true
                }) {
                    Text("Record dose now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.98, green: 0.92, blue: 0.94))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.96, green: 0.75, blue: 0.82), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                // Adjust schedule button
                NavigationLink(destination: UnifiedScheduleView()) {
                    Text("Adjust schedule")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.32, green: 0.29, blue: 0.71))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.93, green: 0.93, blue: 0.99))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.85, green: 0.83, blue: 0.95), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            // Helpful message
            Text("It's okay! Just record your dose or adjust your schedule to get back on track.")
                .font(.system(size: 11))
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.clear)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.96, green: 0.75, blue: 0.82), lineWidth: 1.0)
        )
        .sheet(isPresented: $showingRecordDose) {
            RecordDoseView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Record Dose View (Sheet)
struct RecordDoseView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Text("Record your dose")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))

                // Date picker
                DatePicker("When did you take your dose?", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 20)

                // Record button
                Button(action: {
                    medicationManager.recordDose(on: selectedDate)
                    showingConfirmation = true

                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }) {
                    Text("Record dose")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.60, green: 0.21, blue: 0.33))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)

                if showingConfirmation {
                    Text("✓ Dose recorded successfully!")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.23, green: 0.43, blue: 0.07))
                        .transition(.opacity)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MissedDosePrompt()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Color(.systemBackground))
}