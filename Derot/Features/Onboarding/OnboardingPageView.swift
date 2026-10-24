//
//  OnboardingPageView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 24/10/2026.
//

import SwiftUI

struct OnboardingPageView: View {
    let title: String
    let caption: String
    let image: String
    let glowColor: Color
    var imageWidth: CGFloat = 140
    
    var fogImage: String? = nil
    var heavyFogImage: String? = nil
    
    @State private var showFog = false
    @State private var showHeavyFog = false
    
    
    var body: some View {
        VStack{
            VStack(spacing: 16) {
                
                Text(title)
                    .font(Font.custom("ComingSoon-Regular", size:34, relativeTo: .title)).multilineTextAlignment(.center)
                
                Text(caption)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            } .padding(.horizontal, 38).padding(.top, 80)
            
            
            Spacer()
            
            ZStack{
                Ellipse().fill(glowColor.opacity(0.25)).frame(width: 320, height: 240).blur(radius:50)
                
                Image(image).resizable().scaledToFit().frame(width:imageWidth)
                
                if let fogImage{
                    Image(fogImage).resizable().scaledToFit().frame(width:140).offset(y: -65).opacity(showFog ? 1 : 0).scaleEffect(showFog ? 1 : 0.8, anchor: .bottom)}
                
                if let heavyFogImage {
                                    Image(heavyFogImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 150)
                                        .offset(y: -80)
                                        .opacity(showHeavyFog ? 1 : 0)
                                }
                
            }
            Spacer()
        }
        .padding(.bottom, 60)
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeOut(duration: 0.8)) {
                showFog = true
            }

            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.2)) {
                showHeavyFog = true
            }
        }
            .onDisappear {
                showFog = false
                showHeavyFog = false
            }    }
}

#Preview {
    OnboardingPageView(
        title: "We take in more every day than our brains were built for",
        caption: "Videos, posts, news...\nit gets messy up here.",
        image: "tiredbunny",
        glowColor: .pink,
        fogImage: "fog",
        heavyFogImage: "heavyfog"
    )
}
