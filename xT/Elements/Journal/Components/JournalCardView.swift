//
//  JournalCardView.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Journal card component
//

import SwiftUI

struct JournalCardView: View {
    let entry: JournalEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Summary header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Text("🌸")
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's journal")
                            .font(Theme.Fonts.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.accent)

                        if !entry.text.isEmpty {
                            Text(entry.previewText)
                                .font(Theme.Fonts.footnote)
                                .foregroundStyle(Theme.Colors.accent.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.accent.opacity(0.5))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.Colors.Bloom.skin.surface.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }
            .buttonStyle(.plain)

            // Expanded content (conditionally shown)
            if isExpanded {
                NavigationLink(destination: JournalView()) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !entry.text.isEmpty {
                            Text(entry.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.top, 8)
                        }

                        HStack {
                            Spacer()
                            Text("View full entry")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.accent)
                                .padding(.trailing, 14)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

#Preview {
    JournalCardView(entry: JournalEntry(
        id: UUID(),
        date: Date(),
        mood: .happy,
        text: "This is a sample journal entry for preview purposes.",
        symptoms: [Symptom(name: "headache", icon: "brain.head.profile"), Symptom(name: "fatigue", icon: "bed.double")]
    ))
}
