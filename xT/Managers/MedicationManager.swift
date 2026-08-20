//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//  Enhanced with Research-Grade Pharmacokinetic Modeling & Reactive Data Pipeline
//

import SwiftUI
import SwiftData
import Observation

/// Unit of measure for a hormone level. A value rather than a display string so
/// that classification and formatting stay independent of the display locale.
enum HormoneUnit: Equatable {
    case picogramsPerMilliliter   // estrogen
    case nanogramsPerDeciliter    // testosterone
}

/// Where an estimated level sits relative to its comparison bounds.
///
/// This is a model fact, not a verdict. It is only rendered as a comparative
/// statement when `HormoneLevel.boundsSource == .userSet` — the app does not
/// tell the user they are "below target" against a target they never set.
enum LevelStatus: Equatable {
    case criticallyLow
    case veryLow
    case slightlyBelow
    case inRange
    case slightlyAbove
    case high
}

/// How the calibrated level compares to the raw population-model prediction.
enum ModelDeviation: Equatable {
    case below
    case onTrack
    case above
    case incomparable
}

/// A level that crosses a documented clinical threshold. These describe an
/// association, not an instruction; the copy that renders them states the
/// association only.
enum SafetyFlag: Equatable {
    case estrogenCeiling                  // E2 > 1000 pg/mL
    case testosteroneSupraphysiologic     // T > 1500 ng/dL
    case subTherapeuticTrough             // E2 < 50 pg/mL at trough
    case spironolactoneClearance          // E2 < 80 pg/mL at trough while on spiro
}

/// Whether comparison bounds came from the user or from the population model.
/// Comparative copy is gated on `.userSet`.
enum RangeSource: Equatable {
    case userSet
    case modelDerived
}

struct LevelBounds: Equatable {
    let min: Double
    let max: Double
}

/// Equatable replacement for the non-Equatable tuple previously used in
/// `@Published var currentHormoneLevel`. Tuples are not Equatable, so every
/// assignment triggered a publish even when values were identical. This struct
/// enables SwiftUI's Equatable-based change filtering (and works seamlessly
/// with a future @Observable migration).
///
/// Carries classification as values, never as English display strings — views
/// build their own text from these, which keeps semantics and presentation (and
/// therefore localization) separate.
struct HormoneLevel: Equatable {
    let value: Double
    let unit: HormoneUnit
    let status: LevelStatus
    let phase: MedicationManager.CyclePosition
    let deviation: ModelDeviation
    let safety: SafetyFlag?
    let bounds: LevelBounds
    let boundsSource: RangeSource
}

/// MedicationManager with a Reactive Data Pipeline to ensure UI synchronization.
/// This class acts as the Single Source of Truth for all hormone-related state.
@MainActor
@Observable
class MedicationManager {
    static let shared = MedicationManager()

    /// Backing store for this manager's transient preferences.
    ///
    /// Injected rather than reaching for `UserDefaults.standard` directly, because
    /// several properties below persist from their `didSet`. With a global store,
    /// one test setting `customFrequencyDays` silently changed the result of every
    /// later test that built its own manager — `clearSelection()` looked like it
    /// gave a clean slate but never touched persisted state. Tests now pass their
    /// own suite (see `TestDefaults` in the test target) and cannot reach each other.
    let defaults: UserDefaults

    // MARK: - UserDefaults Keys
    enum Keys {
        // Legacy keys retained for one-time migration in migrateToUserPreferences()
        static let antiAndrogenInUse = "mm.antiAndrogenInUse"
        static let spironolactoneInUse = "mm.spironolactoneInUse"
        static let spironolactoneClearanceEnabled = "mm.spironolactoneClearanceEnabled"
        static let suppressionSpeed = "mm.suppressionSpeed"
        static let customFrequencyDays = "mm.customFrequencyDays"
        static let missedDoseGracePeriodHours = "mm.missedDoseGracePeriodHours"
        static let userTherapeuticTarget = "mm.userTherapeuticTarget"
        // Migration completion flag (device-local, not synced)
        static let cloudKitMigrationDone = "prefs.cloudKitMigrationDone"
    }

