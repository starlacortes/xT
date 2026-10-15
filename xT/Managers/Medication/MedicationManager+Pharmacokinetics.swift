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
        if weeksOnHRT >= PKConstants.fullSuppressionWeeks {
            return suppressedBaseline
        }

        // Saturating exponential taper using user-configurable timescale (#9)
        let timescaleWeeks = suppressionSpeed.weeks  // 4, 8, or 12 weeks
        let progress = min(weeksOnHRT / timescaleWeeks, 1.0)
        let suppressionFactor = 1.0 - exp(-PKConstants.suppressionTaperRate * progress)  // reaches ~92% at progress=1.0
        
        return fullBaseline + (suppressedBaseline - fullBaseline) * suppressionFactor
    }

    /// The heart of the reactivity: Recalculates everything and broadcasts changes.
    func refreshState() {
        // Bulk callers (sample-profile seeding, multi-dose imports) suppress the per-mutation
        // recompute and refresh once at the end. See `MedicationManager.performBatch(_:)`.
        guard !suppressRefresh else { return }

        currentHormoneLevel = getCurrentHormoneLevel()

        // The window is sized from the ester actually being plotted and anchored on
        // `now`. See `PKChartWindow` for the rule; `chartWindow()` resolves the effective
        // ester and gates its t_max on `isTmaxCalibrated`.
        //
        // This replaces a window that was anchored on the dose history and branched on
        // the manager's *globally selected* route. That branch is what let the default
        // 1-day step land on the 1-day oral dosing interval, sampling every point at the
        // same phase of the cycle and flattening the oral curve to a line.
        //
        // Anchoring on `now` also makes the skipped-dose guarantee structural instead of
        // incidental: a dose that contributes nothing to the curve cannot stretch the
        // x-axis, because no dose positions it at all. See xTTests/PharmacokineticTests.swift
        // "A skipped dose does not stretch the chart's date window".
        //
        // Accepted consequence: markers leave the visible range for part of a cycle, in
        // both directions. On TU (70-day interval, 10.5-day window) a dose taken five
        // days ago is already off the left edge mid-cycle, and the next dose sits off the
        // right edge for most of the interval. That is the window being honest about its
        // timescale, not a positioning bug.
        resampleRecentLevels()

        recomputeRegimenHistory()
        recomputeAdherenceRate()
        recomputeOnTimeStreak()

        // The widget reads a snapshot of this state from the shared App Group;
        // every change that flows through the funnel also refreshes the Home
        // Screen curve. No-ops when the App Group is unavailable. `self` is
        // passed explicitly — this also runs from the manager's own init,
        // where reading `.shared` again would deadlock (see the writer).
        WidgetSnapshotWriter.publish(from: self)
    }

    /// (Re)samples `recentLevels` from the current chart window (X12c).
    /// `refreshState()` calls this after data changes; a window-mode change
    /// calls it directly, because the regimen history, adherence and the
    /// streak don't depend on the window and shouldn't be paid for on a
    /// mode switch.
    func resampleRecentLevels() {
        let window = chartWindow()
        recentLevels = estimatedLevels(from: window.start, to: window.end,
                                       stepDays: window.stepDays)
    }

    /// Computes the expected time to peak concentration (in days) for a given ester.
    /// Uses the exact Bateman t_max formula: t_max = ln(ka/ke) / (ka - ke).
    /// Under flip-flop kinetics (ka ≪ ke), the denominator ≈ -ke, giving the
    /// asymptotic form t_max ≈ ln(ke/ka) / ke (not 1/ka — a common misconception).
    ///
    /// The formula itself now lives on the ester enums as `timeToPeakDays`, so UI that
    /// has no manager in scope reads the same number this does. Kept as a method
    /// because it is the established call site across the app and the tests.
    /// - Parameter ester: The medication ester enum value.
    /// - Returns: Expected days to peak concentration after injection.
    func expectedTimeToPeak(for ester: MedicationEster) -> Double {
        ester.timeToPeakDays
    }

    /// Computes the expected time to peak concentration (in days) for a given testosterone ester.
    func expectedTimeToPeak(for tesEster: TestosteroneEster) -> Double {
        tesEster.timeToPeakDays
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
              let lastDose = latestDose(matching: {
                  $0.isActive && $0.medicationType == medication && DoseStatus(rawValue: $0.doseStatus) == .taken
              })
        else {
            return .unknown
        }

        let now = Date()
        let daysSinceDose = now.timeIntervalSince(lastDose.doseDate) / AppConstants.secondsPerDay
        let cycleLength = Double(effectivePKIntervalDays(ester: lastDose.ester,
                                                          route: lastDose.administrationMethod,
                                                          medication: medication))

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
        guard let peakPoint = sinceLastDose.max(by: { $0.value < $1.value })
        else {
            return .unknown
        }

        let peakHoursAfterDose = peakPoint.date.timeIntervalSince(lastDose.doseDate) / 3600.0

        // "Near Peak" — within 24 hours after the actual peak
        let hoursSinceDose = daysSinceDose * 24.0
        let peakEnd = peakHoursAfterDose + 24.0
        if hoursSinceDose >= peakHoursAfterDose && hoursSinceDose <= peakEnd {
            return .nearPeak
        }

        // "Trough" — within the last 24 hours of the cycle OR at the actual
        // post-peak minimum.  The Bateman curve is monotonically descending
        // after the peak, so the true trough is the last point before the next
        // dose.  Searching for the min across all points picks t≈0 (where
        // the spike is zero), not the real trough.  Restrict to points after
        // the peak to find the actual descending-tail minimum.
        if daysSinceDose >= (cycleLength - 1.0) {
            return .trough
        }

        let afterPeak = sinceLastDose.filter { $0.date >= peakPoint.date }
        if let troughPoint = afterPeak.min(by: { $0.value < $1.value }) {
            let troughHoursAfterDose = troughPoint.date.timeIntervalSince(lastDose.doseDate) / 3600.0
            if troughHoursAfterDose > peakHoursAfterDose &&
               abs(hoursSinceDose - troughHoursAfterDose) <= 24.0 {
                return .trough
            }
        }

        return .midCycle
    }
    
    // MARK: - Blood Test Calibration Engine
    
    /// Adds a blood test result and computes its calibration factor.
    /// Auto‑calculates hours since last dose from the dose history.
    func addBloodTest(drawDate: Date, measuredLevel: Double, hormoneType: String, notes: String? = nil) {
        // Auto‑compute hours since last matching dose
        let hoursSince: Double? = {
            guard let lastDose = latestDose(matching: {
                $0.isActive && $0.medicationType == hormoneType && DoseStatus(rawValue: $0.doseStatus) == .taken
            }) else { return nil }
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
    
    /// Derives the calibration factor α from the exogenous (drug) contribution alone.
    ///
    /// Application is `C = base + exogenous · α` (see `estimatedLevels`), so the
    /// derivation must invert that: `α = (measured − base) / exogenous`. The previous
    /// implementation divided by the *total* predicted level — baseline included — so
    /// re-evaluating the model at the draw instant returned `measured + (1 − α)·base`
    /// instead of `measured`. Returns nil when no positive α reconciles the draw:
    /// `exogenous ≤ 0.01` (nothing meaningful to divide by) or `measured ≤ base`
    /// (a draw at/below the endogenous floor; clamping to 0.2 would fabricate a
    /// correction that does not exist). Otherwise the result is clamped to 0.2–5.0.
    nonisolated static func calibrationAlpha(measured: Double, base: Double, exogenous: Double) -> Double? {
        guard exogenous > 0.01, measured > base else { return nil }
        return max(0.2, min(5.0, (measured - base) / exogenous))
    }

    /// Computes α for a single blood test record and stores it on the record.
    /// Runs the PK model at the draw date (uncalibrated) to get the predicted value,
    /// then derives α against the exogenous part of that prediction.
    func computeCalibrationFactor(for record: BloodTestRecord) {
        guard let medication = selectedMedication,
              let _ = selectedAdministrationMethod,
              medication == record.hormoneType
        else { return }
        
        // Run the model at the exact draw instant, uncalibrated. Sampling the draw
        // date itself (rather than a ±30-minute window stepped at 1 day) fixes two
        // defects at once: the old window's 86400-second step jumped straight past
        // `end` and produced a single point at drawDate − 1800s, silently anchoring
        // α half an hour before the draw; and because that call went through
        // `estimatedLevels` without `applyCalibration: false`, α was computed
        // against an already-α-scaled prediction — a circularity that damped every
        // subsequent calibration. `predictedLevel` defaults to uncalibrated so the
        // calibration engine never feeds on its own output.
        guard let predicted = predictedLevel(at: record.drawDate,
                                             hormoneType: record.hormoneType) else {
            record.calibrationFactor = nil
            return
        }
        
        // α is applied to the exogenous term alone, so it is derived against the
        // exogenous term alone. `predictedLevel` evaluates `dynamicBaseline` once,
        // as of now, and applies that single value to every point in the series —
        // including historical draw dates — so the baseline subtracted here must be
        // the SAME as-of-now baseline `predictedLevel` added. (Evaluating the baseline
        // per-point fixes the flat baseline but re-scales every stored α; that is a
        // separate change, not part of this fix.)
        guard let type = MedicationType(rawValue: record.hormoneType) else {
            record.calibrationFactor = nil
            return
        }
        let base = dynamicBaseline(for: type)
        let exogenous = predicted - base
        record.calibrationFactor = Self.calibrationAlpha(measured: record.measuredLevel,
                                                         base: base,
                                                         exogenous: exogenous)
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
    
    /// Runs the PK model at a single instant and returns the predicted level.
    ///
    /// This is the calibration engine's sampling primitive. It deliberately defaults
    /// `applyCalibration` to `false` so the calibration factor is always computed
    /// against the raw population-model prediction — never against an already-α-scaled
    /// one (the circularity that the old ±30-minute window introduced). It also samples
    /// the draw date itself rather than a window, so α is anchored at the exact moment
    /// the blood was drawn.
    ///
    /// - Parameters:
    ///   - date: The instant to evaluate the model at (typically `record.drawDate`).
    ///   - hormoneType: The medication type the prediction is for.
    ///   - applyCalibration: Whether to apply the current calibration factor. Defaults
    ///     to `false`; the calibration engine must never feed on its own output.
    /// - Returns: The predicted level, or `nil` when no medication/method is configured
    ///   or the predicted value is ≤ 0.01 (clinically meaningless as a divisor).
    func predictedLevel(at date: Date, hormoneType: String, applyCalibration: Bool = false) -> Double? {
        guard selectedMedication == hormoneType,
              selectedAdministrationMethod != nil else { return nil }
        let points = estimatedLevels(from: date, to: date, stepDays: 1,
                                     applyCalibration: applyCalibration)
        guard let value = points.last?.value, value > 0.01 else { return nil }
        return value
    }
    
    /// Maps the blood test history into chart-ready series points.
    ///
    /// Lives on the manager (rather than in `LabsChartSeries.swift`) so the shared
    /// chart model stays a pure-math value type with no manager dependency. The
    /// predicted value is computed uncalibrated at each draw date, matching how
    /// `computeCalibrationFactor` derives α.
    func labsSeriesPoints(for hormoneType: String) -> [LabsSeriesPoint] {
        bloodTestHistory
            .filter { $0.hormoneType == hormoneType }
            .sorted { $0.drawDate < $1.drawDate }
            .map { record in
                LabsSeriesPoint(
                    drawDate: record.drawDate,
                    measured: record.measuredLevel,
                    predicted: predictedLevel(at: record.drawDate, hormoneType: hormoneType),
                    isCalibrated: record.isCalibrated
                )
            }
    }
    // MARK: - Layer 1: Time-Contextual + Dose-Scaled Targets
    
    /// Returns a context-aware comparison range that accounts for cycle position AND dose intensity.
    ///
    /// `source` reports whether the bounds are the user's own therapeutic targets or
    /// were derived from the population model. Callers must not present model-derived
    /// bounds as the user's target — the user never set them.
    func contextualRange(for medication: MedicationType,
                         at position: CyclePosition,
                         doseIntensity: Double) -> (source: RangeSource, min: Double, max: Double) {
        
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
        
        // If the user set personal therapeutic targets, their trough range is the
        // reference at EVERY cycle position — not only at the trough itself. The
        // old rule quoted "your set trough" just once per cycle (at the trough
        // position), so the range they configured was silently ignored the rest
        // of the time.
        if let userTarget = userTherapeuticTarget {
            return (.userSet, userTarget.troughMin, userTarget.troughMax)
        }

        // No user targets: model-scaled bounds. `.modelDerived` is the honesty
        // marker — the copy never presents these as the user's own range.
        switch position {
        case .nearPeak:
            return (.modelDerived, scaledPeakMin, scaledPeakMax)
        case .trough:
            return (.modelDerived, scaledTroughMin, scaledTroughMax)
        case .midCycle:
            // Interpolate between trough and peak targets
            let midMin = (scaledTroughMin + scaledPeakMin) / 2
            let midMax = (scaledTroughMax + scaledPeakMax) / 2
            return (.modelDerived, midMin, midMax)
        case .unknown:
            // Fallback: widest span, trough floor to peak ceiling
            return (.modelDerived, scaledTroughMin, scaledPeakMax)
        }
    }
    
    // MARK: - Layer 2: Deviation from Model Prediction
    
    /// Compares the actual (calibrated) level to the raw population-model prediction.
    func deviationClassification(actual: Double, predicted: Double) -> ModelDeviation {
        guard predicted > 1.0 else { return .incomparable }
        let ratio = actual / predicted
        switch ratio {
        case 0.0..<0.7:  return .below
        case 0.7..<1.3:  return .onTrack
        default:         return .above
        }
    }

    // MARK: - Layer 4: Clinical Safety & Interaction Flags

    /// Returns a flag if the level crosses a documented clinical threshold.
    /// These fire AFTER the main classification and take precedence over it.
    func safetyOverride(level: Double, medication: MedicationType, phase: CyclePosition) -> SafetyFlag? {
        // Estrogen safety ceiling
        if medication == .estrogen && level > PKConstants.estradiolHighThreshold {
            return .estrogenCeiling
        }
        // Testosterone supra-physiological
        if medication == .testosterone && level > PKConstants.testosteroneSupraphysiologicThreshold {
            return .testosteroneSupraphysiologic
        }
        // E2 < 50 pg/mL at trough is sub-therapeutic (on therapy)
        if medication == .estrogen && level < PKConstants.estradiolVeryLowThreshold && phase == .trough {
            return .subTherapeuticTrough
        }
        // Spironolactone interaction: E2 < 80 pg/mL may indicate accelerated clearance
        if medication == .estrogen && spironolactoneInUse && level < PKConstants.estradiolLowThreshold && phase == .trough {
            return .spironolactoneClearance
        }
        return nil
    }
    
    // MARK: - Unified Hormone Level Pipeline (All 4 Layers)

    /// Computes the current hormone level with contextual, dose-aware, deviation-informed,
    /// and safety-checked classification.
    ///
    /// Returns values only. All display text is built at the view layer, so this
    /// function contains no user-facing English and makes no recommendation.
    func getCurrentHormoneLevel() -> HormoneLevel? {
        guard let medication = selectedMedication,
              let _ = selectedAdministrationMethod else { return nil }

        let medicationEnum = MedicationType(rawValue: medication)
        let unit: HormoneUnit = medicationEnum == .estrogen ? .picogramsPerMilliliter
                                                            : .nanogramsPerDeciliter
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
        let (boundsSource, minTarget, maxTarget) = contextualRange(for: medicationEnum ?? .estrogen,
                                                                   at: position,
                                                                   doseIntensity: intensity)

        // 4. Determine where actual sits relative to the contextual bounds.
        //    Computed regardless of source — the chart bands use it — but only
        //    rendered as a comparative statement when boundsSource == .userSet.
        let status: LevelStatus
        if actual < minTarget * 0.5 {
            status = .criticallyLow
        } else if actual < minTarget * 0.8 {
            status = .veryLow
        } else if actual < minTarget {
            status = .slightlyBelow
        } else if actual <= maxTarget {
            status = .inRange
        } else if actual <= maxTarget * 1.3 {
            status = .slightlyAbove
        } else {
            status = .high
        }

        // 5. Safety flags (take precedence over contextual status)
        let safety = safetyOverride(level: actual,
                                    medication: medicationEnum ?? .estrogen,
                                    phase: position)

        return HormoneLevel(
            value: actual,
            unit: unit,
            status: status,
            phase: position,
            deviation: deviation,
            safety: safety,
            bounds: LevelBounds(min: minTarget, max: maxTarget),
            boundsSource: boundsSource
        )
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
    /// **Oral routes** use the same Bateman biexponential; only the rate constants
    /// differ (fast absorption, fast elimination, no flip‑flop). See `makeDoseEvents`.
    ///
    /// **Transdermal** is the one route that does not: it is modeled as 24 hourly
    /// micro‑doses of amount/24, each decaying single‑exponentially (ke = 0 selects
    /// that branch), forming a square‑wave release across the day.
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
        
        // NOTE (2026‑07‑31): the manager's globally-selected route is deliberately NOT
        // consulted when building dose events. Every dose carries its own
        // `administrationMethod`, and `makeDoseEvents` branches on that. The former
        // `isInjectable` flag derived from `methodStr` was the root of three separate
        // route-mismatch defects; `methodStr` is now only used to label output points
        // and to pick a route for the no-history fallback, where no dose exists to ask.

        // Resolve default ester info for fallback
        let fallback = Self.defaultEsterInfo(for: medication)
        let defaultEsterName = fallback.name
        let defaultHalfLife = fallback.halfLifeDays

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
        ///
        /// Callers must pass the *effective* ester (see `effectiveEsterName`), not the
        /// dose's stored ester, so that non-injectable routes resolve to their own
        /// pseudo-ester constants rather than to the injectable ester's.
        func pkParams(ester: String, medication: String) -> (ka: Double, ke: Double, scaling: Double)? {
            if medication == "Estrogen", let e = MedicationEster(rawValue: ester) {
                let ka = log(2) / e.halfLifeDays
                var ke = log(2) / (e.eliminationHalfLifeHours / 24.0)
                // Spironolactone CYP3A4 induction → ~15% faster E2 clearance (#12)
                // Only applied when the user has opted in via settings.
                if spironolactoneInUse && spironolactoneClearanceEnabled { ke *= PKConstants.spiroClearanceFactor }
                return (ka, ke, e.scalingConstant)
            } else if medication == "Testosterone", let e = TestosteroneEster(rawValue: ester) {
                let ka = log(2) / e.halfLifeDays
                let ke = log(2) / (e.eliminationHalfLifeHours / 24.0)
                return (ka, ke, e.scalingConstant)
            }
            return nil
        }

        /// Builds the dose event(s) for a single administration, choosing the shape
        /// from the route and the constants from the *effective* ester for that route.
        ///
        /// Injectable → one Bateman event. Oral → one Bateman event with the route's
        /// own (fast) rates. Cream → 24 hourly single-exponential micro-doses forming
        /// a square-wave release over the day. Anything unrecognized → a single
        /// exponential at the ester's terminal half-life.
        func makeDoseEvents(date: Date, ester: String, route: String, amount: Double) -> [DoseEvent] {
            let effEster = Self.effectiveEsterName(ester: ester, route: route)

            func genericFallback() -> [DoseEvent] {
                let halfLife: Double
                if medication == "Estrogen", let e = MedicationEster(rawValue: effEster) {
                    halfLife = e.halfLifeDays
                } else if medication == "Testosterone", let e = TestosteroneEster(rawValue: effEster) {
                    halfLife = e.halfLifeDays
                } else {
                    halfLife = defaultHalfLife
                }
                return [DoseEvent(date: date, amount: amount,
                                  ka: log(2) / halfLife, ke: 0.0, scaling: 1.0)]
            }

            guard let pk = pkParams(ester: effEster, medication: medication) else {
                return genericFallback()
            }

            switch route {
            case "Injectable", "Oral":
                // Depot injectable and oral both use the full Bateman biexponential;
                // only the rate constants differ, and those now come from the ester.
                return [DoseEvent(date: date, amount: amount,
                                  ka: pk.ka, ke: pk.ke, scaling: pk.scaling)]
            case "Cream":
                // Transdermal: 24h square wave via hourly micro-doses, each decaying
                // single-exponentially (ke = 0 selects that branch in the sum below).
                let microAmount = amount / 24.0
                return (0..<24).map { hour in
                    DoseEvent(date: date.addingTimeInterval(Double(hour) * 3600.0),
                              amount: microAmount, ka: pk.ka, ke: 0.0, scaling: pk.scaling)
                }
            default:
                return genericFallback()
            }
        }

        if !doseHistory.isEmpty {
            // QA fix (2026‑07‑28): only doses actually TAKEN should contribute to the
            // PK curve. Previously this filter admitted `.skipped` (and any future
            // `.missed`) records too, so a dose the user explicitly logged as skipped
            // was modeled exactly as if it had been injected/swallowed — inflating
            // predicted levels right after a skip. See xTTests/PharmacokineticTests.swift
            // "Skipped doses do not contribute to predicted levels".
            let activeDoses = activeTakenDoses(medication: medication)

            // QA fix (2026‑07‑28): branch on THIS dose's own administration method,
            // not the manager's currently-selected global route. Previously a user
            // who switched routes (e.g. oral → injectable) would have their older
            // doses silently re-modeled with the wrong kinetics whenever the
            // globally-selected route didn't match the historical route of that
            // specific dose. See xTTests/PharmacokineticTests.swift
            // "Historical doses use their own administration method, not the current selection".
            for dose in activeDoses {
                let effAmount = dose.doseAmount * dosePotencyFactor(for: dose)
                doseEvents.append(contentsOf: makeDoseEvents(date: dose.doseDate,
                                                             ester: dose.ester,
                                                             route: dose.administrationMethod,
                                                             amount: effAmount))
            }

            // No synthetic forward doses, deliberately. The chart window extends
            // 2W/3 past `now` (see `PKChartWindow`), and this used to fill that
            // region with phantom doses at `latestReal + k · effectivePKIntervalDays`.
            // The curve then *rose to meet the next-dose marker* as though that dose
            // had already been given, drawn identically to recorded history — so the
            // chart showed levels climbing on the strength of an injection the user
            // had not taken, and would not take for days. If they then delayed or
            // skipped it, the trajectory they had been shown was never going to happen.
            //
            // The forward region is still meaningful without it: a dose that *was*
            // logged keeps rising toward its own t_max (EV peaks 2.1 d out), which is
            // the only future rise the model can actually justify from recorded data.
            // Past that the curve decays — which is what "no further dose logged"
            // honestly predicts.
            //
            // This cannot move "now": future events were already skipped by the
            // `dt < 0` guard below, so `getCurrentHormoneLevel()` and
            // `predictedLevel(at:)` (lab-draw dates, always past) are untouched.
        } else {
            // No real dose records: return baseline-only points.  Do NOT fabricate
            // phantom backfilled doses from `lastDoseDate` — that path mixed a
            // concentration (baseLevel) into a dose-amount slot, producing
            // predictions off by ~1000×, and invented up to 9 full-strength
            // phantom doses the user never took.  If `lastDoseDate` is set
            // without any `DoseRecord`, that state is itself a bug (see
            // `updateSelection` stamping a fake `lastDoseDate`); papering over
            // it here would mask the root cause and produce clinically misleading
            // levels.
        }
        doseEvents.sort { $0.date < $1.date }

        // ------ Cursor iteration: sum contributions at each time point ------
        while cursor <= end {
            var cumulativeSpike = 0.0
            for event in doseEvents {
                let dt = cursor.timeIntervalSince(event.date) / AppConstants.secondsPerDay  // days since dose
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
            let calibratedValue = baseLevel + cumulativeSpike * alpha
            points.append(EstimatedPoint(date: cursor, value: calibratedValue,
                                         medication: medication, method: methodStr))
            cursor = cursor.addingTimeInterval(stepDays * AppConstants.secondsPerDay)
        }
        return points
    }
    
    /// Resolves which ester's constants actually govern a dose, given its route.
    ///
    /// Both `MedicationEster` and `TestosteroneEster` carry `"Oral"` and `"Transdermal"`
    /// pseudo-ester cases whose constants describe a *route*, not a chemical ester. A
    /// dose administered orally or as a cream is governed by those, regardless of which
    /// injectable ester happens to be stored on the record.
    ///
    /// Added 2026‑07‑31 to close a live overprediction defect. Previously the route
    /// branches in `estimatedLevels` looked up their scaling constant behind a
    /// `medication == "Estrogen"` guard and otherwise fell through to hardcoded literals
    /// (12000.0 oral / 8000.0 transdermal — the pre-2026‑07‑28 *estrogen* values, already
    /// documented as ~9.6× and ~52× too large even for estrogen). A testosterone dose on
    /// the Oral or Cream route therefore predicted roughly 1100× high: 50 mg/day of
    /// testosterone gel returned ≈610,000 ng/dL against a clinical expectation near 550.
    /// Both routes are reachable from the UI, so this was user-visible, not theoretical.
    ///
    /// It also fixes two quieter mismatches on the same lookup:
    ///   * `dosePotencyFactor` resolved EDF from the stored ester alone, so a testosterone
    ///     gel dose used cypionate's EWF 0.699 and F 1.0 instead of the gel's 1.0 × 0.10.
    ///   * A dose recorded under one route and later viewed after a route switch kept the
    ///     old route's ester constants.
    static func effectiveEsterName(ester: String, route: String) -> String {
        switch route {
        case "Oral": return "Oral"
        case "Cream": return "Transdermal"
        default: return ester
        }
    }

    /// Returns the effective dose factor (EWF × bioavailability) for a specific dose record.
    private func dosePotencyFactor(for dose: DoseRecord) -> Double {
        let name = Self.effectiveEsterName(ester: dose.ester, route: dose.administrationMethod)
        if dose.medicationType == "Estrogen", let ester = MedicationEster(rawValue: name) {
            return ester.effectiveDoseFactor
        } else if dose.medicationType == "Testosterone", let tesEster = TestosteroneEster(rawValue: name) {
            return tesEster.effectiveDoseFactor
        }
        return 1.0
    }

    // MARK: - Dose Intensity Scaling (#13)
    
    /// Average dose over the last 3 months, divided by a standard starting dose.
    /// Used to scale the unlock speed of expected changes.
    var relativeDoseIntensity: Double {
        let now = Date()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        
        let recentDoses = activeTakenDoses(medication: selectedMedication ?? "")
            .filter { $0.doseDate >= threeMonthsAgo && $0.doseDate <= now }
        
        guard !recentDoses.isEmpty else { return 1.0 }
        
        let avgDose = recentDoses.map(\.doseAmount).reduce(0, +) / Double(recentDoses.count)
        
        // Standard starting doses (population references — see PKConstants)
        let standardDose: Double = selectedMedication == "Estrogen"
            ? PKConstants.referenceEstrogenDoseMg
            : PKConstants.referenceTestosteroneDoseMg
        guard standardDose > 0 else { return 1.0 }
        
        return avgDose / standardDose
    }
    
    /// Note shown below the "Changes Unlocked" section, explaining how dose
    /// intensity feeds into the displayed timelines.
    ///
    /// States what the model does with the number. It does not tell the user their
    /// dose is too low or too high, or what to watch for.
    var doseIntensityNote: String? {
        let intensity = relativeDoseIntensity
        if intensity < 0.5 {
            return String(localized: "Timelines shown are extended, because this dose is below the reference dose the population data is based on.",
                          comment: "Explains why change timelines are stretched at a low dose intensity")
        }
        if intensity > 1.5 {
            return String(localized: "Timelines shown are shortened slightly, because this dose is above the reference dose the population data is based on.",
                          comment: "Explains why change timelines are compressed at a high dose intensity")
        }
        return String(localized: "Timelines shown are based on population data for the reference dose. Individual results vary.",
                      comment: "Explains the basis of the change timelines at a typical dose intensity")
    }
    
    // MARK: - Aromatization Estimator (Trans Men)
    
    /// Estimated estradiol level derived from aromatization of exogenous testosterone.
    /// A small fraction of circulating T is converted to E2 via aromatase.
    /// Clinical data suggest ~0.2% mass-fraction conversion.  Because T is in ng/dL
    /// and E2 is reported in pg/mL (1 ng/dL = 10 pg/mL), the effective factor is
    /// `aromatizationFraction × 10 = 0.02`.
    /// This helps trans men monitor whether their E2 is in the male reference range (10‑40 pg/mL).
    ///
    /// - Parameter testosteroneLevel: Current T level in ng/dL.
    /// - Returns: Estimated E2 level in pg/mL from aromatization.
    func estimatedE2FromTestosterone(_ testosteroneLevel: Double) -> Double {
        return testosteroneLevel * PKConstants.aromatizationFraction * 10.0
    }
    
    /// Checks whether aromatization‑derived E2 is within the male reference range.
    /// Returns a tuple with the estimated E2, whether it's elevated, and a clinical note.
    func aromatizationAssessment(for testosteroneLevel: Double) -> (e2: Double, isElevated: Bool, note: String) {
        let e2 = estimatedE2FromTestosterone(testosteroneLevel)
        let isElevated = e2 > 40.0
        
        let note: String
        if isElevated {
            note = String(localized: "Estimated estradiol from aromatization is above the male reference range of 10–40 pg/mL.",
                          comment: "Where the aromatization estimate falls against the male reference range")
        } else if e2 < 10.0 {
            note = String(localized: "Estimated estradiol from aromatization is below the male reference range of 10–40 pg/mL.",
                          comment: "Where the aromatization estimate falls against the male reference range")
        } else {
            note = String(localized: "Estimated estradiol from aromatization is within the male reference range of 10–40 pg/mL.",
                          comment: "Where the aromatization estimate falls against the male reference range")
        }
        
        return (e2, isElevated, note)
    }

}
