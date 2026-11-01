//
//  PointsStore.swift
//  Derot
//
//  Keeps the user's total points. Starts at 0 and grows every time
//  an activity is finished (from the library, the Home card or a
//  pause notification). Saved on the phone, so it stays after closing the app.
//

import SwiftUI
import Combine

final class PointsStore: ObservableObject {
    static let shared = PointsStore()

    // The label the total is saved under.
    private static let savedKey = "totalPoints"

    // Changing this updates every screen that shows the points.
    @Published private(set) var total: Int {
        didSet { UserDefaults.standard.set(total, forKey: Self.savedKey) }
    }

    private init() {
        // integer(forKey:) gives 0 when nothing was saved yet, so new users start at 0.
        total = UserDefaults.standard.integer(forKey: Self.savedKey)
    }

    /// Adds the points an activity gave on its completion screen.
    func add(_ points: Int) {
        total += points
    }
}
