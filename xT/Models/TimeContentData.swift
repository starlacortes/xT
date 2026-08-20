//
//  TimeContent.swift
//  xT
//
//  Content engine for the Time tab — generates personalized insights
//  based on medication type, months on HRT, and current hormone levels.
//

import Foundation
import SwiftUI

// MARK: - Content Engine
// (Type definitions moved to TimeContentTypes.swift)

struct TimeContentEngine {

    let medication: String        // "Estrogen" or "Testosterone"
    let method: String            // "Injectable", "Patch", "Gel", "Pill"
    let months: Int               // calendar months on HRT (for display)
    let currentLevel: Double?
    let dayOfCycle: Int           // actual day in the current dose cycle

    // --- Plan §4.5: new long-term tenure inputs ---
    let activeMonthsOnHRT: Int            // gap-aware months (for tiering)
    let ageAtStart: Int?                  // age when HRT began (for milestone branching)
    let screeningLog: [ScreeningType: Date]?  // last-done dates by screening type
    let showDoseIntensity: Bool           // user-facing toggle from Settings

    // --- New signals from MedicationManager (#2, #3, #6, #13, #14, #20) ---
    let adherenceRate: Double?            // monthly adherence (0–1), nil if unconfigured
    let cyclePosition: MedicationManager.CyclePosition  // current phase in dose cycle
    let regimenSegments: [MedicationManager.RegimenSegment]  // transition history
    let onTimeStreak: Int                 // consecutive on-time doses
    let relativeDoseIntensity: Double     // avg dose / standard dose
    let doseIntensityNote: String?  // disclaimer text for dose scaling
    let bloodTestSchedulingText: String   // dynamic blood test scheduling text
    let suggestedBloodTestMonth: Int?     // suggested month for next lab

    /// Length of the current dose cycle in days — the user's *effective* dosing
    /// interval (custom frequency when set, else the method default), passed in
    /// from `MedicationManager.effectiveFrequencyDays`. The "Day X of N" cycle
    /// label divides by this; a hardcoded per-method switch used to say "of 7"
    /// even for users on a 5-day custom schedule (and had an unreachable
    /// "Patch" arm — `method` is only ever Injectable/Cream/Oral).
    /// No default — every call site must supply the interval explicitly so this
    /// can never silently drift back to a hardcoded value.
    let cycleLengthDays: Int

    // MARK: Tenure tier

    /// Tier is now driven by gap-aware months (plan §4.2).
    var tenureTier: TenureTier { TenureTier(months: activeMonthsOnHRT) }

    /// Convenience: last screening date for the given type, or nil if never done.
    func lastScreening(_ type: ScreeningType) -> Date? {
        screeningLog?[type]
    }

    // MARK: Timeline header

    var timelineTitle: String {
        tenureTier.timeBandLabel
    }

    var timelineSubtitle: String {
        "\(medication) · \(method) · Month \(months) on HRT"
    }

    // MARK: Changes

