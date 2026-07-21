//
//  HeroView.swift
//  xT
//
//  Slim greeting with gradient name. No medication context (moves to insight/next-dose).
//

import SwiftUI

struct HeroView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var compactHeight: Bool = false
    var horizontalPadding: CGFloat = 22
    
    @ScaledMetric(relativeTo: .largeTitle) private var nameFontSize: CGFloat = 52
    
    private var displayFontSize: CGFloat {
        let base = compactHeight ? nameFontSize * 0.85 : nameFontSize
        let isWide = horizontalSizeClass == .regular
        return min(isWide ? base * 1.15 : base, 72)
    }
    
    private var baseHeight: CGFloat {
        let base: CGFloat = compactHeight ? 110 : 130
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
                
                Text(profileManager.profileDisplayName)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, compactHeight ? 12 : 20)
            .padding(.bottom, 8)
            .offset(y: -scrolledUp * 0.35)
            .opacity(1 - min(1, -scrolledUp / 130))
        }
        .frame(height: baseHeight)
    }
    
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "good morning"
        case 12..<17: return "good afternoon"
        default: return "good evening"
        }
    }
}

#Preview {
    HeroView()
        .background(Color(.systemBackground))
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}