    /// Prevents `persistUserPreferences()` from firing during a bulk load from SwiftData.
    @ObservationIgnored
    var isLoadingPreferences = false

    // MARK: - SwiftData
    /// Injected from the app container so this singleton can query SwiftData.
    var modelContext: ModelContext? {
        didSet {
            reloadFromContext()
        }
    }

    // MARK: - Core State
    var selectedMedication: String? { didSet { persistUserPreferences() } }
    var selectedAdministrationMethod: String? { didSet { persistUserPreferences() } }
    var selectedEster: String? { didSet { persistUserPreferences() } }
    var lastDoseDate: Date?
    var nextDoseDate: Date?
    var defaultDoseAmount: Double?
    var defaultInjectionTime: Date?
    /// When the user actually began HRT (may predate app install). Drives monthsOnHRT.
    var hrtStartDate: Date? { didSet { persistUserPreferences() } }

    // MARK: - Body Type & Rotation Windows (synced via UserPreferences)

    /// The user's chosen body silhouette model. Rawvalue of BodyType.
    var bodyTypeRaw: String = BodyType.neutral.rawValue { didSet { persistUserPreferences() } }

    var rotationWindowInjection: Int = RouteClass.injection.defaultRotationWindowDays {
        didSet { persistUserPreferences() }
    }
    var rotationWindowTopical: Int = RouteClass.topical.defaultRotationWindowDays {
        didSet { persistUserPreferences() }
    }
    var rotationWindowPatch: Int = RouteClass.patch.defaultRotationWindowDays {
        didSet { persistUserPreferences() }
    }

    // MARK: - Reactive Research Properties (The "Signals" for SwiftUI)
    /// Provides the current level summary, including unit, range, and plain-language explanation.
    var currentHormoneLevel: HormoneLevel? = nil
    /// Provides the historical data points used to drive the 7-day and long-term charts.
    var recentLevels: [EstimatedPoint] = []

    // MARK: - Dose History (The Real Source of Truth)
    /// Full log of all logged doses — the backbone of the PK model.
    var doseHistory: [DoseRecord] = []

    /// Incremented each time a dose is successfully recorded. Drives celebration
    /// animations and reactive refresh hooks across the UI.
    var doseRecordedCount: Int = 0

    /// How long HomeView should wait after `doseRecordedCount` changes before
    /// firing the celebration confetti — tuned per recording flow, since each
    /// sheet dismisses on its own schedule. Read once per increment then reset
    /// to `defaultCelebrationDelay`, so an override never leaks into the next
    /// dose recorded through a different flow.
    static let defaultCelebrationDelay: TimeInterval = 0.55
    var celebrationDelay: TimeInterval = defaultCelebrationDelay

    // MARK: - Injection Site Tracking

    /// Zones marked as "avoid" by the user. Key = zone label.
    /// Persisted via `UserPreferences.avoidZonesJSON` (SwiftData/CloudKit).
    var avoidZones: [String: AvoidZoneInfo] = [:]

    /// Convenience accessor: returns the set of zone labels currently marked as avoid.
    var avoidZoneLabels: Set<String> {
        Set(avoidZones.keys)
    }

    /// In-memory cache for async heat map computations.
    /// Keyed by "routeClass_windowDays". Invalidated on dose record.
    @ObservationIgnored
    var heatMapCache: [String: [String: Int]] = [:]

    /// Incremented every time `invalidateHeatMapCache()` is called, so async
    /// heat-map computations can detect that their cached result is stale.
    @ObservationIgnored
    var heatMapCacheGeneration: Int = 0

    /// Cached copies of the two onboarding-chosen vial strengths, filled by
    /// `loadUserPreferences()` (which already fetches the prefs record) so the
    /// concentration fallback chain in `+Dosing` doesn't re-fetch from SwiftData
    /// on every view render. Direct record writes outside the manager must route
    /// through `updateOnboardingDefaultConcentration` to keep these fresh.
    @ObservationIgnored
    var cachedDefaultEstrogenConcentration: Double?
    @ObservationIgnored
    var cachedDefaultTestosteroneConcentration: Double?

    // MARK: - Batch mutation

