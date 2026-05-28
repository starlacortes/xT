//
//  BloomView.swift
//  xT
//
//  Personalized HRT journey tracker with four-zone structure
//

import SwiftUI

struct BloomView: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .frame(height: 14)
                .padding(.horizontal, 16)

                // Header
                HStack {
                    Text("Bloom")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Your body, your journey ✦")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        // Zone 1: Personalized Header Card
                        if medicationManager.isFullyConfigured {
                            PersonalizedHeaderCard()
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }

                        // Zone 2: Happening Right Now
                        if medicationManager.isFullyConfigured {
                            SectionHeader(title: "Happening right now")
                                .padding(.horizontal, 14)

                            if let hormoneData = medicationManager.getCurrentHormoneLevel() {
                                HormoneLevelCard(
                                    value: hormoneData.value,
                                    unit: hormoneData.unit,
                                    range: hormoneData.range,
                                    explanation: hormoneData.explanation
                                )
                                .padding(.horizontal, 14)
                                .padding(.bottom, 10)
                            }

                            // Body System Cards Grid
                            let systems = medicationManager.getBodySystemProgress()
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                ForEach(systems, id: \.name) { system in
                                    BodySystemCard(
                                        name: system.name,
                                        icon: system.icon,
                                        color: system.color,
                                        progress: system.progress,
                                        status: system.status
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                        }

                        // Zone 3: Coming Up For You
                        if medicationManager.isFullyConfigured {
                            SectionHeader(title: "Coming up for you")
                                .padding(.horizontal, 14)

                            let milestones = medicationManager.getUpcomingMilestones()
                            if !milestones.isEmpty {
                                ForEach(milestones.prefix(2), id: \.month) { milestone in
                                    MilestoneCard(
                                        month: milestone.month,
                                        description: milestone.description,
                                        currentMonth: medicationManager.monthsOnHRT
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.bottom: 10)
                                }
                            }

                            // Blood test suggestion
                            if medicationManager.monthsOnHRT >= 3 && medicationManager.monthsOnHRT < 9 {
                                BloodTestCard()
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 16)
                            }
                        } else {
                            // Placeholder for when not configured
                            NotConfiguredView()
                                .padding(.horizontal, 14)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("Bloom")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
    }
}

// MARK: - Personalized Header Card
struct PersonalizedHeaderCard: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Month \(medicationManager.monthsOnHRT) on HRT")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.bloomCycleColor)

                    Text("You're in full swing ✦")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#72243E"))
                }

                Spacer()

                Text("\(medicationManager.medicationName) · \(medicationManager.selectedAdministrationMethod ?? "")")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#993556"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#F4C0D1"))
                    .cornerRadius(12)
            }

            Text("Changes unlocked so far")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#993556"))

            let changes = medicationManager.getChangesUnlocked()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(changes.prefix(4), id: \.self) { change in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#0F6E56"))

                        Text(change)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#72243E"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#F4C0D1"), lineWidth: 0.5)
                    )
                }
            }
        }
        .padding(14)
        .background(Theme.bloomCycleLightColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - Hormone Level Card
struct HormoneLevelCard: View {
    let value: Double
    let unit: String
    let range: String
    let explanation: String

    private var rangeColor: Color {
        switch range {
        case "Optimal", "Suppressed": return Color(hex: "#3B6D11")
        case "Low", "Low male": return Color(hex: "#854F0B")
        default: return Color(hex: "#993556")
        }
    }

    private var rangeBg: Color {
        switch range {
        case "Optimal", "Suppressed": return Color(hex: "#EAF3DE")
        case "Low", "Low male": return Color(hex: "#FAEEDA")
        default: return Color(hex: "#FBEAF0")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
                    )

                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.bloomCycleColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Your \(medicationManager.selectedMedication?.lowercased() ?? "hormone") right now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#72243E"))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: "#72243E"))

                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#993556"))

                    Text(range)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(rangeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rangeBg)
                        .cornerRadius(10)
                }

                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#993556"))
                    .lineSpacing(1.5)
            }
        }
        .padding(14)
        .background(Theme.bloomCycleLightColor)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - Body System Card
struct BodySystemCard: View {
    let name: String
    let icon: String
    let color: String
    let progress: Double
    let status: String

    private var bgColor: Color {
        switch color {
        case "purple": return Theme.bloomMindLightColor
        case "teal": return Theme.bloomSkinLightColor
        case "amber": return Theme.bloomBodyLightColor
        case "pink": return Theme.bloomCycleLightColor
        default: return Theme.cardBackground
        }
    }

    private var borderColor: Color {
        switch color {
        case "purple": return Theme.bloomMindBorderColor
        case "teal": return Theme.bloomSkinBorderColor
        case "amber": return Theme.bloomBodyBorderColor
        case "pink": return Theme.bloomCycleBorderColor
        default: return Theme.borderColor
        }
    }

    private var iconColor: Color {
        switch color {
        case "purple": return Theme.bloomMindColor
        case "teal": return Theme.bloomSkinColor
        case "amber": return Theme.bloomBodyColor
        case "pink": return Theme.bloomCycleColor
        default: return Theme.accentColor
        }
    }

    private var textColor: Color {
        switch color {
        case "purple": return Color(hex: "#3C3489")
        case "teal": return Color(hex: "#085041")
        case "amber": return Color(hex: "#633806")
        case "pink": return Color(hex: "#72243E")
        default: return .primary
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 0.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
            }

            // Title
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textColor)

            // Subtitle
            Text("How \(name.lowercased()) is changing")
                .font(.system(size: 11))
                .foregroundColor(iconColor)
                .lineSpacing(1.4)

            // Progress bar
            VStack(spacing: 3) {
                ProgressBar(progress: progress, color: iconColor)
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(bgColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - Milestone Card
struct MilestoneCard: View {
    let month: Int
    let description: String
    let currentMonth: Int

    private var monthsAway: Int {
        max(0, month - currentMonth)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: "#F1EFE8"))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#D3D1C7"), lineWidth: 0.5)
                    )

                Image(systemName: "clock")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "#5F5E5A"))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Month \(month) milestone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(1.4)

                VStack(spacing: 3) {
                    ProgressBar(progress: Double(currentMonth) / Double(month), color: Color(hex: "#AFA9EC"))
                    Text("\(monthsAway) months away")
                        .font(.system(size: 10))
                        .foregroundColor(.tertiary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - Blood Test Card
struct BloodTestCard: View {
    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Theme.bloomMindLightColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Theme.bloomMindBorderColor, lineWidth: 0.5)
                    )

                Image(systemName: "testtube.2")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.bloomMindColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Your next blood test")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text("At month 9 it's worth checking E2, T, and a full panel with your provider.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(1.4)

                Text("Suggested: month 9")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.bloomMindColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.bloomMindLightColor)
                    .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - Not Configured View
struct NotConfiguredView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 60)

            Text("Set up your medication")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("Configure your HRT regimen in Settings to unlock your Bloom journey")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(UIColor.separator).opacity(0.3))
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: CGFloat(progress) * geometry.size.width, height: 5)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Preview
#Preview {
    BloomView()
        .environment(\.medicationManager, MedicationManager.shared)
}