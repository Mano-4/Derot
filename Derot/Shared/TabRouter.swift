//
//  TabRouter.swift
//  Derot
//
//  Remembers which tab MainTabView shows. It's shared so an activity that
//  finishes (from the library or from a pause notification) can send the
//  user back to Home when they tap "Back home".
//

import SwiftUI
import Combine

enum MainTab: Hashable {
    case home, activity, profile
}

final class TabRouter: ObservableObject {
    static let shared = TabRouter()

    // Changing this switches the tab on screen.
    @Published var selected: MainTab = .home
}
