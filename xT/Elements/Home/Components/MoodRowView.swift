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
    
    private var moodGlyphName: String {
        todayEntry?.mood.icon ?? "square.and.pencil"
    }

    private var moodGlyphColor: Color {
        guard let mood = todayEntry?.mood else { return .secondary }
        return JournalTheme.palette(for: mood).accent
    }
    
    var body: some View {
        Button {
            showingJournalComposer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: moodGlyphName)
                    .font(.system(size: 18))
                    .foregroundStyle(moodGlyphColor)
                
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