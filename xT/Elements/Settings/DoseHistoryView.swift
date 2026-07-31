//
//  DoseHistoryView.swift
//  xT
//
//  Dose history list with swipe-to-correct-site and swipe-to-delete actions.
//

import SwiftUI

struct DoseHistoryView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var correctionTarget: DoseRecord? = nil
    @State private var showCorrectionAlert: Bool = false
    @State private var showCorrectionSheet: Bool = false

    // Delete confirmation state
    @State private var doseToDelete: DoseRecord? = nil
    @State private var showDeleteConfirmation = false

    // MARK: - Grouped Doses

    /// Doses grouped by medication type, sorted newest first within each group.
    private var groupedDoses: [(medication: String, doses: [DoseRecord])] {
        let active = medicationManager.doseHistory.filter { $0.isActive }
        let grouped = Dictionary(grouping: active) { $0.medicationType }
        return grouped
            .map { (medication: $0.key, doses: $0.value.sorted { $0.doseDate > $1.doseDate }) }
            .sorted { $0.medication < $1.medication }
    }

    var body: some View {
        List {
            if groupedDoses.isEmpty {
                ContentUnavailableView(
                    "No Dose History",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Record your first dose to see history here.")
                )
            }

            ForEach(groupedDoses, id: \.medication) { group in
                Section(group.medication) {
                    ForEach(group.doses) { dose in
                        DoseHistoryRow(dose: dose)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    doseToDelete = dose
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                if RouteClass.from(method: dose.administrationMethod) != .oral {
                                    Button("Edit Site") {
                                        correctionTarget = dose
                                        showCorrectionAlert = true
                                    }
                                    .tint(Theme.Colors.accentSecondary)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Dose History")
        .alert("Delete Dose?", isPresented: $showDeleteConfirmation, presenting: doseToDelete) { dose in
            Button("Delete", role: .destructive) {
                medicationManager.softDeleteDose(id: dose.id)
                doseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                doseToDelete = nil
            }
        } message: { dose in
            Text(deleteAlertMessage(for: dose))
        }
        .alert("Edit Administration Site", isPresented: $showCorrectionAlert) {
            Button("Continue") { showCorrectionSheet = true }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Editing the site will delete the original record and create a new one tagged as user-corrected. The original date, dose details, and original site are preserved for audit.")
        }
        .sheet(isPresented: $showCorrectionSheet) {
            QuickDoseSheet(
                isPresented: $showCorrectionSheet,
                correctionMode: true,
                originalDose: correctionTarget
            )
        }
    }

    // MARK: - Delete alert message

    private func deleteAlertMessage(for dose: DoseRecord) -> String {
        """
        This will permanently remove the dose from "\(dose.medicationType)" \
        logged on \(dose.doseDate.formatted(date: .abbreviated, time: .shortened)).
        The record is retained for audit but will no longer appear in charts or history.
        """
    }
}

// MARK: - Dose History Row

struct DoseHistoryRow: View {
    let dose: DoseRecord

    private var routeClass: RouteClass {
        RouteClass.from(method: dose.administrationMethod)
    }

    private var siteDisplay: String {
        let sites = dose.injectionSites
        if sites.isEmpty {
            return routeClass == .oral ? "N/A" : "No site recorded"
        }
        if sites.count == 1 {
            return "\(sites[0].zoneLabel) (\(sites[0].viewContext))"
        }
        return "\(sites.count) sites"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: routeIcon)
                    .foregroundStyle(routeIconColor)
                    .font(.caption)
                Text("\(dose.medicationType) — \(String(format: "%.1f", dose.doseAmount)) mg")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            HStack(spacing: 6) {
                Text(dose.doseDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(siteDisplay)
                    .font(.caption)
                    .foregroundStyle(dose.injectionSites.isEmpty ? .tertiary : .primary)

                if dose.isUserCorrected {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 8))
                        Text("Corrected")
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.accentSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.accentSecondary.opacity(0.12))
                    )
                }
            }

            if dose.isUserCorrected, !dose.originalSites.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 8))
                    Text("Originally: ")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        +
                        Text(dose.originalSites.map { $0.zoneLabel }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 2)
    }

    private var routeIcon: String {
        switch routeClass {
        case .injection: return "syringe.fill"
        case .topical:   return "hand.raised.fill"
        case .patch:     return "square.fill"
        case .oral:      return "pills.fill"
        }
    }

    private var routeIconColor: Color {
        switch routeClass {
        case .injection: return Theme.Colors.accent
        case .topical:   return .orange
        case .patch:     return .green
        case .oral:      return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    SpoofPreview {
        NavigationStack {
            DoseHistoryView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
