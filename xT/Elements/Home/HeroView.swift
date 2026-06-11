//
//  HeroView.swift
//  xT
//
//  Redesigned gradient hero section for HomeView.
//  Surfaces the three most important numbers at a glance.
//

import SwiftUI

struct HeroView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "#D4537E"), location: 0),
                        .init(color: Color(hex: "#8875D4"), location: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 140, height: 140)
                    .offset(x: geometry.size.width - 80, y: -40)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .offset(x: geometry.size.width - 60, y: 60)

                VStack(alignment: .leading, spacing: 0) {
                    // Greeting
                    Text("Good \(timeOfDayGreeting)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 2)

                    Text("Hi \(profileManager.profileDisplayName) ✦")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.bottom, 10)

                    // Medication pill
                    if medicationManager.isFullyConfigured {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(medicationManager.medicationDisplayInfo)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                            if let dayOfCycle = dayOfCycle {
                                Text("· Day \(dayOfCycle)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.18))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                        .padding(.bottom, 14)
                    }

                    // Stats row
                    HStack(spacing: 8) {
                        heroStat(
                            value: levelString,
                            label: "pg/mL now"
                        )
                        heroStat(
                            value: nextDoseString,
                            label: "next dose"
                        )
                        heroStat(
                            value: "\(medicationManager.monthsOnHRT) mo",
                            label: "on HRT"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
    }

    // MARK: - Subviews

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    private var levelString: String {
        if let level = medicationManager.currentHormoneLevel?.value {
            return "\(Int(level))"
        }
        return "—"
    }

    private var nextDoseString: String {
        guard let next = medicationManager.nextDoseDate else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days"
    }

    private var dayOfCycle: Int? {
        guard let last = medicationManager.lastDoseDate,
              let method = medicationManager.selectedAdministrationMethod,
              let freq = MedicationManager.AdministrationMethod(rawValue: method)?.frequencyDays else {
            return nil
        }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        let day = (elapsed % freq) + 1
        return day
    }
}

#Preview {
    HeroView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}