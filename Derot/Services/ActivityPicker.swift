//
//  ActivityPicker.swift
//  Derot
//
//  Picks the random activity for a pause and remembers it ("the box").
//  The shield, the notification and the app all read the SAME saved
//  activity, so they always show the same one.
//
//  Rule: only pickAndSave() chooses. Everyone else just reads `saved`.
//

import Foundation

enum ActivityPicker {
    // The label the activity ID is saved under.
    private static let savedKey = "pendingActivityID"

    // Where we save: for now, the app's own small storage (UserDefaults).
    // Later, when the App Group is ready, change only this line to:
    //     UserDefaults(suiteName: "group.com.lamaalbalawipersonalteam.Derot")!
    // so the shield extensions can open the same box.
    private static var box: UserDefaults { .standard }

    /// Picks a random activity, never the same as last time, and saves it.
    /// Returns the activity so the caller can use it right away.
    @discardableResult
    static func pickAndSave() -> DerotActivity {
        // Every activity except the one we saved last time.
        let choices = DerotActivity.allCases.filter { $0 != saved }

        // randomElement() is nil only if the list is empty, so the fallback never really runs.
        let activity = choices.randomElement() ?? .breathingBox

        // We save the ID text ("breathingBox"), not the activity itself:
        // UserDefaults can only store simple values like text and numbers.
        box.set(activity.rawValue, forKey: savedKey)
        return activity
    }

    /// The activity from the last pick, or nil if nothing was picked yet.
    static var saved: DerotActivity? {
        guard let id = box.string(forKey: savedKey) else { return nil }

        // Turns the saved text back into an activity.
        // If the text doesn't match any case (e.g. an old ID), this gives nil.
        return DerotActivity(rawValue: id)
    }
}
