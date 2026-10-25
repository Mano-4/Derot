//
//  OnboardingView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 24/10/2026.
//

import SwiftUI

struct OnboardingView: View {
    init() {
         UIPageControl.appearance().currentPageIndicatorTintColor = .label
         UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
     }
    
    var body: some View {
        TabView{
            OnboardingPageView(
                title: "We take in more every day than our brains were built for",
                caption: "Videos, posts, news...\nit gets messy up here.",
                image: "tiredbunny",
                glowColor: .pink,
                fogImage: "fog",
                heavyFogImage: "heavyfog"
            )

            OnboardingPageView(
                title: "So when an app keeps you too long, we pause",
                caption: "A little nudge, right when you need it.",
                image: "watchbunny",
                glowColor: .pink,
                imageWidth: 250,
                pillText:"Psst. You've been here a while"
            )
        }
        .tabViewStyle(.page).overlay(alignment: .topTrailing){
            Button("Skip"){}
                .font(.system(.callout ,design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
            
    }
}

#Preview {
    OnboardingView()
}
