//
//  MedicationManager+Schedule.swift
//  xT
//
//  Regimen transition tracking, monthly adherence rate,
//  on-time streak computation, and dynamic blood-test scheduling.
//

import Foundation

extension MedicationManager {

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
    
    /// Returns the suggested month for the next blood test based on actual lab history.
    /// If a test exists within the last 2.5 months, suggests 3 months after that draw.
    /// Otherwise falls back to the next multiple of 3 months from HRT start.
    var suggestedBloodTestMonth: Int {
        let now = Date()
        // Use ~75 days (~2.5 months) as the cutoff window
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

}
