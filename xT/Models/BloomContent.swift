//
//  BloomContent.swift
//  xT
//
//  Content engine for the Bloom tab — generates personalized insights
//  based on medication type, months on HRT, and current hormone levels.
//

import Foundation
import SwiftUI

// MARK: - Tenure Tier

/// Three-stage tenure classification that drives personalized UI & content.
enum TenureTier: String {
    case early       = "Early"       // 0–12 months
    case established = "Established" // 12–24 months
    case mature      = "Mature"      // 24+ months

    init(months: Int) {
        switch months {
        case 0..<12:  self = .early
        case 12..<24: self = .established
        default:      self = .mature
        }
    }

    var statusEmoji: String {
        switch self {
        case .early:       return "🌱"
        case .established: return "🌿"
        case .mature:      return "🌳"
        }
    }
}

// MARK: - Body System Card

struct BloomBodySystem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let palette: BloomPalette
    let progressFraction: Double
    let progressLabel: String
    let systemKey: BodySystemKey   // identifies the system for detail lookup

    /// Tenure-aware status label. Set by the engine based on actual months on HRT.
    var statusLabel: String { progressLabel }
}

enum BodySystemKey: String {
    case moodAndMind    = "mood_mind"
    case skinAndGlow    = "skin_glow"
    case bodyShape      = "body_shape"
    case yourCycle      = "your_cycle"
    case voice          = "voice"
    case skinAndHair    = "skin_hair"
    case muscleStrength = "muscle_strength"
}

// MARK: - Body System Detail (for tappable deep-dive pages)

struct BloomBodySystemDetail {
    let systemKey: BodySystemKey
    let title: String
    let heroIcon: String
    let palette: BloomPalette

    /// Science breakdown — what's physiologically happening.
    let scienceText: String

    /// Personalized timeline based on months on HRT.
    let timelineText: String

    /// Forward-looking: what to expect in the coming months/years.
    let whatToExpect: String

    /// For mature users: what's permanent vs. what requires ongoing dosing.
    let maintenanceNote: String?

    /// Additional context for established users.
    let establishedNote: String?
}

// MARK: - Milestone

struct BloomMilestone: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let palette: BloomPalette
    let badge: String?
}

// MARK: - Unlocked Change

struct BloomChange: Identifiable {
    let id = UUID()
    let label: String
    let unlocked: Bool
}

// MARK: - Hormone Insight

struct BloomHormoneInsight {
    let level: Double
    let unit: String
    let rangeLabel: String
    let bodyDescription: String
    let rangePalette: BloomPalette
}

// MARK: - Palette

struct BloomPalette {
    let surface: Color
    let border: Color
    let accent: Color
    let title: Color
    let progress: Color
    let iconBorder: Color

    static let pink = BloomPalette(
        surface: Color(hex: "#FBEAF0"),
        border:  Color(hex: "#F4C0D1"),
        accent:  Color(hex: "#993556"),
        title:   Color(hex: "#72243E"),
        progress: Color(hex: "#ED93B1"),
        iconBorder: Color(hex: "#F4C0D1")
    )
    static let purple = BloomPalette(
        surface: Color(hex: "#EEEDFE"),
        border:  Color(hex: "#CECBF6"),
        accent:  Color(hex: "#534AB7"),
        title:   Color(hex: "#3C3489"),
        progress: Color(hex: "#AFA9EC"),
        iconBorder: Color(hex: "#CECBF6")
    )
    static let teal = BloomPalette(
        surface: Color(hex: "#E1F5EE"),
        border:  Color(hex: "#9FE1CB"),
        accent:  Color(hex: "#0F6E56"),
        title:   Color(hex: "#085041"),
        progress: Color(hex: "#5DCAA5"),
        iconBorder: Color(hex: "#9FE1CB")
    )
    static let amber = BloomPalette(
        surface: Color(hex: "#FAEEDA"),
        border:  Color(hex: "#FAC775"),
        accent:  Color(hex: "#854F0B"),
        title:   Color(hex: "#633806"),
        progress: Color(hex: "#EF9F27"),
        iconBorder: Color(hex: "#FAC775")
    )
    static let neutral = BloomPalette(
        surface: Color(hex: "#F1EFE8"),
        border:  Color(hex: "#D3D1C7"),
        accent:  Color(hex: "#5F5E5A"),
        title:   Color(hex: "#444441"),
        progress: Color(hex: "#B4B2A9"),
        iconBorder: Color(hex: "#D3D1C7")
    )
    static let optimal = BloomPalette(
        surface: Color(hex: "#EAF3DE"),
        border:  Color(hex: "#C0DD97"),
        accent:  Color(hex: "#3B6D11"),
        title:   Color(hex: "#27500A"),
        progress: Color(hex: "#97C459"),
        iconBorder: Color(hex: "#C0DD97")
    )
}

