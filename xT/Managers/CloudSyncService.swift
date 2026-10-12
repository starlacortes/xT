//
//  CloudSyncService.swift
//  xT
//
//  Shared "Restore from iCloud" and "Sync Now" flows used by onboarding
//  and Settings. The managers are @MainActor singletons, so this service
//  is @MainActor too and owns no UI state — callers track their own
//  progress/alert state around these calls.
//

import Foundation
import CoreData
import SwiftData

/// Coordinates the restore/sync flows against the CloudKit-backed SwiftData
/// store.
///
/// Per Apple (TN3164, "Syncing model data across a person's devices"): there
/// is NO API to force SwiftData/CloudKit sync timing. Saving to the store
/// requests an export; imports happen when the system schedules them. Both
/// flows therefore work the same way: flush pending local changes, give the
/// system a bounded window to import, and refresh the managers' in-memory
/// caches from the store on every pass.
@MainActor
enum CloudSyncService {

    static let pollInterval: Duration = .seconds(1.5)
    /// Restore always waits at least this long before it can give up on an
    /// empty store — covers the gap before a cold-start import's first event.
    static let restoreMinAttempts = 10
    /// Restore extends to this cap while CloudKit import activity is recent.
    static let restoreMaxAttempts = 40
    /// Import activity older than this no longer extends the restore window.
    static let importActivityWindow: Duration = .seconds(10)
    static let syncMaxAttempts = 3       // sync is a warm flush, short window
    /// Defaults flag queuing a store-file wipe at the next launch, set by the
    /// Settings "This Device Only" reset so no deletion history survives to
    /// tombstone the iCloud copy when sync is re-enabled.
    static let pendingLocalStoreWipeKey = "icloudPendingLocalStoreWipe"
    /// Defaults flag set when an onboarding restore succeeds but the restored
    /// profile name is unreadable (encrypted with a device-local key). ContentView
    /// consumes it once Home appears and asks the user to set a name.
    static let profileNamePromptPendingKey = "icloudProfileNamePromptPending"

    private static var hasInstalledEventObserver = false

