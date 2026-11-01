import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView()
        } else if !hasCompletedSetup {
            SetupView()
        } else {
            // The test ⏳ button lives on the Home screen only (see HomeView).
            MainTabView()
        }
    }
}
