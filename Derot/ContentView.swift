import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            Text("Home")          // replace with home view
        } else {
            OnboardingView()
        }
    }
}
