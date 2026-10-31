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
    // Called when the user closes the activity (the X button or after finishing).
    let onClose: () -> Void

    var body: some View {
        // Swift makes us handle every case, so a new activity
        // can't be forgotten here.
        switch activity {
        // Notice
        case .findThreeThings:   FindThreeThingsView(onClose: onClose)
        case .oneGoodThing:      OneGoodThingView(onClose: onClose)
        case .senses54321:       HereAndNowView(onClose: onClose)
        // Breathe
        case .breathingBox:      BreathingBoxView(onClose: onClose)
        case .countEightBreaths: CountEightBreathsView(onClose: onClose)
        case .followTheCircle:   FollowTheCircleView(onClose: onClose)
        // Reflect
        case .nameYourFeeling:   NameYourFeelingView(onClose: onClose)
        case .makeAPlan:         MakeAPlanView(onClose: onClose)
        case .scrollCheckIn:     ScrollCheckInView(onClose: onClose)
        case .threeGoodThings:   LittleThingsKeptView(onClose: onClose)
        // Move
        case .neckReset:         NeckResetView(onClose: onClose)
        }
    }
}
