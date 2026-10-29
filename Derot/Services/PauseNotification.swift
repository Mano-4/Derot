//
//  PauseNotification.swift
//  Derot
//
//  Sends the "time to pause" notification for the saved activity.
//  It never picks an activity itself: it only reads ActivityPicker.saved,
//  so the notification always matches what the shield showed.
//
//  Permission is asked by Taraf's NotificationAuthorization.request().
//

import UserNotifications

enum PauseNotification {
    // Every pause notification uses this same ID, so a new one
    // replaces an old one that hasn't shown yet (no pile-up).
    // PauseRouter also uses it to know a tapped notification is ours.
    static let requestID = "pauseNotification"

    /// Sends the notification for the saved activity after a short delay.
    /// Does nothing if no activity was picked yet.
    static func send(after seconds: TimeInterval = 1) async {
        guard let activity = ActivityPicker.saved else { return }

        // 1. What the notification says (same words as the shield design).
        let content = UNMutableNotificationContent()
        content.title = "Mr. Rabbit's here. Time to pause?"
        content.body = "Let's try \(activity.title) together"
        content.sound = .default

        // 2. When it shows: after `seconds`. iOS needs a delay above 0.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

        // 3. Hand it to iOS. If permission is off, iOS just won't show it,
        //    so there's nothing useful to do with the error here.
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
