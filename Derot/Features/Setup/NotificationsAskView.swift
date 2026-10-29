//
//  NotificationsAskView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI

struct NotificationsAskView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                SpeechBubble(text: "Can I send you a heads-up?")
                    .padding(.horizontal, 48)

                Image("happybunny")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .accessibilityHidden(true)
            }

            Text("So my check-ins reach you even when you're busy.")
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
                .padding(.top, 24)

            Spacer()

            PrimaryButton(title: "Turn On Notifications", action: onAllow)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

#Preview {
    NotificationsAskView { }
}