// MARK: - Content Engine

struct BloomContentEngine {

    let medication: String        // "Estrogen" or "Testosterone"
    let method: String            // "Injectable", "Patch", "Gel", "Pill"
    let months: Int
    let currentLevel: Double?
    let dayOfCycle: Int           // actual day in the current dose cycle

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

    var tenureTier: TenureTier { TenureTier(months: months) }

    // MARK: Timeline header

    var timelineTitle: String {
        switch months {
        case 0..<1:   return "Day one — welcome ✦"
        case 1..<3:   return "Early days ✦"
        case 3..<6:   return "Things are shifting ✦"
        case 6..<12:  return "You're in full swing ✦"
        case 12..<24: return "A year and counting ✦"
        default:      return "Deeply rooted ✦"
        }
    }

    var timelineSubtitle: String {
        let tierSuffix: String = {
            switch tenureTier {
            case .early:       return ""
            case .established: return " · \(tenureTier.statusEmoji) Established"
            case .mature:      return " · \(tenureTier.statusEmoji) Mature"
            }
        }()
        return "Month \(months) on HRT\(tierSuffix)"
    }

    // MARK: Changes

    var changesSectionLabel: String {
        switch tenureTier {
        case .early:       return "CHANGES UNLOCKED"
        case .established: return "ESTABLISHED CHANGES"
        case .mature:      return "ESTABLISHED CHANGES"
        }
    }

    var changesSummaryBadge: String? {
        let unlocked = unlockedChanges.filter(\.unlocked).count
        let total = unlockedChanges.count
        switch tenureTier {
        case .early, .established:
            return "\(unlocked) of \(total)"
        case .mature:
            return "All \(total) active"
        }
    }

    /// Whether the changes section should be collapsed by default.
    /// Mature users see it collapsed; early/established see it expanded.
    var changesDefaultCollapsed: Bool { tenureTier == .mature }

    var unlockedChanges: [BloomChange] {
        if medication == "Estrogen" {
            return estrogenChanges(months: months)
        } else {
            return testosteroneChanges(months: months)
        }
    }

    private func estrogenChanges(months: Int) -> [BloomChange] {
        [
            BloomChange(label: "Skin softening",      unlocked: months >= 1),
            BloomChange(label: "Breast growth",       unlocked: months >= 2),
            BloomChange(label: "Fat redistribution",  unlocked: months >= 3),
            BloomChange(label: "Hair thinning slows", unlocked: months >= 6),
            BloomChange(label: "Body hair softens",   unlocked: months >= 6),
            BloomChange(label: "Muscle mass shifts",  unlocked: months >= 9),
        ]
    }

    private func testosteroneChanges(months: Int) -> [BloomChange] {
        [
            BloomChange(label: "Voice deepening",     unlocked: months >= 2),
            BloomChange(label: "Clitoral growth",     unlocked: months >= 1),
            BloomChange(label: "Body hair growth",    unlocked: months >= 3),
            BloomChange(label: "Fat redistribution",  unlocked: months >= 3),
            BloomChange(label: "Muscle growth",       unlocked: months >= 4),
            BloomChange(label: "Skin oiliness",       unlocked: months >= 1),
        ]
    }

    // MARK: Hormone insight

