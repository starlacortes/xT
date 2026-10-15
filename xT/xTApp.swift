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

/// How to rebuild the model container mid-session.
enum CloudContainerRebuild {
    /// Rebuild on the existing store file with the given CloudKit backing.
    /// Safe when the store's history carries nothing sync-relevant (consent
    /// decline) or when the file is replaced at the next launch anyway
    /// (local-only reset).
    case cloudKit(Bool)
    /// Build a fresh CloudKit-backed store under a temporary file name.
    /// Used by "Turn On iCloud Sync?" — the post-reset store file carries
    /// local-only deletion history that would replay as tombstones against
    /// iCloud if CloudKit were attached to it, so a fresh file guarantees
    /// nothing replays.
    case freshCloudKit
}

/// Lets onboarding swap the model container in place (e.g. declining iCloud
/// after the profile step rebuilds the container as local-only).
struct CloudContainerRebuilderKey: EnvironmentKey {
    static let defaultValue: (CloudContainerRebuild) -> Void = { _ in }
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

    var rebuildCloudContainer: (CloudContainerRebuild) -> Void {
        get { self[CloudContainerRebuilderKey.self] }
        set { self[CloudContainerRebuilderKey.self] = newValue }
    }
}

@main
struct xTApp: App {

    // Container is always created in init(): CloudKit-backed unless the stored
    // preference is off. Onboarding can rebuild it in place (e.g. declining the
    // iCloud consent sheet after the profile step).
    @State private var appContainer: ModelContainer?

    init() {
        UserDefaults.standard.register(defaults: [
            "requireAuthentication": false,
            "autoLockTimeout": AutoLockTimeout.fallback.rawValue,
            "doseReminderEnabled": false,
            "doseReminderHour": NotificationManager.Defaults.doseHour,
            "doseReminderMinute": NotificationManager.Defaults.doseMinute,
            "journalReminderEnabled": false,
            "journalReminderHour": NotificationManager.Defaults.journalHour,
            "journalReminderMinute": NotificationManager.Defaults.journalMinute,
        ])

        // A "local only" reset queues a store-file wipe for the next launch —
        // deleting the files here is safe because no container is alive yet.
        if UserDefaults.standard.bool(forKey: CloudSyncService.pendingLocalStoreWipeKey) {
            Self.wipeLocalStoreFiles()
            UserDefaults.standard.set(false, forKey: CloudSyncService.pendingLocalStoreWipeKey)
        }

        // A mid-session "Turn On iCloud Sync?" swap builds the store under a
        // temporary name; promote it to the canonical one before any
        // container opens (safe — nothing has the files open in init).
        Self.promoteTurnOnStoreIfPresent()

        NotificationManager.shared.registerNotificationHandling()
        Task { await NotificationManager.shared.scheduleAllReminders() }

        // Tracks CloudKit import activity for the restore poll's adaptive window.
        CloudSyncService.installCloudKitEventObserverIfNeeded()
        // Keeps Home + Journal live when a CloudKit import lands outside a restore
        // poll's bounded window (H-D7).
        CloudSyncService.installRemoteChangeObserverIfNeeded()

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
        } else {
            // Truly first launch: start with a CloudKit-backed container so the
            // welcome step's restore link works immediately and onboarding
            // shows right away. The explicit iCloud consent now happens after
            // the profile step inside onboarding; declining rebuilds as
            // local-only via the rebuildCloudContainer environment closure.
            let container = Self.makeContainer(cloudKit: true)
            Self.wireManagers(container)
            _appContainer = State(initialValue: container)
        }

#if DEBUG
        // Sample-profile seeding (DEBUG only). Every branch above has already
        // built and wired a container by this point, so the flag alone is the
        // gate. The old guard also read `appContainer` — a `@State` property —
        // inside init, where reading State is undefined (it isn't installed
        // yet), so the seeding silently depended on that read happening to
        // return the initial value. The explicit saves mirror the Developer-
        // settings path (forceApply → save both contexts):
        // `persistUserPreferences` saves its own writes, but anything still
        // pending in the shared mainContext is committed here, so a process
        // death right after launch can't lose the freshly seeded persona.
        if DeveloperSettings.shared.sampleProfileEnabled {
            SpoofProfile.applyIfNeeded()
            MedicationManager.shared.saveContext()
            try? JournalManager.shared.modelContext?.save()
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
                        if newPhase == .active {
                            Task { await EntitlementManager.shared.refresh() }
                        }
                    }
                    .environment(\.modelContainer, container)
                    .environment(\.rebuildCloudContainer) { rebuild in
                        let container: ModelContainer
                        switch rebuild {
                        case .cloudKit(let useCloudKit):
                            container = Self.makeContainer(cloudKit: useCloudKit)
                        case .freshCloudKit:
                            // Clear any stale temp file first (no live
                            // container references it), then build the fresh
                            // CloudKit-backed store under the temp name.
                            Self.removeStoreFiles(baseName: Self.turnOnStoreBaseName)
                            container = Self.makeContainer(cloudKit: true, storeURL: Self.turnOnStoreURL())
                        }
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
        .environment(\.appIconManager, AppIconManager.shared)
        .environment(\.entitlementManager, EntitlementManager.shared)
    }

