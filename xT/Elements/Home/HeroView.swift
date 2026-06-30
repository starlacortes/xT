//
//  HeroView.swift
//  xT
//
//  Flat greeting with gradient-filled display text and parallax scroll.
//  No card, no background — floats directly on the home surface.
//

import SwiftUI

struct HeroView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager

    private let baseHeight: CGFloat = 155

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("homeScroll")).minY
            let scrolledUp = min(0, minY)

            VStack(alignment: .leading, spacing: 4) {
                Text(timeOfDayGreeting)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Color.secondary)
                    .entrance(delay: 0.04)

                Text("Hi \(profileManager.profileDisplayName),")
                    .font(.system(size: 52, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: Theme.Gradients.brandColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .entrance(delay: 0.10)

                if medicationManager.isFullyConfigured {
                    HStack(spacing: 6) {
                        Text(medicationManager.medicationDisplayInfo)
                        if let day = dayOfCycle, let freq = cycleFrequency {
                            Text("·")
                                .foregroundStyle(Color.secondary.opacity(0.5))
                            Text("Day \(day) of \(freq)")
                        }
                    }
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Color.secondary)
                    .entrance(delay: 0.17)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .offset(y: -scrolledUp * 0.35)
            .opacity(1 - min(1, -scrolledUp / 130))
        }
        .frame(height: baseHeight)
    }

    // MARK: - Helpers

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dayOfCycle: Int? {
        guard let last = medicationManager.lastDoseDate,
              let freq = cycleFrequency else { return nil }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return (elapsed % freq) + 1
    }

    private var cycleFrequency: Int? {
        guard let method = medicationManager.selectedAdministrationMethod,
              let adm = MedicationManager.AdministrationMethod(rawValue: method) else { return nil }
        return adm.frequencyDays
    }
}

#Preview {
    HeroView()
        .background(Color(.systemBackground))
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}
