//
//  HeaderView.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Header component for HomeView
//

import SwiftUI

struct HeaderView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Profile section
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Theme.globalBackgroundGradient
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())

                    Text(profileManager.profileDisplayName.prefix(1))
                        .font(.system(size: 18))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }

                // Profile info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi \(profileManager.profileDisplayName) ✦")
                        .font(.system(size: 22))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if medicationManager.isFullyConfigured {
                        Text(medicationManager.medicationDisplayInfo)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Notification bell
                Image(systemName: "bell")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }

        }
        .padding(12)
        .background(Color.clear)
    }
}

#Preview {
    HeaderView(showingGraphDetail: .constant(false))
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}