//
//  PauseRouter.swift
//  Derot
//
//  Listens for taps on the pause notification and tells SwiftUI
//  which activity to open.
//
//  iOS doesn't talk to SwiftUI views directly. It calls methods on a
//  "delegate" object (like the Coordinator in CameraPicker). PauseRouter
//  is that delegate: iOS tells it "the notification was tapped",
//  and it updates `activityToOpen`, which the app is watching.
//

import SwiftUI
import Combine
import UserNotifications

final class PauseRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    // One shared router for the whole app. iOS only keeps a weak reference
    // to its delegate, so something must hold on to it: this does.
    static let shared = PauseRouter()

    // When this changes from nil to an activity, Derot.swift opens it full screen.
    // Setting it back to nil closes it.
    @Published var activityToOpen: DerotActivity?

    // iOS calls this when a notification arrives while the app is OPEN.
    // By default iOS hides it then; we ask it to show the banner anyway.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // iOS calls this when the user TAPS a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Only react to our pause notification.
        guard response.notification.request.identifier == PauseNotification.requestID else { return }

        // Read (never pick) the saved activity, so it matches the notification.
        activityToOpen = ActivityPicker.saved
    }
}
