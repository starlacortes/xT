//
//  PreferredZonesEditorView.swift
//  xT
//
//  Toggle preferred zones per medication + route class.
//  Each sketch gets its own section; each zone gets a toggle.
//  On save, the full list of enabled zones is returned via callback.
//

import SwiftUI

struct PreferredZonesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let medication: String
    let routeClass: RouteClass
    let onSave: ([String]) -> Void

    @State private var selectedZones: [String: Bool] = [:]

    private let sketchOrder: [String] = [
        "thighsFront", "thighsBack",
        "glutesBack",
        "armsFront", "armsBack",
        "upperBodyFront",
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sketchOrder, id: \.self) { sketchId in
                    let zones = BodySketchData.zoneLabels(for: sketchId)
                    if !zones.isEmpty {
                        Section(header: Text(displayName(for: sketchId))) {
                            ForEach(zones, id: \.self) { zone in
                                Toggle(zone, isOn: Binding(
                                    get: { selectedZones[zone] ?? false },
                                    set: { selectedZones[zone] = $0 }
                                ))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Preferred Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let enabled = selectedZones
                            .filter { $0.value }
                            .map { $0.key }
                        onSave(enabled)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            let preferred = BodySketchData.preferredZones(
                medication: medication,
                routeClass: routeClass
            )
            selectedZones = [:]
            // Pre-seed all zones for all sketches
            for sketchId in sketchOrder {
                for zone in BodySketchData.zoneLabels(for: sketchId) {
                    selectedZones[zone] = preferred.contains(zone)
                }
            }
        }
    }

    private func displayName(for sketchId: String) -> String {
        switch sketchId {
        case "thighsFront":    return "Thighs — Front"
        case "thighsBack":     return "Thighs — Back"
        case "glutesBack":     return "Glutes — Back"
        case "armsFront":      return "Arms — Front"
        case "armsBack":       return "Arms — Back"
        case "upperBodyFront": return "Upper Body — Front"
        default:               return sketchId
        }
    }
}

#Preview {
    PreferredZonesEditorView(
        medication: "Testosterone",
        routeClass: .injection,
        onSave: { _ in }
    )
}
