//
//  ActivityCatalog.swift
//  Derot
//
//  The one shared list of every activity in the app.
//  The random pick, the notification and the shield all read from here,
//  so they always agree on which activities exist.
//
//  The Activity Library (Hessa's ActivityLibraryView) keeps its own list with
//  images, colors and durations. When a new activity screen is added there,
//  add it here too (and in ActivityScreen.swift) so the pause can pick it.
//

import Foundation

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

    // Move
    case neckReset

    // Think
    case sixWordRecall

    /// A random activity that isn't this one (used by "Pick something else").
    func randomOther() -> DerotActivity {
        DerotActivity.allCases.filter { $0 != self }.randomElement() ?? self
    }

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
        case .neckReset:         "Neck Reset"
        case .sixWordRecall:     "6-Word Recall"
        }
    }

    // Its group in the Activity Library. The Home card uses it for the colours.
    var category: LibraryCategory {
        switch self {
        case .findThreeThings, .oneGoodThing, .senses54321:                     .notice
        case .breathingBox, .countEightBreaths, .followTheCircle:               .breathe
        case .nameYourFeeling, .makeAPlan, .scrollCheckIn, .threeGoodThings:    .reflect
        case .neckReset:                                                        .move
        case .sixWordRecall:                                                    .think
        }
    }

    // How long it takes. Same wording as the Activity Library cards.
    var duration: String {
        switch self {
        case .followTheCircle:                  "1 min"
        case .breathingBox, .neckReset:         "About 1 min"
        case .makeAPlan:                        "1, 5 or 10 min"
        default:                                "At your pace"
        }
    }

    // One short line about the activity (shown on the Home card).
    var summary: String {
        switch self {
        case .findThreeThings:   "Move your attention from the screen to your surroundings."
        case .oneGoodThing:      "Savor small moments."
        case .senses54321:       "Ground yourself when your mind is on autopilot."
        case .breathingBox:      "Find a steady breathing rhythm."
        case .countEightBreaths: "Bring your attention back."
        case .followTheCircle:   "Slow your breathing with a guide."
        case .nameYourFeeling:   "Understand how you're feeling."
        case .makeAPlan:         "Choose what to do instead of scrolling."
        case .scrollCheckIn:     "Notice what brought you here."
        case .threeGoodThings:   "Notice what's going well."
        case .neckReset:         "Ease tension from looking down."
        case .sixWordRecall:     "Challenge your short-term memory."
        }
    }

    // The picture on the activity's first screen. Same image names the
    // Activity Library uses (in Assets.xcassets), so both look the same.
    var imageName: String {
        switch self {
        case .findThreeThings:   "3f"
        case .oneGoodThing:      "one good thing"
        case .senses54321:       "54321 senses"
        case .breathingBox:      "Breathing Box"
        case .countEightBreaths: "Count 8 Breaths"
        case .followTheCircle:   "Follow the Circle"
        case .nameYourFeeling:   "Name Your Feeling"
        case .makeAPlan:         "Make a Plan"
        case .scrollCheckIn:     "Scroll Check-In"
        case .threeGoodThings:   "Three Good Things"
        case .neckReset:         "Neck Reset"
        case .sixWordRecall:     "6-Word Recall"
        }
    }
}
