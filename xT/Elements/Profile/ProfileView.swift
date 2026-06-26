//
//  ProfileView.swift
//  xT
//
//  Created by Cline on 3/10/26.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.profileManager) private var profileManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Large profile picture at the top
                    HStack {
                        Image(uiImage: profileManager.getCurrentProfileImage())
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.accent, lineWidth: 2)
                            )
                            .shadow(radius: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileManager.profileDisplayName)
                                .font(.title2)
                                .bold()
                                .foregroundStyle(profileManager.hasProfileData ? Color.primary : Color.gray)

                            Text("Manage your profile settings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 12)

                        Spacer()
                    }
                    .padding(.top, 16)

                    // Profile actions
                    VStack(spacing: 16) {
                        NavigationLink(destination: ProfileEditorView()) {
                            Text("Edit Profile")
                                .asAccentButton()
                        }

                        NavigationLink(destination: ProfileEditorView()) {
                            Text("View Full Profile")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundStyle(Theme.Colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        }
                    }
                    .padding(.vertical, 16)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ProfileView()
        .environment(\.profileManager, ProfileManager.shared)
}