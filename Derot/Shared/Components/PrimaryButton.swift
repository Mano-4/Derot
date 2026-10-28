//
//  PrimaryButton.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.black)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonSizing(.flexible)
        .tint(.derotYellow)
    }
}

#Preview {
    PrimaryButton(title: "Set up") { }
        .padding(.horizontal, 24)
}
