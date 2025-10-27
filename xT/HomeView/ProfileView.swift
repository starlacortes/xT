import SwiftUI

// MARK: - ProfileView backed by existing MedicationManager
struct ProfileView: View {
    // Use the Environment value provided by MedicationManagerKey in your project
    @Environment(\.medicationManager) private var medicationManager: MedicationManager

    var body: some View {
        Form {
            Section(header: Text("Current Selection")) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(medicationManager.medicationName)
                            .font(.headline)
                        Text(medicationManager.dosageInfo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current medication and dosage")
            }

            Section(header: Text("Details")) {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(medicationManager.selectedMedicationType?.displayName ?? "Not selected")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Method")
                    Spacer()
                    Text(medicationManager.selectedAdministrationMethod?.displayName ?? "Not selected")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    medicationManager.clearSelection()
                } label: {
                    Text("Clear Selection")
                }
            }
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    // Inject the singleton manager via EnvironmentValues so the view compiles and runs in preview
    NavigationView {
        ProfileView()
    }
    .environment(\.medicationManager, MedicationManager.shared)
}
