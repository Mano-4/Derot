//
//  SpeechBubble.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI

struct SpeechBubble: View {
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: -6) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))

            // Tail overlaps the bubble slightly so there's no visible seam
            Image(systemName: "arrowtriangle.down.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        // Flattens bubble + tail into one layer so they share a single shadow
        .compositingGroup()
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

#Preview {
    SpeechBubble(text: "I'll let you know when it's time to pause. Deal?")
        .padding(.horizontal, 48)
}
