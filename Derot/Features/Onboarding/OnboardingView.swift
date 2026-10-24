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
            OnboardingPageView()
            OnboardingPageView()
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
