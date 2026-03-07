//
//  HomeView.swift
//  xT
//
//  Created by Starla Cortes on 8/5/25.
//
import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @State private var showingProfileSheet = false

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(0)

            GraphView()
                .tabItem {
                    Label("Graph", systemImage: "chart.bar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .overlay(alignment: .topTrailing) {
            // Profile icon in top right corner
            Button(action: {
                showingProfileSheet = true
            }) {
                Image(uiImage: profileManager.getCurrentProfileImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .shadow(radius: 3)
            }
            .padding(.trailing, 16)
            .padding(.top, 50)
            .sheet(isPresented: $showingProfileSheet) {
                ProfileQuickView()
                    .presentationDetents([.height(200)])
            }
        }
    }
}

// MARK: - Quick Profile View
struct ProfileQuickView: View {
    @Environment(\.profileManager) private var profileManager

    var body: some View {
        VStack(spacing: 16) {
            // Profile image
            Image(uiImage: profileManager.getCurrentProfileImage())
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                )

            // Profile name
            if !profileManager.profileName.isEmpty {
                Text(profileManager.profileName)
                    .font(.headline)
            } else {
                Text("Your Profile")
                    .font(.headline)
                    .foregroundColor(.gray)
            }

            // View full profile button
            NavigationLink(destination: ProfileSettingsView()) {
                Text("View Full Profile")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
}
