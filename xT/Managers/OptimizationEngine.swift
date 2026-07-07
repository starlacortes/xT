//
//  OptimizationEngine.swift
//  xT
//
//  Dose Optimization Advisor — analyzes dose history, blood test results,
//  and journal symptoms to suggest interval and dose adjustments.
//

import Foundation
import SwiftUI

// MARK: - Optimization Suggestion

struct OptimizationSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let confidence: SuggestionConfidence
    let actionText: String

    enum SuggestionType: String {
        case increaseDose    = "Increase Dose"
        case decreaseDose    = "Decrease Dose"
        case adjustInterval  = "Adjust Interval"
        case switchEster     = "Consider Different Ester"
        case addBloodTest    = "Schedule Blood Test"
        case maintainCurrent = "Maintain Current Regimen"
        case watchSymptoms   = "Watch for Symptoms"
    }

    enum SuggestionConfidence: String {
        case high    = "High"
        case medium  = "Medium"
        case low     = "Low"

        var color: Color {
            switch self {
            case .high:   return Theme.Colors.success
            case .medium: return Theme.Colors.warning
            case .low:    return Theme.Colors.info
            }
        }

        var icon: String {
            switch self {
            case .high:   return "checkmark.shield.fill"
            case .medium: return "lightbulb.fill"
            case .low:    return "info.circle.fill"
            }
        }
    }
}

// MARK: - Optimization Engine

@MainActor
final class OptimizationEngine: ObservableObject {

    static let shared = OptimizationEngine()

    // MARK: - Analyze & Suggest

    func generateSuggestions(
        doses: [DoseRecord],
        bloodTests: [BloodTestRecord],
        journalEntries: [JournalEntry],
        currentEster: String,
        currentDoseMg: Double,
        currentFrequencyDays: Int,
        medicationType: String,
        hrtStartDate: Date?,
        adherenceRate: Double?
    ) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        // 1. Blood test analysis
        let recentTests = bloodTests
            .filter { $0.hormoneType == medicationType }
            .sorted { $0.drawDate > $1.drawDate }

        if let latestTest = recentTests.first {
            suggestions += analyzeBloodTest(latestTest, medicationType: medicationType)
        } else if let startDate = hrtStartDate {
            let monthsSinceStart = Calendar.current.dateComponents([.month], from: startDate, to: Date()).month ?? 0
            if monthsSinceStart >= 3 {
                suggestions.append(OptimizationSuggestion(
                    type: .addBloodTest,
                    title: "Blood work recommended",
                    description: "You've been on HRT for \(monthsSinceStart) months. Schedule a blood test to check your levels and calibrate your dosing.",
                    confidence: .high,
                    actionText: "Schedule lab work"
                ))
            }
        }

        // 2. Adherence analysis
        if let adherence = adherenceRate {
            if adherence < 0.6 {
                suggestions.append(OptimizationSuggestion(
                    type: .watchSymptoms,
                    title: "Low adherence — consider simplifying",
                    description: "Your 30-day adherence rate is \(String(format: "%.0f", adherence * 100))%. Frequent missed doses can cause hormonal instability. Consider setting stronger reminders or switching to a longer-acting ester with less frequent dosing.",
                    confidence: .medium,
                    actionText: "Review dosing schedule"
                ))
            }
        }

        // 3. Dose trend analysis
        let takenDoses = doses
            .filter { DoseStatus(rawValue: $0.doseStatus) == .taken }
            .sorted { $0.doseDate < $1.date }

        if takenDoses.count >= 6 {
            let recent3Doses = Array(takenDoses.suffix(3))
            let earlier3Doses = Array(takenDoses.prefix(3))
            let recentAvg = recent3Doses.map(\.doseAmount).reduce(0, +) / 3.0
            let earlierAvg = earlier3Doses.map(\.doseAmount).reduce(0, +) / 3.0

            // Detect dose escalation without blood work
            if recentAvg > earlierAvg * 1.3 && recentTests.isEmpty {
                suggestions.append(OptimizationSuggestion(
                    type: .addBloodTest,
                    title: "Dose increasing — verify with labs",
                    description: "Your average dose has increased from \(String(format: "%.1f", earlierAvg)) mg to \(String(format: "%.1f", recentAvg)) mg. Get a blood test to ensure levels remain in the target range.",
                    confidence: .medium,
                    actionText: "Schedule lab work"
                ))
            }
        }

        // 4. Ester-specific suggestions
        suggestions += analyzeEster(currentEster, doseMg: currentDoseMg, frequencyDays: currentFrequencyDays)

        // 5. Journal symptom analysis
        suggestions += analyzeSymptoms(journalEntries, medicationType: medicationType)

        // 6. If nothing significant, recommend maintaining
        if suggestions.isEmpty {
            suggestions.append(OptimizationSuggestion(
                type: .maintainCurrent,
                title: "Regimen appears stable",
                description: "Your current dosing regimen looks consistent. No significant adjustments recommended at this time. Continue tracking and re-evaluate after your next blood test.",
                confidence: .medium,
                actionText: "Continue current regimen"
            ))
        }

