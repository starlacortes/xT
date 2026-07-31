//
//  MedicationManager+Pharmacokinetics.swift
//  xT
//
//  PK engine: dynamic baseline, cycle position, blood test calibration,
//  contextual target range, deviation classification, safety overrides,
//  unified hormone level pipeline, estimatedLevels, dose intensity scaling,
//  and aromatization estimation.
//

import Foundation
import SwiftData

extension MedicationManager {

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
        // Bulk callers (sample-profile seeding, multi-dose imports) suppress the per-mutation
        // recompute and refresh once at the end. See `MedicationManager.performBatch(_:)`.
        guard !suppressRefresh else { return }

        currentHormoneLevel = getCurrentHormoneLevel()
        let now = Date()
        // Size the chart's date window from the same doses that actually contribute to the
        // computed levels, so a skipped/pending dose can't stretch the x-axis into a window
        // containing no plotted contribution. Matches the `.taken`-only filter used by
        // `estimatedLevels`. See xTTests/PharmacokineticTests.swift
        // "A skipped dose does not stretch the chart's date window".
        let activeDoses = doseHistory.filter { $0.isActive && $0.medicationType == selectedMedication && DoseStatus(rawValue: $0.doseStatus) == .taken }

        var start: Date
        var end: Date

        if activeDoses.count <= 1, let last = lastDoseDate {
            let freqDays: Int = {
                if let custom = customFrequencyDays, custom > 0 { return custom }
                if let methodStr = selectedAdministrationMethod,
                   let method = AdministrationMethod(rawValue: methodStr) { return method.frequencyDays }
                return 7
            }()
            start = Calendar.current.date(byAdding: .day, value: -max(3, Int(Double(freqDays) * 0.5)), to: last) ?? now
            end = max(now, Calendar.current.date(byAdding: .day, value: Int(Double(freqDays) * 1.5), to: last) ?? now)
        } else {
            end = now
            start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        }

