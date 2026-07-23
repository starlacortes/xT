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

                    // Sketch preview
                    if let sketchId = BodySketchData.sketchId(for: zone) {
                        avoidZoneSketchPreview(sketchId: sketchId, zone: zone)
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

    @ViewBuilder
    private func avoidZoneSketchPreview(sketchId: String, zone: String) -> some View {
        VStack(spacing: 8) {
            Text("Location on body")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                silhouetteView(for: sketchId)

                // Highlight the avoided zone
                if let rect = BodySketchData.zoneBoundingRects[sketchId]?[zone]
                    ?? BodySketchData.upperBodyFrontPrecisionRects[zone] {
                    let absRect = CGRect(
                        x: rect.minX * 200,
                        y: rect.minY * 200,
                        width: rect.width * 200,
                        height: rect.height * 200
                    )
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.25))
                        .frame(width: absRect.width, height: absRect.height)
                        .position(x: absRect.midX, y: absRect.midY)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red, lineWidth: 1.5)
                                .frame(width: absRect.width, height: absRect.height)
                                .position(x: absRect.midX, y: absRect.midY)
                        )

                    // ⚠️ icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .position(x: absRect.midX, y: absRect.midY)
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func silhouetteView(for sketchId: String) -> some View {
        switch sketchId {
        case "thighsFront":    ThighsFrontSilhouette().fill(Color.gray.opacity(0.08))
        case "thighsBack":     ThighsBackSilhouette().fill(Color.gray.opacity(0.08))
        case "glutesBack":     GlutesBackSilhouette().fill(Color.gray.opacity(0.08))
        case "armsFront":      ArmsFrontSilhouette().fill(Color.gray.opacity(0.08))
        case "armsBack":       ArmsBackSilhouette().fill(Color.gray.opacity(0.08))
        case "upperBodyFront": UpperBodyFrontSilhouette().fill(Color.gray.opacity(0.08))
        default:               ThighsFrontSilhouette().fill(Color.gray.opacity(0.08))
        }
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

#Preview {
    NavigationStack {
        AvoidZonesEditorView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}