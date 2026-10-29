//
//  ScreenTimeAuthorization.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import FamilyControls

/// The one place the app talks to Screen Time permission.
enum ScreenTimeAuthorization {
    /// Shows Apple's Screen Time permission alert.
    /// Returns true if the user allowed it, false for any failure
    /// (Don't Allow, no passcode, no network, another app already has control).
    static func request() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }

    /// Whether permission was already given. No alert is shown.
    static var isApproved: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
