//
//  SeedHueMirrorTests.swift
//  xTTests
//
//  X6: the seed hue mirrors to iCloud KVS while sync is on, and mirrored
//  values are adopted so a second device looks like the first.
//

import Testing
import Foundation
@testable import xT

@MainActor
struct SeedHueMirrorTests {

    /// In-memory KVS stand-in.
    private final class MirrorStore: SeedHueMirrorStore {
        var values: [String: Double] = [:]

        func setHue(_ hue: Double, forKey key: String) { values[key] = hue }
        func hue(forKey key: String) -> Double? { values[key] }
        func removeHue(forKey key: String) { values.removeValue(forKey: key) }
    }

    /// An isolated, empty defaults suite per test. With no stored
    /// "icloudSyncEnabled" the sync convention reads as *on* — exactly the
    /// fresh-install case the adoption tests rely on.
    private func makeDefaults() -> UserDefaults {
        let name = "SeedHueMirrorTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test("A committed hue mirrors to iCloud while sync is on")
    func commitMirrorsWhileSyncOn() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "icloudSyncEnabled")
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        manager.seedHue = 200
        manager.commitSeedHue()

        #expect(store.hue(forKey: ThemeManager.syncedSeedHueKey) == 200)
        #expect(defaults.object(forKey: ThemeManager.Keys.seedHue) as? Double == 200)
    }

    @Test("A sync-off commit leaves the mirror untouched")
    func syncOffCommitDoesNotMirror() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "icloudSyncEnabled")
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        manager.seedHue = 200
        manager.commitSeedHue()

        #expect(store.hue(forKey: ThemeManager.syncedSeedHueKey) == nil)
        #expect(defaults.object(forKey: ThemeManager.Keys.seedHue) as? Double == 200)
    }

    @Test("A fresh device adopts the mirrored hue at launch")
    func freshDeviceAdoptsMirror() {
        let defaults = makeDefaults()
        // No stored hue, no sync flag — the fresh-install state.
        let store = MirrorStore()
        store.setHue(200, forKey: ThemeManager.syncedSeedHueKey)

        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        #expect(abs(manager.seedHue - 200) < 0.5)
        #expect(defaults.object(forKey: ThemeManager.Keys.seedHue) as? Double == 200)
    }

    @Test("Launch adopts the mirror: the newest dial position wins (X6 policy)")
    func launchAdoptsDifferingMirror() {
        let defaults = makeDefaults()
        defaults.set(40, forKey: ThemeManager.Keys.seedHue)
        let store = MirrorStore()
        store.setHue(200, forKey: ThemeManager.syncedSeedHueKey)

        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        #expect(abs(manager.seedHue - 200) < 0.5)
    }

    @Test("External changes are adopted live")
    func externalChangeAdopted() {
        let defaults = makeDefaults()
        defaults.set(40, forKey: ThemeManager.Keys.seedHue)
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        store.setHue(320, forKey: ThemeManager.syncedSeedHueKey)
        manager.adoptSyncedSeedHue()

        #expect(abs(manager.seedHue - 320) < 0.5)
        #expect(defaults.object(forKey: ThemeManager.Keys.seedHue) as? Double == 320)
    }

    @Test("External changes are ignored while sync is off")
    func externalChangeIgnoredWhenSyncOff() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "icloudSyncEnabled")
        defaults.set(40, forKey: ThemeManager.Keys.seedHue)
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        store.setHue(320, forKey: ThemeManager.syncedSeedHueKey)
        manager.adoptSyncedSeedHue()

        #expect(manager.seedHue == 40)
    }

    @Test("Float dust within the epsilon is not a change")
    func epsilonDustIgnored() {
        let defaults = makeDefaults()
        defaults.set(200, forKey: ThemeManager.Keys.seedHue)
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        store.setHue(200.1, forKey: ThemeManager.syncedSeedHueKey)
        manager.adoptSyncedSeedHue()

        #expect(manager.seedHue == 200)
    }

    @Test("Out-of-range and non-finite mirror values are rejected")
    func invalidMirrorValuesRejected() {
        let defaults = makeDefaults()
        defaults.set(40, forKey: ThemeManager.Keys.seedHue)
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        for bad in [-5.0, 400.0, .infinity] {
            store.setHue(bad, forKey: ThemeManager.syncedSeedHueKey)
            manager.adoptSyncedSeedHue()
            #expect(manager.seedHue == 40)
        }
    }

    @Test("Reset to default mirrors the default to other devices")
    func resetToDefaultMirrors() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "icloudSyncEnabled")
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        manager.seedHue = 200
        manager.commitSeedHue()
        manager.resetToDefault()

        #expect(store.hue(forKey: ThemeManager.syncedSeedHueKey) == ThemeManager.defaultSeedHue)
    }

    @Test("The full-reset wipe clears the mirror")
    func fullResetClearsMirror() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "icloudSyncEnabled")
        let store = MirrorStore()
        let manager = ThemeManager(defaults: defaults, hueMirror: store)

        manager.seedHue = 200
        manager.commitSeedHue()

        ThemeManager.clearSyncedSeedHue(using: store)
        #expect(store.hue(forKey: ThemeManager.syncedSeedHueKey) == nil)
    }
}
