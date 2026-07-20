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
    private enum Keys {
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
    var modelContext: ModelContext?

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
    private let spiroClearanceFactor: Double = 1.15

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

    // MARK: - Ester Enums

    enum MedicationEster: String, CaseIterable {
        case valerate = "Valerate (EV)"
        case cypionate = "Cypionate (EC)"
        case oral = "Oral"
        case transdermal = "Transdermal"

        var halfLifeDays: Double {
            switch self {
            case .valerate: return 2.0
            case .cypionate: return 8.5
            case .oral: return 0.5
            case .transdermal: return 1.5
            }
        }

        /// Terminal half-life (days) is the effective clinical half-life.
        /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).
        /// For oral/transdermal, this is the elimination-dominated half-life.
        
        /// Elimination half-life of free estradiol (hours) — used for Bateman ke parameter.
        /// Free E2 is cleared rapidly; the depot ester's slow absorption dominates the terminal slope.
        var eliminationHalfLifeHours: Double {
            switch self {
            case .valerate: return 3.0
            case .cypionate: return 3.0
            case .oral: return 3.0
            case .transdermal: return 3.0
            }
        }
        
        /// Ester Weight Factor (EWF) — mg of active estradiol per mg of ester.
        /// Calculated from molecular weights: E2 base = 272.4 g/mol.
        /// EV = 356.5 g/mol → EWF = 272.4/356.5 ≈ 0.764
        /// EC = 396.6 g/mol → EWF = 272.4/396.6 ≈ 0.687
        var esterWeightFactor: Double {
            switch self {
            case .valerate: return 0.764
            case .cypionate: return 0.687
            case .oral: return 1.0      // oral is already base E2 (no ester cleavage needed)
            case .transdermal: return 1.0 // transdermal is base E2
            }
        }
        
        /// Route-specific bioavailability (fraction of administered dose reaching systemic circulation).
        /// Injectable depot: near-complete absorption from oil depot → F ≈ 1.0
        /// Oral: extensive first-pass metabolism → F ≈ 0.05
        /// Transdermal: skin barrier limits absorption → F ≈ 0.10–0.20
        var bioavailability: Double {
            switch self {
            case .valerate: return 1.0
            case .cypionate: return 1.0
            case .oral: return 0.05
            case .transdermal: return 0.15
            }
        }
        
        /// Combined effective dose factor = EWF × bioavailability.
        /// Converts administered mg of ester → systemic mg of active estradiol.
        var effectiveDoseFactor: Double {
            return esterWeightFactor * bioavailability
        }
        
        /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
        /// expected peak levels for a reference dose. Calibrated from published PK data
        /// (Düsterberg et al., Tiong et al.) so that a 2 mg dose yields the clinically
        /// observed peak E2 concentration. Recalibrated 2026‑06‑30.
        ///   - EV 2 mg → peak E2 ~250 pg/mL  (S = 3150)
        ///   - EC 2 mg → peak E2 ~180 pg/mL  (S = 2700)
        ///   - Oral 2 mg → peak E2 ~60 pg/mL (S = 12000)
        ///   - TD 1 mg → steady E2 ~50 pg/mL (S = 8000)
        var scalingConstant: Double {
            switch self {
            case .valerate: return 3150.0
            case .cypionate: return 2700.0
            case .oral: return 12000.0
            case .transdermal: return 8000.0
            }
        }

        /// DEPRECATED — kept for backward compatibility during migration.
        /// Use effectiveDoseFactor instead.
        var potencyFactor: Double {
            return effectiveDoseFactor
        }
    }

    enum TestosteroneEster: String, CaseIterable {
        case cypionate = "Cypionate (TC)"
        case enanthate = "Enanthate (TE)"
        case propionate = "Propionate (TP)"
        case undecanoate = "Undecanoate (TU)"

        var halfLifeDays: Double {
            switch self {
            case .cypionate: return 8.0
            case .enanthate: return 7.0
            case .propionate: return 1.0
            case .undecanoate: return 20.0
            }
        }

        /// Terminal half-life (days) is the effective clinical half-life.
        /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).
        
        /// Elimination half-life of free testosterone (hours) — used for Bateman ke parameter.
        /// Free T is cleared rapidly (~2 hrs); depot absorption dominates the terminal slope.
        var eliminationHalfLifeHours: Double {
            switch self {
            case .cypionate: return 2.0
            case .enanthate: return 2.0
            case .propionate: return 2.0
            case .undecanoate: return 2.0
            }
        }
        
        /// Ester Weight Factor (EWF) — mg of active testosterone per mg of ester.
        /// Calculated from molecular weights: T base = 288.4 g/mol.
        /// TC = 412.6 g/mol → EWF = 288.4/412.6 ≈ 0.699
        /// TE = 400.6 g/mol → EWF = 288.4/400.6 ≈ 0.720
        /// TP = 344.5 g/mol → EWF = 288.4/344.5 ≈ 0.837
        /// TU = 456.7 g/mol → EWF = 288.4/456.7 ≈ 0.631
        var esterWeightFactor: Double {
            switch self {
            case .cypionate: return 0.699
            case .enanthate: return 0.720
            case .propionate: return 0.837
            case .undecanoate: return 0.631
            }
        }
        
        /// Route-specific bioavailability for injectable testosterone esters.
        /// Depot injection → near-complete systemic absorption, F ≈ 1.0
        var bioavailability: Double {
            return 1.0  // all T esters here are injectable
        }
        
        /// Combined effective dose factor = EWF × bioavailability.
        var effectiveDoseFactor: Double {
            return esterWeightFactor * bioavailability
        }
        
        /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
        /// expected peak levels for a reference dose. Calibrated from published PK data:
        ///   - TC 100 mg → peak T ~600–900 ng/dL
        ///   - TE 100 mg → peak T ~600–900 ng/dL
        ///   - TP 50 mg  → peak T ~800–1200 ng/dL
        ///   - TU 1000 mg → peak T ~400–700 ng/dL (very flat profile)
        /// Used in the Bateman biexponential to convert mg → concentration.
        var scalingConstant: Double {
            switch self {
            case .cypionate: return 11.0
            case .enanthate: return 11.0
            case .propionate: return 18.0
            case .undecanoate: return 5.0
            }
        }

        /// DEPRECATED — kept for backward compatibility during migration.
        /// Use effectiveDoseFactor instead.
        var potencyFactor: Double {
            return effectiveDoseFactor
        }
    }

    enum MedicationType: String, CaseIterable {
        case estrogen = "Estrogen"
        case testosterone = "Testosterone"

        /// Intact gonadal baseline (pre‑HRT or no suppression).
        var baselineValue: Double {
            switch self {
            case .estrogen: return 100.0
            case .testosterone: return 500.0
            }
        }
        
        /// Suppressed baseline after adequate HRT duration (adrenal contribution only).
        /// Trans women on E2 + AA → T < 50 ng/dL, E2 ~5–10 pg/mL.
        /// Trans men on T → ovarian E2 suppressed, but aromatization produces some E2.
        var suppressedBaseline: Double {
            switch self {
            case .estrogen: return 5.0
            case .testosterone: return 20.0
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

    // MARK: - Dose Helpers

    /// The currently selected ester (derived from the most recent logged dose, or default).
    var currentEster: (ester: String, halfLifeDays: Double)? {
        if let medication = selectedMedication, medication == "Estrogen" {
            if let recent = doseHistory
                .first(where: { $0.isActive && $0.medicationType == medication })
            {
                if let e = MedicationEster(rawValue: recent.ester) {
                    return (recent.ester, e.halfLifeDays)
                }
            }
            // Default for new setups
            let defaultE = MedicationEster.valerate
            return (defaultE.rawValue, defaultE.halfLifeDays)
        } else if let medication = selectedMedication, medication == "Testosterone" {
            if let recent = doseHistory
                .first(where: { $0.isActive && $0.medicationType == medication })
            {
                if let e = TestosteroneEster(rawValue: recent.ester) {
                    return (recent.ester, e.halfLifeDays)
                }
            }
            let defaultE = TestosteroneEster.cypionate
            return (defaultE.rawValue, defaultE.halfLifeDays)
        }
        return nil
    }

    /// Returns the effective dose factor (EWF × bioavailability) for the currently configured ester.
    var currentPotencyFactor: Double {
        guard let medication = selectedMedication else { return 1.0 }
        if medication == "Estrogen", let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == medication })
        {
            return MedicationEster(rawValue: recent.ester)?.effectiveDoseFactor ?? 1.0
        } else if medication == "Testosterone", let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == medication })
        {
            return TestosteroneEster(rawValue: recent.ester)?.effectiveDoseFactor ?? 1.0
        }
        return 1.0
    }

    /// Returns the actual dose amount for the most recent logged dose.
    /// Falls back to default if no dose is logged.
    var actualDoseAmount: Double {
        guard let lastDose = doseHistory.last(where: { $0.isActive && $0.medicationType == selectedMedication })
        else { return (MedicationType(rawValue: selectedMedication ?? "")?.baselineValue ?? 100.0) * 0.5 }
        return lastDose.doseAmount
    }

    /// Returns the last logged dose record for the current medication.
    var lastLoggedDose: DoseRecord? {
        doseHistory.first(where: { $0.isActive && $0.medicationType == selectedMedication })
    }

    // MARK: - Concentration & Volume Helpers

    /// Returns the default vial concentration (mg/mL) for the currently selected medication type.
    /// Reads from the most recent dose's concentration, or falls back to a sensible default.
    var defaultConcentrationMgPerMl: Double? {
        // First, check the most recent dose with a recorded concentration
        if let recent = doseHistory
            .first(where: { $0.isActive && $0.medicationType == selectedMedication && $0.concentrationMgPerMl != nil })
        {
            return recent.concentrationMgPerMl
        }
        // Fall back to sensible defaults per medication type
        if selectedMedication == "Estrogen" {
            return 40.0   // EV 40 mg/mL is most common
        } else if selectedMedication == "Testosterone" {
            return 200.0  // TC 200 mg/mL is most common
        }
        return nil
    }

    /// Common vial concentrations (mg/mL) for a given ester string.
    /// Returns an array of typical concentrations, plus a sentinel for "Custom".
    static func commonConcentrations(forEster ester: String) -> [Double] {
        switch ester {
        // Estradiol esters
        case "Valerate (EV)":   return [10, 20, 40, -1]
        case "Cypionate (EC)":  return [5, 10, -1]
        // Testosterone esters
        case "Cypionate (TC)":  return [100, 200, -1]
        case "Enanthate (TE)":  return [200, 250, -1]
        case "Propionate (TP)": return [100, -1]
        case "Undecanoate (TU)": return [250, -1]
        default:                return [40, -1]
        }
    }

    /// Computes injection volume in mL from a dose amount and concentration.
    static func computedVolume(doseMg: Double, concentrationMgPerMl: Double) -> Double {
        guard concentrationMgPerMl > 0 else { return 0 }
        return doseMg / concentrationMgPerMl
    }

    /// True if the computed injection volume is below the practical measurement threshold.
    /// Volumes below 0.1 mL are extremely difficult to measure accurately even with
    /// a 0.3 mL insulin syringe.
    static func isVolumeTooSmall(_ volumeMl: Double) -> Bool {
        return volumeMl < 0.1
    }

    /// True if the volume is large enough to cause injection discomfort for frequent dosing.
    /// For long-acting esters (TU), volumes up to 4 mL are normal.
    /// For short/medium-acting esters, > 2-3 mL per injection is impractical.
    static func isVolumeTooLarge(_ volumeMl: Double, isLongActing: Bool = false) -> Bool {
        let threshold = isLongActing ? 4.5 : 2.5
        return volumeMl > threshold
    }

    /// Recommends a syringe size based on injection volume.
    static func recommendedSyringe(for volumeMl: Double) -> String {
        if volumeMl <= 0.3 {
            return "0.3 mL insulin syringe"
        } else if volumeMl <= 1.0 {
            return "1 mL syringe"
        } else if volumeMl <= 3.0 {
            return "3 mL syringe"
        } else {
            return "5 mL syringe"
        }
    }

    /// Generates a warning message (or nil) for a given volume.
    static func volumeWarning(for volumeMl: Double, ester: String? = nil) -> String? {
        let isLong = ester == "Undecanoate (TU)"
        if isVolumeTooSmall(volumeMl) {
            let syringe = recommendedSyringe(for: volumeMl)
            return "A volume of \(String(format: "%.3f", volumeMl)) mL can be difficult to measure accurately. Consider a lower-concentration formulation or a \(syringe) with unit markings."
        }
        if isVolumeTooLarge(volumeMl, isLongActing: isLong) {
            return "A volume of \(String(format: "%.1f", volumeMl)) mL is quite large — consider splitting the dose or using multiple injection sites."
        }
        return nil
    }

    // MARK: - Initialization

    init() {
        loadTransientPreferences()
        loadSelection()
        loadDoseDates()
        loadDoseHistory()
        loadBloodTestHistory()
        loadScreeningHistory()
        migrateToEncryptedStorage()
        refreshState() // Initialize reactive state
        recomputeCalibrationFactors()  // re-derive α from loaded blood tests
    }

    // MARK: - Public API (Management)

    func updateSelection(type: MedicationType, method: AdministrationMethod) {
        selectedMedication = type.rawValue
        selectedAdministrationMethod = method.rawValue
        persistSelection()

        let next = calculateNextDoseDate(from: Date())
        updateDoseDates(last: Date(), next: next)
        refreshState()
    }

    func clearSelection() {
        selectedMedication = nil
        selectedAdministrationMethod = nil
        lastDoseDate = nil
        nextDoseDate = nil
        persistSelection()
        persistDoseDates()
        refreshState()
    }

    /// Records a full dose with amount, ester, method, concentration, and optional notes.
    /// This is the primary method for logging doses going forward.
    func addDose(
        date: Date = Date(),
        type: String,
        ester: String,
        method: String,
        doseAmount: Double,
        concentrationMgPerMl: Double? = nil,
        notes: String? = nil
    ) {
        let record = DoseRecord(
            doseDate: date,
            medicationType: type,
            ester: ester,
            administrationMethod: method,
            doseAmount: doseAmount,
            concentrationMgPerMl: concentrationMgPerMl,
            notes: notes
        )

        // Don't add duplicates
        guard !doseHistory.contains(where: { $0.id == record.id }) else { return }
        doseHistory.append(record)

        // Insert into SwiftData
        modelContext?.insert(record)

        // Update simple date tracking for backward compat
        if type == selectedMedication, method == selectedAdministrationMethod {
            lastDoseDate = date
            nextDoseDate = calculateNextDoseDate(from: date)
        }

        try? modelContext?.save()
        persistDoseDates()
        refreshState()

        // Bump celebration counter so UI can react
        doseRecordedCount += 1

        // Reschedule dose reminder to next dose date (frequency-aware)
        if let next = nextDoseDate {
            NotificationManager.shared.rescheduleAfterDose(nextDoseDate: next)
        }
    }

    /// Removes a dose (soft delete — keeps it in history for audit purposes).
    func removeDose(withId id: String) {
        if let index = doseHistory.firstIndex(where: { $0.id == id }) {
            doseHistory[index].isDeleted = true
            try? modelContext?.save()
            refreshState()
        }
    }

    func recordDose(on date: Date = Date()) {
        lastDoseDate = date
        if selectedMedication != nil, selectedAdministrationMethod != nil {
            nextDoseDate = calculateNextDoseDate(from: date)
        }
        persistDoseDates()
        refreshState()

        // Reschedule dose reminder to next dose date (frequency-aware)
        if let next = nextDoseDate {
            NotificationManager.shared.rescheduleAfterDose(nextDoseDate: next)
        }
    }

    /// Logs an intentionally skipped dose. Does NOT advance `nextDoseDate`;
    /// the schedule stays anchored to the last *taken* dose. The skipped
    /// record is persisted so it shows in timelines and affects adherence rate.
    func skipDose(on date: Date = Date(), reason: String? = nil) {
        guard let medType = selectedMedication,
              let medMethod = selectedAdministrationMethod else { return }

        let ester = lastLoggedDose?.ester
            ?? (medType == "Estrogen" ? "Valerate (EV)" : "Cypionate (TC)")
        let amount = lastLoggedDose?.doseAmount
            ?? (medType == "Estrogen" ? 2.0 : 40.0)
        let concentration = lastLoggedDose?.concentrationMgPerMl

        let record = DoseRecord(
            doseDate: date,
            medicationType: medType,
            ester: ester,
            administrationMethod: medMethod,
            doseAmount: amount,
            concentrationMgPerMl: concentration,
            doseStatus: .skipped,
            skipReason: reason
        )

        guard !doseHistory.contains(where: { $0.id == record.id }) else { return }
        doseHistory.append(record)
        modelContext?.insert(record)

        // Do NOT advance lastDoseDate or nextDoseDate for skipped doses
        try? modelContext?.save()
        refreshState()
    }

    /// Calculates the next dose date using the custom frequency if set (#18),
    /// otherwise falls back to the administration method's default frequency.
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        let interval: Int
        if let custom = customFrequencyDays, custom > 0 {
            interval = custom
        } else if let methodStr = selectedAdministrationMethod,
                  let method = AdministrationMethod(rawValue: methodStr) {
            interval = method.frequencyDays
        } else {
            interval = 7
        }
        return Calendar.current.date(byAdding: .day, value: interval, to: lastDose) ?? Date()
    }

    // MARK: - Research Engine (Pharmacokinetics)
    
    /// Computes the dynamic endogenous baseline for a given medication type,
    /// accounting for HRT duration, anti‑androgen use, and gonadal suppression.
    /// 
    /// **Logic (#9, #10):**
    /// - If `hrtStartDate` is far in the past (e.g. >2 years), immediately return suppressed baseline.
    /// - If `antiAndrogenInUse` → testosterone baseline goes to near‑zero immediately.
    /// - Otherwise, saturating exponential taper: `suppressionFactor = 1.0 − exp(−2.5 × progress)`
    ///   where progress is capped at 1.0. The timescale (4/8/12 weeks) is user-configurable.
    /// - For trans men on T: E2 baseline can be estimated as ~0.2% of current T level (aromatization).
    ///
    /// - Parameter type: The medication type to compute baseline for.
    /// - Returns: The dynamic baseline level in pg/mL or ng/dL.
    func dynamicBaseline(for type: MedicationType) -> Double {
        let fullBaseline = type.baselineValue
        let suppressedBaseline = type.suppressedBaseline
        
        // Anti‑androgen overrides: suppress T aggressively (#10)
        if type == .testosterone && antiAndrogenInUse {
            return suppressedBaseline
        }
        
        // No HRT start date → assume full gonadal function
        guard let startDate = hrtStartDate ?? lastDoseDate else {
            return fullBaseline
        }
        
        let daysOnHRT = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let weeksOnHRT = Double(daysOnHRT) / 7.0
        
        // Early return: if HRT started >2 years ago, fully suppressed (#9)
        if weeksOnHRT >= 104 {  // 2 years = 104 weeks
            return suppressedBaseline
        }
        
        // Saturating exponential taper using user-configurable timescale (#9)
        let timescaleWeeks = suppressionSpeed.weeks  // 4, 8, or 12 weeks
        let progress = min(weeksOnHRT / timescaleWeeks, 1.0)
        let suppressionFactor = 1.0 - exp(-2.5 * progress)  // reaches ~92% at progress=1.0
        
        return fullBaseline + (suppressedBaseline - fullBaseline) * suppressionFactor
    }

    /// The heart of the reactivity: Recalculates everything and broadcasts changes.
    func refreshState() {
        currentHormoneLevel = getCurrentHormoneLevel()
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        recentLevels = estimatedLevels(from: start, to: end)
        recomputeRegimenHistory()
        recomputeAdherenceRate()
        recomputeOnTimeStreak()
    }

    /// Computes the expected time to peak concentration (in days) for a given ester.
    /// Uses the Bateman t_max formula: t_max = ln(ka/ke) / (ka - ke)
    /// Under flip-flop kinetics (ka ≪ ke), this simplifies to approximately 1/ka.
    /// - Parameter ester: The medication ester enum value.
    /// - Returns: Expected days to peak concentration after injection.
    func expectedTimeToPeak(for ester: MedicationEster) -> Double {
        let ka = log(2) / ester.halfLifeDays
        let ke = log(2) / (ester.eliminationHalfLifeHours / 24.0)
        guard abs(ka - ke) > 0.0001 else { return 1.0 / ka }
        return log(ka / ke) / (ka - ke)
    }
    
    /// Computes the expected time to peak concentration (in days) for a given testosterone ester.
    func expectedTimeToPeak(for tesEster: TestosteroneEster) -> Double {
        let ka = log(2) / tesEster.halfLifeDays
        let ke = log(2) / (tesEster.eliminationHalfLifeHours / 24.0)
        guard abs(ka - ke) > 0.0001 else { return 1.0 / ka }
        return log(ka / ke) / (ka - ke)
    }
    
    /// Determines where the user currently sits in their dose cycle
    /// using the actual PK curve shape (derivative‑based peak/trough detection).
    ///
    /// For injectable routes, the `recentLevels` points array is searched to find
    /// the true peak (highest value in this cycle) and true trough (lowest value
    /// just before the next scheduled dose).  The current time is then compared
    /// against those coordinates, replacing the old ±30% t_max heuristic.
    ///
    /// For non‑injectable routes, falls back to `.unknown`.
    var currentCyclePosition: CyclePosition {
        guard let medication = selectedMedication,
              let methodStr = selectedAdministrationMethod,
              let method = AdministrationMethod(rawValue: methodStr),
              method == .injectable,
              let lastDose = doseHistory
                  .filter({ $0.isActive && $0.medicationType == medication })
                  .sorted(by: { $0.doseDate > $1.doseDate })
                  .first
        else {
            return .unknown
        }

        let now = Date()
        let daysSinceDose = now.timeIntervalSince(lastDose.doseDate) / 86400.0
        let cycleLength = Double(method.frequencyDays)

        // Use the actual PK curve if we have enough data points
        let levels = recentLevels
        guard levels.count >= 3 else {
            // Fallback to theoretical t_max when no curve data is available
            let tMax: Double
            if medication == "Estrogen", let ester = MedicationEster(rawValue: lastDose.ester) {
                tMax = expectedTimeToPeak(for: ester)
            } else if medication == "Testosterone", let tesEster = TestosteroneEster(rawValue: lastDose.ester) {
                tMax = expectedTimeToPeak(for: tesEster)
            } else {
                return .unknown
            }
            let peakWindow = tMax * 0.30
            if abs(daysSinceDose - tMax) <= peakWindow { return .nearPeak }
            if daysSinceDose >= (cycleLength - 1.0) { return .trough }
            return .midCycle
        }

        // Find the true peak: highest value in the curve since last dose
        let sinceLastDose = levels.filter { $0.date >= lastDose.doseDate }
        guard let peakPoint = sinceLastDose.max(by: { $0.value < $1.value }),
              let troughPoint = sinceLastDose.filter({ $0.date >= lastDose.doseDate })
                  .min(by: { $0.value < $1.value })
        else {
            return .unknown
        }

        let peakHoursAfterDose = peakPoint.date.timeIntervalSince(lastDose.doseDate) / 3600.0
        let troughHoursAfterDose = troughPoint.date.timeIntervalSince(lastDose.doseDate) / 3600.0

        // "Near Peak" — within 24 hours after the actual peak
        let hoursSinceDose = daysSinceDose * 24.0
        let peakEnd = peakHoursAfterDose + 24.0
        if hoursSinceDose >= peakHoursAfterDose && hoursSinceDose <= peakEnd {
            return .nearPeak
        }

        // "Trough" — within the last 24 hours of the cycle OR within 24h of the actual trough
        if daysSinceDose >= (cycleLength - 1.0) ||
            (troughHoursAfterDose > 0 && abs(hoursSinceDose - troughHoursAfterDose) <= 24.0) {
            return .trough
        }

        return .midCycle
    }
    
    // MARK: - Blood Test Calibration Engine
    
    /// Adds a blood test result and computes its calibration factor.
    /// Auto‑calculates hours since last dose from the dose history.
    func addBloodTest(drawDate: Date, measuredLevel: Double, hormoneType: String, notes: String? = nil) {
        // Auto‑compute hours since last matching dose
        let hoursSince: Double? = {
            guard let lastDose = doseHistory
                .filter({ $0.isActive && $0.medicationType == hormoneType })
                .sorted(by: { $0.doseDate > $1.doseDate })
                .first
            else { return nil }
            let interval = drawDate.timeIntervalSince(lastDose.doseDate) / 3600.0  // seconds → hours
            return max(0, interval)
        }()
        
        let record = BloodTestRecord(
            drawDate: drawDate,
            measuredLevel: measuredLevel,
            hormoneType: hormoneType,
            hoursSinceLastDose: hoursSince,
            notes: notes
        )
        
        // Don't add duplicates
        guard !bloodTestHistory.contains(where: { $0.id == record.id }) else { return }
        bloodTestHistory.append(record)
        modelContext?.insert(record)
        try? modelContext?.save()
        
        // Compute calibration factor for this new record
        computeCalibrationFactor(for: record)
        refreshState()
    }
    
    /// Removes a blood test record (soft delete pattern — keep for audit).
    func removeBloodTest(withId id: String) {
        if let index = bloodTestHistory.firstIndex(where: { $0.id == id }) {
            modelContext?.delete(bloodTestHistory[index])
            bloodTestHistory.remove(at: index)
            try? modelContext?.save()
            refreshState()
        }
    }
    
    /// Computes α = measured / predicted for a single blood test record.
    /// Runs the PK model at the draw date to get the predicted value,
    /// then stores the ratio.  If predicted ≈ 0, clamps to a sane range.
    func computeCalibrationFactor(for record: BloodTestRecord) {
        guard let medication = selectedMedication,
              let _ = selectedAdministrationMethod,
              medication == record.hormoneType
        else { return }
        
        // Run model at the exact draw time (± 1 hour window)
        let modelPoints = estimatedLevels(
            from: record.drawDate.addingTimeInterval(-1800),
            to: record.drawDate.addingTimeInterval(1800),
            stepDays: 1
        )
        guard let predicted = modelPoints.last?.value, predicted > 0.01 else {
            record.calibrationFactor = nil
            return
        }
        
        let alpha = record.measuredLevel / predicted
        // Clamp to clinically plausible range (0.2 – 5.0×)
        record.calibrationFactor = max(0.2, min(5.0, alpha))
    }
    
    /// Recomputes calibration factors for all blood test records.
    /// Called on init and whenever the model parameters change significantly.
    func recomputeCalibrationFactors() {
        for record in bloodTestHistory {
            computeCalibrationFactor(for: record)
        }
    }
    
    /// Loads blood test history from SwiftData.
    func loadBloodTestHistory() {
        guard let context = modelContext else { return }
        let descriptor = SortDescriptor<BloodTestRecord>(\BloodTestRecord.drawDate, order: .reverse)
        let fetchDescriptor = FetchDescriptor<BloodTestRecord>(sortBy: [descriptor])
        let allRecords = try? context.fetch(fetchDescriptor)
        bloodTestHistory = allRecords ?? []
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
    
    // MARK: - Layer 1: Time-Contextual + Dose-Scaled Targets
    
    /// Returns a context-aware target range that accounts for cycle position AND dose intensity.
    /// When the user has set personal therapeutic targets, those override the clinical defaults.
    func contextualRange(for medication: MedicationType,
                         at position: CyclePosition,
                         doseIntensity: Double) -> (label: String, min: Double, max: Double) {
        
        // Base clinical targets (for a "standard" dose, intensity ≈ 1.0)
        let base: (peakMin: Double, peakMax: Double, troughMin: Double, troughMax: Double)
        let isEstrogen = medication == .estrogen
        
        if isEstrogen {
            base = (peakMin: 200, peakMax: 600,
                    troughMin: 100, troughMax: 250)
        } else {
            base = (peakMin: 600, peakMax: 1200,
                    troughMin: 400, troughMax: 700)
        }
        
        // Scale targets by the user's relative dose intensity
        let scale = max(doseIntensity, 0.25)  // floor at 0.25× to prevent pathological low targets
        let scaledPeakMin = base.peakMin * scale
        let scaledPeakMax = base.peakMax * scale
        // Trough doesn't scale linearly with dose; cap at 1.5×
        let troughScale = min(scale, 1.5)
        let scaledTroughMin = base.troughMin * troughScale
        let scaledTroughMax = base.troughMax * troughScale
        
        // If user has set personal therapeutic targets, use those as the trough reference
        let troughMin: Double
        let troughMax: Double
        let peakCeiling: Double
        let labelPrefix: String
        
        if let userTarget = userTherapeuticTarget {
            troughMin = userTarget.troughMin
            troughMax = userTarget.troughMax
            peakCeiling = userTarget.peakCeiling
            labelPrefix = "Your Target"
        } else {
            troughMin = scaledTroughMin
            troughMax = scaledTroughMax
            peakCeiling = scaledPeakMax
            labelPrefix = ""
        }
        
        switch position {
        case .nearPeak:
            let label = labelPrefix.isEmpty ? "Expected Peak" : "\(labelPrefix) (Peak)"
            return (label, scaledPeakMin, peakCeiling)
        case .trough:
            let label = labelPrefix.isEmpty ? "Target Trough" : "\(labelPrefix) (Trough)"
            return (label, troughMin, troughMax)
        case .midCycle:
            // Interpolate between trough and peak targets
            let midMin = (troughMin + scaledPeakMin) / 2
            let midMax = (troughMax + peakCeiling) / 2
            let label = labelPrefix.isEmpty ? "Mid-Cycle Range" : "\(labelPrefix) (Mid)"
            return (label, midMin, midMax)
        case .unknown:
            let label = labelPrefix.isEmpty ? "Optimal" : labelPrefix
            // Fallback: use trough for safety
            return (label, troughMin, peakCeiling)
        }
    }
    
    // MARK: - Layer 2: Deviation from Model Prediction
    
    /// Compares the actual (calibrated) level to the raw population-model prediction.
    /// Tells the user whether their body is responding as expected, slower, or faster.
    func deviationClassification(actual: Double, predicted: Double) -> (label: String, emoji: String) {
        guard predicted > 1.0 else {
            return ("Unable to Compare", "·")
        }
        let ratio = actual / predicted
        switch ratio {
        case 0.0..<0.5:  return ("Critically Below Expected", "⚠️")
        case 0.5..<0.7:  return ("Below Expected", "⬇️")
        case 0.7..<1.3:  return ("On Track", "✅")
        case 1.3..<2.0:  return ("Above Expected", "⬆️")
        default:          return ("Unusually High", "🛑")
        }
    }
    
    // MARK: - Layer 4: Clinical Safety & Interaction Flags
    
    /// Returns an override label if the level triggers a clinical safety concern.
    /// These fire AFTER the main classification and take precedence over contextual labels.
    func safetyOverride(level: Double, medication: MedicationType, contextLabel: String) -> String? {
        // Estrogen safety ceiling
        if medication == .estrogen && level > 1000 {
            return "Very High – Safety Check"
        }
        // Testosterone supra-physiological
        if medication == .testosterone && level > 1500 {
            return "Supraphysiological"
        }
        // E2 < 50 pg/mL at trough is sub-therapeutic (on therapy)
        if medication == .estrogen && level < 50 && contextLabel.contains("Trough") {
            return "Sub-Therapeutic (Trough)"
        }
        // Spironolactone interaction: E2 < 80 pg/mL may indicate accelerated clearance
        if medication == .estrogen && spironolactoneInUse && level < 80 && contextLabel.contains("Trough") {
            return "Low (Spiro May Increase Clearance)"
        }
        return nil
    }
    
    // MARK: - Unified Hormone Level Pipeline (All 4 Layers)
    
    /// Computes the current hormone level with contextual, dose-aware, deviation-informed,
    /// and safety-checked classification. Replaces the old static-range lookup.
    func getCurrentHormoneLevel() -> HormoneLevel? {
        guard let medication = selectedMedication,
              let _ = selectedAdministrationMethod else { return nil }
        
        let medicationEnum = MedicationType(rawValue: medication)
        let unit = medicationEnum == .estrogen ? "pg/mL" : "ng/dL"
        let now = Date()
        
        // 1. Get actual calibrated level (PK model with α applied)
        let calibratedPoints = estimatedLevels(from: now.addingTimeInterval(-3600), to: now,
                                                applyCalibration: true)
        guard let calibratedLevel = calibratedPoints.last else { return nil }
        let actual = calibratedLevel.value
        
        // 2. Get raw predicted level (PK model without α) for deviation analysis
        let rawPoints = estimatedLevels(from: now.addingTimeInterval(-3600), to: now,
                                         applyCalibration: false)
        let predicted = rawPoints.last?.value ?? actual
        let deviation = deviationClassification(actual: actual, predicted: predicted)
        
        // 3. Get cycle context + dose intensity
        let position = currentCyclePosition
        let intensity = relativeDoseIntensity
        let (contextLabel, minTarget, maxTarget) = contextualRange(for: medicationEnum ?? .estrogen,
                                                                    at: position,
                                                                    doseIntensity: intensity)
        
        // 4. Determine where actual sits relative to the contextual target
        let status: String
        if actual < minTarget * 0.5 {
            status = "Critically Low"
        } else if actual < minTarget * 0.8 {
            status = "Very Low"
        } else if actual < minTarget {
            status = "Slightly Below Target"
        } else if actual <= maxTarget {
            status = "On Target"
        } else if actual <= maxTarget * 1.3 {
            status = "Slightly Above Target"
        } else {
            status = "High"
        }
        
        // 5. Safety overrides (take precedence over contextual status)
        let safetyLabel = safetyOverride(level: actual, medication: medicationEnum ?? .estrogen,
                                          contextLabel: contextLabel)
        let positionSuffix = position != .unknown ? " · \(position.rawValue)" : ""
        let finalLabel: String
        if let safety = safetyLabel {
            finalLabel = "\(safety)\(positionSuffix)"
        } else if deviation.label.contains("Below") || deviation.label.contains("Above") {
            finalLabel = "\(status) · \(contextLabel) · \(deviation.label)\(positionSuffix)"
        } else {
            finalLabel = "\(status) · \(contextLabel)\(positionSuffix)"
        }
        
        // 6. Build rich explanation
        let explanation = buildExplanation(
            actual: actual, unit: unit, status: status,
            contextLabel: contextLabel, minTarget: minTarget, maxTarget: maxTarget,
            position: position, deviation: deviation,
            medication: medicationEnum ?? .estrogen
        )
        
        return HormoneLevel(
            value: actual,
            unit: unit,
            range: finalLabel,
            explanation: explanation
        )
    }
    
    /// Constructs a plain-language explanation of the user's current hormone status.
    private func buildExplanation(actual: Double, unit: String, status: String,
                                   contextLabel: String, minTarget: Double, maxTarget: Double,
                                   position: CyclePosition, deviation: (label: String, emoji: String),
                                   medication: MedicationType) -> String {
        let levelStr = String(format: "%.0f", actual)
        var parts: [String] = []
        
        // Opening: what the level is
        parts.append("Your level is \(levelStr) \(unit)")
        
        // Cycle position context
        switch position {
        case .nearPeak:
            parts.append("near your peak")
        case .trough:
            parts.append("at trough")
        case .midCycle:
            parts.append("at mid-cycle")
        case .unknown:
            break
        }
        
        // Status interpretation
        switch status {
        case "Critically Low":
            parts.append("— far below your target of \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
            if deviation.label.contains("Below Expected") {
                parts.append("This is significantly below what the model expects. Consider a dose review or blood test.")
            } else {
                parts.append("Consult your provider about a potential dose adjustment.")
            }
        case "Very Low", "Slightly Below Target":
            parts.append("— under your \(contextLabel.lowercased()) of \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
            if deviation.label.contains("Below Expected") {
                parts.append("Your body may be clearing faster than average. A blood test could clarify.")
            } else {
                parts.append("You may want to discuss a small increase with your provider.")
            }
        case "On Target":
            parts.append("— right within your \(contextLabel.lowercased()) of \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
            parts.append("Continue your current regimen. \(deviation.emoji)")
        case "Slightly Above Target":
            parts.append("— slightly above your \(contextLabel.lowercased()) of \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
            if position == .nearPeak {
                parts.append("This is expected near peak — no concern.")
            } else {
                parts.append("Monitor for any side effects.")
            }
        case "High":
            parts.append("— well above your \(contextLabel.lowercased()) of \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
            if position == .nearPeak {
                parts.append("Peak levels run high; ensure your trough stays in range.")
            } else if medication == .estrogen && actual > 1000 {
                parts.append("Levels above 1,000 pg/mL carry an elevated thromboembolic risk. Contact your provider.")
            } else if medication == .testosterone && actual > 1500 {
                parts.append("Supraphysiological levels increase polycythemia risk. Consider a dose reduction.")
            } else {
                parts.append("Consider a dose review with your provider.")
            }
        default:
            parts.append("— your \(contextLabel.lowercased()) is \(Int(minTarget))–\(Int(maxTarget)) \(unit).")
        }
        
        return parts.joined(separator: " ")
    }

    /// Pharmacokinetic model: superposition of individual dose contributions.
    ///
    /// **Injectable routes** use the Bateman biexponential function (first‑order absorption
    /// from depot + first‑order elimination of free hormone), producing a realistic
    /// rise‑to‑peak followed by decay:
    ///
    /// \[ C_i(t) = D_i^{\text{eff}} \cdot S \cdot \frac{k_a}{k_a - k_e}\bigl(e^{-k_e \Delta t} - e^{-k_a \Delta t}\bigr) \]
    ///
    /// where \(k_a = \ln 2 / t_{1/2,\text{term}}\) (absorption‑limited terminal slope),
    /// \(k_e = \ln 2 / t_{1/2,\text{elim}}\) (free‑hormone clearance),
    /// \(S\) = pre‑tuned scaling constant, \(D_i^{\text{eff}}\) = dose × EWF × bioavailability.
    ///
    /// **Oral/transdermal routes** use the simpler single‑exponential model
    /// (instant release → elimination), as the absorption profile is different
    /// and flip‑flop kinetics do not dominate.
    ///
    /// Falls back to estimated dose history if no doses are logged yet.
    func estimatedLevels(from start: Date, to end: Date, stepDays: Int = 1,
                         applyCalibration: Bool = true) -> [EstimatedPoint] {
        guard let medication = selectedMedication,
              let methodStr = selectedAdministrationMethod else { return [] }

        var points = [EstimatedPoint]()
        var cursor = start
        let calendar = Calendar.current

        let medicationEnum = MedicationType(rawValue: medication)
        let baseLevel: Double = medicationEnum.map { dynamicBaseline(for: $0) } ?? 100.0
        let alpha = (applyCalibration ? (calibrationFactor ?? 1.0) : 1.0)  // user‑specific calibration multiplier
        
        // Determine if we should use the Bateman biexponential (injectable) or
        // the simpler single‑exponential (oral/transdermal)
        let isInjectable = AdministrationMethod(rawValue: methodStr) == .injectable
        
        // Get the most recent active dose for logging context
        _ = doseHistory
            .filter { $0.isActive && $0.medicationType == medication }
            .sorted { $0.doseDate > $1.doseDate }
            .first
        
        // Resolve default ester info for fallback
        let defaultEsterName: String
        let defaultHalfLife: Double
        if medication == "Estrogen" {
            let def = MedicationEster.valerate
            defaultEsterName = def.rawValue
            defaultHalfLife = def.halfLifeDays
        } else {
            let def = TestosteroneEster.cypionate
            defaultEsterName = def.rawValue
            defaultHalfLife = def.halfLifeDays
        }

        // ------ Build dose events with per‑dose PK parameters ------
        // Each event carries: date, effective amount, absorption ka, elimination ke, scaling constant.
        struct DoseEvent {
            let date: Date
            let amount: Double       // effective systemic dose (mg = dose × EWF × F)
            let ka: Double           // absorption rate constant (days⁻¹)
            let ke: Double           // elimination rate constant (days⁻¹)
            let scaling: Double      // pre‑tuned F/Vd constant
        }
        
        var doseEvents: [DoseEvent] = []
        
        /// Helper to extract PK parameters for a given ester string.
        /// Applies spironolactone clearance adjustment to ke when applicable.
        func pkParams(ester: String, medication: String) -> (ka: Double, ke: Double, scaling: Double)? {
            if medication == "Estrogen", let e = MedicationEster(rawValue: ester) {
                let ka = log(2) / e.halfLifeDays
                var ke = log(2) / (e.eliminationHalfLifeHours / 24.0)
                // Spironolactone CYP3A4 induction → ~15% faster E2 clearance (#12)
                // Only applied when the user has opted in via settings.
                if spironolactoneInUse && spironolactoneClearanceEnabled { ke *= spiroClearanceFactor }
                return (ka, ke, e.scalingConstant)
            } else if medication == "Testosterone", let e = TestosteroneEster(rawValue: ester) {
                let ka = log(2) / e.halfLifeDays
                let ke = log(2) / (e.eliminationHalfLifeHours / 24.0)
                return (ka, ke, e.scalingConstant)
            }
            return nil
        }
        
        if !doseHistory.isEmpty {
            let activeDoses = doseHistory
                .filter { $0.isActive && $0.medicationType == medication }
                .sorted { $0.doseDate < $1.doseDate }
            
            for dose in activeDoses {
                let effAmount = dose.doseAmount * dosePotencyFactor(for: dose)
                let isOralRoute = dose.administrationMethod == "Oral"
                let isTransdermalRoute = dose.administrationMethod == "Cream"
                
                if isInjectable, let pk = pkParams(ester: dose.ester, medication: medication) {
                    // Depot injectable: full Bateman biexponential
                    doseEvents.append(DoseEvent(date: dose.doseDate, amount: effAmount,
                                                ka: pk.ka, ke: pk.ke, scaling: pk.scaling))
                } else if isOralRoute {
                    // Oral: fast Bateman with ka = 2.5 d⁻¹ (≈1h absorption), ke = 1.386 d⁻¹
                    // Models the rapid spike ~1‑2h after ingestion followed by fast drop
                    let oralKa = 2.5
                    let oralKe = 1.386   // ln(2) / 0.5d elimination half-life
                    var oralScaling: Double = 12000.0
                    if medication == "Estrogen", let e = MedicationEster(rawValue: dose.ester) {
                        oralScaling = e.scalingConstant  // already calibrated for oral
                    }
                    doseEvents.append(DoseEvent(date: dose.doseDate, amount: effAmount,
                                                ka: oralKa, ke: oralKe, scaling: oralScaling))
                } else if isTransdermalRoute {
                    // Transdermal: 24h square-wave via hourly micro‑doses
                    // Each micro‑dose = effAmount / 24, spread over 24 hours from application
                    let microAmount = effAmount / 24.0
                    let tdKa = log(2) / 1.5     // 1.5d terminal half-life for transdermal
                    var tdScaling: Double = 8000.0
                    if medication == "Estrogen", let e = MedicationEster(rawValue: dose.ester) {
                        tdScaling = e.scalingConstant
                    }
                    for hour in 0..<24 {
                        let microDate = dose.doseDate.addingTimeInterval(Double(hour) * 3600.0)
                        doseEvents.append(DoseEvent(date: microDate, amount: microAmount,
                                                    ka: tdKa, ke: 0.0, scaling: tdScaling))
                    }
                } else {
                    // Generic fallback: single‑exponential
                    let halfLife: Double
                    if medication == "Estrogen", let e = MedicationEster(rawValue: dose.ester) {
                        halfLife = e.halfLifeDays
                    } else if medication == "Testosterone", let e = TestosteroneEster(rawValue: dose.ester) {
                        halfLife = e.halfLifeDays
                    } else {
                        halfLife = defaultHalfLife
                    }
                    let ka = log(2) / halfLife
                    doseEvents.append(DoseEvent(date: dose.doseDate, amount: effAmount,
                                                ka: ka, ke: 0.0, scaling: 1.0))
                }
            }
        } else {
            // Fallback: estimate doses from lastDoseDate using frequency
            if let last = lastDoseDate {
                let lookbackStart = calendar.date(byAdding: .day, value: -60, to: start) ?? start
                var d = last
                let accumulatedDose = baseLevel * 0.5
                if isInjectable, let pk = pkParams(ester: defaultEsterName, medication: medication) {
                    while d >= lookbackStart {
                        doseEvents.append(DoseEvent(date: d, amount: accumulatedDose,
                                                    ka: pk.ka, ke: pk.ke, scaling: pk.scaling))
                        let prev = calendar.date(byAdding: .day, value: -7, to: d) ?? d
                        if prev >= last { break }
                        d = prev
                    }
                } else {
                    let lam = log(2) / defaultHalfLife
                    while d >= lookbackStart {
                        doseEvents.append(DoseEvent(date: d, amount: accumulatedDose,
                                                    ka: lam, ke: 0.0, scaling: 1.0))
                        let prev = calendar.date(byAdding: .day, value: -7, to: d) ?? d
                        if prev >= last { break }
                        d = prev
                    }
                }
            }
        }
        doseEvents.sort { $0.date < $1.date }

        // ------ Cursor iteration: sum contributions at each time point ------
        while cursor <= end {
            var cumulativeSpike = 0.0
            for event in doseEvents {
                let dt = cursor.timeIntervalSince(event.date) / 86400.0  // days since dose
                if dt < 0 { continue }  // future doses not yet administered
                
                if isInjectable && event.ke > 0 {
                    // Bateman biexponential for depot injectables
                    let denom = event.ka - event.ke
                    if abs(denom) < 0.0001 {
                        // ka ≈ ke edge case: use limit approximation
                        cumulativeSpike += event.amount * event.scaling * event.ka * dt * exp(-event.ka * dt)
                    } else {
                        cumulativeSpike += event.amount * event.scaling *
                            (event.ka / denom) * (exp(-event.ke * dt) - exp(-event.ka * dt))
                    }
                } else {
                    // Simple single‑exponential for oral/transdermal / fallback
                    cumulativeSpike += event.amount * exp(-event.ka * dt)
                }
            }
            let rawValue = baseLevel + cumulativeSpike
            let calibratedValue = rawValue * alpha
            points.append(EstimatedPoint(date: cursor, value: calibratedValue,
                                         medication: medication, method: methodStr))
            cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor) ?? cursor
        }
        return points
    }
    
    /// Returns the effective dose factor (EWF × bioavailability) for a specific dose record.
    private func dosePotencyFactor(for dose: DoseRecord) -> Double {
        if dose.medicationType == "Estrogen", let ester = MedicationEster(rawValue: dose.ester) {
            return ester.effectiveDoseFactor
        } else if dose.medicationType == "Testosterone", let tesEster = TestosteroneEster(rawValue: dose.ester) {
            return tesEster.effectiveDoseFactor
        }
        return 1.0
    }

    func estimatedRecentLevels(days: Int = 90) -> [EstimatedPoint] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return estimatedLevels(from: start, to: end)
    }
    
    // MARK: - Regimen Transition Tracking (#3)
    
    /// A contiguous time segment where ester, doseAmount, and administrationMethod
    /// were all identical. Computed from doseHistory on each refreshState().
    struct RegimenSegment: Identifiable {
        let id = UUID()
        let startDate: Date
        let endDate: Date?                       // nil = ongoing (most recent segment)
        let ester: String
        let doseAmount: Double
        let administrationMethod: String
        let concentrationMgPerMl: Double?
        let previousConcentrationMgPerMl: Double?  // concentration JUST before this segment
    }
    
    /// Regimen transition history, computed by grouping consecutive doses (#3).
    /// A new segment is created whenever ester, doseAmount, or administrationMethod changes.
    /// Concentration changes are flagged within the segment.
    @Published var regimenTransitionHistory: [RegimenSegment] = []
    
    /// Recomputes regimenTransitionHistory from doseHistory.
    /// Called inside refreshState().
    func recomputeRegimenHistory() {
        let activeDoses = doseHistory
            .filter { $0.isActive && $0.medicationType == (selectedMedication ?? "") }
            .sorted { $0.doseDate < $1.doseDate }
        
        guard !activeDoses.isEmpty else {
            regimenTransitionHistory = []
            return
        }
        
        var segments: [RegimenSegment] = []
        var currentStart = activeDoses[0].doseDate
        var currentEster = activeDoses[0].ester
        var currentAmount = activeDoses[0].doseAmount
        var currentMethod = activeDoses[0].administrationMethod
        var currentConc = activeDoses[0].concentrationMgPerMl
        var previousConc: Double? = nil
        
        for i in 1..<activeDoses.count {
            let dose = activeDoses[i]
            let esterChanged = dose.ester != currentEster
            let amountChanged = abs(dose.doseAmount - currentAmount) > 0.01
            let methodChanged = dose.administrationMethod != currentMethod
            
            if esterChanged || amountChanged || methodChanged {
                // Close the current segment
                segments.append(RegimenSegment(
                    startDate: currentStart,
                    endDate: activeDoses[i-1].doseDate,
                    ester: currentEster,
                    doseAmount: currentAmount,
                    administrationMethod: currentMethod,
                    concentrationMgPerMl: currentConc,
                    previousConcentrationMgPerMl: previousConc
                ))
                // Start a new segment
                previousConc = currentConc
                currentStart = dose.doseDate
                currentEster = dose.ester
                currentAmount = dose.doseAmount
                currentMethod = dose.administrationMethod
                currentConc = dose.concentrationMgPerMl
            } else {
                // Check for concentration change within same segment
                if let newConc = dose.concentrationMgPerMl, newConc != currentConc {
                    // Close segment at concentration change
                    segments.append(RegimenSegment(
                        startDate: currentStart,
                        endDate: activeDoses[i-1].doseDate,
                        ester: currentEster,
                        doseAmount: currentAmount,
                        administrationMethod: currentMethod,
                        concentrationMgPerMl: currentConc,
                        previousConcentrationMgPerMl: previousConc
                    ))
                    previousConc = currentConc
                    currentStart = dose.doseDate
                    currentConc = newConc
                } else {
                    currentConc = dose.concentrationMgPerMl ?? currentConc
                }
            }
        }
        
        // Final (ongoing) segment
        segments.append(RegimenSegment(
            startDate: currentStart,
            endDate: nil,
            ester: currentEster,
            doseAmount: currentAmount,
            administrationMethod: currentMethod,
            concentrationMgPerMl: currentConc,
            previousConcentrationMgPerMl: previousConc
        ))
        
        regimenTransitionHistory = segments
    }
    
    /// Human-readable summary of regimen transitions (e.g., "Jun 1 – Jun 20: EV 2.0 mg | Jun 21 – Present: EC 4.0 mg")
    var regimenTimelineSummary: String {
        guard !regimenTransitionHistory.isEmpty else { return "No regimen history yet." }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return regimenTransitionHistory.map { segment in
            let start = df.string(from: segment.startDate)
            let end = segment.endDate.map { df.string(from: $0) } ?? "Present"
            let concInfo = segment.concentrationMgPerMl.map { " @ \(String(format: "%.0f", $0)) mg/mL" } ?? ""
            return "\(start) – \(end): \(segment.ester) \(String(format: "%.1f", segment.doseAmount)) mg\(concInfo)"
        }.joined(separator: " | ")
    }
    
    // MARK: - Monthly Adherence Rate (#2)
    
    /// Monthly adherence rate: taken doses / scheduled doses in the last 30 days.
    /// Skipped and missed doses count against the numerator; only .taken doses qualify.
    /// Returns a value between 0.0 and 1.0, or nil if no dosing schedule is configured.
    @Published var adherenceRate: Double? = nil
    
    func recomputeAdherenceRate() {
        guard selectedMedication != nil, selectedAdministrationMethod != nil else {
            adherenceRate = nil
            return
        }
        
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        
        // Count taken doses in the last 30 days
        let takenDoses = doseHistory
            .filter { $0.isActive && $0.medicationType == (selectedMedication ?? "") }
            .filter { $0.doseDate >= thirtyDaysAgo && $0.doseDate <= now }
            .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
            .count
        
        // Calculate how many doses SHOULD have been scheduled in the last 30 days
        let intervalDays: Double = {
            if let custom = customFrequencyDays, custom > 0 { return Double(custom) }
            if let methodStr = selectedAdministrationMethod,
               let method = AdministrationMethod(rawValue: methodStr) {
                return Double(method.frequencyDays)
            }
            return 7
        }()
        
        let scheduledCount = max(1, Int(ceil(30.0 / intervalDays)))
        let rate = min(1.0, Double(takenDoses) / Double(scheduledCount))
        adherenceRate = rate
    }
    
    // MARK: - On-Time Streak (#20)
    
    /// Consecutive doses taken within the grace period, scanning backwards from now.
    /// For daily dosing, grace = ±12h; for weekly, grace = ±1 day.
    @Published var onTimeStreak: Int = 0
    
    func recomputeOnTimeStreak() {
        guard selectedMedication != nil else {
            onTimeStreak = 0
            return
        }
        
        let activeDoses = doseHistory
            .filter { $0.isActive && $0.medicationType == (selectedMedication ?? "") }
            .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
            .sorted { $0.doseDate > $1.doseDate }  // most recent first
        
        guard !activeDoses.isEmpty else {
            onTimeStreak = 0
            return
        }
        
        // Determine grace window based on dosing frequency
        let intervalDays: Double = {
            if let custom = customFrequencyDays, custom > 0 { return Double(custom) }
            if let methodStr = selectedAdministrationMethod,
               let method = AdministrationMethod(rawValue: methodStr) {
                return Double(method.frequencyDays)
            }
            return 7
        }()
        let graceHours = intervalDays <= 1 ? 12.0 : 24.0  // ±12h for daily, ±1d for weekly+
        
        var streak = 1  // most recent dose counts
        for i in 1..<activeDoses.count {
            let expectedInterval = activeDoses[i-1].doseDate.timeIntervalSince(activeDoses[i].doseDate)
            let expectedDays = intervalDays * 86400.0
            let deviation = abs(expectedInterval - expectedDays) / 3600.0  // in hours
            
            if deviation <= graceHours {
                streak += 1
            } else {
                break  // streak broken
            }
        }
        
        onTimeStreak = streak
    }
    
    // MARK: - Dynamic Blood-Test Scheduling (#14)
    
    /// Returns the suggested month for the next blood test based on actual lab history.
    /// If a test exists within the last 2.5 months, suggests 3 months after that draw.
    /// Otherwise falls back to the next multiple of 3 months from HRT start.
    var suggestedBloodTestMonth: Int {
        let now = Date()
        let twoAndHalfMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        // Actually use 2.5 months = ~75 days ago
        let cutoff = Calendar.current.date(byAdding: .day, value: -75, to: now) ?? now
        
        // Check for a recent blood test
        if let mostRecentTest = bloodTestHistory
            .filter({ $0.hormoneType == (selectedMedication ?? "") })
            .sorted(by: { $0.drawDate > $1.drawDate })
            .first,
           mostRecentTest.drawDate >= cutoff {
            // Suggest 3 months after most recent draw
            let nextDraw = Calendar.current.date(byAdding: .month, value: 3, to: mostRecentTest.drawDate) ?? now
            let monthsFromNow = Calendar.current.dateComponents([.month], from: now, to: nextDraw).month ?? 3
            return max(monthsFromNow, 1)
        }
        
        // Fallback: next multiple of 3 months from HRT start
        let m = monthsOnHRT
        return ((m / 3) + 1) * 3
    }
    
    /// Human-readable blood-test scheduling text (#14).
    var bloodTestSchedulingText: String {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -75, to: now) ?? now
        
        if let mostRecentTest = bloodTestHistory
            .filter({ $0.hormoneType == (selectedMedication ?? "") })
            .sorted(by: { $0.drawDate > $1.drawDate })
            .first,
           mostRecentTest.drawDate >= cutoff {
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            let monthsAway = suggestedBloodTestMonth
            return "Your last test was \(df.string(from: mostRecentTest.drawDate)). Schedule your next one in \(monthsAway) month\(monthsAway == 1 ? "" : "s")."
        }
        return "Schedule your next blood test around month \(suggestedBloodTestMonth)."
    }
    
    // MARK: - Dose Intensity Scaling (#13)
    
    /// Average dose over the last 3 months, divided by a standard starting dose.
    /// Used to scale the unlock speed of expected changes.
    var relativeDoseIntensity: Double {
        let now = Date()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        
        let recentDoses = doseHistory
            .filter { $0.isActive && $0.medicationType == (selectedMedication ?? "") }
            .filter { $0.doseDate >= threeMonthsAgo && $0.doseDate <= now }
            .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
        
        guard !recentDoses.isEmpty else { return 1.0 }
        
        let avgDose = recentDoses.map(\.doseAmount).reduce(0, +) / Double(recentDoses.count)
        
        // Standard starting doses
        let standardDose: Double = selectedMedication == "Estrogen" ? 2.0 : 50.0
        guard standardDose > 0 else { return 1.0 }
        
        return avgDose / standardDose
    }
    
    /// The progress scaling factor applied to change unlock timelines (#13).
    /// < 0.5 intensity → 0.8× speed (20% slower)
    /// > 1.5 intensity → 1.1× speed (10% faster)
    var doseIntensityProgressScale: Double {
        let intensity = relativeDoseIntensity
        if intensity < 0.5 { return 0.8 }
        if intensity > 1.5 { return 1.1 }
        return 1.0
    }
    
    /// Disclaimer text shown below the "Changes Unlocked" section (#13).
    var doseIntensityDisclaimer: String? {
        let intensity = relativeDoseIntensity
        if intensity < 0.5 {
            return "Your dose is lower than the standard starting dose. Changes may develop more gradually."
        }
        if intensity > 1.5 {
            return "Your dose is higher than typical — timelines may accelerate slightly. Monitor for side effects."
        }
        return "Timelines are typical for standard doses; individual results vary."
    }
    
    // MARK: - Aromatization Estimator (Trans Men)
    
    /// Estimated estradiol level derived from aromatization of exogenous testosterone.
    /// A small fraction of circulating T is converted to E2 via aromatase.
    /// Clinical data suggest ~0.2% conversion (0.002 × T_ng/dL ≈ E2_pg/mL).
    /// This helps trans men monitor whether their E2 is in the male reference range (10‑40 pg/mL).
    ///
    /// - Parameter testosteroneLevel: Current T level in ng/dL.
    /// - Returns: Estimated E2 level in pg/mL from aromatization.
    func estimatedE2FromTestosterone(_ testosteroneLevel: Double) -> Double {
        return testosteroneLevel * 0.002
    }
    
    /// Checks whether aromatization‑derived E2 is within the male reference range.
    /// Returns a tuple with the estimated E2, whether it's elevated, and a clinical note.
    func aromatizationAssessment(for testosteroneLevel: Double) -> (e2: Double, isElevated: Bool, note: String) {
        let e2 = estimatedE2FromTestosterone(testosteroneLevel)
        let isElevated = e2 > 40.0
        
        let note: String
        if isElevated {
            note = "Estimated E2 from aromatization may exceed the male reference range (10–40 pg/mL)."
        } else if e2 < 10.0 {
            note = "Estimated E2 is below the typical male range — unlikely to cause issues."
        } else {
            note = "Estimated E2 is within the typical male reference range (10–40 pg/mL)."
        }
        
        return (e2, isElevated, note)
    }

    // MARK: - Persistence (Private)

    func updateDoseDates(last: Date?, next: Date?) {
        lastDoseDate = last
        nextDoseDate = next
        persistDoseDates()
    }

    /// Loads transient preferences from UserDefaults that are persisted via didSet.
    /// Called during init() and rehydrateManagers() to restore snapshotted state.
    func loadTransientPreferences() {
        let defaults = UserDefaults.standard
        antiAndrogenInUse = defaults.bool(forKey: Keys.antiAndrogenInUse)
        spironolactoneInUse = defaults.bool(forKey: Keys.spironolactoneInUse)
        spironolactoneClearanceEnabled = defaults.bool(forKey: Keys.spironolactoneClearanceEnabled)
        if let raw = defaults.string(forKey: Keys.suppressionSpeed) {
            suppressionSpeed = SuppressionSpeed(rawValue: raw) ?? .fast
        }
        if defaults.object(forKey: Keys.customFrequencyDays) != nil {
            customFrequencyDays = defaults.integer(forKey: Keys.customFrequencyDays)
        }
        if defaults.object(forKey: Keys.missedDoseGracePeriodHours) != nil {
            missedDoseGracePeriodHours = defaults.double(forKey: Keys.missedDoseGracePeriodHours)
        }
        if let data = defaults.data(forKey: Keys.userTherapeuticTarget),
           let target = try? JSONDecoder().decode(TherapeuticTarget.self, from: data) {
            userTherapeuticTarget = target
        }
    }

    func loadSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedMedicationSelection"),
           let decrypted = try? security.decryptData(data),
           let str = String(data: decrypted, encoding: .utf8) {
            let parts = str.components(separatedBy: "|")
            if parts.count >= 2 {
                selectedMedication = parts[0].isEmpty ? nil : parts[0]
                selectedAdministrationMethod = parts[1].isEmpty ? nil : parts[1]
                selectedEster = parts.count >= 3 ? (parts[2].isEmpty ? nil : parts[2]) : nil
            }
        } else {
            selectedMedication = defaults.string(forKey: "selectedMedication")
            selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
        }
        loadUserPreferences()
    }

    func persistSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let str = "\(selectedMedication ?? "")|\(selectedAdministrationMethod ?? "")|\(selectedEster ?? "")"
        if let data = str.data(using: .utf8), let encrypted = try? security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedMedicationSelection")
        }
    }

    func loadUserPreferences() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        let prefs = try? context.fetch(descriptor).first
        customFrequencyDays = prefs?.customFrequencyDays
        defaultDoseAmount = prefs?.defaultDoseAmount
        defaultInjectionTime = prefs?.defaultInjectionTime
        showDoseIntensityInsights = prefs?.showDoseIntensityInsights ?? false
    }

    func persistUserPreferences() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            existing.customFrequencyDays = customFrequencyDays
            existing.defaultDoseAmount = defaultDoseAmount
            existing.defaultInjectionTime = defaultInjectionTime
            existing.showDoseIntensityInsights = showDoseIntensityInsights
        } else {
            let prefs = UserPreferences(
                customFrequencyDays: customFrequencyDays,
                defaultDoseAmount: defaultDoseAmount,
                defaultInjectionTime: defaultInjectionTime,
                showDoseIntensityInsights: showDoseIntensityInsights
            )
            context.insert(prefs)
        }
        try? context.save()
    }

    func loadDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedDoseDates"),
           let decrypted = try? security.decryptData(data),
           let container = try? JSONDecoder().decode(DoseDatesContainer.self, from: decrypted) {
            lastDoseDate = container.lastDoseDate
            nextDoseDate = container.nextDoseDate
            hrtStartDate = container.hrtStartDate
        }
    }

    func persistDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let container = DoseDatesContainer(lastDoseDate: lastDoseDate, nextDoseDate: nextDoseDate, hrtStartDate: hrtStartDate)
        if let data = try? JSONEncoder().encode(container), let encrypted = try? security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedDoseDates")
        }
    }

    /// Loads dose history from SwiftData.
    func loadDoseHistory() {
        guard let context = modelContext else { return }
        let descriptor = SortDescriptor<DoseRecord>(\DoseRecord.doseDate, order: .forward)
        let fetchDescriptor = FetchDescriptor<DoseRecord>(sortBy: [descriptor])
        let allRecords = try? context.fetch(fetchDescriptor)
        doseHistory = (allRecords ?? []).filter { !$0.isDeleted }
    }

    /// Persists the managed context to SwiftData (all pending insertions/deletions).
    func saveContext() {
        guard let context = modelContext else { return }
        try? context.save()
    }

    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "encryptedMedicationSelection") == nil { persistSelection() }
        if defaults.object(forKey: "encryptedDoseDates") == nil { persistDoseDates() }
    }

    private struct DoseDatesContainer: Codable {
        let lastDoseDate: Date?
        let nextDoseDate: Date?
        let hrtStartDate: Date?
    }
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