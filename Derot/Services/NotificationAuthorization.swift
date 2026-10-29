//
//  NotificationAuthorization.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import UserNotifications

/// The one place the app asks for notification permission.
enum NotificationAuthorization {
    /// Shows Apple's notification alert. Returns true if the user allowed it.
    static func request() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
}