        return suggestions
    }

    // MARK: - Blood Test Analysis

    private func analyzeBloodTest(_ test: BloodTestRecord, medicationType: String) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        if medicationType == "Estrogen" {
            if test.measuredLevel > 500 {
                suggestions.append(OptimizationSuggestion(
                    type: .decreaseDose,
                    title: "Estradiol elevated — consider reducing dose",
                    description: "Your measured E2 is \(String(format: "%.0f", test.measuredLevel)) pg/mL, above the typical target range (100-400 pg/mL). Consider reducing by 10-20% and retesting in 6-8 weeks.",
                    confidence: .high,
                    actionText: "Reduce dose by 10-20%"
                ))
            } else if test.measuredLevel < 80 {
                suggestions.append(OptimizationSuggestion(
                    type: .increaseDose,
                    title: "Estradiol low — consider increasing dose",
                    description: "Your measured E2 is \(String(format: "%.0f", test.measuredLevel)) pg/mL, below the typical target range. Consider increasing by 10-20% and retesting in 6-8 weeks.",
                    confidence: .high,
                    actionText: "Increase dose by 10-20%"
                ))
            }
        } else {
            if test.measuredLevel > 1000 {
                suggestions.append(OptimizationSuggestion(
                    type: .decreaseDose,
                    title: "Testosterone elevated — consider reducing dose",
                    description: "Your measured T is \(String(format: "%.0f", test.measuredLevel)) ng/dL, above the typical target range (300-800 ng/dL). Consider reducing by 10-20% and retesting.",
                    confidence: .high,
                    actionText: "Reduce dose by 10-20%"
                ))
            } else if test.measuredLevel < 250 {
                suggestions.append(OptimizationSuggestion(
                    type: .increaseDose,
                    title: "Testosterone low — consider increasing dose",
                    description: "Your measured T is \(String(format: "%.0f", test.measuredLevel)) ng/dL, below the typical male range. Consider increasing and retesting.",
                    confidence: .high,
                    actionText: "Increase dose by 10-20%"
                ))
            }
        }

        return suggestions
    }

    // MARK: - Ester Analysis

    private func analyzeEster(_ ester: String, doseMg: Double, frequencyDays: Int) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        // Very short esters at long intervals
        if (ester.contains("Valerate") || ester.contains("EV")) && frequencyDays >= 14 {
            suggestions.append(OptimizationSuggestion(
                type: .adjustInterval,
                title: "Estradiol Valerate has a short half-life",
                description: "EV typically requires dosing every 5-7 days for stable levels. A \(frequencyDays)-day interval may cause significant peaks and troughs. Consider dosing every 5-7 days, or switching to Estradiol Cypionate (EC) for longer intervals.",
                confidence: .high,
                actionText: "Adjust to 5-7 day interval"
            ))
        }

        // High dose at frequent intervals
        if doseMg > 10 && frequencyDays <= 5 && ester.contains("Valerate") {
            suggestions.append(OptimizationSuggestion(
                type: .watchSymptoms,
                title: "High estrogen dose — watch for symptoms",
                description: "\(String(format: "%.1f", doseMg)) mg EV every \(frequencyDays) days is a relatively high regimen. Watch for: breast tenderness, mood instability, fluid retention. Consider monitoring SHBG.",
                confidence: .low,
                actionText: "Monitor symptoms"
            ))
        }

        return suggestions
    }

    // MARK: - Symptom Analysis

    private func analyzeSymptoms(_ entries: [JournalEntry], medicationType: String) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        let recentEntries = entries
            .sorted { $0.date > $1.date }
            .prefix(14)  // Last 2 weeks

        // Count mood patterns
        let moodCounts = Dictionary(grouping: recentEntries, by: { $0.mood }).mapValues { $0.count }

        let sadAnxiousCount = (moodCounts[.sad] ?? 0) + (moodCounts[.anxious] ?? 0)
        let happyEnergeticCount = (moodCounts[.happy] ?? 0) + (moodCounts[.energetic] ?? 0)

        if sadAnxiousCount > happyEnergeticCount && sadAnxiousCount >= 3 {
            if medicationType == "Estrogen" {
                suggestions.append(OptimizationSuggestion(
                    type: .watchSymptoms,
                    title: "Low mood pattern detected",
                    description: "You've logged more low-mood days than high-mood days recently. This can be a sign of low estradiol. Consider verifying with a blood test.",
                    confidence: .medium,
                    actionText: "Check hormone levels"
                ))
            }
        }

        // Hot flashes / menopause symptoms
        let hotFlashSymptoms = recentEntries
            .flatMap { $0.symptoms }
            .filter { $0.name.lowercased().contains("hot flash") || $0.name.lowercased().contains("fatigue") }
            .count

        if hotFlashSymptoms >= 3 {
            suggestions.append(OptimizationSuggestion(
                type: .watchSymptoms,
                title: "Menopause-range symptoms reported",
                description: "Frequent fatigue/hot flash symptoms may indicate hormone levels have dropped to menopause range. Verify with a blood test.",
                confidence: .medium,
                actionText: "Schedule lab work"
            ))
        }

        return suggestions
    }
}