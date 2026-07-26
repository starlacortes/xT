//
//  SpoofPreview.swift
//  xT
//
//  DEBUG-only #Preview wrapper that seeds the singleton managers with
//  Jan's rich test-profile data so Previews render meaningful content
//  instead of empty-state placeholders.
//

#if DEBUG

import SwiftUI

/// Wraps preview content and seeds all managers with SpoofProfile (Jan) data.
///
/// Usage:
/// ```swift
/// #Preview {
///     SpoofPreview {
///         HomeView()
///     }
/// }
/// ```
struct SpoofPreview<Content: View>: View {
    @State private var seeded = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .task {
                guard !seeded else { return }
                seeded = true
                SpoofProfile.forceApply()
            }
    }
}

#endif
