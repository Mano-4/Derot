//
//  PermissionDeniedView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI

struct PermissionDeniedView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                SpeechBubble(text: "All good! We can still do fun stuff together.")
                    .padding(.horizontal, 48)

                Image("happybunny")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .accessibilityHidden(true)
            }

            Spacer()

            Text("You can turn on check-ins anytime in Settings.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
                .padding(.bottom, 16)

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
}

#Preview {
    PermissionDeniedView { }
}