    var changesSectionLabel: String {
        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            return String(localized: "CHANGES UNLOCKED")
        case .t5Settled:
            return String(localized: "ESTABLISHED CHANGES")
        case .t6Rooted:
            return String(localized: "ALL ESTABLISHED")
        case .t7Veteran:
            return String(localized: "YOUR JOURNEY")
        }
    }

    var changesSummaryBadge: String? {
        let unlocked = unlockedChanges.filter(\.unlocked).count
        let total = unlockedChanges.count
        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            return String(localized: "\(unlocked) of \(total)")
        case .t5Settled:
            return String(localized: "\(total) changes established")
        case .t6Rooted:
            return nil  // single-item "All established" doesn't need a badge
        case .t7Veteran:
            return nil  // retrospective summary stands alone
        }
    }

    /// Whether the changes section should be collapsed by default.
    /// T5+ (settled and beyond) see it collapsed; T1–T4 see it expanded.
    var changesDefaultCollapsed: Bool { tenureTier >= .t5Settled }

    var unlockedChanges: [TimeChange] {
        let early = medication == "Estrogen"
            ? estrogenChanges(months: activeMonthsOnHRT)
            : testosteroneChanges(months: activeMonthsOnHRT)

        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return early
        case .t4Deepening:
            return early.map { c in TimeChange(label: c.label, unlocked: true) }
        case .t5Settled:
            // All early changes established + long-term changes still unfolding.
            let earlyEstablished = early.map { c in
                TimeChange(label: c.label, unlocked: true)
            }
            let longTerm = estrogenLongTermChanges + testosteroneLongTermChanges
            // Only show the ones that are still maturing (perpetual for some).
            return earlyEstablished + longTerm
        case .t6Rooted:
            // T6: single "All established" — the changes section stops being
            // useful at 5 years per spec §3.3. Return a single-item list.
            return [TimeChange(label: "All changes fully established", unlocked: true)]
        case .t7Veteran:
            // T7: retrospective summary.
            let count = early.count + estrogenLongTermChanges.count + testosteroneLongTermChanges.count
            return [TimeChange(label: "\(count) changes over \(activeMonthsOnHRT) months", unlocked: true)]
        }
    }

    private func estrogenChanges(months: Int) -> [TimeChange] {
        [
            TimeChange(label: "Skin softening",      unlocked: months >= 1),
            TimeChange(label: "Breast growth",       unlocked: months >= 2),
            TimeChange(label: "Fat redistribution",  unlocked: months >= 3),
            TimeChange(label: "Hair thinning slows", unlocked: months >= 6),
            TimeChange(label: "Body hair softens",   unlocked: months >= 6),
            TimeChange(label: "Muscle mass shifts",  unlocked: months >= 9),
        ]
    }

    private func testosteroneChanges(months: Int) -> [TimeChange] {
        [
            TimeChange(label: "Voice deepening",     unlocked: months >= 2),
            TimeChange(label: "Clitoral growth",     unlocked: months >= 1),
            TimeChange(label: "Body hair growth",    unlocked: months >= 3),
            TimeChange(label: "Fat redistribution",  unlocked: months >= 3),
            TimeChange(label: "Muscle growth",       unlocked: months >= 4),
            TimeChange(label: "Skin oiliness",       unlocked: months >= 1),
        ]
    }

    // MARK: - Long-term Changes (plan §5.3)

    /// Changes that continue unfolding beyond 24 months. Only surfaced for
    /// estrogen users at T5 (settled). T6 collapses to "All established";
    /// T7 shows a retrospective count.
    private var estrogenLongTermChanges: [TimeChange] {
        medication == "Estrogen" ? [
            TimeChange(label: "Breast maturation continues (year 3–5)",  unlocked: activeMonthsOnHRT >= 24),
            TimeChange(label: "Bone density remodeling",                 unlocked: activeMonthsOnHRT >= 36),
            TimeChange(label: "Full tissue integration complete",        unlocked: activeMonthsOnHRT >= 60),
        ] : []
    }

    /// Long-term changes for testosterone users — mostly voice and hair
    /// final settling.
    private var testosteroneLongTermChanges: [TimeChange] {
        medication == "Testosterone" ? [
            TimeChange(label: "Voice final settling (year 3)",           unlocked: activeMonthsOnHRT >= 24),
            TimeChange(label: "Body hair completion",                    unlocked: activeMonthsOnHRT >= 36),
            TimeChange(label: "Facial hair full maturity",               unlocked: activeMonthsOnHRT >= 60),
        ] : []
    }

    // MARK: Hormone insight

    var hormoneInsight: TimeHormoneInsight? {
        guard let level = currentLevel else { return nil }

        if medication == "Estrogen" {
            let (label, palette, desc) = estrogenInsight(level: level)
            return TimeHormoneInsight(
                level: level,
                unit: "pg/mL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        } else {
            let (label, palette, desc) = testosteroneInsight(level: level)
            return TimeHormoneInsight(
                level: level,
                unit: "ng/dL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        }
    }

    private func estrogenInsight(level: Double) -> (String, TimeContentPalette, String) {
        let tier = tenureTier
        switch level {
        case ..<50:
            return (String(localized: "Below 50 pg/mL", comment: "Label naming the estradiol band the level falls in"),
                    .neutral, estrogenVeryLowCopy(tier: tier))
        case 50..<100:
            return (String(localized: "50–100 pg/mL", comment: "Label naming the estradiol band the level falls in"),
                    .neutral, estrogenLowCopy(tier: tier))
        case 100..<200:
            return (String(localized: "100–200 pg/mL", comment: "Label naming the estradiol band the level falls in"),
                    .neutral, estrogenMidCopy(tier: tier))
        case 200..<300:
            return (String(localized: "200–300 pg/mL", comment: "Label naming the estradiol band the level falls in"),
                    .neutral, estrogenHighCopy(tier: tier))
        default:
            return (String(localized: "Above 300 pg/mL", comment: "Label naming the estradiol band the level falls in"),
                    .neutral, estrogenVeryHighCopy(tier: tier))
        }
    }

    // MARK: Tenure-aware estrogen band copy
    //
    // The band label already states the number. These strings add the one thing a
    // number does not carry: what the band is typically associated with, and — once
    // the user has enough history for the phrase to mean anything — how it sits
    // against their own established range. They make no recommendation. Deciding
    // what to do about a reading is the user's and their provider's call, and the
    // app has neither their labs nor their history to make it.

    /// True once the user has been on therapy long enough to have an established
    /// personal range worth referring to.
    private func hasEstablishedBaseline(_ tier: TenureTier) -> Bool {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening: return false
        case .t5Settled, .t6Rooted, .t7Veteran:                    return true
        }
    }

    private func estrogenVeryLowCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Below the range most people on established estrogen therapy maintain, and below the range typically associated with therapeutic effect.",
                     comment: "Factual description of a very low estradiol band for a long-term user")
            : String(localized: "Below the range typically associated with therapeutic effect. Levels commonly fluctuate in the first months of therapy while a dose settles.",
                     comment: "Factual description of a very low estradiol band for a newer user")
    }

    private func estrogenLowCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "At the lower end of the range most people on established estrogen therapy maintain.",
                     comment: "Factual description of a low estradiol band for a long-term user")
            : String(localized: "At the lower end of the typical therapeutic range. Levels in this band are often seen near the end of a dose cycle.",
                     comment: "Factual description of a low estradiol band for a newer user")
    }

    private func estrogenMidCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Within the range most people on established estrogen therapy maintain.",
                     comment: "Factual description of a mid estradiol band for a long-term user")
            : String(localized: "Within the range most feminising hormone therapy aims for. Skin, fat distribution and breast development are associated with sustained levels in this band.",
                     comment: "Factual description of a mid estradiol band for a newer user")
    }

    private func estrogenHighCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Above the range most people on established estrogen therapy maintain.",
                     comment: "Factual description of a high estradiol band for a long-term user")
            : String(localized: "Above the typical therapeutic range. Levels in this band are common shortly after an injected dose.",
                     comment: "Factual description of a high estradiol band for a newer user")
    }

    private func estrogenVeryHighCopy(tier: TenureTier) -> String {
        String(localized: "Well above the typical therapeutic range. Sustained estradiol above 300 pg/mL is associated with increased thromboembolic risk.",
               comment: "Factual description of a very high estradiol band, including the clinical association")
    }

    private func testosteroneInsight(level: Double) -> (String, TimeContentPalette, String) {
        let tier = tenureTier
        switch level {
        case ..<50:
            return (String(localized: "Below 50 ng/dL", comment: "Label naming the testosterone band the level falls in"),
                    .neutral, tSuppressedCopy(tier: tier))
        case 50..<200:
            return (String(localized: "50–200 ng/dL", comment: "Label naming the testosterone band the level falls in"),
                    .neutral, tLowMaleCopy(tier: tier))
        case 200..<800:
            return (String(localized: "200–800 ng/dL", comment: "Label naming the testosterone band the level falls in"),
                    .neutral, tMaleRangeCopy(tier: tier))
        default:
            return (String(localized: "Above 800 ng/dL", comment: "Label naming the testosterone band the level falls in"),
                    .neutral, tHighCopy(tier: tier))
        }
    }

    // MARK: Tenure-aware testosterone band copy

    private func tSuppressedCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Suppressed, consistent with established anti-androgen or estrogen therapy.",
                     comment: "Factual description of a suppressed testosterone band for a long-term user")
            : String(localized: "Suppressed. This is the band feminising therapy typically brings testosterone down to.",
                     comment: "Factual description of a suppressed testosterone band for a newer user")
    }

    private func tLowMaleCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Below the range most people on established masculinising therapy maintain.",
                     comment: "Factual description of a low-male testosterone band for a long-term user")
            : String(localized: "Below the typical adult male reference range of 300–1,000 ng/dL.",
                     comment: "Factual description of a low-male testosterone band for a newer user")
    }

    private func tMaleRangeCopy(tier: TenureTier) -> String {
        hasEstablishedBaseline(tier)
            ? String(localized: "Within the range most people on established masculinising therapy maintain.",
                     comment: "Factual description of a mid testosterone band for a long-term user")
            : String(localized: "Within the typical adult male reference range. Voice change, muscle mass and body hair growth are associated with sustained levels in this band.",
                     comment: "Factual description of a mid testosterone band for a newer user")
    }

    private func tHighCopy(tier: TenureTier) -> String {
        String(localized: "Above the typical adult male reference range. A share of circulating testosterone converts to estradiol via aromatase, and that conversion rises with the level.",
               comment: "Factual description of a high testosterone band, including the aromatization mechanism")
    }

    // MARK: Upcoming milestones

    /// Screening-log-driven badge: shows "Done" with date if a recent screening
    /// exists, otherwise the default label.
    private func screeningBadge(for type: ScreeningType, label: String) -> String {
        guard let date = lastScreening(type) else { return label }
        return String(localized: "Done \(AppDateFormatters.monthYear.string(from: date))",
                      comment: "Badge showing the month a screening was last done")
    }

    /// Bone-density milestone text, as a whole sentence per case.
    ///
    /// This used to append a fragment (", especially given you started HRT at 34")
    /// onto a base sentence. A leading-comma fragment is not translatable — clause
    /// order and punctuation differ by language, and a translator sees the piece
    /// without the sentence it attaches to. Each variant is now its own string.
    private func boneDensityNote(hormoneSupportsDensity: String) -> String {
        guard let age = ageAtStart, age >= 30 else { return hormoneSupportsDensity }
        return String(localized: "\(hormoneSupportsDensity) Starting hormone therapy at \(age) places bone density earlier on the monitoring schedule.",
                      comment: "Bone density milestone for someone who started HRT at 30 or older")
    }

    /// Age- and tenure-aware note for cancer screenings (T7 milestone).
    ///
    /// Names which screenings the age band covers. Whether to have them is between
    /// the user and their provider, so this states the schedule rather than
    /// instructing them to book anything.
    private var ageBasedScreeningNote: String {
        guard let age = ageAtStart else {
            return String(localized: "Age-appropriate cancer screening at this stage may include mammogram, colorectal screening or skin checks.",
                          comment: "Cancer screening milestone when the user's starting age is unknown")
        }
        let currentAge = age + (activeMonthsOnHRT / 12)
        return String(localized: "At around age \(currentAge), age-appropriate cancer screening may include mammogram, colorectal screening or skin checks.",
                      comment: "Cancer screening milestone naming the user's approximate current age")
    }

    var milestonesSectionLabel: String {
        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            return String(localized: "COMING UP")
        case .t5Settled, .t6Rooted, .t7Veteran:
            return String(localized: "LONG-TERM HEALTH")
        }
    }

    // MARK: - Shared milestone builders
    //
    // Seventeen call sites in the two milestone lists below built six milestone
    // shapes by hand; the duplicates drifted (one T-side DEXA row had a purple
    // palette where every other was teal) and any badge tweak had to be repeated.
    // All authored strings are unchanged — these only centralize the shapes.

    /// Shared "N months away" countdown milestone (clock icon, neutral palette,
    /// localized inflected badge). Used by the month-12 and year-2 check-ins.
    private func countdownMilestone(title: String, description: String, targetMonth: Int) -> TimeMilestone {
        let monthsAway = targetMonth - activeMonthsOnHRT
        return TimeMilestone(
            title: title,
            description: description,
            icon: "clock",
            palette: .neutral,
            badge: String(localized: "^[\(monthsAway) month](inflect: true) away",
                          comment: "Badge showing how far off a scheduled milestone is")
        )
    }

    /// "Your next blood test" — the scheduling text plus an optional suggested-month badge.
    private var nextBloodTestMilestone: TimeMilestone {
        TimeMilestone(
            title: "Your next blood test",
            description: bloodTestSchedulingText,
            icon: "test-pipe",
            palette: .purple,
            badge: suggestedBloodTestMonth.map { String(localized: "Around month \($0)") }
        )
    }

    /// "Annual blood panel" — identical on every settled-tier list for both
    /// hormones (the T lists title it "+ CBC"). The badge flips to "Done <month>"
    /// once a panel is on file.
    private func annualBloodPanelMilestone(title: String = "Annual blood panel") -> TimeMilestone {
        TimeMilestone(
            title: title,
            description: bloodTestSchedulingText,
            icon: "test-pipe",
            palette: .purple,
            badge: screeningBadge(for: .bloodPanel, label: "Due annually")
        )
    }

    /// The 5-year comprehensive review — identical on both hormones.
    private var fiveYearReassessmentMilestone: TimeMilestone {
        TimeMilestone(
            title: "5-year provider reassessment",
            description: "A comprehensive review with your provider: dose, labs, screenings, and any emerging health considerations.",
            icon: "stethoscope",
            palette: .pink,
            badge: activeMonthsOnHRT >= 60 ? String(localized: "Due now") : String(localized: "At month 60")
        )
    }

    /// The 10-year comprehensive review — shared shell; the description names
    /// whichever hormone-specific markers apply.
    private func tenYearReviewMilestone(description: String) -> TimeMilestone {
        TimeMilestone(
            title: "10-year comprehensive review",
            description: description,
            icon: "stethoscope",
            palette: .pink,
            badge: activeMonthsOnHRT >= 120 ? String(localized: "Due now") : String(localized: "At month 120")
        )
    }

    /// Shared DEXA bone-density milestone — clock icon and a "last done" badge.
    private func dexaMilestone(title: String, description: String,
                               badgeLabel: String, palette: TimeContentPalette = .teal) -> TimeMilestone {
        TimeMilestone(
            title: title,
            description: description,
            icon: "clock",
            palette: palette,
            badge: screeningBadge(for: .dexaScan, label: badgeLabel)
        )
    }

    var upcomingMilestones: [TimeMilestone] {
        if medication == "Estrogen" {
            return estrogenMilestones
        } else {
            return testosteroneMilestones
        }
    }

    private var estrogenMilestones: [TimeMilestone] {
        var milestones: [TimeMilestone] = []

        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            if activeMonthsOnHRT < 12 {
                milestones.append(countdownMilestone(
                    title: "Month 12 milestone",
                    description: "Hair regrowth typically begins, and breast growth enters a new phase.",
                    targetMonth: 12
                ))
            }

            if activeMonthsOnHRT < 24 {
                milestones.append(countdownMilestone(
                    title: "2-year milestone",
                    description: "Most permanent changes have developed by year two. Skin and fat redistribution are near complete.",
                    targetMonth: 24
                ))
            }

            milestones.append(nextBloodTestMilestone)

        case .t5Settled:
            // Years 2–5: shift from "what's changing" to "maintain + first long-term screenings".
            milestones.append(annualBloodPanelMilestone())

            milestones.append(dexaMilestone(
                title: "Bone density scan",
                description: boneDensityNote(hormoneSupportsDensity: String(localized: "Estrogen supports bone mineral density. A DEXA scan measures it directly; the usual schedule is a baseline plus follow-ups every 2 years.",
                                                                            comment: "Bone density milestone on estrogen therapy")),
                badgeLabel: "Every 2 years"
            ))

            milestones.append(TimeMilestone(
                title: "Breast health screening",
                description: "After 5+ years of estrogen therapy, discuss mammogram timing with your provider. Self-exams remain important regardless of tenure.",
                icon: "clock",
                palette: .pink,
                badge: activeMonthsOnHRT >= 60
                    ? screeningBadge(for: .breastScreening, label: "Discussed")
                    : "After year 5"
            ))

            milestones.append(TimeMilestone(
                title: "Cardiovascular check",
                description: "Long-term estrogen therapy affects lipid profiles and cardiovascular risk. Annual checkups help monitor heart health.",
                icon: "clock",
                palette: .amber,
                badge: screeningBadge(for: .cardioCheck, label: "Annual")
            ))

        case .t6Rooted:
            // Years 5–10: richer health surveillance, 5-year reassessment.
            milestones.append(annualBloodPanelMilestone())

            milestones.append(dexaMilestone(
                title: "DEXA rescan due",
                description: "Bone density should be reassessed every 2 years from baseline. Compare against your prior scan to track trends.",
                badgeLabel: "Every 2 years"
            ))

            milestones.append(fiveYearReassessmentMilestone)

            milestones.append(TimeMilestone(
                title: "10-year CVD risk re-score",
                description: "Recalculate cardiovascular risk with current lipid panel, blood pressure, and family history. Estrogen's long-term CV effects warrant periodic risk assessment.",
                icon: "heart",
                palette: .amber,
                badge: "Schedule with provider"
            ))

        case .t7Veteran:
            // 10+ years: long-term health is the whole story.
            milestones.append(annualBloodPanelMilestone())

            milestones.append(tenYearReviewMilestone(
                description: "A thorough reassessment: dose adequacy, all screening histories, bone density trend, cardiovascular risk, and mental health check-in."
            ))

            milestones.append(TimeMilestone(
                title: "Age-appropriate cancer screenings",
                description: ageBasedScreeningNote,
                icon: "cross.case",
                palette: .amber,
                badge: "Discuss with provider"
            ))

            milestones.append(dexaMilestone(
                title: "Bone density trend review",
                description: "Compare serial DEXA scans. Stable or improving density = estrogen is working. Declining density may warrant intervention.",
                badgeLabel: "Review trend"
            ))

            milestones.append(TimeMilestone(
                title: "Anniversary: 10 years on HRT",
                description: "Ten years of hormone therapy.",
                icon: "sparkles",
                palette: .optimal,
                badge: "10 years"
            ))
        }

        return milestones
    }

    private var testosteroneMilestones: [TimeMilestone] {
        var milestones: [TimeMilestone] = []

        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            if activeMonthsOnHRT < 6 {
                milestones.append(TimeMilestone(
                    title: "Voice changes begin",
                    description: "Most people notice voice deepening between months 3–6. It can feel sudden or gradual.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(max(0, 3 - activeMonthsOnHRT)) months away"
                ))
            }

            if activeMonthsOnHRT < 12 {
                milestones.append(countdownMilestone(
                    title: "Month 12 check-in",
                    description: "A good time to reassess your dose and review all changes with your provider.",
                    targetMonth: 12
                ))
            }

            milestones.append(nextBloodTestMilestone)

        case .t5Settled:
            // Years 2–5: established maintenance, first long-term screenings.
            milestones.append(annualBloodPanelMilestone())

            milestones.append(TimeMilestone(
                title: "Cardiovascular health",
                description: "Testosterone affects red blood cell production and lipid profiles. Annual CBC and lipid panels are recommended.",
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .cardioCheck, label: "Annual")
            ))

            milestones.append(TimeMilestone(
                title: "Liver function panel",
                description: "Long-term testosterone therapy can affect liver enzymes, especially with oral formulations. Annual monitoring is standard care.",
                icon: "clock",
                palette: .amber,
                badge: screeningBadge(for: .liverPanel, label: "Annual")
            ))

            milestones.append(dexaMilestone(
                title: "Bone density check",
                description: boneDensityNote(hormoneSupportsDensity: String(localized: "Testosterone supports bone mineral density. A DEXA scan measures it directly; the usual schedule is a baseline plus periodic follow-ups.",
                                                                            comment: "Bone density milestone on testosterone therapy")),
                badgeLabel: "Periodic",
                palette: .purple
            ))

        case .t6Rooted:
            // Years 5–10: richer surveillance.
            milestones.append(annualBloodPanelMilestone(title: "Annual blood panel + CBC"))

            milestones.append(fiveYearReassessmentMilestone)

            milestones.append(TimeMilestone(
                title: "Liver & lipid panels",
                description: "Long-term T therapy warrants periodic liver enzyme and lipid monitoring. Annual panels are the standard at this stage.",
                icon: "clock",
                palette: .amber,
                badge: screeningBadge(for: .liverPanel, label: "Annual")
            ))

            milestones.append(dexaMilestone(
                title: "DEXA rescan due",
                description: "Reassess bone density every 2–3 years. Stable or improving trends confirm T is doing its job for skeletal health.",
                badgeLabel: "Every 2–3 years"
            ))

        case .t7Veteran:
            // 10+ years: comprehensive long-term health.
            milestones.append(annualBloodPanelMilestone(title: "Annual blood panel + CBC"))

            milestones.append(tenYearReviewMilestone(
                description: "A thorough reassessment: dose adequacy, all screening histories, cardiovascular risk, hematocrit trends, and metabolic health."
            ))

            milestones.append(TimeMilestone(
                title: "Age-appropriate screenings",
                description: ageBasedScreeningNote,
                icon: "cross.case",
                palette: .amber,
                badge: "Discuss with provider"
            ))

            milestones.append(dexaMilestone(
                title: "Bone density trend review",
                description: "Compare serial DEXA scans. T supports bone mineral density — stable or improving trends are expected with adequate levels.",
                badgeLabel: "Review trend"
            ))

            milestones.append(TimeMilestone(
                title: "Anniversary: 10 years on HRT",
                description: "Ten years of hormone therapy.",
                icon: "sparkles",
                palette: .optimal,
                badge: "10 years"
            ))
        }

        return milestones
    }

    private var isEstrogen: Bool { medication == "Estrogen" }

}
