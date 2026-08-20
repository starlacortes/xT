//
//  HistoryListView.swift
//  xT
//
//  Generic scaffold for the record-history lists (blood tests, screenings,
//  doses): grouped sections, a swipe-to-delete flow with confirmation alert,
//  an optional swipe-to-edit action, an optional "+" composer sheet, and an
//  empty-state ContentUnavailableView. The three hand-written copies had
//  already drifted (one forgot the sort, another the empty state).
//

import SwiftUI

/// What the "+" button or the edit swipe should present.
enum ComposerMode<Item> {
    case add, edit(Item)
}

struct HistoryListView<Item: Identifiable, RowContent: View, ComposerContent: View>: View {
    let title: String
    let emptyTitle: String
    let emptyIcon: String
    let emptyDescription: String
    let groups: [(title: String, items: [Item])]
    let deleteAlertTitle: String
    let deleteMessage: (Item) -> String
    let onDelete: (Item) -> Void

    /// Optional content pinned above the groups (e.g. the labs chart).
    var topContent: AnyView? = nil
    /// Label for the "+" toolbar button; nil hides it (no composer).
    var addLabel: String? = nil
    var editLabel: String = "Edit"
    var editVisible: (Item) -> Bool = { _ in true }
    /// Custom edit action. When nil (and a composer is provided), the edit swipe
    /// opens the composer in `.edit(item)` mode.
    var onEdit: ((Item) -> Void)? = nil

    @ViewBuilder var row: (Item) -> RowContent
    @ViewBuilder var composer: (ComposerMode<Item>) -> ComposerContent

    @State private var composerMode: ComposerMode<Item>?
    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            if let topContent { topContent }

            if groups.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
            }

            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items) { item in
                        row(item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                if editVisible(item) {
                                    Button(editLabel) {
                                        if let onEdit { onEdit(item) } else { composerMode = .edit(item) }
                                    }
                                    .tint(Theme.Colors.accentSecondary)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            if let addLabel {
                ToolbarItem(placement: .primaryAction) {
                    Button { composerMode = .add } label: {
                        Label(addLabel, systemImage: "plus")
                    }
                }
            }
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteConfirmation, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                onDelete(item)
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: { item in
            Text(deleteMessage(item))
        }
        .sheet(isPresented: Binding(
            get: { composerMode != nil },
            set: { isPresented in if !isPresented { composerMode = nil } }
        )) {
            if let composerMode {
                composer(composerMode)
            }
        }
    }
}
