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

                detailDivider()

                // Tenure status banner
                tenureBanner
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)

                detailDivider()

                // Science section
                detailSection(
                    title: "What's happening",
                    icon: "text.book.closed.fill",
                    content: detail.scienceText
                )

                detailDivider()

                // Timeline section
                detailSection(
                    title: "Your timeline",
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
        let monthStr = "\(engine.months) month\(engine.months == 1 ? "" : "s")"
        switch tier {
        case .t1Beginning: return "Body is actively adapting — \(monthStr)"
        case .t2Emerging:  return "First visible changes emerging — \(monthStr)"
        case .t3InMotion:  return "Changes stacking rapidly — \(monthStr)"
        case .t4Deepening: return "Changes are deepening — \(monthStr)"
        case .t5Settled:   return "Changes largely settled — \(monthStr)"
        case .t6Rooted:    return "Long-term maintenance — \(monthStr)"
        case .t7Veteran:   return "Health monitoring is key — \(monthStr)"
        }
    }

    private var tenureBannerSubtitle: String {
        let monthStr = "\(engine.months) month\(engine.months == 1 ? "" : "s") on HRT"
        switch tier {
        case .t1Beginning: return "\(tier.statusEmoji) \(monthStr) — body is reacting, not yet adapting."
        case .t2Emerging:  return "\(tier.statusEmoji) \(monthStr) — first physical changes appearing."
        case .t3InMotion:  return "\(tier.statusEmoji) \(monthStr) — most rapid visible shift."
        case .t4Deepening: return "\(tier.statusEmoji) \(monthStr) — still changing, not established."
        case .t5Settled:   return "\(tier.statusEmoji) \(monthStr) — shift from 'what's changing' to 'maintain + screen'."
        case .t6Rooted:    return "\(tier.statusEmoji) \(monthStr) — 5–10 years; maintenance, richer health surveillance."
        case .t7Veteran:   return "\(tier.statusEmoji) \(monthStr) — 10+ years; long-term health is the whole story."
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
                doseIntensityDisclaimer: nil,
                bloodTestSchedulingText: "Schedule your next blood test around month 9.",
                suggestedBloodTestMonth: 9,
                calibrationContext: nil
            )
        )
    }
}