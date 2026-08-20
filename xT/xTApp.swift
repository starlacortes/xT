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

    // Container is created either in init() (when sync preference is already known)
    // or after the user makes their iCloud choice in CloudSyncChoiceView.
    @State private var appContainer: ModelContainer?

    init() {
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

        NotificationManager.shared.registerNotificationHandling()
        Task { await NotificationManager.shared.scheduleAllReminders() }

        let defaults = UserDefaults.standard
        let syncPreferenceIsSet = defaults.object(forKey: "icloudSyncEnabled") != nil
        let hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if syncPreferenceIsSet {
            // Normal launch: create container using the stored preference.
            let useCloudKit = defaults.bool(forKey: "icloudSyncEnabled")
            let container = Self.makeContainer(cloudKit: useCloudKit)
            Self.wireManagers(container)
            _appContainer = State(initialValue: container)
        } else if hasCompletedOnboarding {
            // Existing user updating from a build that predates the iCloud choice —
            // CloudKit was always on before, so keep that behaviour and save the preference.
            defaults.set(true, forKey: "icloudSyncEnabled")
            let container = Self.makeContainer(cloudKit: true)
            Self.wireManagers(container)
            _appContainer = State(initialValue: container)
        }
        // else: truly first launch — container is deferred until CloudSyncChoiceView
        // calls back with the user's choice.

#if DEBUG
        if DeveloperSettings.shared.sampleProfileEnabled && appContainer != nil {
            SpoofProfile.applyIfNeeded()
        }
#else
        DeveloperSettings.scrubStaleReleaseState()
#endif
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let container = appContainer {
                ContentView()
                    .onChange(of: scenePhase) { _, newPhase in
                        AuthenticationManager.shared.handleScenePhase(newPhase)
                    }
                    .environment(\.modelContainer, container)
            } else {
                CloudSyncChoiceView { useCloudKit in
                    UserDefaults.standard.set(useCloudKit, forKey: "icloudSyncEnabled")
                    let container = Self.makeContainer(cloudKit: useCloudKit)
                    Self.wireManagers(container)
                    appContainer = container
                }
            }
        }
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.notificationManager, NotificationManager.shared)
        .environment(\.authenticationManager, AuthenticationManager.shared)
        .environment(\.securityManager, SecurityManager.shared)
        .environment(\.themeManager, ThemeManager.shared)
    }

    // MARK: - Container factory

    static func makeContainer(cloudKit: Bool) -> ModelContainer {
        let schema = Schema([
            UserPreferences.self,
            DoseRecord.self,
            JournalEntry.self,
            BloodTestRecord.self,
            ScreeningRecord.self,
        ])
        let config = ModelConfiguration(
            "xT",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
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
                // An in-memory container fails only if the schema definition itself is
                // invalid — a build-time programmer error with no runtime recovery path.
                fatalError("Could not create in-memory ModelContainer from schema: \(error)")
            }
        }
    }

    // MARK: - Manager wiring

    @MainActor
    static func wireManagers(_ container: ModelContainer) {
        MedicationManager.shared.modelContext = container.mainContext
        JournalManager.shared.modelContext = container.mainContext
        ProfileManager.shared.setModelContext(container.mainContext)
    }
}