    // MARK: - Store file management

    /// File name of the store built mid-session by "Turn On iCloud Sync?".
    /// Promoted to the canonical name at the next launch.
    static let turnOnStoreBaseName = "xT.turnon.store"

    /// The temp store's file URL, or nil when Application Support is missing.
    static func turnOnStoreURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(turnOnStoreBaseName)
    }

    /// Deletes a store's files (main plus -shm/-wal siblings). Call only when
    /// no ModelContainer has them open — i.e. during init, or for a file no
    /// live container references.
    static func removeStoreFiles(baseName: String) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        for name in ["\(baseName)", "\(baseName)-shm", "\(baseName)-wal"] {
            let url = appSupport.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("[xTApp] wipe: failed to remove \(name): \(error)")
                }
            }
        }
    }

    /// Deletes the on-disk SwiftData store files — both the canonical store
    /// and any mid-session rebuild file (a reset must clear the temp store
    /// too, or a later launch would promote it and resurrect wiped data).
    /// Call only when no ModelContainer is alive — i.e. during init, before
    /// container creation.
    static func wipeLocalStoreFiles() {
        removeStoreFiles(baseName: "xT.store")
        removeStoreFiles(baseName: turnOnStoreBaseName)
    }

    /// If a mid-session rebuild left the store under the temporary name,
    /// promote it to the canonical one. Call only in init, before containers.
    static func promoteTurnOnStoreIfPresent() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fm = FileManager.default
        let tempBase = appSupport.appendingPathComponent(turnOnStoreBaseName)
        guard fm.fileExists(atPath: tempBase.path) else { return }
        removeStoreFiles(baseName: "xT.store")
        for suffix in ["", "-shm", "-wal"] {
            let src = appSupport.appendingPathComponent("\(turnOnStoreBaseName)\(suffix)")
            let dst = appSupport.appendingPathComponent("xT.store\(suffix)")
            guard fm.fileExists(atPath: src.path) else { continue }
            do {
                try fm.moveItem(at: src, to: dst)
            } catch {
                print("[xTApp] promote: failed to move \(suffix): \(error)")
            }
        }
    }

    // MARK: - Container factory

    static func makeContainer(cloudKit: Bool, storeURL: URL? = nil) -> ModelContainer {
        let schema = Schema([
            UserPreferences.self,
            DoseRecord.self,
            JournalEntry.self,
            BloodTestRecord.self,
            ScreeningRecord.self,
        ])
        let config: ModelConfiguration
        if let storeURL {
            // Explicit URL variant — used for the mid-session "Turn On"
            // rebuild, which must live under a temporary file name.
            config = ModelConfiguration(
                "xT",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKit ? .automatic : .none
            )
        } else {
            config = ModelConfiguration(
                "xT",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKit ? .automatic : .none
            )
        }
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
