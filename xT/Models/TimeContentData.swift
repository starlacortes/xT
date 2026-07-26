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
    let doseIntensityDisclaimer: String?  // disclaimer text for dose scaling
    let bloodTestSchedulingText: String   // dynamic blood test scheduling text
    let suggestedBloodTestMonth: Int?     // suggested month for next lab
    let calibrationContext: String?       // trough/peak info for calibration factor

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
            return "CHANGES UNLOCKED"
        case .t5Settled:
            return "ESTABLISHED CHANGES"
        case .t6Rooted:
            return "ALL ESTABLISHED"
        case .t7Veteran:
            return "YOUR JOURNEY"
        }
    }

    var changesSummaryBadge: String? {
        let unlocked = unlockedChanges.filter(\.unlocked).count
        let total = unlockedChanges.count
        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            return "\(unlocked) of \(total)"
        case .t5Settled:
            return "\(total) changes established"
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
            return ("Very low", .pink, estrogenVeryLowCopy(tier: tier))
        case 50..<100:
            return ("Low", .amber, estrogenLowCopy(tier: tier))
        case 100..<200:
            return ("Optimal", .optimal, estrogenOptimalCopy(tier: tier))
        case 200..<300:
            return ("High", .amber, estrogenHighCopy(tier: tier))
        default:
            return ("Very high", .pink, estrogenVeryHighCopy(tier: tier))
        }
    }

    // MARK: Tenure-aware estrogen insight copy (spec §3.2)
    // Previously a single tenure-agnostic string per range — a 3-month and
    // 10-year user got identical copy. Now framed by tier.

    private func estrogenVeryLowCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Levels are quite low right now. Early on this can be normal as your dose settles, but you may feel emotional dips or notice changes slowing. Worth talking to your provider."
        case .t4Deepening:
            return "Levels are still quite low at this stage. If you've been on this dose for a while, it's worth checking timing and dose with your provider."
        case .t5Settled:
            return "Levels are quite low for your tenure. Your baseline is well known by now — a drop like this is worth a check-in to rule out dose or timing drift."
        case .t6Rooted, .t7Veteran:
            return "This is below your established maintenance range. Flag it with your provider — meaningful drift from a long-stable baseline is worth investigating."
        }
    }

    private func estrogenLowCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Levels are on the lower side. Some changes may feel slower, and you might notice mood shifts near the end of your cycle. Common early on."
        case .t4Deepening:
            return "Levels are on the lower side. By now your dose should be holding steadier — if not, check timing/dose with your provider."
        case .t5Settled:
            return "Levels are on the lower side of maintenance. No urgent action needed, but worth mentioning at your next check-in."
        case .t6Rooted, .t7Veteran:
            return "A bit below your established maintenance range. Track the trend — a single reading isn't cause for concern, but a drift is worth a conversation."
        }
    }

    private func estrogenOptimalCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "At this level, you'll feel emotionally stable and notice ongoing skin and body changes. This is the sweet spot for most people."
        case .t4Deepening:
            return "Levels are right in range. You should feel stable and your changes should continue progressing steadily."
        case .t5Settled:
            return "Solidly in your maintenance range. No action needed — this is where you want to be long-term."
        case .t6Rooted, .t7Veteran:
            return "Right in your established maintenance range. Your baseline is well known — trust it."
        }
    }

    private func estrogenHighCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Levels are running a little high. Effects are strong, though very high E2 can occasionally cause bloating or mood swings."
        case .t4Deepening:
            return "Levels are running a little high. If you're noticing side effects, talk to your provider about timing or dose."
        case .t5Settled:
            return "Slightly above maintenance range. Not dangerous, but worth a conversation if it persists."
        case .t6Rooted, .t7Veteran:
            return "Above your established maintenance range. A sustained shift upward is worth flagging with your provider."
        }
    }

    private func estrogenVeryHighCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your levels are elevated. It's worth checking in with your provider about your dose timing or amount."
        case .t4Deepening:
            return "Your levels are elevated. This is a good moment to revisit dose timing and amount with your provider."
        case .t5Settled:
            return "Levels are elevated for maintenance. Worth a check-in to recalibrate."
        case .t6Rooted, .t7Veteran:
            return "Well above your established baseline. This is a meaningful drift — flag it with your provider."
        }
    }

    private func testosteroneInsight(level: Double, months: Int) -> (String, TimeContentPalette, String) {
        let tier = TenureTier(months: months)
        switch level {
        case ..<50:
            return ("Suppressed", .optimal, tSuppressedCopy(tier: tier))
        case 50..<200:
            return ("Low male range", .teal, tLowMaleCopy(tier: tier))
        case 200..<800:
            return ("Male range", .optimal, tMaleRangeCopy(tier: tier))
        default:
            return ("High", .amber, tHighCopy(tier: tier))
        }
    }

    // MARK: Tenure-aware testosterone insight copy (spec §3.2)

    private func tSuppressedCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "T is well suppressed — great for feminising effects if that's your goal."
        case .t4Deepening:
            return "T remains well suppressed. This is the expected, stable state."
        case .t5Settled:
            return "T is well suppressed — maintenance range. No action needed."
        case .t6Rooted, .t7Veteran:
            return "T is well suppressed — consistent with your long-term baseline. Trust it."
        }
    }

    private func tLowMaleCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Levels are in a low range. Voice and body changes may be progressing steadily."
        case .t4Deepening:
            return "Levels are in a low range. If you're aiming for more pronounced changes, discuss with your provider."
        case .t5Settled:
            return "Low range for maintenance. If you feel well, this is fine; if not, a small adjustment may help."
        case .t6Rooted, .t7Veteran:
            return "A bit below your established range. Track the trend before adjusting."
        }
    }

    private func tMaleRangeCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your T is in the typical male range, which supports voice deepening, muscle growth, and body hair."
        case .t4Deepening:
            return "Solidly in the male range — supporting continued voice, muscle, and hair changes."
        case .t5Settled:
            return "In the typical male range — your maintenance target. No action needed."
        case .t6Rooted, .t7Veteran:
            return "In your established maintenance range. Your baseline is well known — trust it."
        }
    }

    private func tHighCopy(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Levels are elevated. Strong effects — worth a check-in with your provider to make sure timing and dose are dialled in."
        case .t4Deepening:
            return "Levels are elevated. Watch for aromatization symptoms; worth discussing timing/dose with your provider."
        case .t5Settled:
            return "Levels are elevated above maintenance. Worth a check-in if it persists."
        case .t6Rooted, .t7Veteran:
            return "Above your established baseline. A sustained drift is worth flagging with your provider."
        }
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
                systemKey: .moodAndMind
            ),
            TimeBodySystem(
                title: "Skin & glow",
                subtitle: estrogenSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .teal,
                progressLabel: estrogenSkinLabel(tier: tier, months: months),
                systemKey: .skinAndGlow
            ),
            TimeBodySystem(
                title: "Body shape",
                subtitle: estrogenBodySubtitle(tier: tier),
                icon: "body-scan",
                palette: .amber,
                progressLabel: estrogenBodyLabel(tier: tier, months: months),
                systemKey: .bodyShape
            ),
            TimeBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle
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
                systemKey: .voice
            ),
            TimeBodySystem(
                title: "Skin & hair",
                subtitle: testosteroneSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .amber,
                progressLabel: testosteroneSkinLabel(tier: tier, months: months),
                systemKey: .skinAndHair
            ),
            TimeBodySystem(
                title: "Muscle & strength",
                subtitle: testosteroneMuscleSubtitle(tier: tier),
                icon: "body-scan",
                palette: .teal,
                progressLabel: testosteroneMuscleLabel(tier: tier, months: months),
                systemKey: .muscleStrength
            ),
            TimeBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle
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
            return "How estrogen shapes your emotions"
        case .t4Deepening:       return "Emotional patterns are settling"
        case .t5Settled:         return "Long-term emotional baseline"
        case .t6Rooted:          return "Emotional baseline at 5+ years"
        case .t7Veteran:         return "Emotional baseline at 10+ years"
        }
    }
    private func estrogenSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "Just starting"
        case .t3InMotion:
            return "Well underway"
        case .t4Deepening:       return "Ongoing"
        case .t5Settled:         return "Maintained"
        case .t6Rooted:          return "Maintained · Year 5+"
        case .t7Veteran:         return "Maintained · 10+ years"
        }
    }
    private func estrogenSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "What's changing and why"
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
            return "Fat, curves & what to expect"
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
            return "Early changes"
        case .t3InMotion:
            return "Still shifting"
        case .t4Deepening:       return "Near final"
        case .t5Settled:         return "Settled"
        case .t6Rooted:          return "Settled · Year 5+"
        case .t7Veteran:         return "Settled · 10+ years"
        }
    }
    private func testosteroneVoiceSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Deepening timeline"
        case .t4Deepening:       return "Voice has largely settled"
        case .t5Settled:         return "Permanent depth"
        case .t6Rooted:          return "Voice at 5+ years"
        case .t7Veteran:         return "Voice at 10+ years"
        }
    }
    private func testosteroneSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Just starting"
        case .t4Deepening:       return "Ongoing"
        case .t5Settled:         return "Maintained"
        case .t6Rooted:          return "Maintained · Year 5+"
        case .t7Veteran:         return "Maintained · 10+ years"
        }
    }
    private func testosteroneSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Oil, texture & growth"
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
            return "What T does to your body"
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
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return "Done \(df.string(from: date))"
    }

    /// Age-qualified context for milestones that reference "after age 30".
    private var ageContext: String {
        if let age = ageAtStart, age >= 30 {
            return ", especially given you started HRT at \(age)"
        }
        return ""
    }

    /// Age- and tenure-aware note for cancer screenings (T7 milestone).
    private var ageBasedScreeningNote: String {
        var note = "Discuss age-appropriate cancer screenings with your provider"
        if let age = ageAtStart {
            let currentAge = age + (activeMonthsOnHRT / 12)
            note += " (current age ~\(currentAge))"
        }
        note += ". Based on your age and tenure, this may include mammogram, colorectal screening, or skin checks."
        return note
    }

    var milestonesSectionLabel: String {
        switch tenureTier {
        case .t1Beginning, .t2Emerging, .t3InMotion, .t4Deepening:
            return "COMING UP"
        case .t5Settled, .t6Rooted, .t7Veteran:
            return "LONG-TERM HEALTH"
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
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
                ))
            }

            if months < 24 {
                let monthsAway = 24 - months
                milestones.append(TimeMilestone(
                    title: "2-year milestone",
                    description: "Most permanent changes have developed by year two. Skin and fat redistribution are near complete.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
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
                description: "Estrogen protects bone mineral density. A baseline DEXA scan and follow-ups every 2 years are recommended\(ageContext).",
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
                description: "A decade of living authentically. Take a moment to reflect on how far you've come — this is a meaningful milestone.",
                icon: "sparkles",
                palette: .optimal,
                badge: "Celebrate"
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
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
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
                description: "Testosterone supports bone mineral density. A baseline DEXA scan and periodic follow-ups are recommended\(ageContext).",
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
                description: "A decade of living authentically. Take a moment to reflect on how far you've come — this is a meaningful milestone.",
                icon: "sparkles",
                palette: .optimal,
                badge: "Celebrate"
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
                    ? "You're likely very familiar with how you feel across your injection week. Use this knowledge to optimize dose timing."
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
                Injectable testosterone esters (cypionate, enanthate) follow a predictable pharmacokinetic curve: a rise to peak 24–48 hours post-injection, then a gradual multi-day decline to trough. The half-life of testosterone cypionate is ~8 days, so with weekly dosing you get a moderate peak-to-trough swing.

                Some people feel energetic peaks shortly after their shot, while others feel a dip in the day or two before their next dose. These fluctuations are normal and reflect the difference between peak and trough serum levels.

                Aromatization — the conversion of testosterone to estradiol — also tracks this curve. If your dose is high, peak aromatization can produce enough E2 to cause mood changes, water retention, or nipple sensitivity. This is why many providers aim for trough T in the 400–700 ng/dL range rather than chasing higher peaks.
                """,
                timelineText: cycleTimelineTextForT(tier: tier),
                whatToExpect: cycleWhatToExpectForT(tier: tier),
                maintenanceNote: tier >= .t5Settled
                    ? "You know your rhythm. If troughs are uncomfortable, ask about splitting your dose to twice-weekly — it flattens the curve and reduces aromatization spikes."
                    : nil,
                deepeningNote: tier == .t4Deepening
                    ? "You likely know exactly how you feel across your shot week. Trust that knowledge when discussing adjustments with your provider."
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
            return "Months 1–3: Emotional sensitivity often increases first. You may feel more tearful, reactive, or emotionally open. This is neurochemical recalibration.\n\nMonths 3–6: Emotional range broadens. Many describe feeling 'more themselves' — a sense of emotional alignment that was missing before."
        case .t3InMotion:
            return "Months 6–12: Mood patterns stabilise as your brain adapts to the new hormonal environment. Cyclical trough effects may become noticeable."
        case .t4Deepening:
            return "Months 12–24: Your emotional baseline should feel natural and stable. You likely have a good read on how you feel across your dose cycle. This is your new normal."
        case .t5Settled:
            return "Year 2+: Your emotional landscape is fully established. You're reading from the same neurochemical playbook that cis women operate on — the brain has fully adapted to estrogen-dominant signaling."
        case .t6Rooted:
            return "Year 5+: Your emotional baseline is deeply ingrained. You've navigated years of hormone-steady cognition — trust your read of your own patterns. Annual mental health check-ins remain valuable, even when things feel stable."
        case .t7Veteran:
            return "10+ years: Your brain has run on estrogen for over a decade. The neurochemistry is second nature. At this stage, the priority is protecting what you've built — cognitive exercise, stress management, and periodic screening for age-appropriate neurological health."
        }
    }

    private func timelineTextForSkin(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning:
            return "Month 1: Reduced oiliness is often the very first change — noticeable within weeks."
        case .t2Emerging:
            return "Months 2–5: Skin texture begins softening. Pores appear smaller, hydration improves."
        case .t3InMotion:
            return "Months 6–12: The 'glow' becomes apparent. Skin is noticeably softer and more radiant than pre-HRT."
        case .t4Deepening:
            return "Months 12–24: Your skin has fully transitioned. Collagen density is up, sebum is down, and the texture difference from pre-HRT is complete."
        case .t5Settled:
            return "Year 2+: Your skin is estrogen-maintained at this point. It will stay soft and hydrated as long as levels remain in range. Age-related changes (fine lines, elasticity loss) will still occur — estrogen slows but doesn't stop the clock."
        case .t6Rooted:
            return "Year 5+: Collagen density remains above what it would be without estrogen, but the natural aging timeline still runs. Fine lines and elasticity loss are normal. Retinoids, vitamin C, and SPF are your allies. Annual dermatology check-ins are a good habit."
        case .t7Veteran:
            return "10+ years: Your skin has been estrogen-dominant for over a decade. The structural benefits (hydration, collagen, softness) are embedded. Age-related changes are universal — focus on skin cancer screening and gentle maintenance rather than chasing youthful texture."
        }
    }

    private func timelineTextForBody(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "Months 1–3: Subtle — you may notice slight softening around the hips or face.\n\nMonths 3–5: Fat redistribution becomes visible. Pants may fit differently as hip and thigh circumference increases."
        case .t3InMotion:
            return "Months 6–12: Waist-to-hip ratio begins shifting noticeably. Upper body muscle loss contributes to a narrower shoulder appearance."
        case .t4Deepening:
            return "Months 12–24: The bulk of your fat redistribution is complete. Your silhouette has changed meaningfully. Any remaining shifts are slow and subtle — fat cells turn over on a ~2–3 year cycle."
        case .t5Settled:
            return "Year 2+: Your body shape is stable. Weight cycling (±5–10 lbs) will still produce new fat deposition in estrogen-dominant patterns. Muscle mass requires active resistance training to maintain — use it or lose it."
        case .t6Rooted:
            return "Year 5+: Your silhouette is fully estrogen-dominant. Bone density is protected by estrogen — but this protection depends on continued dosing. Weight-bearing exercise and adequate calcium/vitamin D become increasingly important in this decade."
        case .t7Veteran:
            return "10+ years: Your body has been estrogen-dominant for over a decade. Bone health, metabolic rate, and muscle maintenance deserve active attention. Resistance training and bone-density monitoring (DEXA) are the cornerstones of long-term physical health."
        }
    }

    private func cycleTimelineText(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "You're still learning your cycle. Track how you feel on days 1–2 (peak), 3–5 (mid), and 6–7 (trough). Patterns will emerge with consistency."
        case .t4Deepening:
            return "You know your cycle well. Use this awareness to plan around trough days — schedule demanding tasks around peak, allow extra rest near trough."
        case .t5Settled:
            return "Your cycle is second nature. Consider whether your ester choice still serves you — switching from EV to EC can flatten the curve if troughs are bothersome. A shorter injection interval (e.g., every 5 days instead of 7) is another option worth discussing."
        case .t6Rooted:
            return "You've lived with your cycle for years — it's background rhythm at this point. If you've already optimised your dosing, there's no need to revisit it. Stability, not novelty, is the goal at this stage."
        case .t7Veteran:
            return "Your cycle is entirely automatic after a decade. Dosing is maintenance. The priority is ensuring your ester, interval, and levels remain appropriate as your body ages — periodic lab review is the only active work needed."
        }
    }

    // MARK: - Estrogen What To Expect Helpers

    private func whatToExpectForMood(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your emotional range will continue expanding. Be patient — neurochemical adaptation takes time. If mood swings are severe, discuss dose timing with your provider."
        case .t4Deepening:
            return "You're in a stable period. If you notice mood dips correlating with trough, a shorter injection interval may help smooth things out."
        case .t5Settled:
            return "You're in maintenance mode. Annual check-ins with your provider are sufficient unless something feels off. Trust your self-knowledge — you know your emotional baseline better than anyone."
        case .t6Rooted:
            return "At 5+ years your neurochemistry is stable. The biggest mental-health variable at this stage is life, not hormones. Invest in therapy, relationships, and stress management — the things that protect emotional health independent of HRT."
        case .t7Veteran:
            return "After a decade, your emotional self is fully integrated. Perimenopause-like considerations (if age-appropriate) may begin, but your estrogen-dominant baseline is well established. Periodic mental-health screening rounds out physical health checkups."
        }
    }

    private func whatToExpectForSkin(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Skin will keep getting softer over the next several months. Sunscreen is your friend — estrogen-thinned skin is more UV-sensitive. Acne should continue decreasing."
        case .t4Deepening:
            return "Your skin is in its prime. Maintain a simple skincare routine — gentle cleanser, moisturiser, SPF. No special intervention needed."
        case .t5Settled:
            return "Skin aging continues naturally. Retinoids, vitamin C serum, and diligent SPF are your best tools. Your skin will remain softer than it would be without estrogen — but photoaging and collagen loss with age are universal."
        case .t6Rooted:
            return "After 5 years, your skin's baseline is well known to you. Annual dermatology screening becomes relevant — estrogen's protective effects don't eliminate skin cancer risk. Continue SPF and gentle maintenance."
        case .t7Veteran:
            return "A decade of estrogen-maintained skin is a solid foundation. Age-related thinning and dryness are normal. Gentle products, hydration, and skin cancer vigilance are the priorities — chasing 'youthful' texture isn't realistic or necessary."
        }
    }

    private func whatToExpectForBody(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Fat redistribution is a marathon, not a sprint. Be patient. Weight cycling (intentional gain and loss of 5–10 lbs) can accelerate the process, but it's not necessary — time will do the work."
        case .t4Deepening:
            return "You're near the finish line. Any further changes will be subtle. Focus on what your body can do, not just how it looks."
        case .t5Settled:
            return "This is your body. If you want to fine-tune, diet and exercise work the same way they always have — you'll just deposit and lose fat in estrogen-dominant patterns now. Resistance training helps maintain bone density and metabolic health."
        case .t6Rooted:
            return "At 5+ years, bone-density maintenance should be on your radar. Weight-bearing exercise, calcium, and vitamin D matter. Your fat distribution is stable — lifestyle changes affect body comp in predictable, estrogen-dominant ways."
        case .t7Veteran:
            return "After a decade, bone health is a central concern. Regular DEXA scans, resistance training, and adequate nutrition are the pillars. Your body's relationship with estrogen is well established — protect what you've built with preventive care."
        }
    }

    private func cycleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your cycle is still becoming predictable as you establish consistent dosing. If you recently switched esters or doses, give it 4–6 weeks to reach steady state before evaluating how you feel."
        case .t4Deepening:
            return "Your cycle is predictable. If you want less fluctuation, talk to your provider about a shorter interval or switching to a longer-acting ester like cypionate."
        case .t5Settled:
            return "If your current rhythm works, keep it. If you're curious about optimising — more frequent smaller doses produce the flattest curve and the most stable mood. It's a quality-of-life optimisation, not a medical necessity."
        case .t6Rooted:
            return "Your cycle rhythm is background music at this point — you may not even think about it. If it's working, don't fix it. The goal is stable maintenance, not further optimisation."
        case .t7Veteran:
            return "Your dosing rhythm is second nature after a decade. The only action item: periodic lab review to confirm your levels remain age-appropriate. No schedule tweaks are needed unless something changes."
        }
    }

    // MARK: - Testosterone Timeline Helpers

    private func tVoiceTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "Months 1–3: You may feel a scratchy throat or notice slight hoarseness — the first signs of vocal fold thickening.\n\nMonths 3–5: The first noticeable pitch drop typically happens here. Voice may crack or feel unstable."
        case .t3InMotion:
            return "Months 6–12: Continuing gradual drop. Your voice is settling into its new range."
        case .t4Deepening:
            return "Months 12–24: Most of the deepening is done. Any remaining changes are very subtle. Your speaking voice has found its natural pitch."
        case .t5Settled:
            return "Year 2+: Your voice is permanent and settled. It will not revert if you pause or stop T. Vocal training can still improve resonance, projection, and control regardless of where your pitch landed."
        case .t6Rooted:
            return "Year 5+: A decade of settled pitch. Your voice has been in its final range for years. Vocal quality (resonance, projection, clarity) can still be refined with training, but the fundamental frequency is permanent."
        case .t7Veteran:
            return "10+ years: Your voice is unshakeable — it's been set for most of a decade. No changes will occur. Any vocal work at this stage is about expression and confidence, not biology."
        }
    }

    private func tSkinTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "Month 1: Oil production kicks in quickly — skin may feel greasier within weeks. Acne often follows.\n\nMonths 3–5: Body hair begins appearing in a predictable pattern: lower legs → thighs → abdomen."
        case .t3InMotion:
            return "Months 6–12: Body hair continues filling in (chest, back, face). Acne may peak during this period."
        case .t4Deepening:
            return "Months 12–24: Body and facial hair continue filling in. Acne typically begins to mellow. Scalp hairline may stabilise or continue receding depending on genetics."
        case .t5Settled:
            return "Year 2+: Body and facial hair are fully established and permanent. Scalp hair loss, if it was going to happen, has likely stabilised at its genetic baseline. Acne should be minimal by now."
        case .t6Rooted:
            return "Year 5+: Your hair pattern — body, facial, and scalp — has been stable for years. Any androgenic scalp loss has plateaued. Skin oil production may gradually decrease with age even on T. Dermatology screening (skin cancer) is a good annual habit."
        case .t7Veteran:
            return "10+ years: Hair and skin patterns are fully mature. Scalp hair, if affected by androgenetic alopecia, reached its plateau long ago. Skin aging follows its normal course — sun protection and skin checks are the primary active steps."
        }
    }

    private func tMuscleTimeline(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "Months 1–3: Early strength gains — you may notice exercises feeling easier. Some water retention can give a 'fuller' look.\n\nMonths 3–5: Noticeable muscle growth, especially upper body. Recovery between workouts improves significantly."
        case .t3InMotion:
            return "Months 6–12: Strength continues increasing. Body composition is visibly shifting toward more lean mass."
        case .t4Deepening:
            return "Months 12–24: Muscle growth velocity peaks. Without training, you'll maintain above-baseline lean mass. With training, this is peak gain season."
        case .t5Settled:
            return "Year 2+: Your muscle profile is stable. Gains beyond this point come from training stimulus, not from T duration. You'll maintain your physique as long as levels stay in range and you stay active."
        case .t6Rooted:
            return "Year 5+: Your physique is established. T maintains lean mass but won't drive new growth without progressive overload. Cardiovascular fitness and metabolic health deserve equal attention alongside strength at this stage."
        case .t7Veteran:
            return "10+ years: Muscle mass is maintained by T but gradually declines with age regardless. Resistance training, adequate protein, and cardiovascular health are lifelong commitments. Your baseline is solid — protect it with consistency."
        }
    }

    private func cycleTimelineTextForT(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your body is still adapting to exogenous T. Aromatization patterns, energy fluctuations, and trough effects are all still emerging. Give it 3–6 months of consistent dosing to establish a clear pattern."
        case .t4Deepening:
            return "You know your rhythm. Energy peaks around day 2 post-shot, trough around day 6–7. Plan heavy workouts near peak, rest near trough."
        case .t5Settled:
            return "You've mastered your cycle. If you want even more stability, twice-weekly dosing flattens the curve and reduces aromatization spikes. Some providers are open to this — it's worth asking."
        case .t6Rooted:
            return "Your cycle is entirely routine by now. If you've already optimised, no changes are needed. The priority at this stage is lab monitoring, not schedule tweaking."
        case .t7Veteran:
            return "Dosing is maintenance after a decade. You know your rhythm intimately. Periodic labs confirm your levels remain appropriate — that's the only active monitoring needed for your cycle."
        }
    }

    // MARK: - Testosterone What To Expect Helpers

    private func tVoiceWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging:
            return "The biggest pitch drop is coming in months 3–6. Be patient with cracking — it's temporary. Stay hydrated, and avoid straining your voice."
        case .t3InMotion:
            return "Your voice is well into its drop. Cracking should subside. Keep hydrating and avoid strain."
        case .t4Deepening:
            return "Your voice is largely done changing. If you want to work on resonance or speech patterns, a voice therapist can help — but pitch itself is structural and complete."
        case .t5Settled:
            return "This is your voice. It's permanent, it's yours, and it won't change further. Voice training can still refine how you use it, but the instrument itself is set."
        case .t6Rooted:
            return "Your voice has been stable for half a decade. If you've considered voice training for resonance or confidence, it's purely optional — the biological work is long complete."
        case .t7Veteran:
            return "After a decade, your voice is as permanent as it gets. No biological shifts ahead. If you want to work on delivery, projection, or singing — that's art, not hormones."
        }
    }

    private func tSkinWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Acne may worsen before it improves. A simple skincare routine (cleanser, moisturiser, salicylic acid) can help. Body and facial hair will continue filling in for 2+ years."
        case .t4Deepening:
            return "Hair is still filling in. Acne should be calming down. If scalp hair loss is a concern, finasteride or minoxidil are options to discuss with your provider."
        case .t5Settled:
            return "Your hair pattern is fully expressed. Scalp hair loss won't progress further as long as DHT levels are managed. Acne is unlikely to be an ongoing issue at this stage."
        case .t6Rooted:
            return "At 5+ years, your hair pattern is fully mature. DHT management continues to matter for scalp hair. Annual dermatology visits for skin checks are a good preventive habit."
        case .t7Veteran:
            return "Hair and skin patterns are lifelong and stable. Scalp hair, if affected, reached its plateau years ago. Skin cancer vigilance and gentle skincare are the focus now — the T-driven changes are complete."
        }
    }

    private func tMuscleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Strength will keep climbing. Even without training, you'll gain lean mass. With consistent training, you're entering the fastest gain period of your life."
        case .t4Deepening:
            return "Gains are still strong. Recovery is excellent. If you're training, this is prime time for progressive overload. If you're not, you'll maintain an above-baseline physique."
        case .t5Settled:
            return "Your baseline is stable. Further gains require training stimulus — you've reached the plateau where T alone won't drive more growth. Stay active to maintain what you've built."
        case .t6Rooted:
            return "At 5+ years your physique is well established. Cardiovascular fitness and metabolic health become increasingly important alongside strength. Annual lipid panels and blood pressure checks complement your training."
        case .t7Veteran:
            return "After a decade, age-related muscle loss (sarcopenia) begins for everyone, T or not. The best defence: consistent resistance training, adequate protein, and staying active. Your T baseline gives you an edge — use it."
        }
    }

    private func cycleWhatToExpectForT(tier: TenureTier) -> String {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion:
            return "Your cycle is still stabilising. Aromatization effects (mood changes, water retention at peak) may fluctuate. Steady state takes 4–6 weeks after any dose change."
        case .t4Deepening:
            return "Your cycle is predictable. If aromatization symptoms at peak bother you, a slightly lower dose or more frequent injections can help."
        case .t5Settled:
            return "You've optimised. If not, twice-weekly dosing is the single best lever for smoothing out the peak-to-trough swing. It reduces both the T spike and the aromatization spike that follows."
        case .t6Rooted:
            return "Your cycle is fully optimised by now. No changes are needed unless something shifts. Periodic labs to confirm levels remain in range are the only active monitoring."
        case .t7Veteran:
            return "After a decade, your dosing is background rhythm. Labs every 6–12 months confirm stability. Unless you're experiencing symptoms, no adjustments are needed — your protocol is proven."
        }
    }

}
