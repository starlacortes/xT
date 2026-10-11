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
        HistoryListView(
            title: "Dose History",
            emptyTitle: "No Dose History",
            emptyIcon: "clock.badge.exclamationmark",
            emptyDescription: "Record your first dose to see history here.",
            groups: groupedDoses.map { (title: $0.medication, items: $0.doses) },
            deleteAlertTitle: "Delete Dose?",
            deleteMessage: deleteAlertMessage(for:),
            onDelete: { medicationManager.softDeleteDose(id: $0.id) },
            editLabel: "Edit Site",
            editVisible: { RouteClass.from(method: $0.administrationMethod) != .oral },
            onEdit: { dose in
                correctionTarget = dose
                showCorrectionAlert = true
            },
            row: { DoseHistoryRow(dose: $0) },
            composer: { _ in EmptyView() }
        )
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

    /// Returns a `Text` so each branch picks the right initializer:
    /// `Text(verbatim:)` for plain assembled strings, `Text(LocalizedStringResource(...))`
    /// for the inflected plural case. Returning `String` would route every branch
    /// through `Text(_:StringProtocol)` (verbatim) and the `^[N site](inflect: true)`
    /// marker would render as literal text.
    private var siteDisplay: Text {
        let sites = dose.injectionSites
        if sites.isEmpty {
            return Text(verbatim: routeClass == .oral ? "N/A" : "No site recorded")
        }
        if sites.count == 1 {
            return Text(verbatim: "\(sites[0].zoneLabel) (\(sites[0].viewContext))")
        }
        return Text(LocalizedStringResource(
            "^[\(sites.count) site](inflect: true)",
            comment: "Count of distinct administration sites used"
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: routeIcon)
                    .foregroundStyle(routeIconColor)
                    .font(Theme.Fonts.caption)
                Text("\(dose.medicationType) — \(AppNumberFormatters.dose.string(dose.doseAmount)) mg")
                    .font(Theme.Fonts.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            HStack(spacing: 6) {
                Text(dose.doseDate.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                siteDisplay
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(dose.injectionSites.isEmpty ? .tertiary : .primary)

                if dose.isUserCorrected {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 8))
                        Text("Corrected")
                    }
                    .font(Theme.Fonts.caption2)
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
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.tertiary)
                    Text(dose.originalSites.map { $0.zoneLabel }.joined(separator: ", "))
                        .font(Theme.Fonts.caption2)
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

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            DoseHistoryView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
