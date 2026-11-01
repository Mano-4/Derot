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
            MainTabView()
                #if DEBUG
                // Test-only button that opens a fake shield (see ShieldPreviewView).
                // Shown only after Onboarding and Setup.
                .overlay(alignment: .bottomTrailing) {
                    DebugShieldButton()
                        .padding(.trailing, 16)
                        .padding(.bottom, 64)
                }
                #endif
        }
    }
}
