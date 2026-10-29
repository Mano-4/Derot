//
//  ShieldPreviewView.swift
//  Derot
//
//  A FAKE shield screen for testing without Screen Time
//  (no paid account and no Simulator support needed).
//  It does exactly what the real shield will do:
//    1. When it shows -> pick + save a random activity.
//    2. "Let's do it" -> send the pause notification, then close.
//  When the real shield is ready, it calls the same two functions.
//
//  #if DEBUG means this whole file is left out of App Store builds.
//

#if DEBUG
import SwiftUI

struct ShieldPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activity: DerotActivity?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("watchbunny")
                .resizable()
                .scaledToFit()
                .frame(width: 160)
                .accessibilityHidden(true)

            // The real shield can only use the system font, so the fake one does too.
            // This shows the team what the real shield will actually look like.
            Text("Mr. Rabbit's here. Time to pause?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            if let activity {
                Text("Let's try \(activity.title) together")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            Spacer()

            PrimaryButton(title: "Let's do it", action: letsDoIt)

            // The real one will lift the shield for 15 minutes of use.
            // Here it just closes the fake shield.
            Button("15 more minutes") { dismiss() }
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        // Step 1: the shield is the ONLY place that picks.
        .onAppear {
            activity = ActivityPicker.pickAndSave()
        }
    }

    // Step 2: same as the real shield's "Let's do it" button.
    private func letsDoIt() {
        Task {
            // Taraf's function: shows Apple's permission alert the first time only.
            _ = await NotificationAuthorization.request()
            // 3 seconds, so you can watch the banner arrive after the shield closes.
            await PauseNotification.send(after: 3)
            dismiss()
        }
    }
}

// The small floating test button that opens the fake shield.
struct DebugShieldButton: View {
    @State private var showShield = false

    var body: some View {
        Button {
            showShield = true
        } label: {
            Image(systemName: "hourglass")
                .font(.title3)
                .padding(12)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Test pause shield")
        .fullScreenCover(isPresented: $showShield) {
            ShieldPreviewView()
        }
    }
}

#Preview {
    ShieldPreviewView()
}
#endif
