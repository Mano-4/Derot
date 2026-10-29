//
//  SetupView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI
import FamilyControls
import ManagedSettings

enum SetupStep: Hashable {
    case denied, pickApps, setLimits, notifications
}

struct SetupView: View {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    @State private var path: [SetupStep] = []
    @State private var selection = FamilyActivitySelection()
    @State private var appLimits: [ApplicationToken: Int] = [:]
    @State private var categoryLimits: [ActivityCategoryToken: Int] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            SetupIntroView {
                Task {
                    if await ScreenTimeAuthorization.request() {
                        path.append(.pickApps)
                    } else {
                        path.append(.denied)
                    }
                }
            }
            .toolbar { progressBar(for: nil) }
            .navigationDestination(for: SetupStep.self) { step in
                screen(for: step)
                    .toolbar { progressBar(for: step) }
            }
        }
    }

    @ViewBuilder
    private func screen(for step: SetupStep) -> some View {
        switch step {
        case .denied:
            PermissionDeniedView {
                path.append(.notifications)
            }
        case .pickApps:
            PickAppsView(selection: $selection) {
                path.append(.setLimits)
            }
        case .setLimits:
            SetLimitsView(
                selection: selection,
                appLimits: $appLimits,
                categoryLimits: $categoryLimits,
                onContinue: { path.append(.notifications) },
                onSkip: { path.append(.notifications) }  // Skipping keeps the 30m defaults
            )
        case .notifications:
            NotificationsAskView {
                Task {
                    // Setup finishes whether they allow or not
                    _ = await NotificationAuthorization.request()
                    finishSetup()
                }
            }
        }
    }

    /// nil = intro screen. The denied screen has no bar (matches the prototype).
    @ToolbarContentBuilder
    private func progressBar(for step: SetupStep?) -> some ToolbarContent {
        if let value = progress(for: step) {
            ToolbarItem(placement: .principal) {
                ProgressView(value: value)
                    .frame(width: 120)
                    .accessibilityLabel("Setup progress")
            }
        }
    }

    private func progress(for step: SetupStep?) -> Double? {
        switch step {
        case nil: 0
        case .denied: nil
        case .pickApps: 1 / 3
        case .setLimits: 2 / 3
        case .notifications: 1
        }
    }

    private func finishSetup() {
        // TODO: save selection + limits to the App Group so the intervention extensions can read them
        withAnimation {
            hasCompletedSetup = true
        }
    }
}

#Preview {
    SetupView()
}