    /// When `true`, `refreshState()` returns immediately without recomputing.
    ///
    /// Recording a dose triggers a full pharmacokinetic re-integration over the entire
    /// dose history plus a SwiftData save, which is the right behaviour for a single user
    /// action but quadratic when seeding many doses at once (the sample profile logs ~110).
    /// Wrap bulk work in `performBatch(_:)` so the recompute happens once at the end.
    @ObservationIgnored
    var suppressRefresh: Bool = false

    /// Runs `body` with `refreshState()` suppressed, then refreshes exactly once.
    ///
    /// Safe to nest: only the outermost call performs the trailing refresh.
    func performBatch(_ body: () throws -> Void) rethrows {
        let wasSuppressed = suppressRefresh
        suppressRefresh = true
        defer {
            suppressRefresh = wasSuppressed
            if !wasSuppressed { refreshState() }
        }
        try body()
    }

    // MARK: - Endogenous Suppression Settings
    /// Whether the user takes an anti‑androgen (spironolactone, cyproterone, GnRH agonist).
    /// When true, endogenous testosterone baseline is aggressively suppressed to near‑zero.
    var antiAndrogenInUse: Bool = false { didSet { persistUserPreferences() } }

    /// Spironolactone is a known enzyme inducer (CYP3A4) that can modestly increase
    /// estradiol clearance. When the user is on spiro, we apply a small multiplier to ke
    /// to reflect this interaction (see `PKConstants.spiroClearanceFactor`).
    /// Set to false if the user is on other AAs (cyproterone, GnRH agonists).
    var spironolactoneInUse: Bool = false { didSet { persistUserPreferences() } }

    // --- User Preference-Driven Settings (#9, #12, #18) ---
    /// User-configurable suppression timescale (4/8/12 weeks).
    var suppressionSpeed: SuppressionSpeed = .fast { didSet { persistUserPreferences() } }
    /// Whether the spironolactone clearance adjustment is opted in.
    var spironolactoneClearanceEnabled: Bool = false { didSet { persistUserPreferences() } }
    /// Custom dosing interval in days; nil = use method default.
    var customFrequencyDays: Int? = nil { didSet { persistUserPreferences() } }

    /// When true, the Time tab surfaces relativeDoseIntensity-derived copy.
    /// T5+ users default to off. Persisted via UserPreferences.
    var showDoseIntensityInsights: Bool = false { didSet { persistUserPreferences() } }

    // --- Missed Dose Settings (#1) ---
    /// Grace period in hours after the scheduled dose during which it's still "Due Soon".
    /// Default 12 hours. After this window, the dose is marked "Missed".
    var missedDoseGracePeriodHours: Double = PKConstants.missedDoseGraceHours { didSet { persistUserPreferences() } }

    // MARK: - Blood Test Calibration
    /// History of user‑entered lab results used to calibrate the PK model.
    var bloodTestHistory: [BloodTestRecord] = []

    /// Health screening log (DEXA, breast, cardio, liver, CBC, etc.).
    /// Drives milestone completion tracking for long-term tenure tiers (plan §4.1).
    var screeningRecords: [ScreeningRecord] = [] {
        didSet { rebuildScreeningLog() }
    }

    /// The current calibration factor derived from the most recent blood test.
    /// α = measured / predicted. Applied as a multiplier to all model outputs.
    /// Returns nil if no blood tests have been entered yet.
    ///
    /// Read once per `estimatedLevels(...)` call, so it stays a single allocation-free
    /// pass rather than the `filter` + `sorted` + `first` chain it replaces.
    ///
    /// Deliberately **not** memoized: `computeCalibrationFactor(for:)` writes
    /// `calibrationFactor` straight onto a record without touching `bloodTestHistory`,
    /// so there is no mutation hook a cache could hang invalidation off — a stale
    /// entry would silently drop a freshly entered lab result from the model.
    var calibrationFactor: Double? {
        var latest: BloodTestRecord?
        // The factor is only meaningful for the hormone the model is currently
        // predicting. Previously this scanned every calibrated record regardless of
        // hormone type, so a user who logged labs for both E2 and T could have the
        // wrong hormone's α applied to the model — e.g. a testosterone draw silently
        // rescaling the estrogen curve. `selectedMedication` is the same value
        // `estimatedLevels` gates its dose events on, so the filter keeps the
        // calibration and the prediction on the same hormone.
        for record in bloodTestHistory
        where record.isCalibrated && record.hormoneType == selectedMedication {
            if let current = latest, current.drawDate >= record.drawDate { continue }
            latest = record
        }
        return latest?.calibrationFactor
    }

