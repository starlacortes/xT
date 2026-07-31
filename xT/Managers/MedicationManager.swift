//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//  Enhanced with Research-Grade Pharmacokinetic Modeling & Reactive Data Pipeline
//

import SwiftUI
import SwiftData
import CryptoKit

/// Equatable replacement for the non-Equatable tuple previously used in
/// `@Published var currentHormoneLevel`. Tuples are not Equatable, so every
/// assignment triggered a publish even when values were identical. This struct
/// enables SwiftUI's Equatable-based change filtering (and works seamlessly
/// with a future @Observable migration).
struct HormoneLevel: Equatable {
    let value: Double
    let unit: String
    let range: String
    let explanation: String
}

/// MedicationManager with a Reactive Data Pipeline to ensure UI synchronization.
/// This class acts as the Single Source of Truth for all hormone-related state.
@MainActor
class MedicationManager: ObservableObject {
    static let shared = MedicationManager()

    // MARK: - UserDefaults Keys for Transient Properties
    // These properties are persisted to UserDefaults via didSet so the
    // snapshot/restore cycle (ProfileSnapshot) can capture and restore them.
    enum Keys {
        static let antiAndrogenInUse = "mm.antiAndrogenInUse"
        static let spironolactoneInUse = "mm.spironolactoneInUse"
        static let spironolactoneClearanceEnabled = "mm.spironolactoneClearanceEnabled"
        static let suppressionSpeed = "mm.suppressionSpeed"
        static let customFrequencyDays = "mm.customFrequencyDays"
        static let missedDoseGracePeriodHours = "mm.missedDoseGracePeriodHours"
        static let userTherapeuticTarget = "mm.userTherapeuticTarget"
    }

    // MARK: - SwiftData
    /// Injected from the app container so this singleton can query SwiftData.
    var modelContext: ModelContext? {
        didSet {
            reloadFromContext()
        }
    }

    // MARK: - Core State
    @Published var selectedMedication: String?
    @Published var selectedAdministrationMethod: String?
    @Published var selectedEster: String?
    @Published var lastDoseDate: Date?
    @Published var nextDoseDate: Date?
    @Published var defaultDoseAmount: Double?
    @Published var defaultInjectionTime: Date?
    /// When the user actually began HRT (may predate app install). Drives monthsOnHRT.
    @Published var hrtStartDate: Date?

    // MARK: - Reactive Research Properties (The "Signals" for SwiftUI)
    /// Provides the current level summary, including unit, range, and plain-language explanation.
    @Published var currentHormoneLevel: HormoneLevel? = nil
    /// Provides the historical data points used to drive the 7-day and long-term charts.
    @Published var recentLevels: [EstimatedPoint] = []

    // MARK: - Dose History (The Real Source of Truth)
    /// Full log of all logged doses — the backbone of the PK model.
    @Published var doseHistory: [DoseRecord] = []

    /// Incremented each time a dose is successfully recorded. Drives celebration
    /// animations and reactive refresh hooks across the UI.
    @Published var doseRecordedCount: Int = 0

    // MARK: - Injection Site Tracking

    /// Zones marked as "avoid" by the user. Key = zone label.
    /// Persisted to UserDefaults for cross-launch durability.
    @Published var avoidZones: [String: AvoidZoneInfo] = [:]

    /// Convenience accessor: returns the set of zone labels currently marked as avoid.
    var avoidZoneLabels: Set<String> {
        Set(avoidZones.keys)
    }

    /// In-memory cache for async heat map computations.
    /// Keyed by "routeClass_windowDays". Invalidated on dose record.
    var heatMapCache: [String: [String: Int]] = [:]

    // MARK: - Endogenous Suppression Settings
    /// Whether the user takes an anti‑androgen (spironolactone, cyproterone, GnRH agonist).
    /// When true, endogenous testosterone baseline is aggressively suppressed to near‑zero.
    @Published var antiAndrogenInUse: Bool = false {
        didSet { UserDefaults.standard.set(antiAndrogenInUse, forKey: Keys.antiAndrogenInUse) }
    }

