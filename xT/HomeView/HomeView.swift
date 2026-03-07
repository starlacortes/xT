//
//  HomeView.swift
//  xT
//
//  Created by Starla Cortes on 8/5/25.
//
import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(0)

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(1)

            GraphView()
                .tabItem {
                    Label("Graph", systemImage: "chart.bar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview {
    HomeView()
}
