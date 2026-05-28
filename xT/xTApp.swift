//
//  xTApp.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//

import SwiftUI
import SwiftData

// MARK: - Environment Extensions
struct SecurityManagerKey: EnvironmentKey {
    static let defaultValue = SecurityManager.shared
}

extension EnvironmentValues {
    var securityManager: SecurityManager {
        get { self[SecurityManagerKey.self] }
        set { self[SecurityManagerKey.self] = newValue }
    }
}

@main
struct xTApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserPreferences.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.medicationManager, MedicationManager.shared)
                .environment(\.profileManager, ProfileManager.shared)
                .environment(\.journalManager, JournalManager.shared)
                .environment(\.authenticationManager, AuthenticationManager.shared)
                .environment(\.securityManager, SecurityManager.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}