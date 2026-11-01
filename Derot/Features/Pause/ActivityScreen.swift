//
//  ActivityScreen.swift
//  Derot
//
//  Turns an activity from the shared list into its real screen.
//  Used when a pause notification opens an activity.
//

import SwiftUI

struct ActivityScreen: View {
    let activity: DerotActivity
    // Called when the activity is finished (it reaches its completion screen), with its points.
    var onComplete: (Int) -> Void = { _ in }
    // Called when the user closes the activity (the X button or "Back home").
    let onClose: () -> Void

    var body: some View {
        // The first-screen picture, same as the Activity Library shows.
        let image = activity.imageName

        // Swift makes us handle every case, so a new activity
        // can't be forgotten here.
        switch activity {
        // Notice
        case .findThreeThings:   FindThreeThingsWithCamera(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .oneGoodThing:      OneGoodThingView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .senses54321:       HereAndNowView(onComplete: onComplete, onClose: onClose, introImageName: image)
        // Breathe
        case .breathingBox:      BreathingBoxView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .countEightBreaths: CountEightBreathsView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .followTheCircle:   FollowTheCircleView(onComplete: onComplete, onClose: onClose, introImageName: image)
        // Reflect
        case .nameYourFeeling:   NameYourFeelingView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .makeAPlan:         MakeAPlanView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .scrollCheckIn:     ScrollCheckInView(onComplete: onComplete, onClose: onClose, introImageName: image)
        case .threeGoodThings:   LittleThingsKeptView(onComplete: onComplete, onClose: onClose, introImageName: image)
        // Move
        case .neckReset:         NeckResetView(onComplete: onComplete, onClose: onClose, introImageName: image)
        // Think
        case .sixWordRecall:     SixWordRecallView(onComplete: onComplete, onClose: onClose, introImageName: image)
        }
    }
}
