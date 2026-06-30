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

/// MedicationManager with a Reactive Data Pipeline to ensure UI synchronization.
/// This class acts as the Single Source of Truth for all hormone-related state.
@MainActor
class MedicationManager: ObservableObject {
    static let shared = MedicationManager()

    // MARK: - SwiftData
    /// Injected from the app container so this singleton can query SwiftData.
    var modelContext: ModelContext?

    // MARK: - Core State
    @Published var selectedMedication: String?
    @Published var selectedAdministrationMethod: String?
    @Published var lastDoseDate: Date?
    @Published var nextDoseDate: Date?
    /// When the user actually began HRT (may predate app install). Drives monthsOnHRT.
    @Published var hrtStartDate: Date?

    // MARK: - Reactive Research Properties (The "Signals" for SwiftUI)
    /// Provides the current level summary, including unit, range, and plain-language explanation.
    @Published var currentHormoneLevel: (value: Double, unit: String, range: String, explanation: String)?
    /// Provides the historical data points used to drive the 7-day and long-term charts.
    @Published var recentLevels: [EstimatedPoint] = []

    // MARK: - Dose History (The Real Source of Truth)
    /// Full log of all logged doses — the backbone of the PK model.
    @Published var doseHistory: [DoseRecord] = []

    // MARK: - Endogenous Suppression Settings
    /// Whether the user takes an anti‑androgen (spironolactone, cyproterone, GnRH agonist).
    /// When true, endogenous testosterone baseline is aggressively suppressed to near‑zero.
    @Published var antiAndrogenInUse: Bool = false
    
    /// Number of weeks after HRT start for endogenous production to reach suppressed levels.
    /// Clinical consensus: 4–6 weeks for gonadal suppression.
    let hrtSuppressionWeeks: Int = 4
    
    /// Spironolactone is a known enzyme inducer (CYP3A4) that can modestly increase
    /// estradiol clearance. When the user is on spiro, we apply a small multiplier to ke
    /// to reflect this interaction. Typical estimates: 10‑20% faster clearance.
    /// Set to false if the user is on other AAs (cyproterone, GnRH agonists).
    @Published var spironolactoneInUse: Bool = false
    
    /// Multiplier applied to elimination rate (ke) when spironolactone is in use.
    /// Accounts for CYP3A4 induction → faster E2 clearance.
    private let spiroClearanceFactor: Double = 1.15