    /// Registers the CloudKit import-activity observer once per process.
    /// Safe to call repeatedly. Installed at launch (not on first restore)
    /// so it also records imports that start when the container comes up,
    /// before the user ever taps Restore.
    static func installCloudKitEventObserverIfNeeded() {
        guard !hasInstalledEventObserver else { return }
        hasInstalledEventObserver = true
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            CloudKitImportActivity.shared.noteEvent(event)
        }
    }

    private static var hasInstalledRemoteChangeObserver = false

    /// Registers a store-remote-change observer once per process (H-D7).
    ///
    /// The restore poll reloads the caches only during its bounded window; without
    /// this, a CloudKit import that lands while the user is sitting on Home never moves
    /// the curve or the journal until the next manual sync. `NSPersistentStoreRemoteChange`
    /// fires whenever another process or the CloudKit mirroring layer writes to the
    /// store, so it covers exactly that gap. Reloads run on the main actor because the
    /// managers are main-actor singletons bound to the main context.
    static func installRemoteChangeObserverIfNeeded() {
        guard !hasInstalledRemoteChangeObserver else { return }
        hasInstalledRemoteChangeObserver = true
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MedicationManager.shared.reloadAllFromStore()
                JournalManager.shared.loadEntries()
                ProfileManager.shared.loadProfile()
            }
        }
    }

    /// Row counts of the local store — shows whether a CloudKit import
    /// actually delivered anything (TEMP-DEBUG for the restore diagnosis).
    private static func storeCensus() -> (userPrefs: Int, doses: Int) {
        guard let context = MedicationManager.shared.modelContext else { return (-1, -1) }
        let userPrefs = (try? context.fetchCount(FetchDescriptor<UserPreferences>())) ?? -1
        let doses = (try? context.fetchCount(FetchDescriptor<DoseRecord>())) ?? -1
        return (userPrefs, doses)
    }

    /// Saves pending changes on the shared main context (this requests a
    /// CloudKit export) and refreshes all three managers' caches.
    static func flushAndReload() {
        do {
            try MedicationManager.shared.modelContext?.save()
            print("[CloudSync] flush: context save ok")
        } catch {
            print("[CloudSync] flush: context save FAILED: \(error)")
        }
        MedicationManager.shared.reloadAllFromStore()
        JournalManager.shared.loadEntries()
        ProfileManager.shared.loadProfile()
    }

    /// Bounded poll: reload medication state until CloudKit-imported data
    /// appears in the store, then refresh Journal + Profile. Returns whether
    /// medication data is present.
    static func restoreFromiCloud() async -> Bool {
        print("[CloudSync] restoreFromiCloud start (min \(restoreMinAttempts) / max \(restoreMaxAttempts) polls)")
        var restored = false

        // CloudKit's initial sync is asynchronous and can take longer than a
        // fixed delay on a cold start, so poll the local store rather than
        // waiting a single hard-coded duration. Past the minimum window the
        // poll only keeps going while import events are still arriving, so a
        // genuinely empty iCloud doesn't make the user sit through the full
        // wait.
        for attempt in 0..<restoreMaxAttempts {
            try? await Task.sleep(for: pollInterval)
            MedicationManager.shared.reloadAllFromStore()
            let hasData = MedicationManager.shared.selectedMedication != nil
            let census = storeCensus()
            print("[CloudSync] restore poll \(attempt + 1)/\(restoreMaxAttempts): selectedMedication=\(hasData) userPrefs=\(census.userPrefs) doses=\(census.doses)")
            if hasData {
                restored = true
                break
            }
            if attempt + 1 >= restoreMinAttempts,
               !CloudKitImportActivity.shared.isImportActive(within: importActivityWindow) {
                print("[CloudSync] restore: no recent import activity, giving up at poll \(attempt + 1)")
                break
            }
        }

        // Refresh the remaining managers' in-memory caches so journal entries
        // and profile reflect the CloudKit-synced store too.
        JournalManager.shared.loadEntries()
        ProfileManager.shared.loadProfile()
        print("[CloudSync] restoreFromiCloud -> \(restored)")
        return restored
    }

    /// "Sync Now": flush pending changes, then a short bounded poll so any
    /// in-flight import gets a window. Returns false only when no model
    /// context exists (should not happen — the container is built at launch).
    static func syncNow() async -> Bool {
        print("[CloudSync] syncNow start")
        guard MedicationManager.shared.modelContext != nil else {
            print("[CloudSync] syncNow -> false (no modelContext)")
            return false
        }
        flushAndReload()
        for attempt in 0..<syncMaxAttempts {
            try? await Task.sleep(for: pollInterval)
            MedicationManager.shared.reloadAllFromStore()
            JournalManager.shared.loadEntries()
            ProfileManager.shared.loadProfile()
            print("[CloudSync] syncNow poll \(attempt + 1)/\(syncMaxAttempts) done")
        }
        print("[CloudSync] syncNow -> true")
        return true
    }
}

// MARK: - Import activity tracking

/// Records recent CloudKit import activity so the restore poll can tell an
/// import that's still running from a store that's genuinely empty.
///
/// `NSPersistentCloudKitContainer` only posts `eventChangedNotification`
/// when an import round *finishes*, so this is a proxy, not a guarantee:
/// silence can also mean one long round with no completed events yet. The
/// restore poll's minimum window covers that gap; this tracker covers
/// multi-round imports, which emit events steadily while they run.
final class CloudKitImportActivity: @unchecked Sendable {
    static let shared = CloudKitImportActivity()

    private let lock = NSLock()
    private var lastImportEventAt: ContinuousClock.Instant?

    private init() {}

    func noteEvent(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.type == .import || event.type == .setup else { return }
        lock.lock()
        lastImportEventAt = ContinuousClock.now
        lock.unlock()
    }

    func isImportActive(within window: Duration) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let lastImportEventAt else { return false }
        return ContinuousClock.now - lastImportEventAt < window
    }
}
