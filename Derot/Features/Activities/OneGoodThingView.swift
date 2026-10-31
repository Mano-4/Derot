import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
public struct OneGoodThingView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveEntry: ((String) -> Void)?
    private let introImageName: String

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveEntry: ((String) -> Void)? = nil,
        introImageName: String = "notice-good-intro"
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveEntry = onSaveEntry
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, journal, complete }
    private struct Draft: Codable, Equatable {
        let entry: String
    }
    @StateObject private var draftStore = ActivityDraftStore<Draft>(activityID: "one-good-thing")
    @State private var draftExitAction: ActivityDraftExitAction?
    @State private var didRestoreDraft = false
    @State private var draftSessionEnded = false
    @State private var screen: Screen = .instructions
    @State private var entry = ""
    @State private var showDiscardPrompt = false
    @ScaledMetric(relativeTo: .body) private var journalHeight: CGFloat = 320
    @FocusState private var writing: Bool
    @Environment(\.activityDraftHostArchives) private var hostArchivesDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption) private var numberBadgeSize: CGFloat = 28

    private var yellow: Color {
        colorScheme == .dark
            ? Color(red: 0.38, green: 0.35, blue: 0.12)
            : Color(red: 250 / 255, green: 235 / 255, blue: 107 / 255)
    }
    private var surface: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        colorScheme == .dark ? .black : .white
        #endif
    }
    private var paperFill: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.135, blue: 0.095)
            : Color(red: 1, green: 0.99, blue: 0.95)
    }
    private var trimmedEntry: String {
        entry.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .journal:
                        journal
                    case .complete:
                        completion.frame(minHeight: max(0, geometry.size.height - 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(surface.ignoresSafeArea())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .toolbar {
            #if os(iOS)
            if writing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { writing = false }
                        .fontWeight(.semibold)
                        .buttonStyle(.automatic)
                }
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                if screen != .complete {
                    Button(action: requestClose) {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Close activity")
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(screen == .complete ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .interactiveDismissDisabled(screen != .complete && !trimmedEntry.isEmpty)
        .confirmationDialog("Keep this for later?", isPresented: $showDiscardPrompt,
                            titleVisibility: .visible) {
            Button("Save draft and close", action: saveDraftAndClose)
            Button("Discard draft", role: .destructive, action: discardDraftAndClose)
            Button("Keep writing", role: .cancel) {}
        } message: {
            Text("Your draft stays on this device until you finish or discard it.")
        }
        }
        .safeAreaInset(edge: .top, spacing: 0) { ActivityDraftNotice(store: draftStore,
                                retryTitle: draftExitAction?.retryTitle ?? "Try again",
                                onRetry: retryDraftAction) }
        .onAppear(perform: restoreDraft)
        .onChange(of: entry) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistDraft() }
        }
        .onDisappear { persistDraft() }
    }

    private var badge: some View {
        Label("Notice", systemImage: "eye")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(yellow, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            GoodThingArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("At your pace", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("One good thing")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            instruction(number: "1", text: "Think of something good, big or small")
            instruction(number: "2", text: "Write a little about it, in your own words")

            Spacer(minLength: 36)
            if draftStore.hasDraft {
                Text("Your draft is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            yellowButton(draftStore.hasDraft ? "Resume" : "Start") {
                draftSessionEnded = false
                if draftStore.hasDraft, let saved = draftStore.restore() {
                    entry = saved.entry
                } else { entry = "" }
                screen = .journal
            }
            Button("Pick something else", action: requestClose)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .frame(width: numberBadgeSize, height: numberBadgeSize)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text).font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 20) {
            badge
            Text("One good thing")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            Text("What’s one good thing you’d like to remember?")
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))

            Text("A kind interaction, a small win, or something you’re glad is in your life.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("A little good")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 5)

                ZStack(alignment: .topLeading) {
                    if entry.isEmpty {
                        Text("It can be something small…")
                            .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $entry)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .lineSpacing(8)
                        .scrollContentBackground(.hidden)
                        .focused($writing)
                        .frame(height: journalHeight)
                        .accessibilityLabel("Your one good thing")
                }
            }
            .padding(.leading, 28)
            .padding(.trailing, 18)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(paperFill)
                    .overlay {
                        GoodThingPaperRules()
                            .stroke(Color(red: 0.70, green: 0.78, blue: 0.86).opacity(0.3), lineWidth: 0.7)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.pink.opacity(0.18))
                            .frame(width: 1)
                            .padding(.leading, 18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }

            Text("A few words are enough. More is welcome, too.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            yellowButton("Finish", action: finish)
                .disabled(trimmedEntry.isEmpty)
                .opacity(trimmedEntry.isEmpty ? 0.45 : 1)
        }
        .padding(.top, 10)
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)

            ZStack {
                Circle()
                    .fill(yellow.opacity(0.22))
                    .frame(width: 166, height: 166)
                GoodThingArtwork(name: "notice-good-listening")
                    .frame(width: 170, height: 190)
                Image(systemName: "heart")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color(red: 0.83, green: 0.60, blue: 0.24))
                    .rotationEffect(.degrees(12))
                    .offset(x: 85, y: -62)
                Image(systemName: "heart")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color(red: 0.83, green: 0.60, blue: 0.24).opacity(0.65))
                    .rotationEffect(.degrees(-15))
                    .offset(x: -82, y: -42)
            }
            .frame(height: 220)

            Text("That matters.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
            Text("Thank you for sharing your good thing.\nBig or small, it deserves to be remembered.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Label("+10 pts", systemImage: "star.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(yellow, in: Capsule())

            Spacer(minLength: 60)
            yellowButton("Back home", action: close)
        }
        .frame(maxWidth: .infinity)
    }

    private func yellowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func finish() {
        guard screen == .journal, !trimmedEntry.isEmpty else { return }
        guard (hostArchivesDraft ? persistDraft() : draftStore.discard()) else {
            draftExitAction = .complete
            return
        }
        draftSessionEnded = true
        writing = false
        let finishedEntry = trimmedEntry
        screen = .complete
        onSaveEntry?(finishedEntry)
        onComplete(10)
    }

    private func requestClose() {
        writing = false
        if screen != .complete, !trimmedEntry.isEmpty || draftStore.hasDraft {
            showDiscardPrompt = true
        } else {
            close()
        }
    }

    private func close() {
        draftExitAction = nil
        draftSessionEnded = true
        writing = false
        if let onClose {
            onClose()
        } else {
            dismiss()
            entry = ""
            screen = .instructions
        }
    }

    private func restoreDraft() {
        guard !didRestoreDraft else { return }
        didRestoreDraft = true
        if let saved = draftStore.restore() { entry = saved.entry }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard didRestoreDraft, !draftSessionEnded, screen == .journal else { return true }
        let saved = trimmedEntry.isEmpty ? draftStore.clearEmptyDraft() : draftStore.save(Draft(entry: entry))
        if saved { draftExitAction = nil }
        return saved
    }

    private func saveDraftAndClose() {
        guard persistDraft() else { draftExitAction = .saveAndClose; return }
        close()
    }

    private func retryDraftAction() {
        switch draftExitAction {
        case .some(.saveAndClose): saveDraftAndClose()
        case .some(.discardAndClose): discardDraftAndClose()
        case .some(.complete): finish()
        case .none: draftStore.retryLastOperation()
        }
    }

    private func discardDraftAndClose() {
        guard draftStore.discard() else { draftExitAction = .discardAndClose; return }
        close()
    }
}

private struct GoodThingPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 75
        while y < rect.height - 12 {
            path.move(to: CGPoint(x: 24, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 12, y: y))
            y += 36
        }
        return path
    }
}

private struct GoodThingArtwork: View {
    let name: String

    private var exists: Bool {
        #if os(iOS)
        UIImage(named: name) != nil
        #elseif canImport(AppKit)
        NSImage(named: name) != nil
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if exists {
                Image(name).resizable().scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    OneGoodThingView()
}
