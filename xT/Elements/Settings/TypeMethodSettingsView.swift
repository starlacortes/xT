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

    private let medicationTypes: [(id: String, label: String, subtitle: LocalizedStringResource)] = [
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
    private var availableEsters: [(name: String, halfLife: LocalizedStringResource)] {
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
            .background(Theme.Colors.appBackground)
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
            SheetSectionLabel(text: "Medication Type")

            ForEach(medicationTypes, id: \.id) { type in
                typeCard(type: type)
            }
        }
    }

    private func typeCard(type: (id: String, label: String, subtitle: LocalizedStringResource)) -> some View {
        SelectableOptionRow(title: type.label, subtitle: type.subtitle,
                            isSelected: selectedType == type.id) {
            if selectedType != type.id {
                selectedType = type.id
                selectedEster = Self.defaultEster(for: type.id, method: selectedMethod)
                hasChanges = true
            }
        }
    }

    // MARK: - Method Section

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Administration Method")

            ForEach(administrationMethods, id: \.rawValue) { method in
                methodCard(method)
            }
        }
    }

    private func methodCard(_ method: MedicationManager.AdministrationMethod) -> some View {
        SelectableOptionRow(title: method.rawValue, subtitle: frequencyHint(for: method),
                            isSelected: selectedMethod == method.rawValue) {
            if selectedMethod != method.rawValue {
                selectedMethod = method.rawValue
                selectedEster = Self.defaultEster(for: selectedType, method: method.rawValue)
                hasChanges = true
            }
        }
    }

    // MARK: - Ester Section

    private var esterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetSectionLabel(text: "Ester")

            ForEach(availableEsters, id: \.name) { ester in
                esterCard(ester)
            }
        }
    }

    private func esterCard(_ ester: (name: String, halfLife: LocalizedStringResource)) -> some View {
        SelectableOptionRow(title: ester.name, subtitle: ester.halfLife,
                            isSelected: selectedEster == ester.name) {
            if selectedEster != ester.name {
                selectedEster = ester.name
                hasChanges = true
            }
        }
    }

    // MARK: - Helpers


    private func frequencyHint(for method: MedicationManager.AdministrationMethod) -> LocalizedStringResource {
        switch method {
        case .injectable: return "Typical cycle: 7 days"
        case .cream: return "Applied daily"
        case .oral: return "Taken daily"
        }
    }

    private func halfLifeLabel(_ days: Double) -> LocalizedStringResource {
        LocalizedStringResource(
            "Half-life ~^[\(Int(days.rounded())) day](inflect: true)",
            comment: "Approximate elimination half-life of the selected ester"
        )
    }

    private static func defaultEster(for type: String, method: String) -> String {
        // Two previously hand-maintained switch ladders route through the
        // manager's single sources: the injectable default ester comes from
        // `defaultEsterInfo`, and Cream/Oral map to the Transdermal/Oral
        // pseudo-esters via `effectiveEsterName` — non-injectable routes must
        // not default to an injectable ester, or the stored ester disagrees
        // with what the PK engine models.
        MedicationManager.effectiveEsterName(
            ester: MedicationManager.defaultEsterInfo(for: type).name,
            route: method
        )
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
