//
//  TypeMethodSettingsView.swift
//  xT
//
//  Configure medication type, administration method, and ester from Settings.
//

import SwiftUI

struct TypeMethodSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.medicationManager) private var medicationManager

    @State private var selectedType: String
    @State private var selectedMethod: String
    @State private var selectedEster: String

    @State private var hasChanges = false
    @State private var showConfirmation = false

    @AppStorage("hasSeenTypeMethodWarning") private var hasSeenWarning = false

    private let medicationTypes: [(id: String, label: String, subtitle: String)] = [
        ("Estrogen", "Estrogen-based HRT", "Estradiol-based hormone therapy"),
        ("Testosterone", "Testosterone-based HRT", "Testosterone-based hormone therapy")
    ]

    private var administrationMethods: [MedicationManager.AdministrationMethod] {
        MedicationManager.AdministrationMethod.allCases
    }

    /// Testosterone previously returned `TestosteroneEster.allCases` for Injectable —
    /// which now includes the Oral/Transdermal route pseudo-esters — and `[]` for the
    /// Oral and Cream methods, leaving whatever injectable ester was already selected
    /// silently in place. Both enums now expose `injectableCases`, and every
    /// medication/method pair resolves to the pseudo-ester the PK engine will actually
    /// use (see `MedicationManager.effectiveEsterName`).
    private var availableEsters: [(name: String, halfLife: String)] {
        let isEstrogen = selectedType == "Estrogen"
        switch selectedMethod {
        case "Injectable":
            return isEstrogen
                ? MedicationEster.injectableCases.map { ($0.rawValue, halfLifeLabel($0.halfLifeDays)) }
                : TestosteroneEster.injectableCases.map { ($0.rawValue, halfLifeLabel($0.halfLifeDays)) }
        case "Oral":
            return [("Oral", "Rapid absorption")]
        case "Cream":
            return [("Transdermal", "Sustained 24h release")]
        default:
            return []
        }
    }

    init() {
        let mgr = MedicationManager.shared
        _selectedType = State(initialValue: mgr.selectedMedication ?? "Estrogen")
        _selectedMethod = State(initialValue: mgr.selectedAdministrationMethod ?? "Injectable")
        _selectedEster = State(initialValue: mgr.selectedEster ?? Self.defaultEster(for: mgr.selectedMedication ?? "Estrogen", method: mgr.selectedAdministrationMethod ?? "Injectable"))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    typeSection
                    methodSection
                    if !availableEsters.isEmpty {
                        esterSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Type & Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!hasChanges)
                        .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
        .alert("Change Medication Settings?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Save Changes") { performSave() }
        } message: {
            Text("Your existing dose history and blood test records will be preserved. This change affects how future doses are calculated and displayed.")
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Medication Type")

            ForEach(medicationTypes, id: \.id) { type in
                typeCard(type: type)
            }
        }
    }

    private func typeCard(type: (id: String, label: String, subtitle: String)) -> some View {
        Button {
            if selectedType != type.id {
                selectedType = type.id
                selectedEster = Self.defaultEster(for: type.id, method: selectedMethod)
                hasChanges = true
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.label)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(type.subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedType == type.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedType == type.id ? Theme.Colors.accent.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedType == type.id ? Theme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Method Section

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Administration Method")

            ForEach(administrationMethods, id: \.rawValue) { method in
                methodCard(method)
            }
        }
    }

    private func methodCard(_ method: MedicationManager.AdministrationMethod) -> some View {
        Button {
            if selectedMethod != method.rawValue {
                selectedMethod = method.rawValue
                selectedEster = Self.defaultEster(for: selectedType, method: method.rawValue)
                hasChanges = true
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(frequencyHint(for: method))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedMethod == method.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedMethod == method.rawValue ? Theme.Colors.accent.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedMethod == method.rawValue ? Theme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ester Section

    private var esterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Ester")

            ForEach(availableEsters, id: \.name) { ester in
                esterCard(ester)
            }
        }
    }

    private func esterCard(_ ester: (name: String, halfLife: String)) -> some View {
        Button {
            if selectedEster != ester.name {
                selectedEster = ester.name
                hasChanges = true
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ester.name)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text(ester.halfLife)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedEster == ester.name {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(selectedEster == ester.name ? Theme.Colors.accent.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(selectedEster == ester.name ? Theme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private func frequencyHint(for method: MedicationManager.AdministrationMethod) -> String {
        switch method {
        case .injectable: return "Typical cycle: 7 days"
        case .cream: return "Applied daily"
        case .oral: return "Taken daily"
        }
    }

    private func halfLifeLabel(_ days: Double) -> String {
        String(localized: "Half-life ~^[\(Int(days.rounded())) day](inflect: true)",
               comment: "Approximate elimination half-life of the selected ester")
    }

    private static func defaultEster(for type: String, method: String) -> String {
        if type == "Estrogen" {
            switch method {
            case "Injectable": return "Valerate (EV)"
            case "Oral": return "Oral"
            case "Cream": return "Transdermal"
            default: return "Valerate (EV)"
            }
        } else {
            // Cream/Oral must not default to an injectable ester: the PK engine resolves
            // those routes to the Transdermal/Oral pseudo-esters, and leaving "Cypionate
            // (TC)" on the record made the stored ester disagree with what was modeled.
            switch method {
            case "Injectable": return "Cypionate (TC)"
            case "Cream": return "Transdermal"
            case "Oral": return "Oral"
            default: return "Cypionate (TC)"
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        if !hasSeenWarning {
            hasSeenWarning = true
            showConfirmation = true
        } else {
            performSave()
        }
    }

    private func performSave() {
        guard let type = MedicationManager.MedicationType(rawValue: selectedType),
              let method = MedicationManager.AdministrationMethod(rawValue: selectedMethod) else { return }

        medicationManager.selectedEster = selectedEster
        medicationManager.updateSelection(type: type, method: method)
        medicationManager.refreshState()
        dismiss()
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        TypeMethodSettingsView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
