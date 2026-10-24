//
//  OnboardingPageView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 24/10/2026.
//

import SwiftUI

struct OnboardingPageView: View {
    var body: some View {
        VStack{
            VStack(spacing: 16) {
                
                Text("We take in more every day than our brains were built for")
                    .font(Font.custom("ComingSoon-Regular", size:34, relativeTo: .title)).multilineTextAlignment(.center)
                
                Text("Videos, posts, news...\nit gets messy up here.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            } .padding(.horizontal, 38).padding(.top, 80)
            
            
            Spacer()
            
            ZStack{
                Ellipse().fill(.pink.opacity(0.25)).frame(width: 320, height: 240).blur(radius:50)
                
                Image("tiredbunny").resizable().scaledToFit().frame(width:140)
                
                Image("fog").resizable().scaledToFit().frame(width:140).offset(y: -65)
                
            }
            Spacer()
        }
        .padding(.bottom, 60)
        
    }
}

#Preview {
    OnboardingPageView()
}
