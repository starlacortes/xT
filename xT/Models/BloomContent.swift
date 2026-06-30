//
//  BloomContent.swift
//  xT
//
//  Content engine for the Bloom tab — generates personalized insights
//  based on medication type, months on HRT, and current hormone levels.
//

import Foundation
import SwiftUI

// MARK: - Body System Card

struct BloomBodySystem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let palette: BloomPalette
    let progressFraction: Double
    let progressLabel: String
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

    var timelineSubtitle: String { "Month \(months) on HRT" }

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
        let cycleProgress: Double = {
            guard method == "Injectable" else { return 1.0 }
            return 1.0
        }()

        return [
            BloomBodySystem(
                title: "Mood & mind",
                subtitle: "How estrogen shapes your emotions",
                icon: "brain",
                palette: .purple,
                progressFraction: min(Double(months) / 18.0, 1.0),
                progressLabel: months < 6 ? "Settling in" : months < 12 ? "Stabilising" : "Well-established"
            ),
            BloomBodySystem(
                title: "Skin & glow",
                subtitle: "What's changing and why",
                icon: "sparkles",
                palette: .teal,
                progressFraction: min(Double(months) / 12.0, 1.0),
                progressLabel: months < 3 ? "Just starting" : months < 9 ? "Well underway" : "Ongoing"
            ),
            BloomBodySystem(
                title: "Body shape",
                subtitle: "Fat, curves & what to expect",
                icon: "body-scan",
                palette: .amber,
                progressFraction: min(Double(months) / 24.0, 1.0),
                progressLabel: months < 6 ? "Early changes" : months < 18 ? "Still in progress" : "Mature changes"
            ),
            BloomBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressFraction: cycleProgress,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)"
            ),
        ]
    }

    private var testosteroneBodySystems: [BloomBodySystem] {
        [
            BloomBodySystem(
                title: "Voice",
                subtitle: "Deepening timeline",
                icon: "microphone",
                palette: .purple,
                progressFraction: min(Double(months) / 24.0, 1.0),
                progressLabel: months < 3 ? "Early changes" : months < 12 ? "Still shifting" : "Settled"
            ),
            BloomBodySystem(
                title: "Skin & hair",
                subtitle: "Oil, texture & growth",
                icon: "sparkles",
                palette: .amber,
                progressFraction: min(Double(months) / 12.0, 1.0),
                progressLabel: months < 3 ? "Just starting" : "Ongoing"
            ),
            BloomBodySystem(
                title: "Muscle & strength",
                subtitle: "What T does to your body",
                icon: "body-scan",
                palette: .teal,
                progressFraction: min(Double(months) / 18.0, 1.0),
                progressLabel: months < 6 ? "Building" : "Growing"
            ),
            BloomBodySystem(
                title: "Your cycle",
                subtitle: "\(method) peaks & troughs",
                icon: "heart-rate-monitor",
                palette: .pink,
                progressFraction: 1.0,
                progressLabel: "Day \(dayOfCycle) of \(cycleLengthDays)"
            ),
        ]
    }

    private var cycleLengthDays: Int {
        switch method {
        case "Injectable": return 7
        case "Patch": return 3
        default: return 1
        }
    }

    // MARK: Upcoming milestones

    var upcomingMilestones: [BloomMilestone] {
        if medication == "Estrogen" {
            return estrogenMilestones
        } else {
            return testosteroneMilestones
        }
    }

    private var estrogenMilestones: [BloomMilestone] {
        var milestones: [BloomMilestone] = []

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

        let bloodTestMonth = ((months / 3) + 1) * 3
        milestones.append(BloomMilestone(
            title: "Your next blood test",
            description: "At month \(bloodTestMonth) it's worth checking E2, T, and a full panel with your provider.",
            icon: "test-pipe",
            palette: .purple,
            badge: "Suggested: month \(bloodTestMonth)"
        ))

        return milestones
    }

    private var testosteroneMilestones: [BloomMilestone] {
        var milestones: [BloomMilestone] = []

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

        let bloodTestMonth = ((months / 3) + 1) * 3
        milestones.append(BloomMilestone(
            title: "Your next blood test",
            description: "At month \(bloodTestMonth) check T, hematocrit, and liver enzymes with your provider.",
            icon: "test-pipe",
            palette: .purple,
            badge: "Suggested: month \(bloodTestMonth)"
        ))

        return milestones
    }
}