    // MARK: - Research Models

    enum MedicationType: String, CaseIterable {
        case estrogen = "Estrogen"
        case testosterone = "Testosterone"

        /// Intact gonadal baseline (pre‑HRT or no suppression).
        var baselineValue: Double {
            switch self {
            case .estrogen: return 100.0
            case .testosterone: return 600.0
            }
        }
        
        /// Suppressed baseline after adequate HRT duration (adrenal contribution only).
        /// Trans women on E2 + AA → T < 50 ng/dL, E2 ~5–10 pg/mL.
        /// Trans men on T → ovarian E2 suppressed, but aromatization produces some E2.
        var suppressedBaseline: Double {
            switch self {
            case .estrogen: return 5.0
            case .testosterone: return 15.0
            }
        }

        /// The ester assumed for this medication when no prior dose carries one.
        ///
        /// Returns the *raw ester name* rather than an enum case: the two ester
        /// enums are separate types, and a `MedicationEster` return value meant
        /// the testosterone arm used to produce "Cypionate (EC)" — the estradiol
        /// ester's raw value — instead of "Cypionate (TC)".
        var defaultEsterName: String {
            switch self {
            case .estrogen: return MedicationEster.valerate.rawValue
            case .testosterone: return TestosteroneEster.cypionate.rawValue
            }
        }
    }

    enum AdministrationMethod: String, CaseIterable {
        case injectable = "Injectable"
        case cream = "Cream"
        case oral = "Oral"

        var frequencyDays: Int {
            switch self {
            case .injectable: return 7
            case .cream, .oral: return 1
            }
        }
    }

