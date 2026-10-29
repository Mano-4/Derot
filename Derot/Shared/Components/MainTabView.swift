//
//  MainTabView.swift
//  Derot
//
//  Created by mona almogren on 18/05/1448 AH.
//



import SwiftUI
import Combine

enum AppTab: Hashable {
    case home, activity, profile
}

struct MainTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

       /*     NavigationStack {
                ActivitiesHomeView()
            }
            .tabItem {
                Label("Activity", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.activity)*/

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(AppTab.profile)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(CharacterStore())
}
