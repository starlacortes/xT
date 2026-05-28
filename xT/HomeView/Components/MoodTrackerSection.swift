//
//  MoodTrackerSection.swift
//  xT
//
//  Created by Cline on 5/25/2026.
//  Mood tracking component for journaling
//
//
import SwiftUI

// MARK: - Mood Tracker Section
struct MoodTrackerSection: View {
    @Binding var selectedMood: Mood
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        VStack( spacing: 12) {
            Text("How are you feeling today?")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
                .padding(.leading, 16)
            

            HStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button(action: {
                        selectedMood = mood
                    }) {
                        VStack {
                            Image(systemName: mood.icon)
                                .font(.title2)
                            Text(mood.rawValue)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(selectedMood == mood ? Theme.accentColor : Theme.tertiaryTextColor.opacity(0.2))
                        .clipShape(Circle())
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
