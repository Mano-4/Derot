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
            // ContentView shows Onboarding and Setup the first time, then the tabs.
            ContentView()
                .environmentObject(store)
                // Opens the activity over any tab when a pause notification
                // or the Home card's Start button is tapped.
                .fullScreenCover(item: $pauseRouter.activityToOpen) { activity in
                    ActivityScreen(
                        activity: activity,
                        // Finished: add its points, and switch to Home behind the activity,
                        // so "Back home" lands there.
                        onComplete: { points in
                            PointsStore.shared.add(points)
                            TabRouter.shared.selected = .home
                        },
                        onClose: { pauseRouter.activityToOpen = nil }
                    )
                    // "Pick something else" swaps in another random activity.
                    .environment(\.pickSomethingElse) {
                        pauseRouter.activityToOpen = activity.randomOther()
                    }
                }
        }

    }
}
