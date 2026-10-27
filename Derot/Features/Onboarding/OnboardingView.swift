//
//  OnboardingView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 24/10/2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var showSplash = true

    private let lastPage = 3

    init() {
        // Sets page-dot colors app-wide (only onboarding uses page dots)
        UIPageControl.appearance().currentPageIndicatorTintColor = .label
        UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
    }

    var body: some View {
        if showSplash {
            SplashView()
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
        } else {
            pages
                .transition(.opacity)
        }
    }
    private var pages: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    title: "We take in more every day than our brains were built for.",
                    caption: "Videos, posts, news...\nit gets messy up here.",
                    image: "tiredbunny",
                    glowColor: .derotPink,
                    fogImage: "fog",
                    heavyFogImage: "heavyfog"
                )
                .tag(0)

                OnboardingPageView(
                    title: "So when an app keeps you too long, we pause.",
                    caption: "A little nudge, right when you need it.",
                    image: "watchbunny",
                    glowColor: .derotPink,
                    imageWidth: 250,
                    pillText: "Psst. You've been here a while",
                    buzzes: true
                )
                .tag(1)

                OnboardingResetPageView()
                    .tag(2)

                OnboardingPageView(
                    title: "And slowly, it all settles.",
                    caption: "I'll be your little friend along the way.",
                    image: "celebratingbunny",
                    glowColor: .derotYellow,
                    imageWidth: 260
                )
                .tag(3)
            }
            .tabViewStyle(.page)
            .overlay(alignment: .topTrailing) {
                Button("Skip") {
                    finishOnboarding()
                }
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(currentPage == lastPage ? 0 : 1)
                .disabled(currentPage == lastPage)
            }

            Button {
                finishOnboarding()
            } label: {
                Text("Let's go")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.derotYellow)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(currentPage == lastPage ? 1 : 0)
            .disabled(currentPage != lastPage)
        }
        .animation(.easeInOut, value: currentPage)
    }
    private func finishOnboarding() {
        withAnimation {
            hasSeenOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
}
