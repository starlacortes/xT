//
//  DataExportView.swift
//  xT
//
//  Created 2026-07-04.
//  View for exporting all user data as CSV or JSON via the system share sheet.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.profileManager) private var profileManager
    @Environment(\.modelContainer) private var modelContainer

    @State private var csvString: String?
    @State private var jsonData: Data?
    @State private var showCSVShare = false
    @State private var showJSONShare = false

    var body: some View {
        List {
            // MARK: - Export Actions
            Section {
                Button {
                    showCSVShare = true
                } label: {
                    exportRow(
                        icon: "tablecells",
                        title: "Export as CSV",
                        subtitle: "Spreadsheet format — opens in Numbers, Excel, or any text editor"
                    )
                }

                Button {
                    showJSONShare = true
                } label: {
                    exportRow(
                        icon: "curlybraces",
                        title: "Export as JSON",
                        subtitle: "Structured format — machine-readable, ideal for research tools"
                    )
                }
            } header: {
                Text("Export All Data")
            } footer: {
                Text("Your data is exported as plain text and may contain sensitive health information. Only share with trusted recipients.")
            }

            // MARK: - What's Included
            Section {
                summaryRow(icon: "syringe", label: "Dose history", count: activeDoseCount)
                summaryRow(icon: "figure.arms.open", label: "Administration site history", count: siteDoseCount)
                summaryRow(icon: "book", label: "Journal entries", count: journalManager.entries.count)
                summaryRow(icon: "drop", label: "Blood test results", count: medicationManager.bloodTestHistory.count)
                summaryRow(icon: "heart.text.square", label: "Health screenings", count: medicationManager.screeningRecords.count)
                summaryRow(icon: "exclamationmark.shield", label: "Avoid zones", count: avoidZoneCount)
            } header: {
                Text("What's Included")
            }

            // MARK: - Privacy Note
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your Privacy", systemImage: "hand.raised")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(.primary)
                    Text("All export processing happens on your device. No data is sent to any server. Exported files contain unencrypted personal health information — please store them securely.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Export")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showCSVShare) {
            if let csv = generateCSV() {
                ShareSheet(items: [csvStringAsFile(csv)])
            }
        }
        .sheet(isPresented: $showJSONShare) {
            if let json = generateJSON() {
                ShareSheet(items: [jsonAsFile(json)])
            }
        }
        .onChange(of: showCSVShare) { _, shown in if !shown { csvString = nil } }
        .onChange(of: showJSONShare) { _, shown in if !shown { jsonData = nil } }
    }

    // MARK: - Views

    private func exportRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(Theme.Fonts.callout)
                .foregroundStyle(.primary)

            Spacer()

            Text(verbatim: AppNumberFormatters.percent.string(count))
                .font(Theme.Fonts.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var activeDoseCount: Int {
        medicationManager.doseHistory.filter(\.isActive).count
    }

    private var siteDoseCount: Int {
        medicationManager.doseHistory.filter { $0.isActive && !$0.injectionSites.isEmpty }.count
    }

    private var avoidZoneCount: Int {
        medicationManager.avoidZones.count
    }

    /// Builds only the format actually being shared — serializing CSV *and*
    /// JSON on screen-open (and then again per tap) wasted a full-History pass
    /// per visit.
    private func buildExportState() -> DataExporter.ExportState? {
        guard let context = modelContainer?.mainContext else { return nil }
        let prefs = UserPreferences.canonical(in: context)
        let defaults = UserDefaults.standard

        return DataExporter.ExportState(
            doseHistory: medicationManager.doseHistory,
            journalEntries: journalManager.entries,
            bloodTests: medicationManager.bloodTestHistory,
            screenings: medicationManager.screeningRecords,
            swiftDataPreferences: prefs,
            selectedMedication: medicationManager.selectedMedication,
            hrtStartDate: medicationManager.hrtStartDate,
            antiAndrogenInUse: medicationManager.antiAndrogenInUse,
            spironolactoneInUse: medicationManager.spironolactoneInUse,
            missedDoseGracePeriodHours: medicationManager.missedDoseGracePeriodHours,
            doseReminderEnabled: defaults.bool(forKey: NotificationManager.Keys.doseReminderEnabled),
            doseReminderHour: defaults.integer(forKey: NotificationManager.Keys.doseReminderHour),
            doseReminderMinute: defaults.integer(forKey: NotificationManager.Keys.doseReminderMinute),
            journalReminderEnabled: defaults.bool(forKey: NotificationManager.Keys.journalReminderEnabled),
            journalReminderHour: defaults.integer(forKey: NotificationManager.Keys.journalReminderHour),
            journalReminderMinute: defaults.integer(forKey: NotificationManager.Keys.journalReminderMinute),
            useCustomTargets: medicationManager.userTherapeuticTarget != nil,
            targetTroughMin: medicationManager.userTherapeuticTarget?.troughMin ?? 0,
            targetTroughMax: medicationManager.userTherapeuticTarget?.troughMax ?? 0,
            targetPeakCeiling: medicationManager.userTherapeuticTarget?.peakCeiling ?? 0,
            medicationUnit: medicationManager.selectedMedication.map(BloodTestRecord.unit(for:)) ?? "pg/mL",
            profileName: profileManager.profileName,
            avoidZones: medicationManager.avoidZones
        )
    }

    private func generateCSV() -> String? {
        guard let state = buildExportState() else { return nil }
        let csv = DataExporter.exportCSV(state: state)
        csvString = csv
        return csv
    }

    private func generateJSON() -> Data? {
        guard let state = buildExportState() else { return nil }
        let data = DataExporter.exportJSON(state: state)
        jsonData = data
        return data
    }

    private func csvStringAsFile(_ csv: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = DataExporter.exportFilename(prefix: "export", ext: "csv")
        let url = tempDir.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func jsonAsFile(_ data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = DataExporter.exportFilename(prefix: "export", ext: "json")
        let url = tempDir.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}

// MARK: - UIKit Share Sheet Wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            DataExportView()
                .environment(\.medicationManager, MedicationManager.shared)
                .environment(\.journalManager, JournalManager.shared)
                .environment(\.profileManager, ProfileManager.shared)
        }
    }
}
#endif