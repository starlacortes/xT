//
//  HeroView.swift
//  xT
//
//  Full-bleed welcome hero. Large name, soft greeting, medication pill.
//  Stats removed — they live in HybridStatusCard below.
//

import SwiftUI

struct HeroView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false

    private let baseHeight: CGFloat = 170

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("homeScroll")).minY
            let stretch = max(0, minY)      // pull-down past the top
            let scrolledUp = min(0, minY)   // scrolled up under the top (<= 0)

            ZStack(alignment: .topLeading) {
                // Stretchy background — grows upward to fill the pull-down gap
                ZStack(alignment: .topLeading) {
                    Theme.Gradients.brand

                    // Decorative circles — drift gently to keep the hero breathing
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 200, height: 200)
                        .offset(x: geo.size.width - 80, y: -60 + (float ? 12 : -12))

                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width - 40, y: 90 + (float ? -14 : 14))
                }
                .frame(width: geo.size.width, height: baseHeight + stretch)
                .offset(y: -stretch)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 0
                    )
                )
                .shadow(color: Color(hex: "#8875D4").opacity(0.2), radius: 16, x: 0, y: 8)

                // Foreground copy — lags behind the scroll and fades as it leaves
                VStack(alignment: .leading, spacing: 0) {
                    Text("Good \(timeOfDayGreeting)")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 6)
                        .entrance(delay: 0.05)

                    Text(profileManager.profileDisplayName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 16)
                        .entrance(delay: 0.13)

                    if medicationManager.isFullyConfigured {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(medicationManager.medicationDisplayInfo)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.white)
                            if let day = dayOfCycle {
                                Text("· Day \(day)")
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .entrance(delay: 0.21)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -scrolledUp * 0.35)
                .opacity(1 - min(1, -scrolledUp / 130))
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    float = true
                }
            }
        }
        .frame(height: baseHeight)
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

    private var dayOfCycle: Int? {
        guard let last = medicationManager.lastDoseDate,
              let method = medicationManager.selectedAdministrationMethod,
              let freq = MedicationManager.AdministrationMethod(rawValue: method)?.frequencyDays else {
            return nil
        }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return (elapsed % freq) + 1
    }
}

#Preview {
    HeroView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}
