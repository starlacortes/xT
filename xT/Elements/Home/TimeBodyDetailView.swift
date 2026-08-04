//
//  TimeBodyDetailView.swift
//  xT
//
//  Deep-dive detail page for each body system. Pushed via NavigationLink
//  from the Time tab's "YOUR BODY" section. Content is tenure-aware:
//  early users see timeline projections, established users see stabilizing
//  notes, and mature users see maintenance guidance.
//

import SwiftUI

struct TimeBodyDetailView: View {
    let system: TimeBodySystem
    let engine: TimeContentEngine

    private var detail: TimeBodySystemDetail {
        engine.bodySystemDetail(for: system.systemKey)
    }

    private var tier: TenureTier { engine.tenureTier }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero icon area
                heroSection
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                if system.systemKey == .voice {
                    VoiceProgressView(months: engine.activeMonthsOnHRT, tier: engine.tenureTier)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)
                }

                detailDivider()

                // Tenure status banner
                tenureBanner
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)

                detailDivider()

                // Everything from here down is general educational content, closed
                // out by the EducationalFooter below.
                detailSection(
                    title: "What's happening",
                    icon: "text.book.closed.fill",
                    content: detail.scienceText
                )

                detailDivider()

                // "Typical", not "Your" — this is the population timeline, and the
                // app has no way to know where this particular user will land on it.
                detailSection(
                    title: "Typical timeline",
                    icon: "clock.fill",
                    content: detail.timelineText
                )

                detailDivider()

                // What to expect section
                detailSection(
                    title: "What to expect",
                    icon: "forward.fill",
                    content: detail.whatToExpect
                )

                // Conditional sections
                // Deepening tier (T4) — formerly "established"
                if let deepeningNote = detail.deepeningNote, tier == .t4Deepening {
                    detailDivider()
                    detailSection(
                        title: "Where you are now",
                        icon: "checkmark.seal.fill",
                        content: deepeningNote
                    )
                }

                // Settled and beyond (T5+) — maintenance/long-term health
                if let maintenanceNote = detail.maintenanceNote, tier >= .t5Settled {
                    detailDivider()
                    detailSection(
                        title: "Maintenance",
                        icon: "wrench.and.screwdriver.fill",
                        content: maintenanceNote
                    )
                }

                detailDivider()

                EducationalFooter(accent: detail.palette.accent)

                // Spacer for bottom padding
                Color.clear.frame(height: 40)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(detail.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(detail.palette.surface)
                    .frame(width: 64, height: 64)
                Image(systemName: detail.heroIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(detail.palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    tierBadge
                    Text(system.progressLabel)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var tierBadge: some View {
        Text(tier.timeBandLabel)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tierBadgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tierBadgeColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var tierBadgeColor: Color {
        switch tier {
        case .t1Beginning, .t2Emerging, .t3InMotion: return .blue
        case .t4Deepening: return .green
        case .t5Settled: return .purple
        case .t6Rooted: return .indigo
        case .t7Veteran: return .orange
        }
    }

    // MARK: - Tenure Banner

    private var tenureBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 12))
                .foregroundStyle(detail.palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(tenureBannerTitle)
                    .font(Theme.Fonts.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(tenureBannerSubtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(detail.palette.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(detail.palette.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    private var tenureBannerTitle: String {
        let monthStr = String(localized: "^[\(engine.months) month](inflect: true)",
                              comment: "A number of months, e.g. '7 months'")
        switch tier {
        case .t1Beginning: return "Body is actively adapting — \(monthStr)"
        case .t2Emerging:  return "First visible changes emerging — \(monthStr)"
        case .t3InMotion:  return "Changes stacking rapidly — \(monthStr)"
        case .t4Deepening: return "Changes are deepening — \(monthStr)"
        case .t5Settled:   return "Changes largely settled — \(monthStr)"
        case .t6Rooted:    return "Long-term maintenance — \(monthStr)"
        case .t7Veteran:   return "Long-term health monitoring — \(monthStr)"
        }
    }

    /// Months on therapy, plus what the tenure band describes. The banner title
    /// already names the stage, so this states the elapsed time and the one fact
    /// the band adds — no emoji, no verdict on the stage.
    private var tenureBannerSubtitle: String {
        let monthStr = String(localized: "^[\(engine.months) month](inflect: true) on HRT",
                              comment: "Elapsed time on hormone therapy, e.g. '7 months on HRT'")
        switch tier {
        case .t1Beginning: return String(localized: "\(monthStr) — responses precede adaptation.",
                                         comment: "What the earliest tenure band describes")
        case .t2Emerging:  return String(localized: "\(monthStr) — first physical changes appear.",
                                         comment: "What this tenure band describes")
        case .t3InMotion:  return String(localized: "\(monthStr) — the period of most rapid visible change.",
                                         comment: "What this tenure band describes")
        case .t4Deepening: return String(localized: "\(monthStr) — changes continue but are not yet settled.",
                                         comment: "What this tenure band describes")
        case .t5Settled:   return String(localized: "\(monthStr) — changes are largely settled; screening intervals begin.",
                                         comment: "What this tenure band describes")
        case .t6Rooted:    return String(localized: "\(monthStr) — 5–10 years; maintenance and health surveillance.",
                                         comment: "What this tenure band describes")
        case .t7Veteran:   return String(localized: "\(monthStr) — 10+ years; long-term health monitoring.",
                                         comment: "What this tenure band describes")
        }
    }

    // MARK: - Detail Section

    private func detailSection(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(detail.palette.accent)
                Text(title.uppercased())
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(detail.palette.accent)
                    .tracking(0.5)
            }

            Text(content)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    // MARK: - Helpers

    private func detailDivider() -> some View {
        Divider().opacity(0.5)
    }
}

// MARK: - Voice Progress View

private struct VoiceProgressView: View {
    let months: Int
    let tier: TenureTier

    private var progress: Double {
        switch tier {
        case .t1Beginning: return 0.05
        case .t2Emerging:  return 0.25
        case .t3InMotion:  return 0.55
        case .t4Deepening: return 0.78
        case .t5Settled, .t6Rooted, .t7Veteran: return 0.95
        }
    }

    private var stageLabel: String {
        switch tier {
        case .t1Beginning: return "Pre-change"
        case .t2Emerging:  return "Shifting"
        case .t3InMotion:  return "Deepening"
        case .t4Deepening: return "Settling"
        case .t5Settled, .t6Rooted, .t7Veteran: return "Settled"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VOICE RANGE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Text(stageLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.Time.mind.base)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.Time.mind.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Theme.Colors.Time.cycle.base.opacity(0.25),
                            Theme.Colors.Time.body.base.opacity(0.25)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    LinearGradient(
                        colors: [
                            Theme.Colors.Time.cycle.base,
                            Theme.Colors.Time.body.base
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * progress, height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Theme.Colors.Time.body.base, lineWidth: 2))
                        .offset(x: geo.size.width * progress - 7)
                        .animation(.easeInOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 14)

            HStack {
                Text("Higher range")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Lower range")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.Time.mind.base.opacity(0.15), lineWidth: 0.5)
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TimeBodyDetailView(
            system: TimeBodySystem(
                title: "Mood & mind",
                subtitle: "How estrogen shapes your emotions",
                icon: "brain",
                palette: .purple,
                progressLabel: "Stabilising",
                systemKey: .moodAndMind
            ),
            engine: TimeContentEngine(
                medication: "Estrogen",
                method: "Injectable",
                months: 8,
                currentLevel: 185,
                dayOfCycle: 3,
                activeMonthsOnHRT: 8,
                ageAtStart: nil,
                screeningLog: nil,
                showDoseIntensity: false,
                adherenceRate: 0.92,
                cyclePosition: .midCycle,
                regimenSegments: [],
                onTimeStreak: 4,
                relativeDoseIntensity: 1.0,
                doseIntensityNote: nil,
                bloodTestSchedulingText: "Schedule your next blood test around month 9.",
                suggestedBloodTestMonth: 9
            )
        )
    }
}
#endif