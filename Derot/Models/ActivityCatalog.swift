//
//  ActivityCatalog.swift
//  Derot
//
//  The one shared list of every activity in the app.
//  The random pick, the notification and the shield all read from here,
//  so they always agree on which activities exist.
//

import Foundation

// The categories (Notice, Breathe, Reflect, Move, Think) and their colors
// live in ActivityCategory, in Features/Activity/Activity.swift (Sadeem's library).

// MARK: - DerotActivity

// Every activity screen in the app.
//
// Why an enum? Each case is one activity, and Swift won't let us
// forget one in a switch. The String raw value ("findThreeThings")
// is the activity's fixed ID: it's what we save and send in the
// notification, so never rename a raw value once it's in use.
//
// Named DerotActivity (not Activity) because Home.swift already has a type called Activity.
enum DerotActivity: String, CaseIterable, Identifiable {
    // Notice
    case findThreeThings
    case oneGoodThing
    case senses54321

    // Breathe
    case breathingBox
    case countEightBreaths
    case followTheCircle

    // Reflect
    case nameYourFeeling
    case makeAPlan
    case scrollCheckIn
    case threeGoodThings

    // Identifiable lets SwiftUI lists use the activity directly.
    var id: String { rawValue }

    // The name people see.
    var title: String {
        switch self {
        case .findThreeThings:   "Find Three Things"
        case .oneGoodThing:      "One Good Thing"
        case .senses54321:       "5-4-3-2-1 Senses"
        case .breathingBox:      "Breathing Box"
        case .countEightBreaths: "Count 8 Breaths"
        case .followTheCircle:   "Follow the Circle"
        case .nameYourFeeling:   "Name Your Feeling"
        case .makeAPlan:         "Make a Plan"
        case .scrollCheckIn:     "Scroll Check-In"
        case .threeGoodThings:   "Three Good Things"
        }
    }

    // Which group the activity belongs to.
    var category: ActivityCategory {
        switch self {
        case .findThreeThings, .oneGoodThing, .senses54321:
            .notice
        case .breathingBox, .countEightBreaths, .followTheCircle:
            .breathe
        case .nameYourFeeling, .makeAPlan, .scrollCheckIn, .threeGoodThings:
            .reflect
        }
    }
}
