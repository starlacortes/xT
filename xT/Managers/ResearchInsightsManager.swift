//
//  ResearchInsightsManager.swift
//  xT
//
//  Aggregation engine for Phase 2 Research Dashboard.
//  Computes Pearson correlations, linear regressions, longitudinal trends,
//  and adherence/safety audit metrics from SwiftData records.
//
//  All computation is on-device — no server required.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Variable Definition

/// A variable that can be selected for correlation or trend analysis.
enum InsightVariable: String, CaseIterable, Identifiable {
    case monthsOnHRT      = "Months on HRT"
    case moodValence      = "Mood Score (1-7)"
    case doseAmount        = "Dose Amount (mg)"
    case hormoneLevel      = "Est. Hormone Level"
    case adherenceRate     = "30-Day Adherence Rate"
    case bloodTestLevel    = "Blood Test Level"
    case skinProgress      = "Skin Progress"
    case bodyProgress      = "Body Shape Progress"
    case mindProgress      = "Mind / Mood Progress"
    case cycleProgress     = "Cycle Progress"
    case doseIntensity     = "Dose Intensity (× standard)"
    case onTimeStreak      = "On-Time Streak"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .monthsOnHRT:      return "months"
        case .moodValence:      return "pts"
        case .doseAmount:        return "mg"
        case .hormoneLevel:     return ""
        case .adherenceRate:    return "%"
        case .bloodTestLevel:   return ""
        case .skinProgress:     return "/10"
        case .bodyProgress:     return "/10"
        case .mindProgress:     return "/10"
        case .cycleProgress:    return "/10"
        case .doseIntensity:    return "×"
        case .onTimeStreak:     return "doses"
        }
    }

    var category: VariableCategory {
        switch self {
        case .monthsOnHRT, .doseAmount, .doseIntensity:
            return .dosing
        case .moodValence, .skinProgress, .bodyProgress, .mindProgress, .cycleProgress:
            return .outcome
        case .hormoneLevel, .bloodTestLevel:
            return .biomarker
        case .adherenceRate, .onTimeStreak:
            return .behavior
        }
    }
}

enum VariableCategory: String {
    case dosing    = "Dosing"
    case outcome   = "Outcome"
    case biomarker = "Biomarker"
    case behavior  = "Behavior"
}

// MARK: - Statistical Types

/// A single (x, y) data point for correlation / scatter plots.
struct CorrelationPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let label: String?   // optional date/annotation label
}

/// Result of a Pearson correlation analysis.
struct CorrelationResult {
    let r: Double                // Pearson correlation coefficient (-1 to 1)
    let rSquared: Double         // Coefficient of determination
    let pValue: Double?          // Two-tailed p-value (approximate)
    let sampleSize: Int
    let slope: Double            // Linear regression slope
    let intercept: Double        // Linear regression intercept
    let points: [CorrelationPoint]
    let varA: InsightVariable
    let varB: InsightVariable

    var strength: CorrelationStrength {
        let absR = abs(r)
        if absR >= 0.7 { return .strong }
        if absR >= 0.4 { return .moderate }
        if absR >= 0.2 { return .weak }
        return .negligible
    }

    var direction: CorrelationDirection {
        if r > 0 { return .positive }
        if r < 0 { return .negative }
        return .none
    }
}

enum CorrelationStrength: String {
    case strong    = "Strong"
    case moderate  = "Moderate"
    case weak      = "Weak"
    case negligible = "Negligible"

    var color: Color {
        switch self {
        case .strong:     return Theme.Colors.success
        case .moderate:   return Theme.Colors.warning
        case .weak:       return Theme.Colors.error
        case .negligible: return .secondary
        }
    }
}

enum CorrelationDirection: String {
    case positive = "Positive"
    case negative = "Negative"
    case none     = "None"
}

/// A single data series for longitudinal trend charts.
struct TrendSeries: Identifiable {
    let id = UUID()
    let name: String
    let points: [TrendPoint]
    let color: Color
    let unit: String
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String?     // milestone annotation
    let monthsOnHRT: Double
}

