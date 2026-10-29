//
//  OnboardingResetPageView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 27/10/2026.
//

import SwiftUI

struct OnboardingResetPageView: View {
    @State private var fogGone = false
    @State private var isCalm = false
    @State private var walkerGone = false

    private let activities = ["Move", "Notice", "Breathe", "Reflect", "Think"]

    private var selectedActivity: String {
        isCalm ? "Breathe" : "Move"
    }

    private var stateColor: Color {
        isCalm ? .derotBlue : .derotGreen
    }
    var body: some View {
        VStack {
            VStack(spacing: 16) {
                Text(isCalm ? "We take a slow breath" : "We get up and move a little")
                    .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                Text("Five small ways to reset,\nwhenever you need.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(isCalm ? 1 : 0)
            }
            .padding(.horizontal, 38)
            .padding(.top, 80)

            Spacer()
            
            ZStack {
                Ellipse()
                    .fill(stateColor.opacity(0.35))
                    .frame(width: 320, height: 240)
                    .blur(radius: 50)
                
                if isCalm {
                    Image("sittingbunny")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .transition(.opacity)
                } else if !walkerGone {
                    ZStack {
                        Image("walkingbunny")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                        
                        Image("fog")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150)
                            .offset(y: -90)
                            .opacity(fogGone ? 0 : 1)
                    }
                    .phaseAnimator([false, true]) { content, isUp in
                        content
                            .offset(y: isUp && !fogGone ? -6 : 0)
                            .rotationEffect(.degrees(fogGone ? 0 : (isUp ? 3 : -3)))
                    } animation: { _ in
                            .easeInOut(duration: 0.35)
                    }
                    .transition(.opacity)
                }}

            Spacer()
            HStack(spacing: 6) {
                ForEach(activities, id: \.self) { activity in
                    Text(activity)
                        .font(.system(.caption2, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(activity == selectedActivity ? stateColor.opacity(0.6) : .clear)
                        }
                        .overlay {
                            Capsule()
                                .stroke(Color.derotGray, lineWidth: 1)
                        }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.bottom, 60)
        .task {
            do {
                try await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 0.8)) {
                    fogGone = true
                }

                try await Task.sleep(for: .seconds(1.25))
                withAnimation(.easeInOut(duration: 1.0)) {
                    isCalm = true
                }
            } catch {
                // page left the screen: stop
            }
        }
        .onDisappear {
            fogGone = false
            isCalm = false
        }
    }
}

#Preview {
    OnboardingResetPageView()
}
