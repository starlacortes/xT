//
//  QuickDoseSheet.swift
//  xT
//
//  Quick dose recording sheet with mg/mL toggle, concentration picker,
//  date selection, and volume warnings.
//

import SwiftUI

struct QuickDoseSheet: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var isPresented: Bool

    @State private var doseUnit: String = "mg"
    @State private var mgAmount: Double = 2.0
    @State private var mlAmount: Double = 0.05
    @State private var concentration: Double = 40.0
    @State private var showCustomConcentration: Bool = false
    @State private var customConcentrationText: String = ""
    @State private var doseDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Record Dose")
                    .font(.headline)
                    .padding(.top, 8)

                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(Theme.Colors.accent)
                    Text(medicationManager.medicationDisplayInfo)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 20)

                Picker("Dose Unit", selection: $doseUnit) {
                    Text("mg").tag("mg")
                    Text("mL").tag("mL")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                if doseUnit == "mg" {
                    HStack(spacing: 12) {
                        TextField("mg", value: $mgAmount, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        Text("mg")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)

                    let volume = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
                    Text("= \(String(format: "%.3f", volume)) mL (@ \(String(format: "%.0f", concentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let warning = MedicationManager.volumeWarning(for: volume, ester: medicationManager.lastLoggedDose?.ester) {
                        quickDoseWarning(warning)
                    }
                } else {
                    HStack(spacing: 12) {
                        TextField("mL", value: $mlAmount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        Text("mL")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)

                    let computedMg = mlAmount * concentration
                    Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", concentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let warning = MedicationManager.volumeWarning(for: mlAmount, ester: medicationManager.lastLoggedDose?.ester) {
                        quickDoseWarning(warning)
                    }
                }

                VStack(spacing: 6) {
                    Text("Vial concentration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    let ester = medicationManager.lastLoggedDose?.ester ?? ""
                    let concentrations = MedicationManager.commonConcentrations(forEster: ester)
                        .filter { $0 > 0 }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(concentrations, id: \.self) { conc in
                                Button {
                                    withAnimation { concentration = conc; showCustomConcentration = false }
                                } label: {
                                    Text("\(String(format: "%.0f", conc))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(concentration == conc && !showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Color(.tertiarySystemFill))
                                        )
                                }
                            }
                            Button {
                                withAnimation { showCustomConcentration = true }
                            } label: {
                                Text("Custom")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Color(.tertiarySystemFill))
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose date & time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    DatePicker("", selection: $doseDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.horizontal, 20)
                }

                Spacer()

                Button {
                    recordDose()
                } label: {
                    Text("Record Dose")
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
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .onAppear {
                if let lastDose = medicationManager.lastLoggedDose {
                    mgAmount = lastDose.doseAmount
                    if let conc = lastDose.concentrationMgPerMl {
                        concentration = conc
                    } else if let defaultConc = medicationManager.defaultConcentrationMgPerMl {
                        concentration = defaultConc
                    }
                    updateMlFromMg()
                } else if let defaultConc = medicationManager.defaultConcentrationMgPerMl {
                    concentration = defaultConc
                    updateMlFromMg()
                }
            }
            .onChange(of: concentration) { _, _ in updateMlFromMg() }
            .onChange(of: mgAmount) { _, _ in updateMlFromMg() }
        }
    }

    private func updateMlFromMg() {
        guard concentration > 0 else { return }
        mlAmount = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
    }

    private func recordDose() {
        let finalMg = doseUnit == "mg" ? mgAmount : mlAmount * concentration
        let finalConcentration = concentration > 0 ? concentration : nil

        guard let medType = medicationManager.selectedMedication,
              let medMethod = medicationManager.selectedAdministrationMethod else { return }

        let ester: String
        if let recentEster = medicationManager.lastLoggedDose?.ester {
            ester = recentEster
        } else if medType == "Estrogen" {
            ester = "Valerate (EV)"
        } else {
            ester = "Cypionate (TC)"
        }

        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()

        medicationManager.addDose(
            date: doseDate,
            type: medType,
            ester: ester,
            method: medMethod,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        isPresented = false
    }

    private func quickDoseWarning(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.yellow.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    QuickDoseSheet(isPresented: .constant(true))
        .environment(\.medicationManager, MedicationManager.shared)
}
