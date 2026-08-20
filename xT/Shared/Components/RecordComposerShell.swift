//
//  RecordComposerShell.swift
//  xT
//
//  Shared chrome for the add/edit record sheets (`BloodTestComposerView`,
//  `ScreeningComposerView`): NavigationStack wrapping a Form, an inline title,
//  and Cancel/Save toolbar items. `title` is passed in whole (not assembled
//  from an entity name) so the existing "Add/Edit <entity>" localization keys
//  keep their spot in the string catalog.
//

import SwiftUI

struct RecordComposerShell<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    var canSave: Bool = true
    let onSave: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            Form {
                content()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(!canSave)
                }
            }
        }
    }
}
