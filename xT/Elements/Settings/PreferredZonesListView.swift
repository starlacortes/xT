//
//  PreferredZonesListView.swift
//  xT
//
//  Standalone list of medication + route combinations, each linking to the
//  per-combo PreferredZonesEditorView. Extracted from DoseScheduleSettingsView
//  so it can be surfaced from both the Dose schedule sheet and the main
//  Settings "Body & zones" section without duplicating persistence logic.
//

import SwiftUI

struct PreferredZonesListView: View {
    private let userPreferredZonesKey = "mm.userPreferredZones"
    @State private var userPreferredZones: [String: [String]]

    init() {
        if let data = UserDefaults.standard.data(forKey: "mm.userPreferredZones"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            _userPreferredZones = State(initialValue: decoded)
        } else {
            _userPreferredZones = State(initialValue: [:])
        }
    }

    private var medicationRouteCombos: [(medication: String, routeClass: RouteClass)] {
        let medications = ["Estrogen", "Testosterone", "Progesterone"]
        let routes = RouteClass.allCases.filter { $0 != .oral }
        var combos: [(String, RouteClass)] = []
        for med in medications {
            for route in routes {
                combos.append((med, route))
            }
        }
        return combos
    }

    var body: some View {
        List {
            ForEach(Array(medicationRouteCombos.enumerated()), id: \.offset) { _, combo in
                let count = preferredZonesCount(
                    medication: combo.medication,
                    routeClass: combo.routeClass
                )
                NavigationLink(destination: PreferredZonesEditorView(
                    medication: combo.medication,
                    routeClass: combo.routeClass,
                    onSave: { zones in
                        let key = "\(combo.medication)|\(combo.routeClass.rawValue)"
                        userPreferredZones[key] = zones
                        if let data = try? JSONEncoder().encode(userPreferredZones) {
                            UserDefaults.standard.set(data, forKey: userPreferredZonesKey)
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: combo.routeClass.iconName)
                            .font(.title3)
                            .foregroundStyle(combo.routeClass.tintColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(combo.medication) — \(combo.routeClass.displayName)")
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(.primary)
                            Text("^[\(count) zone](inflect: true)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Preferred Zones")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preferredZonesCount(medication: String, routeClass: RouteClass) -> Int {
        let key = "\(medication)|\(routeClass.rawValue)"
        if let userZones = userPreferredZones[key], !userZones.isEmpty {
            return userZones.count
        }
        return ZoneCentroidStore.preferredZones(medication: medication, routeClass: routeClass).count
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PreferredZonesListView()
    }
}
#endif
