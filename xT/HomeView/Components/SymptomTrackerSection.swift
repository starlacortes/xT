//
//  SymptomTrackerSection.swift
//  xT
//
//  Created by Cline on 5/25/2026.
//  Symptom tracking component for journaling
//

import SwiftUI

// MARK: - Symptom Tracker Section
struct SymptomTrackerSection: View {
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Symptoms")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
                .padding(.leading, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(80))], spacing: 12) {
                    ForEach(Symptom.commonSymptoms) { symptom in
                        SymptomButton(symptom: symptom)
                            .frame(width: 100) // Fixed width for consistency
                    }
                }
                .padding(.horizontal, 8) // Ensure horizontal padding within scroll view
            }
        }
    }
}

// MARK: - Individual Symptom Button
struct SymptomButton: View {
    @Environment(\.journalManager) private var journalManager
    let symptom: Symptom

    var isSelected: Bool {
        journalManager.currentSymptoms.contains { $0.id == symptom.id }
    }

    var body: some View {
        Button(action: {
            toggleSymptom()
        }) {
            VStack(spacing: 8) {
                Image(systemName: symptom.icon)
                    .font(.title3)
                Text(symptom.name)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ?
                AnyView(LinearGradient(colors: [Theme.accentColor, .purple], startPoint: .top, endPoint: .bottom)) :
                AnyView(Theme.tertiaryTextColor.opacity(0.1))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
        }
        .buttonStyle(.borderedProminent)
    }

    private func toggleSymptom() {
        var updatedSymptoms = journalManager.currentSymptoms
        if isSelected {
            updatedSymptoms = updatedSymptoms.filter { $0.id != symptom.id }
        } else {
            updatedSymptoms.insert(symptom)
        }
        journalManager.updateCurrentSymptoms(updatedSymptoms)
    }
}
