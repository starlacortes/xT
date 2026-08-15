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
            ? estrogenChanges(months: months)
            : testosteroneChanges(months: months)

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
            return [TimeChange(label: "\(count) changes over \(months) months", unlocked: true)]
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
            let (label, palette, desc) = estrogenInsight(level: level, months: months)
            return TimeHormoneInsight(
                level: level,
                unit: "pg/mL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        } else {
            let (label, palette, desc) = testosteroneInsight(level: level, months: months)
            return TimeHormoneInsight(
                level: level,
                unit: "ng/dL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        }
    }

    private func estrogenInsight(level: Double, months: Int) -> (String, TimeContentPalette, String) {
        let tier = TenureTier(months: months)
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

    private func testosteroneInsight(level: Double, months: Int) -> (String, TimeContentPalette, String) {
        let tier = TenureTier(months: months)
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

    // MARK: Body system cards

    var bodySystems: [TimeBodySystem] {
        if medication == "Estrogen" {
            return estrogenBodySystems
        } else {
            return testosteroneBodySystems
        }
    }

    private var estrogenBodySystems: [TimeBodySystem] {
        let tier = tenureTier

        return [
            TimeBodySystem(
                title: "Mood & mind",
                subtitle: estrogenMoodSubtitle(tier: tier),
                icon: "brain",
                palette: .purple,
                progressLabel: estrogenMoodLabel(tier: tier, months: months),
                systemKey: .moodAndMind,
                focusText: bodySystemFocus(for: .moodAndMind)
            ),
            TimeBodySystem(
                title: "Skin & glow",
                subtitle: estrogenSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .teal,
                progressLabel: estrogenSkinLabel(tier: tier, months: months),
                systemKey: .skinAndGlow,
                focusText: bodySystemFocus(for: .skinAndGlow)
            ),
            TimeBodySystem(
                title: "Body shape",
                subtitle: estrogenBodySubtitle(tier: tier),
                icon: "body-scan",
                palette: .amber,
                progressLabel: estrogenBodyLabel(tier: tier, months: months),
                systemKey: .bodyShape,
                focusText: bodySystemFocus(for: .bodyShape)
            ),
            TimeBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle,
                focusText: bodySystemFocus(for: .yourCycle)
            ),
        ]
    }

    private var testosteroneBodySystems: [TimeBodySystem] {
        let tier = tenureTier

        return [
            TimeBodySystem(
                title: "Voice",
                subtitle: testosteroneVoiceSubtitle(tier: tier),
                icon: "microphone",
                palette: .purple,
                progressLabel: testosteroneVoiceLabel(tier: tier, months: months),
                systemKey: .voice,
                focusText: bodySystemFocus(for: .voice)
            ),
            TimeBodySystem(
                title: "Skin & hair",
                subtitle: testosteroneSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .amber,
                progressLabel: testosteroneSkinLabel(tier: tier, months: months),
                systemKey: .skinAndHair,
                focusText: bodySystemFocus(for: .skinAndHair)
            ),
            TimeBodySystem(
                title: "Muscle & strength",
                subtitle: testosteroneMuscleSubtitle(tier: tier),
                icon: "body-scan",
                palette: .teal,
                progressLabel: testosteroneMuscleLabel(tier: tier, months: months),
                systemKey: .muscleStrength,
                focusText: bodySystemFocus(for: .muscleStrength)
            ),
            TimeBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle,
                focusText: bodySystemFocus(for: .yourCycle)
            ),
        ]
    }

    // MARK: - Tenure label helpers (Estrogen)

    private func estrogenMoodLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return months < 6 ? "Settling in" : "Stabilising"
        case .t4Deepening:       return "Well-established"
        case .t5Settled:         return "Stable"
        case .t6Rooted:          return "Stable · Year 5+"
        case .t7Veteran:         return "Stable · 10+ years"
        }
    }
    private func estrogenMoodSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "How estrogen shapes your emotions")
        case .t4Deepening:       return "Emotional patterns are settling"
        case .t5Settled:         return "Long-term emotional baseline"
        case .t6Rooted:          return "Emotional baseline at 5+ years"
        case .t7Veteran:         return "Emotional baseline at 10+ years"
        }
    }
    private func estrogenSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Just starting")
        case .t3InMotion:
            return String(localized: "Well underway")
        case .t4Deepening:       return "Ongoing"
        case .t5Settled:         return "Maintained"
        case .t6Rooted:          return "Maintained · Year 5+"
        case .t7Veteran:         return "Maintained · 10+ years"
        }
    }
    private func estrogenSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "What's changing and why")
        case .t4Deepening:       return "Your skin has fully adapted"
        case .t5Settled:         return "Long-term dermal health"
        case .t6Rooted:          return "Dermal health at 5+ years"
        case .t7Veteran:         return "Dermal health at 10+ years"
        }
    }
    private func estrogenBodyLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return months < 6 ? "Early changes" : "Still in progress"
        case .t4Deepening:       return "Near complete"
        case .t5Settled:         return "Mature changes"
        case .t6Rooted:          return "Mature · Year 5+"
        case .t7Veteran:         return "Mature · 10+ years"
        }
    }
    private func estrogenBodySubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Fat, curves & what to expect")
        case .t4Deepening:       return "Curves have largely settled"
        case .t5Settled:         return "Your body's established form"
        case .t6Rooted:          return "Body composition at 5+ years"
        case .t7Veteran:         return "Body composition at 10+ years"
        }
    }

    // MARK: - Tenure label helpers (Testosterone)

    private func testosteroneVoiceLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Early changes")
        case .t3InMotion:
            return String(localized: "Still shifting")
        case .t4Deepening:       return "Near final"
        case .t5Settled:         return "Settled"
        case .t6Rooted:          return "Settled · Year 5+"
        case .t7Veteran:         return "Settled · 10+ years"
        }
    }
    private func testosteroneVoiceSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Deepening timeline")
        case .t4Deepening:       return "Voice has largely settled"
        case .t5Settled:         return "Permanent depth"
        case .t6Rooted:          return "Voice at 5+ years"
        case .t7Veteran:         return "Voice at 10+ years"
        }
    }
    private func testosteroneSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Just starting")
        case .t4Deepening:       return "Ongoing"
        case .t5Settled:         return "Maintained"
        case .t6Rooted:          return "Maintained · Year 5+"
        case .t7Veteran:         return "Maintained · 10+ years"
        }
    }
    private func testosteroneSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Oil, texture & growth")
        case .t4Deepening:       return "Skin & hair patterns stabilised"
        case .t5Settled:         return "Long-term texture & growth"
        case .t6Rooted:          return "Skin & hair at 5+ years"
        case .t7Veteran:         return "Skin & hair at 10+ years"
        }
    }
    private func testosteroneMuscleLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return months < 6 ? "Building" : "Growing"
        case .t4Deepening:       return "Peak growth phase"
        case .t5Settled:         return "Stable"
        case .t6Rooted:          return "Stable · Year 5+"
        case .t7Veteran:         return "Stable · 10+ years"
        }
    }
    private func testosteroneMuscleSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "What T does to your body")
        case .t4Deepening:       return "Strength is well established"
        case .t5Settled:         return "Sustained muscle profile"
        case .t6Rooted:          return "Muscle profile at 5+ years"
        case .t7Veteran:         return "Muscle profile at 10+ years"
        }
    }

    private var cycleLengthDays: Int {
        switch method {
        case "Injectable": return 7
        case "Patch": return 3
        default: return 1
        }
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
            if months < 12 {
                let monthsAway = 12 - months
                milestones.append(TimeMilestone(
                    title: "Month 12 milestone",
                    description: "Hair regrowth typically begins, and breast growth enters a new phase.",
                    icon: "clock",
                    palette: .neutral,
                    badge: String(localized: "^[\(monthsAway) month](inflect: true) away",
                                  comment: "Badge showing how far off a scheduled milestone is")
                ))
            }

            if months < 24 {
                let monthsAway = 24 - months
                milestones.append(TimeMilestone(
                    title: "2-year milestone",
                    description: "Most permanent changes have developed by year two. Skin and fat redistribution are near complete.",
                    icon: "clock",
                    palette: .neutral,
                    badge: String(localized: "^[\(monthsAway) month](inflect: true) away",
                                  comment: "Badge showing how far off a scheduled milestone is")
                ))
            }

            milestones.append(TimeMilestone(
                title: "Your next blood test",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

        case .t5Settled:
            // Years 2–5: shift from "what's changing" to "maintain + first long-term screenings".
            milestones.append(TimeMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

            milestones.append(TimeMilestone(
                title: "Bone density scan",
                description: boneDensityNote(hormoneSupportsDensity: String(localized: "Estrogen supports bone mineral density. A DEXA scan measures it directly; the usual schedule is a baseline plus follow-ups every 2 years.",
                                                                            comment: "Bone density milestone on estrogen therapy")),
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .dexaScan, label: "Every 2 years")
            ))

            milestones.append(TimeMilestone(
                title: "Breast health screening",
                description: "After 5+ years of estrogen therapy, discuss mammogram timing with your provider. Self-exams remain important regardless of tenure.",
                icon: "clock",
                palette: .pink,
                badge: months >= 60
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
            milestones.append(TimeMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

            milestones.append(TimeMilestone(
                title: "DEXA rescan due",
                description: "Bone density should be reassessed every 2 years from baseline. Compare against your prior scan to track trends.",
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .dexaScan, label: "Every 2 years")
            ))

            milestones.append(TimeMilestone(
                title: "5-year provider reassessment",
                description: "A comprehensive review with your provider: dose, labs, screenings, and any emerging health considerations.",
                icon: "stethoscope",
                palette: .pink,
                badge: activeMonthsOnHRT >= 60 ? "Due now" : "At month 60"
            ))

            milestones.append(TimeMilestone(
                title: "10-year CVD risk re-score",
                description: "Recalculate cardiovascular risk with current lipid panel, blood pressure, and family history. Estrogen's long-term CV effects warrant periodic risk assessment.",
                icon: "heart",
                palette: .amber,
                badge: "Schedule with provider"
            ))

        case .t7Veteran:
            // 10+ years: long-term health is the whole story.
            milestones.append(TimeMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

            milestones.append(TimeMilestone(
                title: "10-year comprehensive review",
                description: "A thorough reassessment: dose adequacy, all screening histories, bone density trend, cardiovascular risk, and mental health check-in.",
                icon: "stethoscope",
                palette: .pink,
                badge: activeMonthsOnHRT >= 120 ? "Due now" : "At month 120"
            ))

            milestones.append(TimeMilestone(
                title: "Age-appropriate cancer screenings",
                description: ageBasedScreeningNote,
                icon: "cross.case",
                palette: .amber,
                badge: "Discuss with provider"
            ))

            milestones.append(TimeMilestone(
                title: "Bone density trend review",
                description: "Compare serial DEXA scans. Stable or improving density = estrogen is working. Declining density may warrant intervention.",
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .dexaScan, label: "Review trend")
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
            if months < 6 {
                milestones.append(TimeMilestone(
                    title: "Voice changes begin",
                    description: "Most people notice voice deepening between months 3–6. It can feel sudden or gradual.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(max(0, 3 - months)) months away"
                ))
            }

            if months < 12 {
                let monthsAway = 12 - months
                milestones.append(TimeMilestone(
                    title: "Month 12 check-in",
                    description: "A good time to reassess your dose and review all changes with your provider.",
                    icon: "clock",
                    palette: .neutral,
                    badge: String(localized: "^[\(monthsAway) month](inflect: true) away",
                                  comment: "Badge showing how far off a scheduled milestone is")
                ))
            }

            milestones.append(TimeMilestone(
                title: "Your next blood test",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

        case .t5Settled:
            // Years 2–5: established maintenance, first long-term screenings.
            milestones.append(TimeMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

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

            milestones.append(TimeMilestone(
                title: "Bone density check",
                description: boneDensityNote(hormoneSupportsDensity: String(localized: "Testosterone supports bone mineral density. A DEXA scan measures it directly; the usual schedule is a baseline plus periodic follow-ups.",
                                                                            comment: "Bone density milestone on testosterone therapy")),
                icon: "clock",
                palette: .purple,
                badge: screeningBadge(for: .dexaScan, label: "Periodic")
            ))

        case .t6Rooted:
            // Years 5–10: richer surveillance.
            milestones.append(TimeMilestone(
                title: "Annual blood panel + CBC",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

            milestones.append(TimeMilestone(
                title: "5-year provider reassessment",
                description: "A comprehensive review with your provider: dose, labs, screenings, and any emerging health considerations.",
                icon: "stethoscope",
                palette: .pink,
                badge: activeMonthsOnHRT >= 60 ? "Due now" : "At month 60"
            ))

            milestones.append(TimeMilestone(
                title: "Liver & lipid panels",
                description: "Long-term T therapy warrants periodic liver enzyme and lipid monitoring. Annual panels are the standard at this stage.",
                icon: "clock",
                palette: .amber,
                badge: screeningBadge(for: .liverPanel, label: "Annual")
            ))

            milestones.append(TimeMilestone(
                title: "DEXA rescan due",
                description: "Reassess bone density every 2–3 years. Stable or improving trends confirm T is doing its job for skeletal health.",
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .dexaScan, label: "Every 2–3 years")
            ))

        case .t7Veteran:
            // 10+ years: comprehensive long-term health.
            milestones.append(TimeMilestone(
                title: "Annual blood panel + CBC",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: screeningBadge(for: .bloodPanel, label: "Due annually")
            ))

            milestones.append(TimeMilestone(
                title: "10-year comprehensive review",
                description: "A thorough reassessment: dose adequacy, all screening histories, cardiovascular risk, hematocrit trends, and metabolic health.",
                icon: "stethoscope",
                palette: .pink,
                badge: activeMonthsOnHRT >= 120 ? "Due now" : "At month 120"
            ))

            milestones.append(TimeMilestone(
                title: "Age-appropriate screenings",
                description: ageBasedScreeningNote,
                icon: "cross.case",
                palette: .amber,
                badge: "Discuss with provider"
            ))

            milestones.append(TimeMilestone(
                title: "Bone density trend review",
                description: "Compare serial DEXA scans. T supports bone mineral density — stable or improving trends are expected with adequate levels.",
                icon: "clock",
                palette: .teal,
                badge: screeningBadge(for: .dexaScan, label: "Review trend")
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

    // MARK: - Body System Detail Content

    func bodySystemDetail(for systemKey: BodySystemKey) -> TimeBodySystemDetail {
        if medication == "Estrogen" {
            return estrogenDetail(for: systemKey)
        } else {
            return testosteroneDetail(for: systemKey)
        }
    }

    // MARK: - Body System Month Focus

    /// Returns a month-specific factual focus sentence for the given body
    /// system. This is the per-month content that updates continuously as
    /// months progress, even when the tier-level copy is unchanged.
    ///
    /// Maps each `BodySystemKey` to the most relevant `BodyRegion` and returns
    /// its `focusText(at:)`. If no region-specific focus is available, falls
    /// back to the timeline text for the current tier.
    func bodySystemFocus(for systemKey: BodySystemKey) -> String {
        let regions: [BodyRegion]
        let regionKey: String?

        switch systemKey {
        case .moodAndMind:
            regions = isEstrogen ? TimeBodyRegions.mindRegions : TimeBodyRegions.mindRegionsT
            regionKey = "hippocampus"
        case .skinAndGlow:
            regions = TimeBodyRegions.bodyRegions
            regionKey = "abdomen"
        case .bodyShape:
            regions = TimeBodyRegions.bodyRegions
            regionKey = "hips"
        case .yourCycle:
            return cycleFocusText
        case .voice:
            regions = TimeBodyRegions.bodyRegionsT
            regionKey = "chest"
        case .skinAndHair:
            regions = TimeBodyRegions.bodyRegionsT
            regionKey = "chest"
        case .muscleStrength:
            regions = TimeBodyRegions.bodyRegionsT
            regionKey = "thighs"
        }

        if let regionKey,
           let region = regions.first(where: { $0.key == regionKey }),
           let focus = region.focusText(at: activeMonthsOnHRT) {
            return focus
        }

        return tierFallbackFocus(for: systemKey)
    }

    private var isEstrogen: Bool { medication == "Estrogen" }

    /// Fallback: if no month-band focus is authored, use the timeline text
    /// for the current tier so the card still has fresh, relevant content.
    private func tierFallbackFocus(for systemKey: BodySystemKey) -> String {
        let detail = bodySystemDetail(for: systemKey)
        return detail.timelineText
    }

    /// Cycle focus is tenure-aware but not region-mapped. It describes what's
    /// happening pharmacokinetically at the current tenure.
    private var cycleFocusText: String {
        let tier = tenureTier
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Your dose cycle is still stabilizing. Peak-to-trough variation is at its widest during the first months — tracking how you feel across the cycle helps establish your personal pattern.")
        case .t4Deepening:
            return String(localized: "Your cycle pattern is well established by now. The peak-to-trough swing is predictable from your dosing date, and any trough-related symptoms are identifiable.")
        case .t5Settled:
            return String(localized: "Cycle rhythm is stable and unremarkable at this stage. If you still notice trough effects, a shorter interval or longer-acting ester can flatten the curve.")
        case .t6Rooted:
            return String(localized: "Cycle rhythm is fully established after several years. No changes are needed unless something shifts; periodic labs confirm levels remain appropriate.")
        case .t7Veteran:
            return String(localized: "Dosing is maintenance after a decade. Your rhythm is long established — labs every 6–12 months confirm stability.")
        }
    }

    // MARK: Estrogen Detail Content

    private func estrogenDetail(for key: BodySystemKey) -> TimeBodySystemDetail {
        let tier = tenureTier

        switch key {
        case .moodAndMind:
            return TimeBodySystemDetail(
                systemKey: .moodAndMind,
                title: "Mood & mind",
                heroIcon: "brain.head.profile",
                palette: .purple,
                scienceText: """
                Estrogen directly influences neurotransmitter systems in your brain — serotonin, dopamine, and norepinephrine. ER-α and ER-β receptors are densely expressed in the amygdala, hippocampus, and prefrontal cortex, regions that govern emotion, memory, and executive function.

                As your endogenous testosterone is suppressed and estradiol levels rise, your brain undergoes a gradual neurochemical recalibration. The emotional landscape shifts: many describe a richer emotional range, increased empathy, and a deeper connection to feelings that previously felt muted.

                Estrogen also enhances synaptic plasticity and cerebral blood flow, which is why many people report improved verbal memory and emotional recall during the first two years of HRT.
                """,
                timelineText: timelineTextForMood(tier: tier),
                whatToExpect: whatToExpectForMood(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Your emotional baseline is stable — dips can still occur around trough day. Consistent dosing is the key to avoiding neurosteroid fluctuations that can cause low-mood troughs."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "By now your emotional patterns have largely stabilised. You likely have a good read on where your mood sits across your injection cycle."
                    : nil
            )

        case .skinAndGlow:
            return TimeBodySystemDetail(
                systemKey: .skinAndGlow,
                title: "Skin & glow",
                heroIcon: "sparkles",
                palette: .teal,
                scienceText: """
                Estrogen is a powerful trophic factor for skin. It upregulates collagen types I and III via ER-β receptors in dermal fibroblasts, increases hyaluronic acid production (boosting hydration), and reduces sebaceous gland activity — which is why skin becomes less oily and more radiant.

                The stratum corneum thins slightly, capillaries dilate, and the skin's barrier function improves. These changes combine to create what's often called the "estrogen glow" — softer, more translucent, and more hydrated skin.

                Estrogen also accelerates wound healing and reduces transepidermal water loss. For people switching from testosterone-dominant skin, the reduction in sebum is often one of the first noticeable physical changes.
                """,
                timelineText: timelineTextForSkin(tier: tier),
                whatToExpect: whatToExpectForSkin(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Skin renewal slows with age regardless of HRT. Sun protection, retinoids, and adequate hydration remain important. Estrogen maintains collagen but doesn't halt photoaging."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "Your skin has fully transitioned. The texture difference from pre-HRT is fully established — it's softer, less oily, and heals differently."
                    : nil
            )

        case .bodyShape:
            return TimeBodySystemDetail(
                systemKey: .bodyShape,
                title: "Body shape",
                heroIcon: "figure.stand",
                palette: .amber,
                scienceText: """
                Estrogen fundamentally reprograms where your body stores fat. Adipose tissue expresses both ER-α and ER-β receptors, and estrogen dominance signals fat deposition toward a gynoid (hip, thigh, and gluteal) pattern rather than the android (abdominal) pattern driven by testosterone.

                Lipoprotein lipase (LPL) activity increases in gluteofemoral fat depots, promoting subcutaneous fat storage, while decreasing in visceral depots. Simultaneously, muscle protein synthesis declines without androgenic signaling, leading to gradual loss of upper body muscle mass.

                These changes are slow — fat cells turnover over years, not weeks. The result is a gradual shift in silhouette: narrower shoulders, wider hips, and a more defined waist-to-hip ratio.
                """,
                timelineText: timelineTextForBody(tier: tier),
                whatToExpect: whatToExpectForBody(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Your body shape is largely stable. Weight cycling (±5–10 lbs) can still produce new fat in gynoid patterns. Muscle mass requires active resistance training to maintain."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "The majority of your fat redistribution has occurred by now. Any remaining changes will be subtle and gradual."
                    : nil
            )

        case .yourCycle:
            return TimeBodySystemDetail(
                systemKey: .yourCycle,
                title: "Your cycle",
                heroIcon: "waveform.path.ecg",
                palette: .pink,
                scienceText: """
                Injectable estradiol esters (valerate, cypionate) follow a predictable pharmacokinetic curve: a rise to peak within 1–3 days post-injection, followed by a gradual decline to trough just before your next dose. This is your "cycle" — a hormone wave that repeats every 5–7 days (depending on ester and dose).

                The peak-to-trough ratio varies by ester. Estradiol valerate produces a steeper peak and deeper trough (~3–4× ratio), while estradiol cypionate produces a flatter, more sustained profile (~2× ratio). Your mood, energy, and physical sensations may track this wave — some people are very aware of it, others barely notice it.

                Trough levels below 100 pg/mL may cause mood dips, hot flashes, or fatigue. Trough levels above 250 pg/mL are generally well-tolerated but should be discussed with your provider. The goal is a trough that keeps you feeling stable without exceeding safety thresholds at peak.
                """,
                timelineText: cycleTimelineText(tier: tier),
                whatToExpect: cycleWhatToExpect(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "You know your cycle well by now. If you experience trough symptoms, a shorter interval or ester switch (e.g., EV → EC) can flatten the curve."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "By this stage the pattern across an injection week is usually well known — which is the information a timing change would be based on."
                    : nil
            )

        default:
            return estrogenDetail(for: .moodAndMind) // fallback
        }
    }

    // MARK: Testosterone Detail Content

    private func testosteroneDetail(for key: BodySystemKey) -> TimeBodySystemDetail {
        let tier = tenureTier

        switch key {
        case .voice:
            return TimeBodySystemDetail(
                systemKey: .voice,
                title: "Voice",
                heroIcon: "mic",
                palette: .purple,
                scienceText: """
                Testosterone causes irreversible thickening and lengthening of the vocal folds (vocal cords) by acting on androgen receptors in the laryngeal cartilage and musculature. The thyroid cartilage enlarges, the vocal folds increase in mass, and the fundamental speaking frequency drops — typically settling between 85–155 Hz (compared to a pre-T range of 165–255 Hz).

                This is a structural change, not a muscular one. Once the folds thicken, they stay that way — voice deepening is permanent even if testosterone is stopped. The process typically begins within 3–6 months and continues for 1–2 years, with the most dramatic drop happening in the first year.

                Some people experience voice cracking or instability during the transition. This is normal — your vocal folds are literally growing, and muscle coordination takes time to catch up.
                """,
                timelineText: tVoiceTimeline(tier: tier),
                whatToExpect: tVoiceWhatToExpect(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Your voice is permanently settled. Pitch will not revert even if you pause T. Vocal training can still extend resonance and control regardless of HRT tenure."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "Your voice has done most of its changing. Any remaining shifts will be very subtle — a few Hz at most."
                    : nil
            )

        case .skinAndHair:
            return TimeBodySystemDetail(
                systemKey: .skinAndHair,
                title: "Skin & hair",
                heroIcon: "sparkles",
                palette: .amber,
                scienceText: """
                Testosterone dramatically upregulates sebaceous (oil) gland activity. Sebocytes express 5α-reductase, converting testosterone to the more potent dihydrotestosterone (DHT), which drives oil production. This is why skin becomes oilier, acne can flare (especially in the first year), and the skin texture coarsens slightly.

                DHT also activates vellus hair follicles across the body and face, transforming them into terminal (thick, pigmented) hairs. This process — hirsutism — is gradual and follows a predictable pattern: lower legs, thighs, abdomen, chest, back, and face.

                Scalp hair may thin in a male-pattern distribution if you have genetic susceptibility (androgenetic alopecia). This is mediated by DHT at the follicle level and is dose-dependent. Some people use finasteride or minoxidil to manage this.
                """,
                timelineText: tSkinTimeline(tier: tier),
                whatToExpect: tSkinWhatToExpect(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Body and facial hair are permanent. Scalp hair loss can be slowed with DHT blockers but not fully reversed once follicles miniaturise. Skin oiliness may mellow slightly with time."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "Your skin and hair patterns are largely stable. Acne may still flare around dose day if you're on a weekly schedule."
                    : nil
            )

        case .muscleStrength:
            return TimeBodySystemDetail(
                systemKey: .muscleStrength,
                title: "Muscle & strength",
                heroIcon: "figure.stand",
                palette: .teal,
                scienceText: """
                Testosterone is the primary anabolic hormone in the human body. It binds to androgen receptors on skeletal muscle cells, triggering increased protein synthesis, nitrogen retention, and satellite cell activation — all of which lead to muscle fiber hypertrophy.

                Even without additional exercise, being on testosterone increases lean body mass. Fat-free mass increases measurably within 3–6 months of starting T. Strength gains are even more pronounced when combined with resistance training — trans men often report rapid PR progression in the first year.

                Testosterone also increases erythropoiesis (red blood cell production), improving oxygen-carrying capacity and endurance. This is why hematocrit monitoring is important — levels that climb too high increase cardiovascular risk.
                """,
                timelineText: tMuscleTimeline(tier: tier),
                whatToExpect: tMuscleWhatToExpect(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "Your muscle profile is stable and will stay that way as long as T levels are maintained. Strength is use-it-or-lose-it — detraining will still cause atrophy, just at a slower rate than pre-T."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "You've likely hit peak muscle growth velocity. Continued gains depend on training stimulus more than T duration at this point."
                    : nil
            )

        case .yourCycle:
            return TimeBodySystemDetail(
                systemKey: .yourCycle,
                title: "Your cycle",
                heroIcon: "waveform.path.ecg",
                palette: .pink,
                scienceText: """
                Injectable testosterone esters (cypionate, enanthate) follow a predictable pharmacokinetic curve: a rise to peak within about 1–2 days post-injection, then a gradual multi-day decline to trough. The half-life of testosterone cypionate is approximately 4 days, so with weekly dosing you get a moderate peak-to-trough swing.

                You'll often see ~8 days quoted for cypionate. That figure comes from analysis that doesn't separate the testosterone your body already makes from the dose you injected; once the two are accounted for separately, the injected testosterone's half-life is closer to 4 days (Bi et al. 2018). This app models your own baseline production separately, so it uses the ~4 day figure.

                Some people feel energetic peaks shortly after their shot, while others feel a dip in the day or two before their next dose. These fluctuations are normal and reflect the difference between peak and trough serum levels.

                Aromatization — the conversion of testosterone to estradiol — also tracks this curve. If your dose is high, peak aromatization can produce enough E2 to cause mood changes, water retention, or nipple sensitivity. This is why many providers aim for trough T in the 400–700 ng/dL range rather than chasing higher peaks.
                """,
                timelineText: cycleTimelineTextForT(tier: tier),
                whatToExpect: cycleWhatToExpectForT(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "You know your rhythm. If troughs are uncomfortable, ask about splitting your dose to twice-weekly — it flattens the curve and reduces aromatization spikes."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "By this stage the pattern across a shot week is usually well known."
                    : nil
            )

        default:
            return testosteroneDetail(for: .voice) // fallback
        }
    }

    // MARK: - Estrogen Timeline Text Helpers

    private func timelineTextForMood(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Months 1–3: Emotional sensitivity often increases first. You may feel more tearful, reactive, or emotionally open. This is neurochemical recalibration.\n\nMonths 3–6: Emotional range broadens. Many describe feeling 'more themselves' — a sense of emotional alignment that was missing before.")
        case .t3InMotion:
            return String(localized: "Months 6–12: Mood patterns stabilise as your brain adapts to the new hormonal environment. Cyclical trough effects may become noticeable.")
        case .t4Deepening:
            return String(localized: "Months 12–24: The emotional baseline typically settles and holds. Patterns across a dose cycle are usually recognisable by this point.")
        case .t5Settled:
            return String(localized: "Year 2+: Your emotional landscape is fully established. You're reading from the same neurochemical playbook that cis women operate on — the brain has fully adapted to estrogen-dominant signaling.")
        case .t6Rooted:
            return String(localized: "Year 5+: Your emotional baseline is deeply ingrained. You've navigated years of hormone-steady cognition — trust your read of your own patterns. Annual mental health check-ins remain valuable, even when things feel stable.")
        case .t7Veteran:
            return String(localized: "10+ years: Your brain has run on estrogen for over a decade. The neurochemistry is second nature. Age-appropriate neurological screening is what tracks cognitive health from this stage onward.")
        }
    }

    private func timelineTextForSkin(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning:
            return String(localized: "Month 1: Reduced oiliness is often the very first change — noticeable within weeks.")
        case .t2Emerging:
            return String(localized: "Months 2–5: Skin texture begins softening. Pores appear smaller, hydration improves.")
        case .t3InMotion:
            return String(localized: "Months 6–12: The 'glow' becomes apparent. Skin is noticeably softer and more radiant than pre-HRT.")
        case .t4Deepening:
            return String(localized: "Months 12–24: Your skin has fully transitioned. Collagen density is up, sebum is down, and the texture difference from pre-HRT is complete.")
        case .t5Settled:
            return String(localized: "Year 2+: Your skin is estrogen-maintained at this point. It will stay soft and hydrated as long as levels remain in range. Age-related changes (fine lines, elasticity loss) will still occur — estrogen slows but doesn't stop the clock.")
        case .t6Rooted:
            return String(localized: "Year 5+: Collagen density remains above what it would be without estrogen, but the natural aging timeline still runs. Fine lines and elasticity loss are normal. Retinoids, vitamin C and sun protection are the interventions with evidence behind them for this.")
        case .t7Veteran:
            return String(localized: "10+ years: Your skin has been estrogen-dominant for over a decade. The structural benefits (hydration, collagen, softness) are embedded. Age-related changes are universal — focus on skin cancer screening and gentle maintenance rather than chasing youthful texture.")
        }
    }

    private func timelineTextForBody(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Months 1–3: Subtle — you may notice slight softening around the hips or face.\n\nMonths 3–5: Fat redistribution becomes visible. Pants may fit differently as hip and thigh circumference increases.")
        case .t3InMotion:
            return String(localized: "Months 6–12: Waist-to-hip ratio begins shifting noticeably. Upper body muscle loss contributes to a narrower shoulder appearance.")
        case .t4Deepening:
            return String(localized: "Months 12–24: The bulk of your fat redistribution is complete. Your silhouette has changed meaningfully. Any remaining shifts are slow and subtle — fat cells turn over on a ~2–3 year cycle.")
        case .t5Settled:
            return String(localized: "Year 2+: Your body shape is stable. Weight cycling (±5–10 lbs) will still produce new fat deposition in estrogen-dominant patterns. Muscle mass requires active resistance training to maintain — use it or lose it.")
        case .t6Rooted:
            return String(localized: "Year 5+: Your silhouette is fully estrogen-dominant. Bone density is protected by estrogen — but this protection depends on continued dosing. Weight-bearing exercise and adequate calcium/vitamin D become increasingly important in this decade.")
        case .t7Veteran:
            return String(localized: "10+ years: Your body has been estrogen-dominant for over a decade. Bone health, metabolic rate, and muscle maintenance deserve active attention. Resistance training and bone-density monitoring (DEXA) are the cornerstones of long-term physical health.")
        }
    }

    private func cycleTimelineText(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Levels follow a repeating arc across a dose cycle: highest in the first days after a dose, lowest just before the next one. Patterns in how that feels become apparent once dosing is consistent.")
        case .t4Deepening:
            return String(localized: "The cycle is predictable at this stage, so peak and trough days can be anticipated from the dosing date.")
        case .t5Settled:
            return String(localized: "Two things change the shape of the curve: a longer-acting ester, such as estradiol cypionate in place of valerate, and a shorter injection interval. Both reduce the peak-to-trough swing.")
        case .t6Rooted:
            return String(localized: "Cycle rhythm is typically stable and unremarkable after several years.")
        case .t7Veteran:
            return String(localized: "After a decade, dosing is maintenance. Periodic lab review is what confirms that ester, interval and levels remain appropriate as the body ages.")
        }
    }

    // MARK: - Estrogen What To Expect Helpers

    private func whatToExpectForMood(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Emotional range typically continues to broaden over this period. Neurochemical adaptation is gradual, and mood variability is common while it happens.")
        case .t4Deepening:
            return String(localized: "Mood is typically stable by this stage. Where dips track the trough of a dose cycle, a shorter injection interval produces a flatter curve.")
        case .t5Settled:
            return String(localized: "Levels and mood are typically stable at this stage, and an established personal baseline is the most reliable reference point for noticing a change.")
        case .t6Rooted:
            return String(localized: "At 5+ years neurochemistry is stable, and hormone levels explain less of the variation in mood than life circumstances do.")
        case .t7Veteran:
            return String(localized: "After a decade the estrogen-dominant baseline is long established. Perimenopause-like changes can begin at an age-appropriate point.")
        }
    }

    private func whatToExpectForSkin(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Skin typically continues softening over the next several months, and acne typically continues decreasing. Estrogen-thinned skin is more UV-sensitive than it was before therapy.")
        case .t4Deepening:
            return String(localized: "Skin changes are largely complete by this stage. No hormone-specific intervention is indicated.")
        case .t5Settled:
            return String(localized: "Skin aging continues on its normal course. Skin remains softer than it would be without estrogen, but photoaging and age-related collagen loss are universal. Retinoids, vitamin C and sun protection are the interventions with evidence behind them.")
        case .t6Rooted:
            return String(localized: "After 5 years the skin baseline is well established. Estrogen's effects on skin do not reduce skin cancer risk.")
        case .t7Veteran:
            return String(localized: "After a decade of estrogen-maintained skin, age-related thinning and dryness are typical and are not a sign that therapy has stopped working.")
        }
    }

    private func whatToExpectForBody(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Fat redistribution is among the slowest changes, typically measured in years rather than months. Weight cycling can accelerate it, but redistribution proceeds without it.")
        case .t4Deepening:
            return String(localized: "Fat redistribution is largely complete by this stage. Further change is typically subtle.")
        case .t5Settled:
            return String(localized: "Fat distribution is stable. Diet and exercise affect body composition as they always did, in estrogen-dominant deposition patterns. Resistance training is associated with maintained bone density.")
        case .t6Rooted:
            return String(localized: "At 5+ years, bone density becomes the more clinically relevant measure. Weight-bearing exercise, calcium and vitamin D are associated with maintaining it.")
        case .t7Veteran:
            return String(localized: "After a decade, bone health is the most clinically relevant measure. DEXA scans track bone density directly; resistance training and adequate nutrition are associated with maintaining it.")
        }
    }

    private func cycleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Cycle timing becomes predictable as dosing becomes consistent. After an ester or dose change, levels take roughly 4–6 weeks to reach steady state.")
        case .t4Deepening:
            return String(localized: "Cycle timing is predictable at this stage. A shorter interval or a longer-acting ester both reduce peak-to-trough fluctuation.")
        case .t5Settled:
            return String(localized: "More frequent smaller doses produce a flatter curve and less mood variation across the cycle. The difference is in day-to-day steadiness rather than in clinical outcome.")
        case .t6Rooted:
            return String(localized: "Cycle rhythm is typically stable and unremarkable by this stage.")
        case .t7Veteran:
            return String(localized: "Dosing rhythm is long established after a decade. Periodic lab review is what confirms levels remain age-appropriate.")
        }
    }

    // MARK: - Testosterone Timeline Helpers

    private func tVoiceTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Months 1–3: You may feel a scratchy throat or notice slight hoarseness — the first signs of vocal fold thickening.\n\nMonths 3–5: The first noticeable pitch drop typically happens here. Voice may crack or feel unstable.")
        case .t3InMotion:
            return String(localized: "Months 6–12: Continuing gradual drop. Your voice is settling into its new range.")
        case .t4Deepening:
            return String(localized: "Months 12–24: Most of the deepening is done. Any remaining changes are very subtle. Your speaking voice has found its natural pitch.")
        case .t5Settled:
            return String(localized: "Year 2+: Your voice is permanent and settled. It will not revert if you pause or stop T. Vocal training can still improve resonance, projection, and control regardless of where your pitch landed.")
        case .t6Rooted:
            return String(localized: "Year 5+: A decade of settled pitch. Your voice has been in its final range for years. Vocal quality (resonance, projection, clarity) can still be refined with training, but the fundamental frequency is permanent.")
        case .t7Veteran:
            return String(localized: "10+ years: Your voice is unshakeable — it's been set for most of a decade. No changes will occur. Any vocal work at this stage is about expression and confidence, not biology.")
        }
    }

    private func tSkinTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Month 1: Oil production kicks in quickly — skin may feel greasier within weeks. Acne often follows.\n\nMonths 3–5: Body hair begins appearing in a predictable pattern: lower legs → thighs → abdomen.")
        case .t3InMotion:
            return String(localized: "Months 6–12: Body hair continues filling in (chest, back, face). Acne may peak during this period.")
        case .t4Deepening:
            return String(localized: "Months 12–24: Body and facial hair continue filling in. Acne typically begins to mellow. Scalp hairline may stabilise or continue receding depending on genetics.")
        case .t5Settled:
            return String(localized: "Year 2+: Body and facial hair are fully established and permanent. Scalp hair loss, if it was going to happen, has likely stabilised at its genetic baseline. Acne should be minimal by now.")
        case .t6Rooted:
            return String(localized: "Year 5+: Your hair pattern — body, facial, and scalp — has been stable for years. Any androgenic scalp loss has plateaued. Skin oil production may gradually decrease with age even on T. Dermatology screening (skin cancer) is a good annual habit.")
        case .t7Veteran:
            return String(localized: "10+ years: Hair and skin patterns are fully mature. Scalp hair, if affected by androgenetic alopecia, reached its plateau long ago. Skin aging follows its normal course — sun protection and skin checks are the primary active steps.")
        }
    }

    private func tMuscleTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "Months 1–3: Early strength gains — you may notice exercises feeling easier. Some water retention can give a 'fuller' look.\n\nMonths 3–5: Noticeable muscle growth, especially upper body. Recovery between workouts improves significantly.")
        case .t3InMotion:
            return String(localized: "Months 6–12: Strength continues increasing. Body composition is visibly shifting toward more lean mass.")
        case .t4Deepening:
            return String(localized: "Months 12–24: Muscle growth velocity peaks. Without training, you'll maintain above-baseline lean mass. With training, this is peak gain season.")
        case .t5Settled:
            return String(localized: "Year 2+: Muscle profile is stable. Gains beyond this point come from training stimulus rather than from time on testosterone, and lean mass is maintained by continued levels and activity.")
        case .t6Rooted:
            return String(localized: "Year 5+: Your physique is established. T maintains lean mass but won't drive new growth without progressive overload. Cardiovascular fitness and metabolic health deserve equal attention alongside strength at this stage.")
        case .t7Veteran:
            return String(localized: "10+ years: Muscle mass is maintained by T but gradually declines with age regardless. Resistance training, adequate protein, and cardiovascular health are lifelong commitments. Your baseline is solid — protect it with consistency.")
        }
    }

    private func cycleTimelineTextForT(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Your body is still adapting to exogenous T. Aromatization patterns, energy fluctuations, and trough effects are all still emerging. Give it 3–6 months of consistent dosing to establish a clear pattern.")
        case .t4Deepening:
            return String(localized: "You know your rhythm. Energy peaks around day 2 post-shot, trough around day 6–7. Plan heavy workouts near peak, rest near trough.")
        case .t5Settled:
            return String(localized: "You've mastered your cycle. If you want even more stability, twice-weekly dosing flattens the curve and reduces aromatization spikes. Some providers are open to this — it's worth asking.")
        case .t6Rooted:
            return String(localized: "Your cycle is entirely routine by now. If you've already optimised, no changes are needed. The priority at this stage is lab monitoring, not schedule tweaking.")
        case .t7Veteran:
            return String(localized: "Dosing is maintenance after a decade. You know your rhythm intimately. Periodic labs confirm your levels remain appropriate — that's the only active monitoring needed for your cycle.")
        }
    }

    // MARK: - Testosterone What To Expect Helpers

    private func tVoiceWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return String(localized: "The largest pitch drop typically occurs in months 3–6. Cracking during this period is typical and transient. Hydration and avoiding vocal strain reduce it.")
        case .t3InMotion:
            return String(localized: "The pitch drop is well underway and cracking typically subsides from here.")
        case .t4Deepening:
            return String(localized: "Pitch change is largely complete and is structural. Resonance and speech patterns remain trainable; pitch itself does not.")
        case .t5Settled:
            return String(localized: "Pitch is permanent and will not change further. Voice training affects how the voice is used, not its pitch.")
        case .t6Rooted:
            return String(localized: "Pitch has been stable for half a decade. No further biological change is expected.")
        case .t7Veteran:
            return String(localized: "After a decade, no further hormone-driven voice change occurs. Delivery, projection and singing remain trainable skills.")
        }
    }

    private func tSkinWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Acne commonly worsens before it improves. Body and facial hair typically continue filling in for 2+ years.")
        case .t4Deepening:
            return String(localized: "Hair typically continues filling in and acne typically subsides at this stage. Finasteride and minoxidil are the treatments used for testosterone-driven scalp hair loss.")
        case .t5Settled:
            return String(localized: "Hair pattern is fully expressed by this stage. Scalp hair loss tracks DHT levels. Acne is uncommon at this stage.")
        case .t6Rooted:
            return String(localized: "At 5+ years hair pattern is fully mature. Scalp hair retention continues to track DHT levels.")
        case .t7Veteran:
            return String(localized: "Hair and skin patterns are stable and testosterone-driven change is complete. Scalp hair, where affected, plateaued years earlier.")
        }
    }

    private func tMuscleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Strength typically continues climbing. Lean mass increases with testosterone alone; the rate of gain is highest during this period when combined with resistance training.")
        case .t4Deepening:
            return String(localized: "Rate of strength gain and recovery capacity are both near their peak during this period. Lean mass stays above pre-therapy baseline without training.")
        case .t5Settled:
            return String(localized: "Lean mass has plateaued: testosterone alone no longer drives further growth, and additional gain requires training stimulus.")
        case .t6Rooted:
            return String(localized: "At 5+ years body composition is stable. Testosterone therapy affects lipid profile and blood pressure, which lipid panels and blood pressure checks track.")
        case .t7Veteran:
            return String(localized: "After a decade, age-related muscle loss (sarcopenia) begins for everyone, T or not. The best defence: consistent resistance training, adequate protein, and staying active. Your T baseline gives you an edge — use it.")
        }
    }

    private func cycleWhatToExpectForT(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return String(localized: "Your cycle is still stabilising. Aromatization effects (mood changes, water retention at peak) may fluctuate. Steady state takes 4–6 weeks after any dose change.")
        case .t4Deepening:
            return String(localized: "Your cycle is predictable. If aromatization symptoms at peak bother you, a slightly lower dose or more frequent injections can help.")
        case .t5Settled:
            return String(localized: "You've optimised. If not, twice-weekly dosing is the single best lever for smoothing out the peak-to-trough swing. It reduces both the T spike and the aromatization spike that follows.")
        case .t6Rooted:
            return String(localized: "Your cycle is fully optimised by now. No changes are needed unless something shifts. Periodic labs to confirm levels remain in range are the only active monitoring.")
        case .t7Veteran:
            return String(localized: "After a decade, your dosing is background rhythm. Labs every 6–12 months confirm stability. Unless you're experiencing symptoms, no adjustments are needed — your protocol is proven.")
        }
    }

}