        let isInjectable = AdministrationMethod(rawValue: selectedAdministrationMethod ?? "") == .injectable
        if isInjectable {
            end = now
            start = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
            end = Calendar.current.date(byAdding: .day, value: 2, to: end) ?? end
            let halfLife = currentEster?.halfLifeDays ?? 5.0
            let step = max(2.0 / 24.0, halfLife / 30.0)
            recentLevels = estimatedLevels(from: start, to: end, stepDays: step)
        } else {
            recentLevels = estimatedLevels(from: start, to: end)
        }
        recomputeRegimenHistory()
        recomputeAdherenceRate()
        recomputeOnTimeStreak()
    }

    /// Computes the expected time to peak concentration (in days) for a given ester.
    /// Uses the exact Bateman t_max formula: t_max = ln(ka/ke) / (ka - ke).
    /// Under flip-flop kinetics (ka ≪ ke), the denominator ≈ -ke, giving the
    /// asymptotic form t_max ≈ ln(ke/ka) / ke (not 1/ka — a common misconception).
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
                  .filter({ $0.isActive && $0.medicationType == medication && DoseStatus(rawValue: $0.doseStatus) == .taken })
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
                .filter({ $0.isActive && $0.medicationType == hormoneType && DoseStatus(rawValue: $0.doseStatus) == .taken })
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
    func estimatedLevels(from start: Date, to end: Date, stepDays: Double = 1.0,
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
            // QA fix (2026‑07‑28): only doses actually TAKEN should contribute to the
            // PK curve. Previously this filter admitted `.skipped` (and any future
            // `.missed`) records too, so a dose the user explicitly logged as skipped
            // was modeled exactly as if it had been injected/swallowed — inflating
            // predicted levels right after a skip. See xTTests/PharmacokineticTests.swift
            // "Skipped doses do not contribute to predicted levels".
            let activeDoses = doseHistory
                .filter { $0.isActive && $0.medicationType == medication && DoseStatus(rawValue: $0.doseStatus) == .taken }
                .sorted { $0.doseDate < $1.doseDate }

            for dose in activeDoses {
                let effAmount = dose.doseAmount * dosePotencyFactor(for: dose)
                let isOralRoute = dose.administrationMethod == "Oral"
                let isTransdermalRoute = dose.administrationMethod == "Cream"

                // QA fix (2026‑07‑28): branch on THIS dose's own administration method,
                // not the manager's currently-selected global route. Previously a user
                // who switched routes (e.g. oral → injectable) would have their older
                // doses silently re-modeled with the wrong kinetics whenever the
                // globally-selected route didn't match the historical route of that
                // specific dose. See xTTests/PharmacokineticTests.swift
                // "Historical doses use their own administration method, not the current selection".
                if dose.administrationMethod == "Injectable", let pk = pkParams(ester: dose.ester, medication: medication) {
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

            // When dose history is sparse (1 active dose — fresh onboarding),
            // generate synthetic FORWARD-only doses so the chart can preview the
            // user's projected trajectory if they stay on schedule.
            //
            // QA fix (2026-07-28): this used to ALSO backfill synthetic doses
            // BACKWARD up to 90 days before the user's one real dose, at full
            // dose strength, on a weekly/daily cadence. For a genuinely new
            // user (their first-ever logged dose), that fabricated up to ~13
            // full-strength phantom prior doses that never happened — and
            // because `estimatedLevels()` sums every dose event regardless of
            // the requested date range, those phantom doses fed directly into
            // `getCurrentHormoneLevel()`, not just the chart. The user's very
            // first injection would report a "current level" computed as if
            // they'd already been on a stable regimen for three months.
            // Under the old, severely miscalibrated scaling constants this was
            // numerically invisible; once those were corrected (see the
            // testosterone/oral/transdermal fixes above) it became a large,
            // clearly wrong overstatement (confirmed via xTTests — see
            // teSingleDosePeak/tuSingleDosePeak/evSingleDosePeak/
            // tcSingleDosePeak/oralE2Kinetics/veryOldDose, which all assume a
            // single logged dose means exactly one dose contributing).
            // Forward-filling is left in place: it only affects points at or
            // after `end`/future dates (dt < 0 doses are skipped), so it can't
            // distort "now", and it lets the chart preview an upcoming
            // trajectory the user hasn't actually experienced yet — which is
            // clearly labeled as projection, unlike fabricated history.
            if activeDoses.count == 1 {
                let freqDays: Int = {
                    if let custom = customFrequencyDays, custom > 0 { return custom }
                    if let methodStr = selectedAdministrationMethod,
                       let method = AdministrationMethod(rawValue: methodStr) { return method.frequencyDays }
                    return 7
                }()
                let latestReal = activeDoses.map(\.doseDate).max() ?? start
                let refDose = activeDoses.first
                let effAmount = refDose.map { $0.doseAmount * dosePotencyFactor(for: $0) } ?? (baseLevel * 0.5)
                let refEster = refDose?.ester ?? defaultEsterName

                let lookaheadLimit = calendar.date(byAdding: .day, value: 90, to: end) ?? end
                let now = Date()
                var cursor = calendar.date(byAdding: .day, value: freqDays, to: latestReal) ?? latestReal
                while cursor <= lookaheadLimit {
                    // Only project future doses. When the single real dose is old, this loop
                    // would otherwise generate phantom past doses (latestReal + freqDays…now)
                    // that contribute non-zero Bateman values at current cursor positions,
                    // inflating the predicted level as if the user had never missed a dose.
                    guard cursor > now else {
                        guard let next = calendar.date(byAdding: .day, value: freqDays, to: cursor) else { break }
                        cursor = next
                        continue
                    }
                    if !doseEvents.contains(where: { abs($0.date.timeIntervalSince(cursor)) < 3600 }) {
                        if isInjectable, let pk = pkParams(ester: refEster, medication: medication) {
                            doseEvents.append(DoseEvent(date: cursor, amount: effAmount,
                                                        ka: pk.ka, ke: pk.ke, scaling: pk.scaling))
                        } else {
                            let lam = log(2) / defaultHalfLife
                            doseEvents.append(DoseEvent(date: cursor, amount: effAmount,
                                                        ka: lam, ke: 0.0, scaling: 1.0))
                        }
                    }
                    guard let next = calendar.date(byAdding: .day, value: freqDays, to: cursor) else { break }
                    cursor = next
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
                
                // QA fix (2026‑07‑28): this used to read `if isInjectable && event.ke > 0`,
                // gating the Bateman branch on the manager's GLOBAL selected route rather
                // than on this event's own shape. Since oral dose-events are built with a
                // real ke (oralKe = 1.386, see above) specifically so they get the Bateman
                // rise‑then‑decay shape, but `isInjectable` is false for anyone whose
                // current route is Oral/Cream, oral (and — because the `else` branch below
                // never applied `event.scaling` — transdermal) contributions ALWAYS fell
                // through to a bare, unscaled `amount * exp(-ka*dt)`. In practice this made
                // predicted levels for oral and transdermal users flat at baseline
                // regardless of dose (contributions ~100–1000× smaller than intended).
                // `event.ke > 0` alone is the correct discriminator: depot injectables and
                // oral doses set a real ke (→ Bateman), while transdermal micro-doses and
                // the generic fallback set ke = 0 by design (→ single-exponential). Both
                // branches now apply `event.scaling` so a route's calibration constant is
                // never silently dropped. See xTTests/PharmacokineticTests.swift
                // "Oral and transdermal routes produce non-negligible, scaled dose response".
                if event.ke > 0 {
                    // Bateman biexponential (depot injectables, and oral's fast-absorption case)
                    let denom = event.ka - event.ke
                    if abs(denom) < 0.0001 {
                        // ka ≈ ke edge case: use limit approximation
                        cumulativeSpike += event.amount * event.scaling * event.ka * dt * exp(-event.ka * dt)
                    } else {
                        cumulativeSpike += event.amount * event.scaling *
                            (event.ka / denom) * (exp(-event.ke * dt) - exp(-event.ka * dt))
                    }
                } else {
                    // Simple single‑exponential for transdermal micro-doses / generic fallback
                    cumulativeSpike += event.amount * event.scaling * exp(-event.ka * dt)
                }
            }
            let rawValue = baseLevel + cumulativeSpike
            let calibratedValue = rawValue * alpha
            points.append(EstimatedPoint(date: cursor, value: calibratedValue,
                                         medication: medication, method: methodStr))
            cursor = cursor.addingTimeInterval(stepDays * 86400.0)
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

}
