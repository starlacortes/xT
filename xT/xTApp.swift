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

struct ModelContainerKey: EnvironmentKey {
    static let defaultValue: ModelContainer? = nil
}

struct NotificationManagerKey: EnvironmentKey {
    // Bridge to @MainActor singleton safely: EnvironmentValues is itself MainActor-isolated,
    // so this defaultValue is always accessed on the main actor with no race condition.
    static var defaultValue: NotificationManager {
        return .shared
    }
}

extension EnvironmentValues {
    var securityManager: SecurityManager {
        get { self[SecurityManagerKey.self] }
        set { self[SecurityManagerKey.self] = newValue }
    }
    
    var modelContainer: ModelContainer? {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }

    var notificationManager: NotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
    }
}

@main
struct xTApp: App {
    
    // Configured container — shared across the app and injected into managers.
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            UserPreferences.self,
            DoseRecord.self,
            JournalEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Wire the container's context into managers.
        MedicationManager.shared.modelContext = Self.modelContainer.mainContext
        JournalManager.shared.modelContext = Self.modelContainer.mainContext
        NotificationManager.shared.modelContext = Self.modelContainer.mainContext

        // Set up notification categories and schedule any pending reminders.
        NotificationManager.shared.setupNotificationCategories()
        NotificationManager.shared.scheduleAllReminders()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(\.modelContainer, Self.modelContainer)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.notificationManager, NotificationManager.shared)
        .environment(\.authenticationManager, AuthenticationManager.shared)
        .environment(\.securityManager, SecurityManager.shared)
    }
}