/// Missed dose heatmap cell.
struct HeatmapCell: Identifiable {
    let id = UUID()
    let monthLabel: String     // "Jan", "Feb", ...
    let weekdayLabel: String   // "Mon", "Tue", ...
    let count: Int             // missed doses in this cell
    let maxCount: Int          // max across all cells (for color scaling)
}

/// Adherence trend point for audit view.
struct AdherenceTrendPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let rate: Double
    let takenCount: Int
    let scheduledCount: Int
}

// MARK: - Research Insights Manager

@MainActor
final class ResearchInsightsManager: ObservableObject {

    static let shared = ResearchInsightsManager()

    // MARK: - Mood → numeric valence mapping

    /// Maps Mood enum to a 1-7 valence score for statistical correlation.
    static func moodValence(_ mood: Mood) -> Double {
        switch mood {
        case .happy:     return 7
        case .energetic: return 6
        case .calm:      return 5
        case .neutral:   return 4
        case .tired:     return 3
        case .anxious:   return 2
        case .sad:       return 1
        }
    }

    // MARK: - Data Fetching

    /// Fetches all non-deleted dose records for the current medication.
    private func fetchDoses(context: ModelContext, medicationType: String) -> [DoseRecord] {
        let descriptor = FetchDescriptor<DoseRecord>(
            predicate: #Predicate { $0.isDeleted == false }
        )
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.medicationType == medicationType }
    }

    /// Fetches all journal entries.
    private func fetchJournalEntries(context: ModelContext) -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>()
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetches all blood test records for the given hormone type.
    private func fetchBloodTests(context: ModelContext, hormoneType: String) -> [BloodTestRecord] {
        let descriptor = FetchDescriptor<BloodTestRecord>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.hormoneType == hormoneType }
    }

    // MARK: - Variable Value Extraction

    /// Extracts paired (date, value) samples for a given variable from available data.
    func extractValues(
        for variable: InsightVariable,
        doses: [DoseRecord],
        journalEntries: [JournalEntry],
        bloodTests: [BloodTestRecord],
        hrtStartDate: Date,
        adherenceRate: Double,
        currentLevel: Double?,
        onTimeStreak: Int,
        relativeDoseIntensity: Double,
        bloomProgress: [String: Double]  // body system → 1-10 progress
    ) -> [(date: Date, value: Double)] {
        switch variable {
        case .monthsOnHRT:
            // For each dose, compute months on HRT at that point
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { dose in
                    let months = Calendar.current.dateComponents([.month], from: hrtStartDate, to: dose.doseDate).month ?? 0
                    return (dose.doseDate, Double(max(0, months)))
                }
                .sorted { $0.date < $1.date }

        case .moodValence:
            return journalEntries.map { entry in
                (entry.date, Self.moodValence(entry.mood))
            }.sorted { $0.date < $1.date }

        case .doseAmount:
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { ($0.doseDate, $0.doseAmount) }
                .sorted { $0.date < $1.date }

        case .hormoneLevel:
            // Use estimated level if available, placeholder otherwise
            let level = currentLevel ?? 0
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { ($0.doseDate, level) }
                .sorted { $0.date < $1.date }

        case .adherenceRate:
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { ($0.doseDate, adherenceRate * 100) }
                .sorted { $0.date < $1.date }

        case .bloodTestLevel:
            return bloodTests.map { ($0.drawDate, $0.measuredLevel) }
                .sorted { $0.date < $1.date }

        case .skinProgress:
            return journalEntries.compactMap { entry in
                guard let progress = bloomProgress["Skin & Hair"] else { return nil }
                return (entry.date, progress)
            }.sorted { $0.date < $1.date }

        case .bodyProgress:
            return journalEntries.compactMap { entry in
                guard let progress = bloomProgress["Body Shape"] else { return nil }
                return (entry.date, progress)
            }.sorted { $0.date < $1.date }

        case .mindProgress:
            return journalEntries.compactMap { entry in
                guard let progress = bloomProgress["Mind & Mood"] else { return nil }
                return (entry.date, progress)
            }.sorted { $0.date < $1.date }

        case .cycleProgress:
            return journalEntries.compactMap { entry in
                guard let progress = bloomProgress["Cycle & Flow"] else { return nil }
                return (entry.date, progress)
            }.sorted { $0.date < $1.date }

        case .doseIntensity:
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { ($0.doseDate, relativeDoseIntensity) }
                .sorted { $0.date < $1.date }

        case .onTimeStreak:
            let streak = Double(onTimeStreak)
            return doses
                .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
                .map { ($0.doseDate, streak) }
                .sorted { $0.date < $1.date }
        }
    }

    // MARK: - Pearson Correlation

    /// Computes Pearson correlation between two variables, pairing on nearest dates.
    /// Uses a 3-day window to match variable A and variable B values.
    func computeCorrelation(
        varA: InsightVariable,
        varB: InsightVariable,
        doses: [DoseRecord],
        journalEntries: [JournalEntry],
        bloodTests: [BloodTestRecord],
        hrtStartDate: Date,
        adherenceRate: Double,
        currentLevel: Double?,
        onTimeStreak: Int,
        relativeDoseIntensity: Double,
        bloomProgress: [String: Double]
    ) -> CorrelationResult? {
        let valuesA = extractValues(for: varA, doses: doses, journalEntries: journalEntries,
                                     bloodTests: bloodTests, hrtStartDate: hrtStartDate,
                                     adherenceRate: adherenceRate, currentLevel: currentLevel,
                                     onTimeStreak: onTimeStreak, relativeDoseIntensity: relativeDoseIntensity,
                                     bloomProgress: bloomProgress)
        let valuesB = extractValues(for: varB, doses: doses, journalEntries: journalEntries,
                                     bloodTests: bloodTests, hrtStartDate: hrtStartDate,
                                     adherenceRate: adherenceRate, currentLevel: currentLevel,
                                     onTimeStreak: onTimeStreak, relativeDoseIntensity: relativeDoseIntensity,
                                     bloomProgress: bloomProgress)

        // Pair values by nearest date within a 3-day window
        var paired: [(Double, Double, String?)] = []
        let maxDelta: TimeInterval = 3 * 86400

        for a in valuesA {
            var bestB: (date: Date, value: Double)?
            var bestDelta = TimeInterval.greatestFiniteMagnitude
            for b in valuesB {
                let delta = abs(a.date.timeIntervalSince(b.date))
                if delta < bestDelta && delta <= maxDelta {
                    bestDelta = delta
                    bestB = b
                }
            }
            if let b = bestB {
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                let label = "\(df.string(from: a.date))"
                paired.append((a.value, b.value, label))
            }
        }

        guard paired.count >= 3 else { return nil }

        let n = Double(paired.count)
        let xs = paired.map { $0.0 }
        let ys = paired.map { $0.1 }

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        let sumY2 = ys.reduce(0) { $0 + $1 * $1 }

        let numerator = n * sumXY - sumX * sumY
        let denomX = (n * sumX2 - sumX * sumX).squareRoot()
        let denomY = (n * sumY2 - sumY * sumY).squareRoot()
        let denominator = denomX * denomY

        guard denominator > 0 else { return nil }

        let r = numerator / denominator
        let rSquared = r * r

        // Slope (beta) and intercept
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        // Approximate two-tailed p-value using t-distribution
        let tStat = r * sqrt((n - 2) / (1 - r * r))
        let pValue = approximatePValue(t: abs(tStat), df: n - 2)

        let points = paired.map { CorrelationPoint(x: $0.0, y: $0.1, label: $0.2) }

        return CorrelationResult(
            r: r,
            rSquared: rSquared,
            pValue: pValue,
            sampleSize: paired.count,
            slope: slope,
            intercept: intercept,
            points: points,
            varA: varA,
            varB: varB
        )
    }

    // MARK: - Longitudinal Trends

    /// Builds trend series for body system progress over time.
    func buildLongitudinalTrends(
        journalEntries: [JournalEntry],
        hrtStartDate: Date,
        bloomProgress: [String: Double]
    ) -> [TrendSeries] {
        let systems: [(String, Color)] = [
            ("Skin & Hair",     Theme.Colors.Bloom.skin.base),
            ("Body Shape",      Theme.Colors.Bloom.body.base),
            ("Mind & Mood",     Theme.Colors.Bloom.mind.base),
            ("Cycle & Flow",    Theme.Colors.Bloom.cycle.base),
        ]

        // For now, use journal entries as time markers paired with bloom progress.
        // In a full implementation, we'd track historical progress snapshots.
        var series: [TrendSeries] = []

        for (system, color) in systems {
            guard let currentProgress = bloomProgress[system] else { continue }

            let sortedEntries = journalEntries.sorted { $0.date < $1.date }
            // Simulate a gradual trend from entry dates to current progress
            // For each journal entry, estimate progress based on time proportion
            guard let firstDate = sortedEntries.first?.date,
                  let lastDate = sortedEntries.last?.date else { continue }

            let totalSpan = lastDate.timeIntervalSince(firstDate)
            guard totalSpan > 0 else { continue }

            // Generate synthetic progress points: start at 1, ramp to current
            let points: [TrendPoint] = sortedEntries.enumerated().compactMap { idx, entry in
                let elapsed = entry.date.timeIntervalSince(firstDate)
                let fraction = min(elapsed / totalSpan, 1.0)
                let estimatedProgress = 1.0 + (currentProgress - 1.0) * fraction
                let months = Calendar.current.dateComponents([.month], from: hrtStartDate, to: entry.date).month ?? 0

                return TrendPoint(
                    date: entry.date,
                    value: estimatedProgress,
                    label: nil,
                    monthsOnHRT: Double(max(0, months))
                )
            }

            guard !points.isEmpty else { continue }

            series.append(TrendSeries(
                name: system,
                points: points,
                color: color,
                unit: "/10"
            ))
        }

        return series
    }

    // MARK: - Adherence Audit

    /// Computes weekly adherence rate trend points for the past 12 months.
    func buildAdherenceTrend(doses: [DoseRecord], frequencyDays: Int) -> [AdherenceTrendPoint] {
        guard frequencyDays > 0 else { return [] }

        let calendar = Calendar.current
        let now = Date()
        guard let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now) else { return [] }

        let takenDoses = doses.filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
        var trendPoints: [AdherenceTrendPoint] = []

        // Iterate week by week
        var weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: twelveMonthsAgo)) ?? twelveMonthsAgo

        while weekStart <= now {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }

            let takenInWeek = takenDoses.filter {
                $0.doseDate >= weekStart && $0.doseDate < weekEnd
            }.count

            // Scheduled doses per week = 7 / frequencyDays
            let scheduledPerWeek = max(1.0, 7.0 / Double(frequencyDays))

            let rate = min(Double(takenInWeek) / scheduledPerWeek, 1.0)

            trendPoints.append(AdherenceTrendPoint(
                weekStart: weekStart,
                rate: rate,
                takenCount: takenInWeek,
                scheduledCount: Int(ceil(scheduledPerWeek))
            ))

            weekStart = weekEnd
        }

        return trendPoints
    }

    /// Builds a missed-dose heatmap: weekday × month grid.
    func buildMissedDoseHeatmap(doses: [DoseRecord]) -> [HeatmapCell] {
        let calendar = Calendar.current
        let now = Date()
        guard let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now) else { return [] }

        let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let monthFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM"
            return f
        }()

        // Get last 12 month labels
        var months: [String] = []
        var cursor = twelveMonthsAgo
        while cursor <= now {
            months.append(monthFormatter.string(from: cursor))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Count missed doses per (weekday, month) cell
        var grid: [String: [String: Int]] = [:]  // monthLabel → weekdayLabel → count
        for month in months { grid[month] = [:] }

        let missedDoses = doses.filter { DoseStatus(rawValue: $0.doseStatus) == .missed }

        for dose in missedDoses {
            let monthLabel = monthFormatter.string(from: dose.doseDate)
            let weekdayIdx = calendar.component(.weekday, from: dose.doseDate) - 1  // 0-based
            guard weekdayIdx >= 0, weekdayIdx < 7 else { continue }
            let weekdayLabel = weekdayNames[weekdayIdx]

            grid[monthLabel, default: [:]][weekdayLabel, default: 0] += 1
        }

        // Flatten to cells
        let allCounts = grid.values.flatMap { $0.values }
        let maxCount = allCounts.max() ?? 1

        var cells: [HeatmapCell] = []
        for month in months {
            for weekday in weekdayNames {
                let count = grid[month]?[weekday] ?? 0
                cells.append(HeatmapCell(
                    monthLabel: month,
                    weekdayLabel: weekday,
                    count: count,
                    maxCount: maxCount
                ))
            }
        }

        return cells
    }

    // MARK: - SAE (Serious Adverse Event) Flags

    /// Flags potential adverse events from blood tests:
    /// - E2 > 600 pg/mL or < 30 pg/mL
    /// - T > 1200 ng/dL or < 100 ng/dL
    /// - Calibration factor α < 0.3 or > 3.0 (model extremely off)
    func flagPotentialSAEs(
        bloodTests: [BloodTestRecord],
        hormoneType: String
    ) -> [SAEFlag] {
        var flags: [SAEFlag] = []

        for test in bloodTests {
            if hormoneType == "Estrogen" {
                if test.measuredLevel > 600 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .warning,
                        message: "Estradiol > 600 pg/mL — supra‑physiological, thrombosis risk increased.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                } else if test.measuredLevel < 30 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .warning,
                        message: "Estradiol < 30 pg/mL — may indicate insufficient dosing or menopause-range levels.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                }
            } else {
                if test.measuredLevel > 1200 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .warning,
                        message: "Testosterone > 1200 ng/dL — supra‑physiological, polycythemia & cardiovascular risk.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                } else if test.measuredLevel < 100 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .info,
                        message: "Testosterone < 100 ng/dL — hypogonadal range; possible under‑dosing.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                }
            }

            // Calibration anomaly
            if let alpha = test.calibrationFactor {
                if alpha < 0.3 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .warning,
                        message: "PK model calibration α = \(String(format: "%.2f", alpha)) (model severely over‑predicting). Verify dosing history.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                } else if alpha > 3.0 {
                    flags.append(SAEFlag(
                        date: test.drawDate,
                        severity: .warning,
                        message: "PK model calibration α = \(String(format: "%.2f", alpha)) (model severely under‑predicting). Verify dosing history.",
                        source: "Blood test \(test.id.prefix(6))"
                    ))
                }
            }
        }

        return flags.sorted { $0.date > $1.date }
    }

    // MARK: - De-identification

    /// Returns a de-identified copy of data suitable for research export.
    /// Strips: id (replaced with sequential index), profile name/photo references, notes text.
    func deIdentifyExportData(
        doses: [DoseRecord],
        journalEntries: [JournalEntry],
        bloodTests: [BloodTestRecord]
    ) -> DeIdentifiedExport {
        let deid = DeIdentifiedExport()

        // Doses: keep only non-PII fields
        deid.doses = doses.enumerated().map { idx, dose in
            DeIdentifiedDose(
                recordId: idx,
                date: dose.doseDate,
                medicationType: dose.medicationType,
                ester: dose.ester,
                method: dose.administrationMethod,
                doseMg: dose.doseAmount,
                concentrationMgPerMl: dose.concentrationMgPerMl,
                status: dose.doseStatus
            )
        }

        // Journal: keep mood valence + symptom names, drop free text
        deid.journal = journalEntries.enumerated().map { idx, entry in
            DeIdentifiedJournal(
                recordId: idx,
                date: entry.date,
                moodValence: Self.moodValence(entry.mood),
                moodLabel: entry.mood.rawValue,
                symptomNames: entry.symptoms.map { $0.name }
            )
        }

        // Blood tests: drop notes
        deid.bloodTests = bloodTests.enumerated().map { idx, test in
            DeIdentifiedBloodTest(
                recordId: idx,
                date: test.drawDate,
                measuredLevel: test.measuredLevel,
                hormoneType: test.hormoneType,
                hoursSinceLastDose: test.hoursSinceLastDose,
                calibrationFactor: test.calibrationFactor
            )
        }

        return deid
    }

    // MARK: - Statistics Helpers

    /// Approximate two-tailed p-value from t-statistic using Abramowitz & Stegun approximation.
    private func approximatePValue(t: Double, df: Double) -> Double {
        guard t > 0, df > 0 else { return 1.0 }
        let x = df / (df + t * t)
        let a = df / 2.0
        let b = 0.5
        // Regularized incomplete beta function approximation
        let beta = incompleteBeta(x: x, a: a, b: b)
        return beta
    }

    /// Incomplete beta function (continued fraction approximation).
    private func incompleteBeta(x: Double, a: Double, b: Double) -> Double {
        guard x > 0, x < 1 else { return x >= 1 ? 1 : 0 }

        let maxIter = 100
        let epsilon = 1e-10

        // Log beta(a, b) using lgamma
        let logBeta = lgamma(a) + lgamma(b) - lgamma(a + b)

        // Continued fraction
        var front = exp(a * log(x) + b * log(1 - x) - logBeta) / a

        var f = 1.0
        var c = 1.0
        var d = 1.0 - (a + b) * x / (a + 1)
        if abs(d) < epsilon { d = epsilon }
        d = 1.0 / d
        var h = d

        for m in 1...maxIter {
            let m2 = Double(2 * m)

            // Even step
            let d1 = Double(m) * (b - Double(m)) * x / ((a + m2 - 1) * (a + m2))
            d = 1.0 + d1 * d
            if abs(d) < epsilon { d = epsilon }
            c = 1.0 + d1 / c
            if abs(c) < epsilon { c = epsilon }
            d = 1.0 / d
            h *= d * c

            // Odd step
            let d2 = -(a + Double(m)) * (a + b + Double(m)) * x / ((a + m2) * (a + m2 + 1))
            d = 1.0 + d2 * d
            if abs(d) < epsilon { d = epsilon }
            c = 1.0 + d2 / c
            if abs(c) < epsilon { c = epsilon }
            d = 1.0 / d
            let del = d * c
            h *= del

            if abs(del - 1.0) < epsilon { break }
        }

        return front * (h - 1.0)
    }
}

