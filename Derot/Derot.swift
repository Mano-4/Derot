import SwiftUI
import Combine
import UserNotifications

@main struct Derot: App {
    @StateObject private var store = CharacterStore()
    // Knows which activity a tapped pause notification should open.
    @StateObject private var pauseRouter = PauseRouter.shared

    init() {
        // Tell iOS who receives notification taps. This must happen at launch,
        // so a tap that opens the app from closed is not missed.
        UNUserNotificationCenter.current().delegate = PauseRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                // Opens the activity over any tab when a pause notification is tapped.
                .fullScreenCover(item: $pauseRouter.activityToOpen) { activity in
                    ActivityScreen(activity: activity) {
                        pauseRouter.activityToOpen = nil
                    }
                }
                #if DEBUG
                // Test-only button that opens a fake shield (see ShieldPreviewView).
                .overlay(alignment: .bottomTrailing) {
                    DebugShieldButton()
                        .padding(.trailing, 16)
                        .padding(.bottom, 64)
                }
                #endif
        }

    }
}
