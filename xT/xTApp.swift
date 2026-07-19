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

@MainActor
struct NotificationManagerKey: @MainActor EnvironmentKey {
    // Bridge to @MainActor singleton safely: EnvironmentValues is itself MainActor-isolated,
    // so this defaultValue is always accessed on the main actor with no race condition.
    static var defaultValue: NotificationManager {
        return .shared
    }
}

extension EnvironmentValues {
    @MainActor
    var notificationManager: NotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
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
}

@main
struct xTApp: App {
    
    // Configured container — shared across the app and injected into managers.
    // Uses CloudKit for seamless iCloud sync across devices.
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            UserPreferences.self,
            DoseRecord.self,
            JournalEntry.self,
            BloodTestRecord.self,
            ScreeningRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "xT",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("[xTApp] Failed to create ModelContainer: \(error)")
            print("[xTApp] Deleting corrupted store and retrying...")
            
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = supportDir.appendingPathComponent("default.store")
            
            do {
                try FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathComponent("sqlite-shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathComponent("sqlite-wal"))
            } catch {
                print("[xTApp] Could not remove store: \(error)")
            }
            
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
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

#if DEBUG
        // Developer Area (Settings → Developer): the "Jan" sample profile is
        // strictly opt-in. When the Sample toggle is enabled, Jan was already
        // applied before the enabling launch quit; this guard only re-seeds if
        // that apply was interrupted. The user's real data is preserved by
        // ProfileSnapshot and restored when the toggle turns off.
        if DeveloperSettings.shared.sampleProfileEnabled {
            SpoofProfile.applyIfNeeded()
        }
#else
        // A RELEASE install over a DEBUG build must never inherit developer
        // state (stale dev.* flags or snapshot files) — scrub it.
        DeveloperSettings.scrubStaleReleaseState()
#endif
    }
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, newPhase in
                    AuthenticationManager.shared.handleScenePhase(newPhase)
                }
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