    /// Number of weeks after HRT start for endogenous production to reach suppressed levels.
    /// Clinical consensus: 4–6 weeks for gonadal suppression.
    let hrtSuppressionWeeks: Int = 4

    /// Spironolactone is a known enzyme inducer (CYP3A4) that can modestly increase
    /// estradiol clearance. When the user is on spiro, we apply a small multiplier to ke
    /// to reflect this interaction. Typical estimates: 10‑20% faster clearance.
    /// Set to false if the user is on other AAs (cyproterone, GnRH agonists).
    @Published var spironolactoneInUse: Bool = false {
        didSet { UserDefaults.standard.set(spironolactoneInUse, forKey: Keys.spironolactoneInUse) }
    }

    /// Multiplier applied to elimination rate (ke) when spironolactone is in use.
    /// Accounts for CYP3A4 induction → faster E2 clearance.
    let spiroClearanceFactor: Double = 1.15

    // --- User Preference-Driven Settings (#9, #12, #18) ---
    /// User-configurable suppression timescale (4/8/12 weeks).
    @Published var suppressionSpeed: SuppressionSpeed = .fast {
        didSet { UserDefaults.standard.set(suppressionSpeed.rawValue, forKey: Keys.suppressionSpeed) }
    }
    /// Whether the spironolactone clearance adjustment is opted in.
    @Published var spironolactoneClearanceEnabled: Bool = false {
        didSet { UserDefaults.standard.set(spironolactoneClearanceEnabled, forKey: Keys.spironolactoneClearanceEnabled) }
    }
    /// Custom dosing interval in days; nil = use method default.
    @Published var customFrequencyDays: Int? = nil {
        didSet {
            if let val = customFrequencyDays {
                UserDefaults.standard.set(val, forKey: Keys.customFrequencyDays)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.customFrequencyDays)
            }
        }
    }

    /// When true, the Time tab surfaces relativeDoseIntensity-derived copy.
    /// T5+ users default to off. Persisted via UserPreferences (plan §4.4).
    @Published var showDoseIntensityInsights: Bool = false

    // --- Missed Dose Settings (#1) ---
    /// Grace period in hours after the scheduled dose during which it's still "Due Soon".
    /// Default 12 hours. After this window, the dose is marked "Missed".
    @Published var missedDoseGracePeriodHours: Double = 12.0 {
        didSet { UserDefaults.standard.set(missedDoseGracePeriodHours, forKey: Keys.missedDoseGracePeriodHours) }
    }

    /// Predicted trough drop when a dose is missed (pg/mL or ng/dL).
    /// Computed from the PK model: difference between expected trough with vs. without the missed dose.
    @Published var predictedTroughDrop: Double? = nil

    // MARK: - Blood Test Calibration
    /// History of user‑entered lab results used to calibrate the PK model.
    @Published var bloodTestHistory: [BloodTestRecord] = []

    /// Health screening log (DEXA, breast, cardio, liver, CBC, etc.).
    /// Drives milestone completion tracking for long-term tenure tiers (plan §4.1).
    @Published var screeningRecords: [ScreeningRecord] = []
    
    /// The current calibration factor derived from the most recent blood test.
    /// α = measured / predicted. Applied as a multiplier to all model outputs.
    /// Returns nil if no blood tests have been entered yet.
    var calibrationFactor: Double? {
        // Return the most recent valid calibration factor
        if let latest = bloodTestHistory
            .filter({ $0.isCalibrated })
            .sorted(by: { $0.drawDate > $1.drawDate })
            .first {
            return latest.calibrationFactor
        }
        return nil
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

        var defaultEster: MedicationEster {
            switch self {
            case .estrogen: return .valerate
            case .testosterone: return .cypionate
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

        var isImplemented: Bool {
            switch self {
            case .injectable, .cream, .oral: return true
            }
        }
    }

    struct HormoneRange: Codable {
        let label: String
        let min: Double
        let max: Double
        let colorName: String
    }

    struct EstimatedPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let medication: String
        let method: String
    }
    
    /// Where the user is in their injection cycle relative to expected peak and trough.
    enum CyclePosition: String {
        case nearPeak = "Near Peak"
        case midCycle = "Mid-Cycle"
        case trough = "Trough"
        case unknown = "Unknown"
    }
    
    // MARK: - Therapeutic Targets (User-Configurable)
    
    /// Personalized therapeutic target ranges set by the user (or their provider).
    /// When nil, the model falls back to clinical defaults.
    struct TherapeuticTarget: Codable, Equatable {
        var troughMin: Double   // e.g., 150 pg/mL
        var troughMax: Double   // e.g., 250 pg/mL
        var peakCeiling: Double // e.g., 600 pg/mL (upper safety limit)
        
        static let `default` = TherapeuticTarget(troughMin: 100, troughMax: 200, peakCeiling: 600)
        
        static let defaultTestosterone = TherapeuticTarget(troughMin: 400, troughMax: 700, peakCeiling: 1200)
    }
    
    /// User's personal therapeutic target. When nil, clinical defaults are used.
    @Published var userTherapeuticTarget: TherapeuticTarget? = nil {
        didSet {
            if let target = userTherapeuticTarget, let data = try? JSONEncoder().encode(target) {
                UserDefaults.standard.set(data, forKey: Keys.userTherapeuticTarget)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.userTherapeuticTarget)
            }
        }
    }

    // MARK: - Configuration & UI Helpers

    /// Estrogen ranges in pg/mL (typical for trans women on HRT)
    /// Ranges based on clinical targets: 100-200 pg/mL is standard
    private let estrogenRanges: [HormoneRange] = [
        HormoneRange(label: "Very Low", min: 0, max: 50, colorName: "bloomBodyColor"),
        HormoneRange(label: "Low", min: 50, max: 100, colorName: "bloomBodyColor"),
        HormoneRange(label: "Optimal", min: 100, max: 200, colorName: "successColor"),
        HormoneRange(label: "High", min: 200, max: 500, colorName: "bloomCycleColor"),
        HormoneRange(label: "Very High", min: 500, max: 1000, colorName: "bloomCycleColor")
    ]

    /// Testosterone ranges in ng/dL (typical for trans women on HRT)
    /// Suppression target: < 50 ng/dL (castrate range)
    private let testosteroneRanges: [HormoneRange] = [
        HormoneRange(label: "Suppressed", min: 0, max: 50, colorName: "successColor"),
        HormoneRange(label: "Low (Feminizing)", min: 50, max: 100, colorName: "successColor"),
        HormoneRange(label: "Moderate", min: 100, max: 300, colorName: "warningColor"),
        HormoneRange(label: "Male Range Low", min: 300, max: 500, colorName: "bloomCycleColor"),
        HormoneRange(label: "Male Range", min: 500, max: 1000, colorName: "bloomCycleColor"),
        HormoneRange(label: "Very High", min: 1000, max: 9999, colorName: "bloomCycleColor")
    ]

    var medicationName: String { selectedMedication ?? "None Selected" }

    var medicationDisplayInfo: String {
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
            return "Fully configured and ready"
        } else if isPartiallyConfigured {
            return "Partially configured - needs completion"
        } else {
            return "Not configured"
        }
    }

    var scheduleSummary: String {
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return "\(medication) via \(method) every \(AdministrationMethod(rawValue: method)?.frequencyDays ?? 7) days"
        } else {
            return "Not configured"
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

    /// True when the dose window is open but within the grace period (not yet "Missed").
    var isDoseDueSoon: Bool {
        guard let next = nextDoseDate else { return false }
        let graceSeconds = missedDoseGracePeriodHours * 3600
        return Date() > next && Date() <= next.addingTimeInterval(graceSeconds)
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
    /// Counts calendar months that contain at least one active (taken, non-deleted)
    /// dose record. This means a user who paused for 6 months is correctly tiered
    /// based on active therapy time, not calendar span.
    var activeMonthsOnHRT: Int {
        let referenceDate = hrtStartDate ?? lastDoseDate
        guard let first = referenceDate else { return 0 }
        let activeDoses = doseHistory.filter { $0.doseStatus == DoseStatus.taken.rawValue && !$0.isDeleted }
        guard !activeDoses.isEmpty else { return monthsOnHRT }
        guard let earliestDose = activeDoses.map(\.doseDate).min() else { return monthsOnHRT }
        let start = min(first, earliestDose)
        let calendar = Calendar.current
        var monthSet = Set<String>()
        for dose in activeDoses where dose.doseDate >= start {
            let comps = calendar.dateComponents([.year, .month], from: dose.doseDate)
            monthSet.insert("\(comps.year ?? 0)-\(comps.month ?? 0)")
        }
        return max(0, monthSet.count)
    }

    /// Age at HRT start, derived from ProfileManager.dateOfBirth and hrtStartDate.
    /// Returns nil when either date is unavailable (plan §4.3).
    var ageAtHRTStart: Int? {
        guard let dob = ProfileManager.shared.dateOfBirth,
              let start = hrtStartDate else { return nil }
        let age = Calendar.current.dateComponents([.year], from: dob, to: start).year
        return age
    }

    var currentStreakDays: Int? {
        guard let last = lastDoseDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return max(0, days)
    }

    func availableMethods(for medicationType: MedicationType) -> [AdministrationMethod] {
        // For now, return all available methods
        // In a real app, this might be more sophisticated based on medication type
        return [.injectable, .cream, .oral]
    }

    func configureMedication(type: MedicationType, method: AdministrationMethod, firstDoseDate: Date) {
        updateSelection(type: type, method: method)
        recordDose(on: firstDoseDate)
    }



    // MARK: - Initialization

    init() {
        loadTransientPreferences()
        loadSelection()
        loadDoseDates()
        loadDoseHistory()
        loadBloodTestHistory()
        loadScreeningHistory()
        loadAvoidZones()
        migrateToEncryptedStorage()
        refreshState() // Initialize reactive state
        recomputeCalibrationFactors()  // re-derive α from loaded blood tests
        migrateRecordedAtForLegacyRecords()
    }

    /// Reloads all state that depends on `modelContext`.
    /// Called when `modelContext` is first assigned (which happens after `init`).
    private func reloadFromContext() {
        guard modelContext != nil else { return }
        loadDoseHistory()
        loadBloodTestHistory()
        loadScreeningHistory()
        refreshState()
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
    func lastScreening(_ type: ScreeningType) -> Date? {
        screeningRecords.first(where: { $0.type == type })?.date
    }

    /// Compact lookup table: last-done date for each screening type that has one.
    /// Passed to `TimeContentEngine` so it can flip milestone badges.
    var screeningLog: [ScreeningType: Date] {
        var dict: [ScreeningType: Date] = [:]
        for record in screeningRecords {
            let existing = dict[record.type]
            if existing == nil || record.date > existing! {
                dict[record.type] = record.date
            }
        }
        return dict
    }

    /// Adds a screening record and persists to SwiftData.
    func addScreening(date: Date, type: ScreeningType, notes: String? = nil) {
        let record = ScreeningRecord(date: date, type: type, notes: notes)
        guard !screeningRecords.contains(where: { $0.id == record.id }) else { return }
        screeningRecords.insert(record, at: 0)
        modelContext?.insert(record)
        try? modelContext?.save()
    }
    // MARK: - Dose Deletion

    func softDeleteDose(id: String) {
        guard let index = doseHistory.firstIndex(where: { $0.id == id }) else { return }

        doseHistory[index].isDeleted = true
        try? modelContext?.save()

        // Reload from SwiftData to ensure the in-memory array is consistent
        // with the persisted state – the deleted record is filtered out by loadDoseHistory.
        loadDoseHistory()

        let active = doseHistory.filter {
            $0.isActive && $0.doseStatus == DoseStatus.taken.rawValue
        }
        lastDoseDate = active.max(by: { $0.doseDate < $1.doseDate })?.doseDate
        nextDoseDate = lastDoseDate.map { calculateNextDoseDate(from: $0) }

        refreshState()
    }
    // MARK: - Regimen & Adherence Properties
    
    @Published var regimenTransitionHistory: [RegimenSegment] = []
    @Published var adherenceRate: Double? = nil
    @Published var onTimeStreak: Int = 0
    
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
