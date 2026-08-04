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
            // Leave the on-disk store untouched so user data is never actively destroyed.
            // A transient error gets another chance on the next launch; a genuine schema
            // conflict will be resolved by CloudKit sync rather than a local wipe.
            print("[xTApp] Failed to create ModelContainer: \(error)")
            print("[xTApp] Falling back to in-memory store — data will not persist this session.")

            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                // An in-memory container fails only if the schema itself is invalid —
                // a build-time programmer error — so there is nothing to degrade to.
                fatalError("Could not create in-memory ModelContainer from schema: \(error)")
            }
        }
    }()

    init() {
        // Wire the container's context into managers.
        MedicationManager.shared.modelContext = Self.modelContainer.mainContext
        JournalManager.shared.modelContext = Self.modelContainer.mainContext

        // Register app-wide UserDefaults defaults. Keys that are read but not yet
        // written would otherwise log "found no value for key …" on every read and
        // fall back silently; registering them keeps reads cheap and quiet.
        UserDefaults.standard.register(defaults: [
            "requireAuthentication": false,
            "autoLockTimeout": AutoLockTimeout.fallback.rawValue,
            "doseReminderEnabled": false,
            "doseReminderHour": 9,
            "doseReminderMinute": 0,
            "journalReminderEnabled": false,
            "journalReminderHour": 20,
            "journalReminderMinute": 0,
        ])

        // Install the notification delegate + categories, then schedule pending
        // reminders. Scheduling is gated on authorization, so this is safe to call
        // before the user has granted permission — it will no-op until granted.
        NotificationManager.shared.registerNotificationHandling()
        Task { await NotificationManager.shared.scheduleAllReminders() }

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
