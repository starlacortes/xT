//
//  AppIconManager.swift
//  xT
//
//  Owns the current app-icon choice (I4). `UIApplication` persists the
//  choice itself; this is the observable read model over it, so the picker
//  grid, the "update to match" row and the Settings gateway subtitle all see
//  one value and re-render when it changes.
//
//  Alternate icons are a home-screen feature; Mac Catalyst has no
//  `setAlternateIconName`, so the picker hides there (`isAvailable`).
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class AppIconManager {
    static let shared = AppIconManager()

    /// Whether alternate icons can be set on this platform.
    static var isAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        true
        #endif
    }

    private(set) var current: AppIconChoice = .primary

    init() {
        refresh()
    }

    /// Re-read the system's choice — the system is the source of truth,
    /// including when the icon was last set from somewhere other than the
    /// picker.
    func refresh() {
        guard Self.isAvailable else { return }
        current = AppIconChoice(alternateIconName: UIApplication.shared.alternateIconName)
    }

    /// Ask the system to switch. iOS confirms with its own alert on every
    /// change (I4: the app never switches silently and never fights that
    /// alert); the local value only moves in the completion, so the UI
    /// never runs ahead of the system.
    func apply(_ choice: AppIconChoice) {
        guard Self.isAvailable else { return }
        UIApplication.shared.setAlternateIconName(choice.assetName) { [weak self] error in
            if let error {
                print("[AppIcon] failed to set \(String(describing: choice.assetName)): \(error)")
            }
            Task { @MainActor in self?.refresh() }
        }
    }
}

// MARK: - Environment

@MainActor
struct AppIconManagerKey: @MainActor EnvironmentKey {
    // EnvironmentValues is MainActor-isolated, so this default is always read
    // on the main actor. A fresh manager is a safe fallback for previews that
    // don't inject one.
    static var defaultValue = AppIconManager()
}

extension EnvironmentValues {
    @MainActor
    var appIconManager: AppIconManager {
        get { self[AppIconManagerKey.self] }
        set { self[AppIconManagerKey.self] = newValue }
    }
}
