//
//  PickAppsView.swift
//  Derot
//
//  Created by Taraf Aldriweesh on 28/10/2026.
//

import SwiftUI
import FamilyControls

struct PickAppsView: View {
    @Binding var selection: FamilyActivitySelection
    let onNext: () -> Void

    @State private var isPickerPresented = false

    private var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which apps should Mr. Rabbit keep an eye on?")
                .font(.custom("ComingSoon-Regular", size: 30, relativeTo: .title))
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // Negative spacing tucks the bunny's bottom behind the card.
            // The List comes after the bunny, so it's drawn on top of it.
            VStack(alignment: .trailing, spacing: -16) {
                Image("wonderingbunny")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .padding(.trailing, 32)
                    .accessibilityHidden(true)

                appList
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                PrimaryButton(title: hasSelection ? "Continue" : "Choose apps") {
                    if hasSelection {
                        onNext()
                    } else {
                        isPickerPresented = true
                    }
                }

                if hasSelection {
                    Button("Change apps") {
                        isPickerPresented = true
                    }
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
    }

    private var appList: some View {
        List {
            Section {
                // Group passes listRowBackground down to every row inside it
                Group {
                    if hasSelection {
                        // Apple only gives us tokens, not app names. Label(token) asks iOS to draw the icon + name.
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                        }
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                        }
                    } else {
                        Text("No apps picked yet")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))
            } footer: {
                if hasSelection {
                    selectionSummary
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Removes the List's built-in top gap so the card starts right under the bunny
        .contentMargins(.top, 0, for: .scrollContent)
        .font(.system(.body, design: .rounded))
    }

    /// "3 apps", "1 category", or "3 apps, 1 category".
    /// `^[...](inflect: true)` makes iOS pick "app"/"apps" and "category"/"categories" for us.
    @ViewBuilder
    private var selectionSummary: some View {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count

        if categories == 0 {
            Text("^[\(apps) app](inflect: true)")
        } else if apps == 0 {
            Text("^[\(categories) category](inflect: true)")
        } else {
            Text("^[\(apps) app](inflect: true), ^[\(categories) category](inflect: true)")
        }
    }
}

#Preview {
    PickAppsView(selection: .constant(FamilyActivitySelection())) { }
}
