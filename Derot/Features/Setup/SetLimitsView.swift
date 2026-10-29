//
//  SetLimitsView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI
import FamilyControls
import ManagedSettings

struct SetLimitsView: View {
    let selection: FamilyActivitySelection
    @Binding var appLimits: [ApplicationToken: Int]
    @Binding var categoryLimits: [ActivityCategoryToken: Int]
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let defaultMinutes = 30
    /// Every limit the user can choose: 15m, 30m, 45m … 4h
    private let limitOptions = Array(stride(from: 15, through: 240, by: 15))

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How much time feels right each day?")
                    .font(.custom("ComingSoon-Regular", size: 30, relativeTo: .title))

                Text("Set a limit for each one. You can change it later.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            List {
                // Group passes listRowBackground down to every row inside it
                Group {
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        limitRow(minutes: Binding(
                            get: { categoryLimits[token] ?? defaultMinutes },
                            set: { categoryLimits[token] = $0 }
                        )) {
                            Label(token)
                        }
                    }
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        limitRow(minutes: Binding(
                            get: { appLimits[token] ?? defaultMinutes },
                            set: { appLimits[token] = $0 }
                        )) {
                            Label(token)
                        }
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
            .font(.system(.body, design: .rounded))

            VStack(spacing: 8) {
                PrimaryButton(title: "Continue", action: onContinue)

                Button("Skip for now", action: onSkip)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .onAppear(perform: syncLimitsWithSelection)
    }

    private func limitRow(minutes: Binding<Int>, @ViewBuilder label: () -> some View) -> some View {
        Stepper(value: minutes, in: 15...240, step: 15) {
            HStack {
                label()
                Spacer()
                // Tapping the time opens a list of every option, for big jumps (e.g. 30m → 2h)
                Menu {
                    Picker("Daily limit", selection: minutes) {
                        ForEach(limitOptions, id: \.self) { option in
                            Text(formatted(option)).tag(option)
                        }
                    }
                } label: {
                    Text(formatted(minutes.wrappedValue))
                        .monospacedDigit()
                }
            }
        }
    }

    private func formatted(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    /// Gives every picked app/category a starting limit, and drops ones the user un-picked.
    /// The `?? defaultMinutes` in the rows only shows 30; it doesn't save it until the user taps the stepper.
    private func syncLimitsWithSelection() {
        appLimits = appLimits.filter { selection.applicationTokens.contains($0.key) }
        categoryLimits = categoryLimits.filter { selection.categoryTokens.contains($0.key) }

        for token in selection.applicationTokens where appLimits[token] == nil {
            appLimits[token] = defaultMinutes
        }
        for token in selection.categoryTokens where categoryLimits[token] == nil {
            categoryLimits[token] = defaultMinutes
        }
    }
}

#Preview {
    SetLimitsView(
        selection: FamilyActivitySelection(),
        appLimits: .constant([:]),
        categoryLimits: .constant([:]),
        onContinue: { },
        onSkip: { }
    )
}