    struct EstimatedPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let medication: String
        let method: String
    }
    
    /// Where the user is in their injection cycle relative to expected peak and trough.
    /// Raw values are stable identifiers, not display text — views localize their
    /// own labels for these cases.
    enum CyclePosition: String {
        case nearPeak = "nearPeak"
        case midCycle = "midCycle"
        case trough = "trough"
        case unknown = "unknown"
    }
    
    // MARK: - Therapeutic Targets (User-Configurable)
    
    /// Personalized therapeutic target ranges set by the user (or their provider).
    /// When nil, the model falls back to clinical defaults.
    struct TherapeuticTarget: Codable, Equatable {
        var troughMin: Double   // E2 default 100 pg/mL; T default 400 ng/dL
        var troughMax: Double   // E2 default 200 pg/mL; T default 700 ng/dL
        var peakCeiling: Double // E2 default 600 pg/mL; T default 1200 ng/dL
        
        static let `default` = TherapeuticTarget(troughMin: 100, troughMax: 200, peakCeiling: 600)
        
        static let defaultTestosterone = TherapeuticTarget(troughMin: 400, troughMax: 700, peakCeiling: 1200)
    }
    
    /// User's personal therapeutic target. When nil, clinical defaults are used.
    var userTherapeuticTarget: TherapeuticTarget? = nil { didSet { persistUserPreferences() } }

    // MARK: - Configuration & UI Helpers

    /// `LocalizedStringResource` (not `String`) so any Markdown grammar in the
    /// localized value is parsed by `Text(_:LocalizedStringResource)` at the
    /// render site. Returning `String` would route through the verbatim
    /// `Text(_:StringProtocol)` overload and leave markup visible.
    var medicationDisplayInfo: LocalizedStringResource {
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return "\(medication) via \(method)"
        } else if let medication = selectedMedication {
            return "\(medication) (method not selected)"
        } else {
            return "No medication selected"
        }
    }

    func getConfigurationSummary() -> String {
        if isFullyConfigured {
            return String(localized: "Fully configured and ready")
        } else if isPartiallyConfigured {
            return String(localized: "Partially configured - needs completion")
        } else {
            return String(localized: "Not configured")
        }
    }

    var scheduleSummary: String {
        // `effectiveFrequencyDays` honours the user's custom interval; the method default
        // this used to read ignored it, so the summary contradicted the actual schedule.
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return String(localized: "\(medication) via \(method) every \(effectiveFrequencyDays) days")
        } else {
            return String(localized: "Not configured")
        }
    }

    var isFullyConfigured: Bool {
        selectedMedication != nil && selectedAdministrationMethod != nil
    }

    var isPartiallyConfigured: Bool {
        (selectedMedication != nil) != (selectedAdministrationMethod != nil)
    }

    /// Missed-dose detection using configurable grace period (#1).
    var hasMissedDose: Bool {
        guard let next = nextDoseDate else { return false }
        let graceSeconds = missedDoseGracePeriodHours * 3600
        return Date() > next.addingTimeInterval(graceSeconds)
    }

    var daysSinceMissedDose: Int? {
        guard hasMissedDose, let next = nextDoseDate else { return nil }
        let graceSeconds = missedDoseGracePeriodHours * 3600
        let effectiveDueDate = next.addingTimeInterval(graceSeconds)
        let days = Calendar.current.dateComponents([.day], from: effectiveDueDate, to: Date()).day ?? 0
        return max(1, days) // At least 1 day after grace period expiry
    }

    var monthsOnHRT: Int {
        let referenceDate = hrtStartDate ?? lastDoseDate
        guard let first = referenceDate else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0
        return max(0, months)
    }

    /// Gap-aware months on HRT for tiering and content (plan §4.2).
    ///
    /// The span from the declared start date up to the first logged dose is
    /// trusted as active therapy — an empty dose log there means "started logging
    /// later," not "paused." From the first logged dose forward, only calendar
    /// months that contain at least one taken dose count; months with no dose are
    /// genuine gaps and drop out.
    var activeMonthsOnHRT: Int {
        let referenceDate = hrtStartDate ?? lastDoseDate
        guard let first = referenceDate else { return 0 }
        let activeDoses = doseHistory.filter { $0.doseStatus == DoseStatus.taken.rawValue }
        guard let earliestDose = activeDoses.map(\.doseDate).min() else { return monthsOnHRT }

        let calendar = Calendar.current
        // Months from the declared start to the first logged dose: counted as
        // active, since a missing record there isn't evidence of a pause.
        let preLogMonths = max(0, calendar.dateComponents([.month], from: first, to: earliestDose).month ?? 0)

        // From the first logged dose on, count distinct months that contain a
        // taken dose — months with no dose are real gaps and subtract.
        var loggedMonths = Set<String>()
        for dose in activeDoses where dose.doseDate >= earliestDose {
            let comps = calendar.dateComponents([.year, .month], from: dose.doseDate)
            loggedMonths.insert("\(comps.year ?? 0)-\(comps.month ?? 0)")
        }
        return max(0, preLogMonths + loggedMonths.count)
    }

    /// Age at HRT start, derived from ProfileManager.dateOfBirth and hrtStartDate.
    /// Returns nil when either date is unavailable (plan §4.3).
    var ageAtHRTStart: Int? {
        guard let dob = ProfileManager.shared.dateOfBirth,
              let start = hrtStartDate else { return nil }
        let age = Calendar.current.dateComponents([.year], from: dob, to: start).year
        return age
    }

    // MARK: - Initialization

    /// - Parameter defaults: the preferences store to persist through. Defaults to
    ///   `.standard`; tests inject an isolated suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // All settings are loaded from SwiftData in reloadFromContext(), which runs after
        // modelContext is injected by xTApp. The call here is a no-op until then.
        reloadFromContext()
        refreshState()
    }

    /// Reloads all state that depends on `modelContext`.
    ///
    /// Order: migration first, then preferences and history, then derived values,
    /// then refreshState() last so published chart state reflects the recomputed calibration.
    private func reloadFromContext() {
        guard modelContext != nil else { return }
        migrateToUserPreferences()
        loadUserPreferences()
        loadDoseHistory()
        loadBloodTestHistory()
        loadScreeningHistory()
        migrateRecordedAtForLegacyRecords()
        recomputeCalibrationFactors()
        refreshState()
    }

    /// Re-fetches all data from the local SwiftData store (which CloudKit may have
    /// just populated). Call this after giving CloudKit a moment to complete its
    /// initial sync, e.g. from the "Restore from iCloud" path in onboarding.
    func reloadAllFromStore() {
        reloadFromContext()
    }

    // MARK: - Screening Log (plan §4.1)

    /// Loads screening records from SwiftData.
    func loadScreeningHistory() {
        guard let context = modelContext else { return }
        let descriptor = SortDescriptor<ScreeningRecord>(\ScreeningRecord.date, order: .reverse)
        let fetchDescriptor = FetchDescriptor<ScreeningRecord>(sortBy: [descriptor])
        let allRecords = try? context.fetch(fetchDescriptor)
        screeningRecords = allRecords ?? []
    }

    /// Returns the most recent screening date for the given type, or nil if none exists.
    ///
    /// Reads the cached log rather than scanning `screeningRecords`, which is only sorted
    /// by insertion order — `first(where:)` on it returned whichever record happened to be
    /// at the front, not the most recent one.
    func lastScreening(_ type: ScreeningType) -> Date? {
        screeningLog[type]
    }

    /// Compact lookup table: last-done date for each screening type that has one.
    /// Passed to `TimeContentEngine` so it can flip milestone badges.
    ///
    /// Cached rather than computed: `TimeView` reads it from `body`, so as a computed
    /// property it rebuilt the whole dictionary on every render pass.
    @ObservationIgnored
    private(set) var screeningLog: [ScreeningType: Date] = [:]

    /// Recomputes ``screeningLog``. Called from `screeningRecords`' observer, which is the
    /// only thing the log derives from.
    func rebuildScreeningLog() {
        var log: [ScreeningType: Date] = [:]
        for record in screeningRecords {
            if let existing = log[record.type], existing >= record.date { continue }
            log[record.type] = record.date
        }
        screeningLog = log
    }

    /// Adds a screening record and persists to SwiftData.
    func addScreening(date: Date, type: ScreeningType, notes: String? = nil) {
        let record = ScreeningRecord(date: date, type: type, notes: notes)
        guard !screeningRecords.contains(where: { $0.id == record.id }) else { return }
        screeningRecords.insert(record, at: 0)
        modelContext?.insert(record)
        try? modelContext?.save()
    }

    /// Removes a screening record, symmetric with `removeBloodTest(withId:)`.
    func removeScreening(withId id: String) {
        if let index = screeningRecords.firstIndex(where: { $0.id == id }) {
            modelContext?.delete(screeningRecords[index])
            screeningRecords.remove(at: index)
            try? modelContext?.save()
        }
    }
    // MARK: - Dose Deletion

    func softDeleteDose(id: String) {
        guard let context = modelContext else { return }
        guard let index = doseHistory.firstIndex(where: { $0.id == id }) else { return }

        let record = doseHistory[index]
        context.delete(record)
        try? context.save()

        loadDoseHistory()

        let active = doseHistory.filter { $0.doseStatus == DoseStatus.taken.rawValue }
        lastDoseDate = active.max(by: { $0.doseDate < $1.doseDate })?.doseDate
        nextDoseDate = lastDoseDate.map { calculateNextDoseDate(from: $0) }

        invalidateHeatMapCache()
        refreshState()
    }
    // MARK: - Regimen & Adherence Properties
    
    var regimenTransitionHistory: [RegimenSegment] = []
    var adherenceRate: Double? = nil
    var onTimeStreak: Int = 0
    
}

// MARK: - Environment Key
@MainActor
struct MedicationManagerKey: @MainActor EnvironmentKey {
    static let defaultValue: MedicationManager = MedicationManager.shared
}

extension EnvironmentValues {
    @MainActor
    var medicationManager: MedicationManager {
        get { self[MedicationManagerKey.self] }
        set { self[MedicationManagerKey.self] = newValue }
    }
}
