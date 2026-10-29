import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @StateObject private var store = CharacterStore()
    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView()
        } else if !hasCompletedSetup {
            SetupView()
        } else {
            WindowGroup {
                MainTabView()
                    .environmentObject(store)
            }
        }
    }
}
/*import SwiftUI
import Combine

@main struct Derot: App {
    @StateObject private var store = CharacterStore()
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }

    }
}


