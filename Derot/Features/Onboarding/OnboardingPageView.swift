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
    var pillText:String? = nil
    var buzzes: Bool = false
    
    
    @State private var showFog = false
    @State private var showHeavyFog = false
    @State private var showPillText = false
    @State private var buzzCount = 0
    
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
                
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width:imageWidth)
                    .phaseAnimator([0, -4, 2, -4, 2, 0], trigger: buzzCount) { content, phase in
                    content.offset(x: phase)
                } animation: { _ in
                        .linear(duration: 0.025)
                }
                
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
                if let pillText{
                    Text(pillText).font(Font.custom("ComingSoon-Regular", size: 16))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay{
                            Capsule().stroke(.primary, lineWidth: 2)
                        }.background(Capsule().fill(.background)).offset(y: -162)
                }
                
                
            }
            Spacer()
        }
        .padding(.bottom, 60)
        .task {
            if fogImage != nil {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeOut(duration: 0.8)) {
                    showFog = true
                }
                
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.2)) {
                    showHeavyFog = true
                }
            }
            
            if buzzes {
                try? await Task.sleep(for: .seconds(1))
                buzzCount += 1
            }
        }
        .onDisappear {
            showFog = false
            showHeavyFog = false
        }
    }
}

#Preview {
    OnboardingPageView(
        title: "So when an app keeps you too long, we pause",
        caption: "A little nudge, right when you need it.",
        image: "watchbunny",
        glowColor: .pink,
        imageWidth: 250,
        pillText:"Psst. You've been here a while",
        buzzes: true

    )
}
