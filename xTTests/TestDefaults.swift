//
//  TestDefaults.swift
//  xTTests
//
//  A real fixture for `MedicationManager`, replacing `clearSelection()`.
//
//  Several of the manager's properties persist to `UserDefaults` from their
//  `didSet` — `customFrequencyDays`, `userTherapeuticTarget`, the suppression
//  settings, the avoid zones. Tests used to open with:
//
//      let mgr = MedicationManager()
//      mgr.clearSelection()
//
//  which reads as "fresh manager, clean slate" and is neither. Every manager shared
//  `UserDefaults.standard`, and `clearSelection()` only nilled four in-memory
//  properties — it never touched persisted state. So a value written by one test
//  reached every test that ran after it, and the suite's result depended on
//  execution order. `TestosteronePeakAccuracyTests.tuSingleDosePeak` was the one
//  that surfaced it: with a `customFrequencyDays` of 5 or 10 left behind by
//  `DoseOrderingTests`, testosterone undecanoate projected forward at that interval
//  instead of its real ~70-day one, reporting ~2846 ng/dL against an expected
//  ~1190. It looked flaky. It was deterministic, just not in test order.
//
//  `MedicationManager` now takes its store as a dependency, so a test can be handed
//  one nothing else can see.
//

import Foundation
import Testing
@testable import xT

enum TestDefaults {

    /// A `MedicationManager` backed by its own empty preferences suite.
    ///
    /// The suite name is derived from the call site, so it is stable across runs
    /// (bounded on disk, unlike a UUID) and distinct per test (safe under Swift
    /// Testing's parallel execution). The domain is wiped on the way in, so a test
    /// starts empty regardless of what a previous run left behind.
    ///
    /// Prefer this over `MedicationManager()` in every test. A bare
    /// `MedicationManager()` still resolves to `UserDefaults.standard` — correct for
    /// production, contaminating in a test.
    @MainActor
    static func manager(file: String = #fileID, function: String = #function) -> MedicationManager {
        MedicationManager(defaults: suite(file: file, function: function))
    }

    /// An empty `UserDefaults` suite scoped to the calling test.
    @MainActor
    static func suite(file: String = #fileID, function: String = #function) -> UserDefaults {
        // #fileID is "xTTests/PharmacokineticTests.swift"; the slash and the .swift
        // suffix are noise in a suite name, and `function` carries the parens.
        let scope = (file + "." + function)
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: ".swift", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
        let name = "xT.tests.\(scope)"

        // Wipe first: suite names are deterministic, so yesterday's run would
        // otherwise be today's starting state — the same bug one level up.
        UserDefaults.standard.removePersistentDomain(forName: name)

        guard let defaults = UserDefaults(suiteName: name) else {
            // Only fails for a reserved/global-domain name, which "xT.tests.*" is not.
            fatalError("Could not open UserDefaults suite \(name)")
        }
        return defaults
    }
}

// MARK: - The fixture's own guarantee

/// Isolation is the whole point of the fixture, so it is asserted rather than assumed.
@Suite("Test fixture isolates persisted manager state")
struct TestDefaultsIsolationTests {

    @MainActor
    @Test("A persisted property set on one manager is invisible to another")
    func persistedStateDoesNotLeakBetweenManagers() {
        // This is the exact shape of the bug the fixture exists to prevent:
        // customFrequencyDays writes through to its store from didSet.
        let a = MedicationManager(defaults: TestDefaults.suite(function: "leakCheckA"))
        let b = MedicationManager(defaults: TestDefaults.suite(function: "leakCheckB"))

        a.customFrequencyDays = 5
        #expect(b.customFrequencyDays == nil,
                "manager B must not see manager A's dosing interval")

        b.userTherapeuticTarget = MedicationManager.TherapeuticTarget(troughMin: 1, troughMax: 2, peakCeiling: 3)
        #expect(a.userTherapeuticTarget == nil,
                "manager A must not see manager B's therapeutic target")
    }

    @MainActor
    @Test("A manager built from the fixture starts empty")
    func fixtureManagerStartsEmpty() {
        // Written, then rebuilt on the same call-site-derived suite name: the wipe
        // in `suite(...)` has to clear the previous run, or a stale value on disk
        // becomes the next run's starting state.
        let first = MedicationManager(defaults: TestDefaults.suite(function: "emptyCheck"))
        first.customFrequencyDays = 9

        let second = MedicationManager(defaults: TestDefaults.suite(function: "emptyCheck"))
        #expect(second.customFrequencyDays == nil)
        #expect(second.selectedMedication == nil)
        #expect(second.userTherapeuticTarget == nil)
    }
}
