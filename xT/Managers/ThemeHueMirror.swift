//
//  ThemeHueMirror.swift
//  xT
//
//  The iCloud mirror of the seed hue (X6): a second device should look like
//  the first, and the hue dial is the one piece of theme state a person sets
//  by hand. It travels through NSUbiquitousKeyValueStore — not SwiftData /
//  CloudKit — because the hue is a cosmetic preference, not health data, and
//  the ubiquity-kvstore entitlement already exists.
//
//  Semantics (last-writer-wins, matching KVS itself):
//   * commits write through to the mirror only while sync is on;
//   * at launch, and on an external-change notification, a differing mirror
//     value is adopted — so the newest dial position wins, and a fresh
//     install restores its hue from iCloud;
//   * the one case a mirror value can overwrite a local choice is a
//     deliberate divergence (hue changed while sync was off): per-device
//     themes aren't supported while syncing, and KVS has no vector clocks.
//

import Foundation

/// The slice of key-value mirroring ThemeManager needs — an abstraction that
/// exists so the mirror logic can be unit-tested without iCloud.
protocol SeedHueMirrorStore: AnyObject {
    /// Store `hue` under `key`. Implementations must round-trip full
    /// Double precision.
    func setHue(_ hue: Double, forKey key: String)
    /// The stored hue, or nil when the key is absent or unparseable.
    func hue(forKey key: String) -> Double?
    /// Remove the key entirely.
    func removeHue(forKey key: String)
}

/// NSUbiquitousKeyValueStore-backed mirror. The hue is stored as a string so
/// *presence* is detectable — `double(forKey:)` can't tell "missing" from a
/// hue of 0°, and adopting a phantom 0° would silently repaint the app.
final class UbiquitySeedHueStore: SeedHueMirrorStore {
    private let store: NSUbiquitousKeyValueStore

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        // Documented launch-time nudge: pulls the merged store forward so the
        // first read isn't racing the daemon's first download.
        store.synchronize()
    }

    func setHue(_ hue: Double, forKey key: String) {
        store.set(String(hue), forKey: key)
    }

    func hue(forKey key: String) -> Double? {
        store.string(forKey: key).flatMap { Double($0) }
    }

    func removeHue(forKey key: String) {
        store.removeObject(forKey: key)
    }
}

// MARK: - ThemeManager mirror logic (X6)

extension ThemeManager {

    /// KVS key for the mirrored seed hue. Distinct from the local key so a
    /// synced value is easy to tell from a local one when debugging.
    static let syncedSeedHueKey = "theme.seedHue.icloud"

    /// Hue values this far apart are the same position, not a change —
    /// guards against churn from string round-trips and float dust.
    static let hueAdoptionEpsilon = 0.25

    /// The onboarding convention: a missing flag is on (a fresh install's
    /// container is CloudKit-backed from launch), and only an explicit
    /// opt-out blocks syncing. The mirror follows the same rule.
    var isCloudSyncEnabled: Bool {
        defaults.object(forKey: "icloudSyncEnabled") == nil
            || defaults.bool(forKey: "icloudSyncEnabled")
    }

    /// Adopt the mirrored hue when sync is on and it differs. Called at
    /// launch and on KVS external-change notifications.
    func adoptSyncedSeedHue() {
        guard isCloudSyncEnabled,
              let mirrored = hueMirror.hue(forKey: Self.syncedSeedHueKey),
              mirrored.isFinite,
              mirrored >= 0, mirrored < 360,
              abs(mirrored - seedHue) > Self.hueAdoptionEpsilon else { return }

        seedHue = mirrored
        defaults.set(mirrored, forKey: Keys.seedHue)
    }

    /// Write the committed hue through to the mirror. Sync-off commits leave
    /// the mirror alone — other devices keep their value, this one keeps its
    /// local choice.
    func mirrorSeedHue() {
        guard isCloudSyncEnabled else { return }
        hueMirror.setHue(seedHue, forKey: Self.syncedSeedHueKey)
    }

    /// Removes the mirrored hue. The "This Device and iCloud" reset calls
    /// this so a deliberately wiped hue can't come back from the cloud at
    /// the next launch. The local-only reset does NOT: its iCloud copy
    /// survives by design, and the hue returning with it is restoration,
    /// not a leak.
    static func clearSyncedSeedHue(using store: SeedHueMirrorStore = UbiquitySeedHueStore()) {
        store.removeHue(forKey: syncedSeedHueKey)
    }
}
