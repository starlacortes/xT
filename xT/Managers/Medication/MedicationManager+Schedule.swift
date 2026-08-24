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
    
    // MARK: - Monthly Adherence Rate (#2)

    func recomputeAdherenceRate() {
        guard selectedMedication != nil, selectedAdministrationMethod != nil else {
            adherenceRate = nil
            return
        }
        
        let now = Date()
        let windowDays = PKConstants.adherenceWindowDays
        let windowStart = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) ?? now

        // Count taken doses inside the adherence window
        let takenDoses = activeTakenDoses(medication: selectedMedication ?? "")
            .filter { $0.doseDate >= windowStart && $0.doseDate <= now }
            .count

        // Calculate how many doses SHOULD have been scheduled in that window.
        // The ester-aware due interval, not the method default: a TU user dosed every
        // ~10 weeks was previously judged against ~5 weekly doses per month.
        let scheduledCount = max(1, Int(ceil(Double(windowDays) / Double(effectiveDueIntervalDays))))
        adherenceRate = min(1.0, Double(takenDoses) / Double(scheduledCount))
    }
    
    // MARK: - On-Time Streak (#20)

    func recomputeOnTimeStreak() {
        guard selectedMedication != nil else {
            onTimeStreak = 0
            return
        }
        
        let activeDoses = activeTakenDoses(medication: selectedMedication ?? "", ascending: false)  // most recent first
        
        guard !activeDoses.isEmpty else {
            onTimeStreak = 0
            return
        }
        
        // Determine grace window based on dosing frequency: tighter for daily regimens.
        // Ester-aware, so a TU streak is measured against its real 10-week cadence.
        let intervalDays = Double(effectiveDueIntervalDays)
        let graceHours = intervalDays <= 1
            ? PKConstants.onTimeGraceHoursDaily
            : PKConstants.onTimeGraceHoursPeriodic

        var streak = 1  // most recent dose counts
        for i in 1..<activeDoses.count {
            let expectedInterval = activeDoses[i-1].doseDate.timeIntervalSince(activeDoses[i].doseDate)
            let expectedDays = intervalDays * AppConstants.secondsPerDay
            let deviation = abs(expectedInterval - expectedDays) / 3600.0  // in hours
            
            if deviation <= graceHours {
                streak += 1
            } else {
                break  // streak broken
            }
        }
        
        onTimeStreak = streak
    }
    
    // MARK: - Blood-Test Scheduling (#14)

    /// The newest blood test for the selected medication that is still recent enough to
    /// describe current levels (`PKConstants.bloodTestRelevanceDays`).
    ///
    /// Shared by `suggestedBloodTestMonth` and `bloodTestSchedulingText`, which each used
    /// to run their own filter-and-sort — and, because the text also reads the suggested
    /// month, scanned the history three times per render.
    private var mostRecentRelevantBloodTest: BloodTestRecord? {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -PKConstants.bloodTestRelevanceDays, to: Date()
        ) ?? Date()
        return bloodTestHistory
            .filter { $0.hormoneType == (selectedMedication ?? "") && $0.drawDate >= cutoff }
            .max(by: { $0.drawDate < $1.drawDate })
    }

    /// Returns the suggested month for the next blood test based on actual lab history.
    /// If a recent test exists, suggests 3 months after that draw.
    /// Otherwise falls back to the next multiple of 3 months from HRT start.
    var suggestedBloodTestMonth: Int {
        guard let mostRecentTest = mostRecentRelevantBloodTest else {
            // Fallback: next multiple of 3 months from HRT start
            return ((monthsOnHRT / 3) + 1) * 3
        }
        // Suggest 3 months after most recent draw
        let now = Date()
        let nextDraw = Calendar.current.date(byAdding: .month, value: 3, to: mostRecentTest.drawDate) ?? now
        let monthsFromNow = Calendar.current.dateComponents([.month], from: now, to: nextDraw).month ?? 3
        return max(monthsFromNow, 1)
    }

    /// Blood-test scheduling text (#14).
    ///
    /// States the usual monitoring interval and where the next one falls. It does
    /// not instruct the user to book anything.
    var bloodTestSchedulingText: String {
        let monthsAway = suggestedBloodTestMonth
        guard let mostRecentTest = mostRecentRelevantBloodTest else {
            // In this branch `suggestedBloodTestMonth` is a month number on HRT
            // ("month 6"), not a count of months, so it takes no plural inflection.
            return String(localized: "Blood tests are typically repeated every 3 months while a dose is being established — around month \(monthsAway) here.",
                          comment: "Explains the usual blood test interval when the user has recorded no tests yet")
        }
        let lastDrawText = AppDateFormatters.monthDayYear.string(from: mostRecentTest.drawDate)
        return String(localized: "Last test \(lastDrawText). Next test due in ^[\(monthsAway) month](inflect: true).",
                      comment: "When the last blood test was and when the next is due")
    }

}