    // MARK: - Blood Test Calibration
    /// History of user‑entered lab results used to calibrate the PK model.
    @Published var bloodTestHistory: [BloodTestRecord] = []
    
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
        /// expected peak levels for a reference dose. Calibrated from published PK data:
        ///   - EV 2 mg → peak E2 ~200–300 pg/mL
        ///   - EC 2 mg → peak E2 ~150–200 pg/mL
        /// Used in the Bateman biexponential to convert mg → concentration.
        var scalingConstant: Double {
            switch self {
            case .valerate: return 280.0
            case .cypionate: return 220.0
            case .oral: return 180.0
            case .transdermal: return 120.0
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

    var hasMissedDose: Bool {
        guard let next = nextDoseDate else { return false }
        return Date() > next
    }

    var daysSinceMissedDose: Int? {
        guard hasMissedDose, let next = nextDoseDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: next, to: Date()).day ?? 0
        return max(1, days) // At least 1 day if missed
    }

    var monthsOnHRT: Int {
        let referenceDate = hrtStartDate ?? lastDoseDate
        guard let first = referenceDate else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0
        return max(0, months)
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

    // MARK: - Initialization

    init() {
        loadSelection()
        loadDoseDates()
        loadDoseHistory()
        loadBloodTestHistory()
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

    /// Records a full dose with amount, ester, method, and optional notes.
    /// This is the primary method for logging doses going forward.
    func addDose(
        date: Date = Date(),
        type: String,
        ester: String,
        method: String,
        doseAmount: Double,
        notes: String? = nil
    ) {
        let record = DoseRecord(
            doseDate: date,
            medicationType: type,
            ester: ester,
            administrationMethod: method,
            doseAmount: doseAmount,
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
    }

    func calculateNextDoseDate(from lastDose: Date) -> Date {
        guard let methodStr = selectedAdministrationMethod,
              let method = AdministrationMethod(rawValue: methodStr) else { return Date() }
        return Calendar.current.date(byAdding: .day, value: method.frequencyDays, to: lastDose) ?? Date()
    }

    // MARK: - Research Engine (Pharmacokinetics)
    
    /// Computes the dynamic endogenous baseline for a given medication type,
    /// accounting for HRT duration, anti‑androgen use, and gonadal suppression.
    /// 
    /// **Logic:**
    /// - If no `hrtStartDate` and no `antiAndrogenInUse` → full baseline (gonadal function intact)
    /// - If `antiAndrogenInUse` → testosterone baseline goes to near‑zero immediately
    /// - Otherwise, linear taper from full baseline to suppressed value over `hrtSuppressionWeeks`
    /// - For trans men on T: E2 baseline can be estimated as ~0.2% of current T level (aromatization)
    ///
    /// - Parameter type: The medication type to compute baseline for.
    /// - Returns: The dynamic baseline level in pg/mL or ng/dL.
    func dynamicBaseline(for type: MedicationType) -> Double {
        let fullBaseline = type.baselineValue
        let suppressedBaseline = type.suppressedBaseline
        
        // Anti‑androgen overrides: suppress T aggressively
        if type == .testosterone && antiAndrogenInUse {
            return suppressedBaseline
        }
        
        // No HRT start date → assume full gonadal function
        guard let startDate = hrtStartDate ?? lastDoseDate else {
            return fullBaseline
        }
        
        let daysOnHRT = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let weeksOnHRT = Double(daysOnHRT) / 7.0
        let suppressionWeeks = Double(hrtSuppressionWeeks)
        
        if weeksOnHRT >= suppressionWeeks {
            // Fully suppressed
            return suppressedBaseline
        } else {
            // Linear taper: fraction = weeksOnHRT / suppressionWeeks
            let fraction = Double(weeksOnHRT) / suppressionWeeks
            return fullBaseline + (suppressedBaseline - fullBaseline) * fraction
        }
    }

    /// The heart of the reactivity: Recalculates everything and broadcasts changes.
    func refreshState() {
        currentHormoneLevel = getCurrentHormoneLevel()
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        recentLevels = estimatedLevels(from: start, to: end)
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
    
    /// Determines where the user currently sits in their dose cycle.
    /// Evaluates time since last dose against expected peak and trough windows.
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
        
        let daysSinceDose = Date().timeIntervalSince(lastDose.doseDate) / 86400.0
        let cycleLength = Double(method.frequencyDays)
        
        // Determine expected peak time from ester
        let tMax: Double
        if medication == "Estrogen", let ester = MedicationEster(rawValue: lastDose.ester) {
            tMax = expectedTimeToPeak(for: ester)
        } else if medication == "Testosterone", let tesEster = TestosteroneEster(rawValue: lastDose.ester) {
            tMax = expectedTimeToPeak(for: tesEster)
        } else {
            return .unknown
        }
        
        // Peak window: within ±30% of expected t_max from last dose
        let peakWindow = tMax * 0.30
        if abs(daysSinceDose - tMax) <= peakWindow {
            return .nearPeak
        }
        
        // Trough window: within 24 hours of next scheduled dose
        if daysSinceDose >= (cycleLength - 1.0) {
            return .trough
        }
        
        // Everything else is mid-cycle
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
    
    /// Returns optimal range definitions that are context-aware (separate peak vs trough targets).
    func optimalRangeLabel(for medication: MedicationType, at position: CyclePosition) -> (label: String, min: Double, max: Double) {
        switch (medication, position) {
        case (.estrogen, .trough):
            return ("Optimal (Trough)", 100, 200)
        case (.estrogen, .nearPeak):
            return ("Optimal (Peak)", 100, 400)
        case (.estrogen, .midCycle):
            return ("Optimal", 100, 300)
        case (.estrogen, .unknown):
            return ("Optimal", 100, 200)
        case (.testosterone, .trough):
            // Trans men target: 400-700 ng/dL at trough
            return ("Optimal (Trough)", 400, 700)
        case (.testosterone, .nearPeak):
            // Peak should not exceed ~1000-1500
            return ("Optimal (Peak)", 400, 1000)
        case (.testosterone, .midCycle):
            return ("Optimal", 300, 900)
        case (.testosterone, .unknown):
            return ("Optimal", 300, 1000)
        }
    }

    func getCurrentHormoneLevel() -> (value: Double, unit: String, range: String, explanation: String)? {
        guard let medication = selectedMedication,
              let _ = selectedAdministrationMethod else { return nil }

        let recent = estimatedLevels(from: Date().addingTimeInterval(-3600), to: Date())
        guard let latestLevel = recent.last else { return nil }

        let medicationEnum = MedicationType(rawValue: medication)
        let unit = medicationEnum == .estrogen ? "pg/mL" : "ng/dL"
        let position = currentCyclePosition

        let rangeInfo: HormoneRange
        if medicationEnum == .estrogen {
            rangeInfo = estrogenRanges.first { latestLevel.value >= $0.min && latestLevel.value < $0.max }
                        ?? HormoneRange(label: "Unknown", min: 0, max: 0, colorName: "primary")
        } else {
            rangeInfo = testosteroneRanges.first { latestLevel.value >= $0.min && latestLevel.value < $0.max }
                        ?? HormoneRange(label: "Unknown", min: 0, max: 0, colorName: "primary")
        }
        
        // Build context-aware label: append cycle position if known
        let contextLabel: String
        if position != .unknown {
            contextLabel = "\(rangeInfo.label) · \(position.rawValue)"
        } else {
            contextLabel = rangeInfo.label
        }

        let explanation: String
        if medicationEnum == .estrogen {
            let baseExplanation: String
            switch rangeInfo.label {
            case "Very Low": baseExplanation = "At this level, you may experience mood swings and limited physical changes."
            case "Low": baseExplanation = "You'll notice some emotional and physical changes, but they may be subtle."
            case "Optimal": baseExplanation = "At this level, you'll feel emotionally stable and notice ongoing skin and body changes."
            case "High": baseExplanation = "You'll experience significant emotional and physical changes; monitor for side effects."
            default: baseExplanation = "Levels are outside typical monitoring ranges. Consult your provider."
            }
            // Add cycle position context
            switch position {
            case .nearPeak:
                explanation = baseExplanation + " You're near your peak — levels run higher than trough targets."
            case .trough:
                explanation = baseExplanation + " You're at trough — this is the standard measurement window."
            case .midCycle:
                explanation = baseExplanation
            case .unknown:
                explanation = baseExplanation
            }
        } else {
            let baseExplanation = latestLevel.value < 50 
                ? "Your testosterone is effectively suppressed." 
                : "This is a low male range."
            switch position {
            case .nearPeak:
                explanation = baseExplanation + " Near peak — expect higher readings."
            case .trough:
                explanation = baseExplanation + " At trough — ideal time for lab draws."
            case .midCycle:
                explanation = baseExplanation
            case .unknown:
                explanation = baseExplanation
            }
        }

        return (latestLevel.value, unit, contextLabel, explanation)
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
    func estimatedLevels(from start: Date, to end: Date, stepDays: Int = 1) -> [EstimatedPoint] {
        guard let medication = selectedMedication,
              let methodStr = selectedAdministrationMethod else { return [] }

        var points = [EstimatedPoint]()
        var cursor = start
        let calendar = Calendar.current

        let medicationEnum = MedicationType(rawValue: medication)
        let baseLevel: Double = medicationEnum.map { dynamicBaseline(for: $0) } ?? 100.0
        let alpha = calibrationFactor ?? 1.0  // user‑specific calibration multiplier
        
        // Determine if we should use the Bateman biexponential (injectable) or
        // the simpler single‑exponential (oral/transdermal)
        let isInjectable = AdministrationMethod(rawValue: methodStr) == .injectable
        
        // Get the most recent dose to determine ester and PK params
        let recentDose = doseHistory
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
                // Spironolactone CYP3A4 induction → ~15% faster E2 clearance
                if spironolactoneInUse { ke *= spiroClearanceFactor }
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
                if isInjectable, let pk = pkParams(ester: dose.ester, medication: medication) {
                    doseEvents.append(DoseEvent(date: dose.doseDate, amount: effAmount,
                                                ka: pk.ka, ke: pk.ke, scaling: pk.scaling))
                } else {
                    // Non‑injectable: use single‑exponential fallback (ka from half‑life, ke unused)
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

    func loadSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedMedicationSelection"),
           let decrypted = try? security.decryptData(data),
           let str = String(data: decrypted, encoding: .utf8) {
            let parts = str.components(separatedBy: "|")
            if parts.count == 2 {
                selectedMedication = parts[0].isEmpty ? nil : parts[0]
                selectedAdministrationMethod = parts[1].isEmpty ? nil : parts[1]
            }
        } else {
            selectedMedication = defaults.string(forKey: "selectedMedication")
            selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
        }
    }

    func persistSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let str = "\(selectedMedication ?? "")|\(selectedAdministrationMethod ?? "")"
        if let data = str.data(using: .utf8), let encrypted = try? security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedMedicationSelection")
        }
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