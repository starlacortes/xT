//
//  AppRouter.swift
//  xT
//
//  The app-wide navigation router (element N2). It holds the selected tab and the
//  one-shot intents that a notification — or an in-app affordance — can raise:
//  presenting the record-dose sheet, or jumping the Journal to its newest entry.
//
//  `ContentView` translates `NotificationManager.pendingRoute` into these fields
//  *after* the lock screen clears, so a reminder tapped on a locked phone lands on
//  the right screen only once the user is in.
//

import SwiftUI

/// The four root tabs, in their shipping order. The raw value backs the iOS 26
/// `Tab(value:)` selection binding.
enum AppTab: String, Hashable, CaseIterable {
    case home
    case journal
    case time
    case settings
}

/// App-wide navigation state. Observed by `MainTabView` (selection), `HomeView`
/// (record-dose presentation) and, later, the Journal week strip (scroll-to-top).
@MainActor
@Observable
final class AppRouter {
    /// The selected root tab.
    var tab: AppTab = .home

    /// One-shot: Home should present `QuickDoseSheet`. Home flips it back to `false`
    /// when it hands the request to the sheet's `isPresented` binding.
    var presentRecordDose = false

    /// One-shot: the Journal should scroll to its newest entry. Consumed by the
    /// Journal week strip when that lands (J-tier); harmless until then.
    var journalScrollToTop = false
}

// MARK: - Environment

@MainActor
struct AppRouterKey: @MainActor EnvironmentKey {
    // EnvironmentValues is MainActor-isolated, so this default is always read on the
    // main actor. A fresh router is a safe fallback for previews that don't inject one.
    static var defaultValue = AppRouter()
}

extension EnvironmentValues {
    @MainActor
    var appRouter: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
