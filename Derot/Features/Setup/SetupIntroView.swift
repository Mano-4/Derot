//
//  SetupIntroView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI

struct SetupIntroView: View {
    let onSetUp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                SpeechBubble(text: "I'll let you know when it's time to pause. Deal?")
                    .padding(.horizontal, 48)

                Image("happybunny")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .accessibilityHidden(true)
            }

            Spacer()

            VStack(spacing: 12) {
                Text("Mr. Rabbit only counts minutes in the apps you pick, and checks in when it's time to pause.")
                    .font(.system(.callout, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Your data never leaves your phone.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 38)
            .padding(.bottom, 32)

            PrimaryButton(title: "Set Up", action: onSetUp)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

#Preview {
    SetupIntroView { }
}
