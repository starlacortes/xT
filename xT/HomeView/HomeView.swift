//
//  SwiftUIView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView{
                ProfileView()
                SchedulerView()
                SettingsView()
                GraphView()
        }
        
    }
}

#Preview {
    HomeView()
}