    var hormoneInsight: BloomHormoneInsight? {
        guard let level = currentLevel else { return nil }

        if medication == "Estrogen" {
            let (label, palette, desc) = estrogenInsight(level: level, months: months)
            return BloomHormoneInsight(
                level: level,
                unit: "pg/mL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        } else {
            let (label, palette, desc) = testosteroneInsight(level: level, months: months)
            return BloomHormoneInsight(
                level: level,
                unit: "ng/dL",
                rangeLabel: label,
                bodyDescription: desc,
                rangePalette: palette
            )
        }
    }

    private func estrogenInsight(level: Double, months: Int) -> (String, BloomPalette, String) {
        switch level {
        case ..<50:
            return ("Very low", .pink, "Your levels are quite low right now. You may feel emotional dips or notice changes slowing. It's worth talking to your provider.")
        case 50..<100:
            return ("Low", .amber, "Levels are on the lower side. Some changes may feel slower, and you might notice mood shifts near the end of your cycle.")
        case 100..<200:
            return ("Optimal", .optimal, "At this level, you'll feel emotionally stable and notice ongoing skin and body changes. This is the sweet spot for most people.")
        case 200..<300:
            return ("High", .amber, "Levels are running a little high. Effects are strong, though very high E2 can occasionally cause bloating or mood swings.")
        default:
            return ("Very high", .pink, "Your levels are elevated. It's worth checking in with your provider about your dose timing or amount.")
        }
    }

    private func testosteroneInsight(level: Double, months: Int) -> (String, BloomPalette, String) {
        switch level {
        case ..<50:
            return ("Suppressed", .optimal, "T is well suppressed — great for feminising effects if that's your goal.")
        case 50..<200:
            return ("Low male range", .teal, "Levels are in a low range. Voice and body changes may be progressing steadily.")
        case 200..<800:
            return ("Male range", .optimal, "Your T is in the typical male range, which supports voice deepening, muscle growth, and body hair.")
        default:
            return ("High", .amber, "Levels are elevated. Strong effects — worth a check-in with your provider to make sure timing and dose are dialled in.")
        }
    }

    // MARK: Body system cards

    var bodySystems: [BloomBodySystem] {
        if medication == "Estrogen" {
            return estrogenBodySystems
        } else {
            return testosteroneBodySystems
        }
    }

    private var estrogenBodySystems: [BloomBodySystem] {
        let tier = tenureTier
        let cycleProgress: Double = {
            guard method == "Injectable" else { return 1.0 }
            return 1.0
        }()

        return [
            BloomBodySystem(
                title: "Mood & mind",
                subtitle: estrogenMoodSubtitle(tier: tier),
                icon: "brain",
                palette: .purple,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 18.0, 1.0),
                progressLabel: estrogenMoodLabel(tier: tier, months: months),
                systemKey: .moodAndMind
            ),
            BloomBodySystem(
                title: "Skin & glow",
                subtitle: estrogenSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .teal,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 12.0, 1.0),
                progressLabel: estrogenSkinLabel(tier: tier, months: months),
                systemKey: .skinAndGlow
            ),
            BloomBodySystem(
                title: "Body shape",
                subtitle: estrogenBodySubtitle(tier: tier),
                icon: "body-scan",
                palette: .amber,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 24.0, 1.0),
                progressLabel: estrogenBodyLabel(tier: tier, months: months),
                systemKey: .bodyShape
            ),
            BloomBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressFraction: cycleProgress,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle
            ),
        ]
    }

    private var testosteroneBodySystems: [BloomBodySystem] {
        let tier = tenureTier

        return [
            BloomBodySystem(
                title: "Voice",
                subtitle: testosteroneVoiceSubtitle(tier: tier),
                icon: "microphone",
                palette: .purple,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 24.0, 1.0),
                progressLabel: testosteroneVoiceLabel(tier: tier, months: months),
                systemKey: .voice
            ),
            BloomBodySystem(
                title: "Skin & hair",
                subtitle: testosteroneSkinSubtitle(tier: tier),
                icon: "sparkles",
                palette: .amber,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 12.0, 1.0),
                progressLabel: testosteroneSkinLabel(tier: tier, months: months),
                systemKey: .skinAndHair
            ),
            BloomBodySystem(
                title: "Muscle & strength",
                subtitle: testosteroneMuscleSubtitle(tier: tier),
                icon: "body-scan",
                palette: .teal,
                progressFraction: tier == .mature ? 1.0 : min(Double(months) / 18.0, 1.0),
                progressLabel: testosteroneMuscleLabel(tier: tier, months: months),
                systemKey: .muscleStrength
            ),
            BloomBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressFraction: 1.0,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)",
                systemKey: .yourCycle
            ),
        ]
    }

    // MARK: - Tenure label helpers (Estrogen)

    private func estrogenMoodLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return months < 6 ? "Settling in" : "Stabilising"
        case .established: return "Well-established"
        case .mature:      return "Stable"
        }
    }
    private func estrogenMoodSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "How estrogen shapes your emotions"
        case .established: return "Emotional patterns are settling"
        case .mature:      return "Long-term emotional equilibrium"
        }
    }
    private func estrogenSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return months < 3 ? "Just starting" : "Well underway"
        case .established: return "Ongoing"
        case .mature:      return "Maintained"
        }
    }
    private func estrogenSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "What's changing and why"
        case .established: return "Your skin has fully adapted"
        case .mature:      return "Long-term dermal health"
        }
    }
    private func estrogenBodyLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return months < 6 ? "Early changes" : "Still in progress"
        case .established: return "Near complete"
        case .mature:      return "Mature changes"
        }
    }
    private func estrogenBodySubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "Fat, curves & what to expect"
        case .established: return "Curves have largely settled"
        case .mature:      return "Your body's established form"
        }
    }

    // MARK: - Tenure label helpers (Testosterone)

    private func testosteroneVoiceLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return months < 3 ? "Early changes" : "Still shifting"
        case .established: return "Near final"
        case .mature:      return "Settled"
        }
    }
    private func testosteroneVoiceSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "Deepening timeline"
        case .established: return "Voice has largely settled"
        case .mature:      return "Permanent depth"
        }
    }
    private func testosteroneSkinLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return "Just starting"
        case .established: return "Ongoing"
        case .mature:      return "Maintained"
        }
    }
    private func testosteroneSkinSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "Oil, texture & growth"
        case .established: return "Skin & hair patterns stabilised"
        case .mature:      return "Long-term texture & growth"
        }
    }
    private func testosteroneMuscleLabel(tier: TenureTier, months: Int) -> String {
        switch tier {
        case .early:       return months < 6 ? "Building" : "Growing"
        case .established: return "Peak growth phase"
        case .mature:      return "Stable"
        }
    }
    private func testosteroneMuscleSubtitle(tier: TenureTier) -> String {
        switch tier {
        case .early:       return "What T does to your body"
        case .established: return "Strength is well established"
        case .mature:      return "Sustained muscle profile"
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

    var milestonesSectionLabel: String {
        switch tenureTier {
        case .early, .established: return "COMING UP"
        case .mature:              return "LONG-TERM HEALTH"
        }
    }

    var upcomingMilestones: [BloomMilestone] {
        if medication == "Estrogen" {
            return estrogenMilestones
        } else {
            return testosteroneMilestones
        }
    }

    private var estrogenMilestones: [BloomMilestone] {
        var milestones: [BloomMilestone] = []

        switch tenureTier {
        case .early, .established:
            if months < 12 {
                let monthsAway = 12 - months
                milestones.append(BloomMilestone(
                    title: "Month 12 milestone",
                    description: "Hair regrowth typically begins, and breast growth enters a new phase.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
                ))
            }

            if months < 24 {
                let monthsAway = 24 - months
                milestones.append(BloomMilestone(
                    title: "2-year milestone",
                    description: "Most permanent changes have developed by year two. Skin and fat redistribution are near complete.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
                ))
            }

            milestones.append(BloomMilestone(
                title: "Your next blood test",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

        case .mature:
            // Long-term health milestones for users 2+ years on HRT
            milestones.append(BloomMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

            milestones.append(BloomMilestone(
                title: "Bone density scan",
                description: "Estrogen protects bone mineral density. A DEXA scan every 2 years is recommended, especially if you started HRT after age 30.",
                icon: "clock",
                palette: .teal,
                badge: "Every 2 years"
            ))

            milestones.append(BloomMilestone(
                title: "Breast health screening",
                description: "After 5+ years of estrogen therapy, discuss mammogram timing with your provider. Self-exams remain important regardless of tenure.",
                icon: "clock",
                palette: .pink,
                badge: months >= 60 ? "Discussed" : "After year 5"
            ))

            milestones.append(BloomMilestone(
                title: "Cardiovascular check",
                description: "Long-term estrogen therapy affects lipid profiles and cardiovascular risk. Annual checkups help monitor heart health.",
                icon: "clock",
                palette: .amber,
                badge: "Annual"
            ))
        }

        return milestones
    }

    private var testosteroneMilestones: [BloomMilestone] {
        var milestones: [BloomMilestone] = []

        switch tenureTier {
        case .early, .established:
            if months < 6 {
                milestones.append(BloomMilestone(
                    title: "Voice changes begin",
                    description: "Most people notice voice deepening between months 3–6. It can feel sudden or gradual.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(max(0, 3 - months)) months away"
                ))
            }

            if months < 12 {
                let monthsAway = 12 - months
                milestones.append(BloomMilestone(
                    title: "Month 12 check-in",
                    description: "A good time to reassess your dose and review all changes with your provider.",
                    icon: "clock",
                    palette: .neutral,
                    badge: "\(monthsAway) month\(monthsAway == 1 ? "" : "s") away"
                ))
            }

            milestones.append(BloomMilestone(
                title: "Your next blood test",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

        case .mature:
            milestones.append(BloomMilestone(
                title: "Annual blood panel",
                description: bloodTestSchedulingText,
                icon: "test-pipe",
                palette: .purple,
                badge: suggestedBloodTestMonth.map { "Around month \($0)" }
            ))

            milestones.append(BloomMilestone(
                title: "Cardiovascular health",
                description: "Testosterone affects red blood cell production and lipid profiles. Annual CBC and lipid panels are recommended.",
                icon: "clock",
                palette: .teal,
                badge: "Annual"
            ))

            milestones.append(BloomMilestone(
                title: "Liver function panel",
                description: "Long-term testosterone therapy can affect liver enzymes, especially with oral formulations. Annual monitoring is standard care.",
                icon: "clock",
                palette: .amber,
                badge: "Annual"
            ))

            milestones.append(BloomMilestone(
                title: "Bone density check",
                description: "Testosterone supports bone mineral density. A baseline DEXA scan and periodic follow-ups are recommended, particularly if HRT started after prolonged hypogonadism.",
                icon: "clock",
                palette: .purple,
                badge: "Periodic"
            ))
        }

        return milestones
    }

    // MARK: - Body System Detail Content

    func bodySystemDetail(for systemKey: BodySystemKey) -> BloomBodySystemDetail {
        if medication == "Estrogen" {
            return estrogenDetail(for: systemKey)
        } else {
            return testosteroneDetail(for: systemKey)
        }
    }

    // MARK: Estrogen Detail Content

    private func estrogenDetail(for key: BodySystemKey) -> BloomBodySystemDetail {
        let tier = tenureTier

        switch key {
        case .moodAndMind:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Your emotional baseline is stable — dips can still occur around trough day. Consistent dosing is the key to avoiding neurosteroid fluctuations that can cause low-mood troughs."
                    : nil,
                establishedNote: tier == .established
                    ? "By now your emotional patterns have largely stabilised. You likely have a good read on where your mood sits across your injection cycle."
                    : nil
            )

        case .skinAndGlow:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Skin renewal slows with age regardless of HRT. Sun protection, retinoids, and adequate hydration remain important. Estrogen maintains collagen but doesn't halt photoaging."
                    : nil,
                establishedNote: tier == .established
                    ? "Your skin has fully transitioned. The texture difference from pre-HRT is fully established — it's softer, less oily, and heals differently."
                    : nil
            )

        case .bodyShape:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Your body shape is largely stable. Weight cycling (±5–10 lbs) can still produce new fat in gynoid patterns. Muscle mass requires active resistance training to maintain."
                    : nil,
                establishedNote: tier == .established
                    ? "The majority of your fat redistribution has occurred by now. Any remaining changes will be subtle and gradual."
                    : nil
            )

        case .yourCycle:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "You know your cycle well by now. If you experience trough symptoms, a shorter interval or ester switch (e.g., EV → EC) can flatten the curve."
                    : nil,
                establishedNote: tier == .established
                    ? "You're likely very familiar with how you feel across your injection week. Use this knowledge to optimize dose timing."
                    : nil
            )

        default:
            return estrogenDetail(for: .moodAndMind) // fallback
        }
    }

    // MARK: Testosterone Detail Content

    private func testosteroneDetail(for key: BodySystemKey) -> BloomBodySystemDetail {
        let tier = tenureTier

        switch key {
        case .voice:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Your voice is permanently settled. Pitch will not revert even if you pause T. Vocal training can still extend resonance and control regardless of HRT tenure."
                    : nil,
                establishedNote: tier == .established
                    ? "Your voice has done most of its changing. Any remaining shifts will be very subtle — a few Hz at most."
                    : nil
            )

        case .skinAndHair:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Body and facial hair are permanent. Scalp hair loss can be slowed with DHT blockers but not fully reversed once follicles miniaturise. Skin oiliness may mellow slightly with time."
                    : nil,
                establishedNote: tier == .established
                    ? "Your skin and hair patterns are largely stable. Acne may still flare around dose day if you're on a weekly schedule."
                    : nil
            )

        case .muscleStrength:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "Your muscle profile is stable and will stay that way as long as T levels are maintained. Strength is use-it-or-lose-it — detraining will still cause atrophy, just at a slower rate than pre-T."
                    : nil,
                establishedNote: tier == .established
                    ? "You've likely hit peak muscle growth velocity. Continued gains depend on training stimulus more than T duration at this point."
                    : nil
            )

        case .yourCycle:
            return BloomBodySystemDetail(
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
                maintenanceNote: tier == .mature
                    ? "You know your rhythm. If troughs are uncomfortable, ask about splitting your dose to twice-weekly — it flattens the curve and reduces aromatization spikes."
                    : nil,
                establishedNote: tier == .established
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
        case .early:
            return "Months 1–3: Emotional sensitivity often increases first. You may feel more tearful, reactive, or emotionally open. This is neurochemical recalibration.\n\nMonths 3–6: Emotional range broadens. Many describe feeling 'more themselves' — a sense of emotional alignment that was missing before.\n\nMonths 6–12: Mood patterns stabilise as your brain adapts to the new hormonal environment. Cyclical trough effects may become noticeable."
        case .established:
            return "Months 12–24: Your emotional baseline should feel natural and stable. You likely have a good read on how you feel across your dose cycle. This is your new normal."
        case .mature:
            return "Year 2+: Your emotional landscape is fully established. You're reading from the same neurochemical playbook that cis women operate on — the brain has fully adapted to estrogen-dominant signaling."
        }
    }

    private func timelineTextForSkin(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Month 1: Reduced oiliness is often the very first change — noticeable within weeks.\n\nMonths 2–6: Skin texture begins softening. Pores appear smaller, hydration improves.\n\nMonths 6–12: The 'glow' becomes apparent. Skin is noticeably softer and more radiant than pre-HRT."
        case .established:
            return "Months 12–24: Your skin has fully transitioned. Collagen density is up, sebum is down, and the texture difference from pre-HRT is complete."
        case .mature:
            return "Year 2+: Your skin is estrogen-maintained at this point. It will stay soft and hydrated as long as levels remain in range. Age-related changes (fine lines, elasticity loss) will still occur — estrogen slows but doesn't stop the clock."
        }
    }

    private func timelineTextForBody(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Months 1–3: Subtle — you may notice slight softening around the hips or face.\n\nMonths 3–9: Fat redistribution becomes visible. Pants may fit differently as hip and thigh circumference increases.\n\nMonths 9–12: Waist-to-hip ratio begins shifting noticeably. Upper body muscle loss contributes to a narrower shoulder appearance."
        case .established:
            return "Months 12–24: The bulk of your fat redistribution is complete. Your silhouette has changed meaningfully. Any remaining shifts are slow and subtle — fat cells turn over on a ~2–3 year cycle."
        case .mature:
            return "Year 2+: Your body shape is stable. Weight cycling (±5–10 lbs) will still produce new fat deposition in estrogen-dominant patterns. Muscle mass requires active resistance training to maintain — use it or lose it."
        }
    }

    private func cycleTimelineText(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "You're still learning your cycle. Track how you feel on days 1–2 (peak), 3–5 (mid), and 6–7 (trough). Patterns will emerge with consistency."
        case .established:
            return "You know your cycle well. Use this awareness to plan around trough days — schedule demanding tasks around peak, allow extra rest near trough."
        case .mature:
            return "Your cycle is second nature. Consider whether your ester choice still serves you — switching from EV to EC can flatten the curve if troughs are bothersome. A shorter injection interval (e.g., every 5 days instead of 7) is another option worth discussing."
        }
    }

    // MARK: - Estrogen What To Expect Helpers

    private func whatToExpectForMood(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Your emotional range will continue expanding. Be patient — neurochemical adaptation takes time. If mood swings are severe, discuss dose timing with your provider."
        case .established:
            return "You're in a stable period. If you notice mood dips correlating with trough, a shorter injection interval may help smooth things out."
        case .mature:
            return "You're in maintenance mode. Annual check-ins with your provider are sufficient unless something feels off. Trust your self-knowledge — you know your emotional baseline better than anyone."
        }
    }

    private func whatToExpectForSkin(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Skin will keep getting softer over the next several months. Sunscreen is your friend — estrogen-thinned skin is more UV-sensitive. Acne should continue decreasing."
        case .established:
            return "Your skin is in its prime. Maintain a simple skincare routine — gentle cleanser, moisturiser, SPF. No special intervention needed."
        case .mature:
            return "Skin aging continues naturally. Retinoids, vitamin C serum, and diligent SPF are your best tools. Your skin will remain softer than it would be without estrogen — but photoaging and collagen loss with age are universal."
        }
    }

    private func whatToExpectForBody(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Fat redistribution is a marathon, not a sprint. Be patient. Weight cycling (intentional gain and loss of 5–10 lbs) can accelerate the process, but it's not necessary — time will do the work."
        case .established:
            return "You're near the finish line. Any further changes will be subtle. Focus on what your body can do, not just how it looks."
        case .mature:
            return "This is your body. If you want to fine-tune, diet and exercise work the same way they always have — you'll just deposit and lose fat in estrogen-dominant patterns now. Resistance training helps maintain bone density and metabolic health."
        }
    }

    private func cycleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Your cycle is still becoming predictable as you establish consistent dosing. If you recently switched esters or doses, give it 4–6 weeks to reach steady state before evaluating how you feel."
        case .established:
            return "Your cycle is predictable. If you want less fluctuation, talk to your provider about a shorter interval or switching to a longer-acting ester like cypionate."
        case .mature:
            return "If your current rhythm works, keep it. If you're curious about optimising — more frequent smaller doses produce the flattest curve and the most stable mood. It's a quality-of-life optimisation, not a medical necessity."
        }
    }

    // MARK: - Testosterone Timeline Helpers

    private func tVoiceTimeline(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Months 1–3: You may feel a scratchy throat or notice slight hoarseness — the first signs of vocal fold thickening.\n\nMonths 3–6: The first noticeable pitch drop typically happens here. Voice may crack or feel unstable.\n\nMonths 6–12: Continuing gradual drop. Your voice is settling into its new range."
        case .established:
            return "Months 12–24: Most of the deepening is done. Any remaining changes are very subtle. Your speaking voice has found its natural pitch."
        case .mature:
            return "Year 2+: Your voice is permanent and settled. It will not revert if you pause or stop T. Vocal training can still improve resonance, projection, and control regardless of where your pitch landed."
        }
    }

    private func tSkinTimeline(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Month 1: Oil production kicks in quickly — skin may feel greasier within weeks. Acne often follows.\n\nMonths 3–9: Body hair begins appearing in a predictable pattern: lower legs → thighs → abdomen → chest → back → face.\n\nMonths 9–12: Hair distribution continues filling in. Acne may peak during this period."
        case .established:
            return "Months 12–24: Body and facial hair continue filling in. Acne typically begins to mellow. Scalp hairline may stabilise or continue receding depending on genetics."
        case .mature:
            return "Year 2+: Body and facial hair are fully established and permanent. Scalp hair loss, if it was going to happen, has likely stabilised at its genetic baseline. Acne should be minimal by now."
        }
    }

    private func tMuscleTimeline(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Months 1–3: Early strength gains — you may notice exercises feeling easier. Some water retention can give a 'fuller' look.\n\nMonths 3–9: Noticeable muscle growth, especially upper body. Recovery between workouts improves significantly.\n\nMonths 9–12: Strength continues increasing. Body composition is visibly shifting toward more lean mass."
        case .established:
            return "Months 12–24: Muscle growth velocity peaks. Without training, you'll maintain above-baseline lean mass. With training, this is peak gain season."
        case .mature:
            return "Year 2+: Your muscle profile is stable. Gains beyond this point come from training stimulus, not from T duration. You'll maintain your physique as long as levels stay in range and you stay active."
        }
    }

    private func cycleTimelineTextForT(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Your body is still adapting to exogenous T. Aromatization patterns, energy fluctuations, and trough effects are all still emerging. Give it 3–6 months of consistent dosing to establish a clear pattern."
        case .established:
            return "You know your rhythm. Energy peaks around day 2 post-shot, trough around day 6–7. Plan heavy workouts near peak, rest near trough."
        case .mature:
            return "You've mastered your cycle. If you want even more stability, twice-weekly dosing flattens the curve and reduces aromatization spikes. Some providers are open to this — it's worth asking."
        }
    }

    // MARK: - Testosterone What To Expect Helpers

    private func tVoiceWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "The biggest pitch drop is coming in months 3–6. Be patient with cracking — it's temporary. Stay hydrated, and avoid straining your voice."
        case .established:
            return "Your voice is largely done changing. If you want to work on resonance or speech patterns, a voice therapist can help — but pitch itself is structural and complete."
        case .mature:
            return "This is your voice. It's permanent, it's yours, and it won't change further. Voice training can still refine how you use it, but the instrument itself is set."
        }
    }

    private func tSkinWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Acne may worsen before it improves. A simple skincare routine (cleanser, moisturiser, salicylic acid) can help. Body and facial hair will continue filling in for 2+ years."
        case .established:
            return "Hair is still filling in. Acne should be calming down. If scalp hair loss is a concern, finasteride or minoxidil are options to discuss with your provider."
        case .mature:
            return "Your hair pattern is fully expressed. Scalp hair loss won't progress further as long as DHT levels are managed. Acne is unlikely to be an ongoing issue at this stage."
        }
    }

    private func tMuscleWhatToExpect(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Strength will keep climbing. Even without training, you'll gain lean mass. With consistent training, you're entering the fastest gain period of your life."
        case .established:
            return "Gains are still strong. Recovery is excellent. If you're training, this is prime time for progressive overload. If you're not, you'll maintain an above-baseline physique."
        case .mature:
            return "Your baseline is stable. Further gains require training stimulus — you've reached the plateau where T alone won't drive more growth. Stay active to maintain what you've built."
        }
    }

    private func cycleWhatToExpectForT(tier: TenureTier) -> String {
        switch tier {
        case .early:
            return "Your cycle is still stabilising. Aromatization effects (mood changes, water retention at peak) may fluctuate. Steady state takes 4–6 weeks after any dose change."
        case .established:
            return "Your cycle is predictable. If aromatization symptoms at peak bother you, a slightly lower dose or more frequent injections can help."
        case .mature:
            return "You've optimised. If not, twice-weekly dosing is the single best lever for smoothing out the peak-to-trough swing. It reduces both the T spike and the aromatization spike that follows."
        }
    }
}