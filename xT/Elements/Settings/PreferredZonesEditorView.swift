//
//  PreferredZonesEditorView.swift
//  xT
//
//  Toggle preferred zones per medication + route class.
//  Flat alphabetical list from ZoneCentroidStore (3D migration — no sketch sections).
//  On save, the full list of enabled zones is returned via callback.
//

import SwiftUI

struct PreferredZonesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let medication: String
    let routeClass: RouteClass
    let onSave: ([String]) -> Void

    @State private var selectedZones: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            List {
                ForEach(ZoneCentroidStore.shared.labels, id: \.self) { zone in
                    Toggle(zone, isOn: Binding(
                        get: { selectedZones[zone] ?? false },
                        set: { selectedZones[zone] = $0 }
                    ))
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
            let preferred = ZoneCentroidStore.preferredZones(
                medication: medication,
                routeClass: routeClass
            )
            selectedZones = [:]
            for zone in ZoneCentroidStore.shared.labels {
                selectedZones[zone] = preferred.contains(zone)
            }
        }
    }
}

#if DEBUG
#Preview {
    PreferredZonesEditorView(
        medication: "Testosterone",
        routeClass: .injection,
        onSave: { _ in }
    )
}
#endif