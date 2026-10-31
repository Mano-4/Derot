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
        // Swift makes us handle every case, so a new activity
        // can't be forgotten here.
        switch activity {
        // Notice
        case .findThreeThings:   FindThreeThingsWithCamera(onComplete: onComplete, onClose: onClose)
        case .oneGoodThing:      OneGoodThingView(onComplete: onComplete, onClose: onClose)
        case .senses54321:       HereAndNowView(onComplete: onComplete, onClose: onClose)
        // Breathe
        case .breathingBox:      BreathingBoxView(onComplete: onComplete, onClose: onClose)
        case .countEightBreaths: CountEightBreathsView(onComplete: onComplete, onClose: onClose)
        case .followTheCircle:   FollowTheCircleView(onComplete: onComplete, onClose: onClose)
        // Reflect
        case .nameYourFeeling:   NameYourFeelingView(onComplete: onComplete, onClose: onClose)
        case .makeAPlan:         MakeAPlanView(onComplete: onComplete, onClose: onClose)
        case .scrollCheckIn:     ScrollCheckInView(onComplete: onComplete, onClose: onClose)
        case .threeGoodThings:   LittleThingsKeptView(onComplete: onComplete, onClose: onClose)
        // Move
        case .neckReset:         NeckResetView(onComplete: onComplete, onClose: onClose)
        // Think
        case .sixWordRecall:     SixWordRecallView(onComplete: onComplete, onClose: onClose)
        }
    }
}
