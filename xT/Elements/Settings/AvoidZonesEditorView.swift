//
//  AvoidZonesEditorView.swift
//  xT
//
//  Manage zones marked as "avoid" — list with reason/date,
//  swipe-to-delete, and tap-to-show-on-sketch for v2.1.
//

import SwiftUI

struct AvoidZonesEditorView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var selectedZone: String? = nil
    @State private var showZonePreview: Bool = false

    private var sortedZones: [(zone: String, info: AvoidZoneInfo)] {
        medicationManager.avoidZones
            .sorted { $0.key < $1.key }
            .map { (zone: $0.key, info: $0.value) }
    }

    var body: some View {
        List {
            if sortedZones.isEmpty {
                ContentUnavailableView(
                    "No Avoid Zones",
                    systemImage: "exclamationmark.shield",
                    description: Text("Long-press on a zone in the body picker to mark it as avoid.")
                )
            }

            ForEach(sortedZones, id: \.zone) { entry in
                AvoidZoneRow(zone: entry.zone, info: entry.info)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedZone = entry.zone
                        showZonePreview = true
                    }
            }
            .onDelete { indexSet in
                for i in indexSet {
                    let zone = sortedZones[i].zone
                    medicationManager.unmarkAvoidZone(zone)
                }
            }
        }
        .navigationTitle("Avoid Zones")
        .sheet(isPresented: $showZonePreview) {
            if let zone = selectedZone {
                avoidZoneDetailSheet(zone: zone)
            }
        }
    }

    // MARK: - Detail Sheet

    private func avoidZoneDetailSheet(zone: String) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Zone name
                Text(zone)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let info = medicationManager.avoidZones[zone] {
                    // Reason
                    if !info.reason.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reason")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(info.reason)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    // Marked date
                    HStack {
                        Text("Marked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(info.markedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .padding(.horizontal)

                    // Zone region label
                    if let region = ZoneCentroidStore.shared.region(for: zone) {
                        Text(region.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                // Unmark button
                Button(role: .destructive) {
                    medicationManager.unmarkAvoidZone(zone)
                    showZonePreview = false
                } label: {
                    Label("Remove from Avoid Zones", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showZonePreview = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

}

// MARK: - Avoid Zone Row

struct AvoidZoneRow: View {
    let zone: String
    let info: AvoidZoneInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(zone)
                .font(.subheadline)
                .fontWeight(.medium)

            if !info.reason.isEmpty {
                Text(info.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text("Marked \(info.markedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        AvoidZonesEditorView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif