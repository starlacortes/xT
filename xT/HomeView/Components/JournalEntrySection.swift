//
//  JournalEntrySection.swift
//  xT
//
//  Created by Cline on 5/25/2026.
//  Journal entry input component
//

import SwiftUI

// MARK: - Journal Entry Section
struct JournalEntrySection: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Entry")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
                .padding(.leading, 16)

            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .frame(minHeight: 150)
                .padding()
                .background(.regularMaterial)
                .cornerRadius(Theme.smallCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .stroke(Theme.borderColor, lineWidth: 1)
                )

            if text.isEmpty {
                Text("Write how you're feeling, if you want")
                    .foregroundColor(Theme.tertiaryTextColor)
                    .font(.caption)
                    .padding(.horizontal, 8)
            }
        }
    }
}
