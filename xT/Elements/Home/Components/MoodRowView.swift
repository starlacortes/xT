//
//  MoodRowView.swift
//  xT
//
//  Read-only mood row showing today's journal mood or "Add mood" placeholder.
//  Tap opens JournalComposerView. Adapted from JournalCardView summary layout.
//

import SwiftUI

struct MoodRowView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingJournalComposer = false
    
    private var todayEntry: JournalEntry? {
        guard let last = journalManager.lastEntry,
              Calendar.current.isDateInToday(last.date) else { return nil }
        return last
    }
    
    private var moodEmoji: String {
        guard let mood = todayEntry?.mood else { return "🌸" }
        switch mood {
        case .happy:    return "😊"
        case .calm:     return "😌"
        case .neutral:  return "😐"
        case .tired:    return "😴"
        case .anxious:  return "😰"
        case .sad:      return "😢"
        case .energetic: return "⚡️"
        }
    }
    
    var body: some View {
        Button {
            showingJournalComposer = true
        } label: {
            HStack(spacing: 10) {
                Text(moodEmoji)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(todayEntry?.mood.rawValue.capitalized ?? "Add mood")
                        .font(Theme.Fonts.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    
                    Text(todayEntry?.previewText ?? "Tap to journal")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }
}

#if DEBUG
#Preview {
    MoodRowView()
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Theme.Colors.glassTint)
}
#endif