// MARK: - SAE Flag

struct SAEFlag: Identifiable {
    let id = UUID()
    let date: Date
    let severity: SAESeverity
    let message: String
    let source: String
}

enum SAESeverity: String {
    case info    = "Info"
    case warning = "Warning"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .info:     return Theme.Colors.info
        case .warning:  return Theme.Colors.warning
        case .critical: return Theme.Colors.error
        }
    }

    var icon: String {
        switch self {
        case .info:     return "info.circle"
        case .warning:  return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }
}

// MARK: - De-identified Export Types

class DeIdentifiedExport {
    var doses: [DeIdentifiedDose] = []
    var journal: [DeIdentifiedJournal] = []
    var bloodTests: [DeIdentifiedBloodTest] = []
}

struct DeIdentifiedDose: Codable {
    let recordId: Int
    let date: Date
    let medicationType: String
    let ester: String
    let method: String
    let doseMg: Double
    let concentrationMgPerMl: Double?
    let status: String
}

struct DeIdentifiedJournal: Codable {
    let recordId: Int
    let date: Date
    let moodValence: Double
    let moodLabel: String
    let symptomNames: [String]
}

struct DeIdentifiedBloodTest: Codable {
    let recordId: Int
    let date: Date
    let measuredLevel: Double
    let hormoneType: String
    let hoursSinceLastDose: Double?
    let calibrationFactor: Double?
}

// MARK: - Environment Key

struct ResearchInsightsManagerKey: EnvironmentKey {
    static let defaultValue: ResearchInsightsManager = .shared
}

extension EnvironmentValues {
    var researchInsightsManager: ResearchInsightsManager {
        get { self[ResearchInsightsManagerKey.self] }
        set { self[ResearchInsightsManagerKey.self] = newValue }
    }
}