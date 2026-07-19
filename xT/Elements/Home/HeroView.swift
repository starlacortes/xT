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

    var compactHeight: Bool = false
    var isWide: Bool = false
    var horizontalPadding: CGFloat = 22

    @ScaledMetric(relativeTo: .largeTitle) private var nameFontSize: CGFloat = 52

    private var displayFontSize: CGFloat {
        let base = compactHeight ? nameFontSize * 0.85 : nameFontSize
        return min(isWide ? base * 1.15 : base, 72)
    }

    private var baseHeight: CGFloat {
        let base: CGFloat = compactHeight ? 135 : 155
        return base + max(0, displayFontSize - 52)
    }

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("homeScroll")).minY
            let scrolledUp = min(0, minY)

            VStack(alignment: .leading, spacing: 4) {
                Text(timeOfDayGreeting)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Color.secondary)
                    .entrance(delay: 0.04)

                Text((profileManager.profileDisplayName))
                    .font(.system(size: displayFontSize, weight: .bold))
                    .tracking(-1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .entrance(delay: 0.17)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
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
        case 0..<12: return "good morning"
        case 12..<17: return "good afternoon"
        default: return "good evening"
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
