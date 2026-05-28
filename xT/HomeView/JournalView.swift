//
//  JournalView.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Reimagined journaling interface with modern design and enhanced functionality
//

import SwiftUI

enum JournalTab: String, CaseIterable {
    case log = "Log"
    case history = "History"
}

struct JournalView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var journalEntry: String = ""
    @State private var showingSaveConfirmation = false
    @State private var selectedMood: Mood = .neutral

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Journal grid view
                    JournalHistoryViewContent(journalEntry: $journalEntry, selectedMood: $selectedMood)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemBackground))
            .alert("Entry Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your journal entry has been saved successfully.")
            }
        }
    }
}

// MARK: - Journal Log View Content
struct JournalLogViewContent: View {
    @Binding var journalEntry: String
    @Binding var selectedMood: Mood
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // Date header
            Text(Date.now, style: .date)
                .font(.title2.bold())
                .padding(.top)
                

            // Mood tracker section with enhanced design
            MoodTrackerSection(selectedMood: $selectedMood)
                .asGlassCard()
                .padding(4)

            // Journal entry section
            JournalEntrySection(text: $journalEntry)
                .asGlassCard()
                .padding(4)

            // Symptom tracker section
            SymptomTrackerSection()
                .asGlassCard()
                .padding(4)

            // Health insights section (connects to existing medication data)
            if medicationManager.isFullyConfigured,
               let currentLevel = medicationManager.estimatedRecentLevels().last?.value {
                HealthInsightsView(level: currentLevel)
                    .asGlassCard()
            }
        }


    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        JournalView()
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
