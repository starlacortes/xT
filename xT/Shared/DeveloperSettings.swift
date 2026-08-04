//
//  DeveloperSettings.swift
//  xT
//
//  Developer Area state (Settings → Developer). Three UserDefaults-backed
//  flags gate developer functionality: a master Developer Mode switch, the
//  Sample (Jan test profile) toggle, and the Research (Insights tab) toggle.
//
//  All flags live in UserDefaults under the "dev." prefix so they never sync
//  to iCloud or touch the production data model. In RELEASE builds the flags
//  are hardwired `false` (the Developer section UI is compiled out, so no
//  setter path exists) and any stale "dev." state left by a prior DEBUG
//  install is scrubbed at launch — see `scrubStaleReleaseState()`.
//

import Foundation
import Observation

@MainActor
@Observable
final class DeveloperSettings {

    static let shared = DeveloperSettings()

    // UserDefaults keys, kept in one place. The "dev." prefix is load-bearing:
    // scrubStaleReleaseState() removes every key carrying it.
    private enum Keys {
        static let developerMode = "dev.developerModeEnabled"
        static let sampleProfile = "dev.sampleProfileEnabled"
        static let activePersona = "dev.activePersonaIndex"
    }

    /// Filesystem home for DEBUG-only developer artifacts (e.g. the user-data
    /// snapshot written by `ProfileSnapshot`). Deliberately outside the
    /// CloudKit-backed SwiftData store so developer state can never sync.
    static var developerSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("xT-dev", isDirectory: true)
    }

    /// All available spoof personas. Order matches the UX paper.
    static let personaNames: [String] = [
        "Jan (Sample)",
        "Maya — 4mg EV q7d, first-time",
        "Devon — 100→200mg TC, regimen change",
        "Priya — oral E2→EV IM, route switch",
        "Sam — 50mg/day T gel, missed doses",
        "Rowan — 4mg/day E2 cream, custom conc.",
        "Jules — 100mg TE q7d, blood test calib.",
        "Nadia — 5mg EC q10d, unconventional",
    ]

#if DEBUG
    /// Master gate. When off, the Sample and Research toggles are visible in
    /// Settings but greyed out.
    var developerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(developerModeEnabled, forKey: Keys.developerMode) }
    }

    /// When on, a spoof persona is the active dataset. The user's real
    /// data is preserved by `ProfileSnapshot` and restored on toggle-off.
    var sampleProfileEnabled: Bool {
        didSet { UserDefaults.standard.set(sampleProfileEnabled, forKey: Keys.sampleProfile) }
    }

    /// Which persona is active when sampleProfileEnabled is true.
    /// Index into `DeveloperSettings.personaNames`. Defaults to 0 (Jan).
    var activePersonaIndex: Int {
        didSet { UserDefaults.standard.set(activePersonaIndex, forKey: Keys.activePersona) }
    }

    /// Convenience: the persona name for the currently selected index.
    var activePersonaName: String {
        let i = activePersonaIndex
        guard i >= 0, i < Self.personaNames.count else { return Self.personaNames[0] }
        return Self.personaNames[i]
    }

    private init() {
        let defaults = UserDefaults.standard
        developerModeEnabled = defaults.bool(forKey: Keys.developerMode)
        sampleProfileEnabled = defaults.bool(forKey: Keys.sampleProfile)
        activePersonaIndex = defaults.integer(forKey: Keys.activePersona)
    }
#else
    // RELEASE: hardwired off. Consumers read these without any #if DEBUG.
    let developerModeEnabled = false
    let sampleProfileEnabled = false

    private init() {}
#endif

    /// Removes every "dev." UserDefaults key and the developer support
    /// directory. Called from `xTApp.init()` in RELEASE builds so a RELEASE
    /// install over a DEBUG build can never inherit developer state
    /// (implementation plan §2.7).
    static func scrubStaleReleaseState() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("dev.") {
            defaults.removeObject(forKey: key)
        }
        try? FileManager.default.removeItem(at: developerSupportDirectory)
    }
}
