import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ScrollCheckInAnswer: Equatable {
    public let choices: [String]
    public let note: String
}

public struct ScrollCheckInAnswers: Equatable {
    public let reason: ScrollCheckInAnswer
    public let feeling: ScrollCheckInAnswer
    public let nextStep: ScrollCheckInAnswer
}

@MainActor
public struct ScrollCheckInView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveAnswers: ((ScrollCheckInAnswers) -> Void)?
    private let introImageName: String

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveAnswers: ((ScrollCheckInAnswers) -> Void)? = nil,
        introImageName: String = "reflect-scroll-intro"
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveAnswers = onSaveAnswers
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, questions, complete }
    private enum ResponseMode: String { case choices, journal }
    private struct Draft: Codable, Equatable {
        let step: Int
        let selections: [[String]]
        let notes: [String]
        let modes: [String]
    }
    private struct Question {
        let prompt: String
        let choices: [String]
    }
    private let questions = [
        Question(
            prompt: "What brought you to your phone?",
            choices: ["Boredom", "Habit", "Avoiding something", "Wanting connection", "Looking for something", "Not sure"]
        ),
        Question(
            prompt: "How is scrolling feeling right now?",
            choices: ["Enjoyable", "Just passing time", "Hard to stop", "Leaving me drained", "Not sure"]
        ),
        Question(
            prompt: "What would feel good next?",
            choices: ["Keep scrolling, intentionally", "Take a little break", "Return to something", "Reach out to someone"]
        )
    ]

    @State private var screen: Screen = .instructions
    @State private var step = 0
    @State private var selections: [Set<String>] = [[], [], []]
    @State private var notes = ["", "", ""]
    @State private var responseModes: [ResponseMode] = [.choices, .choices, .choices]
    @FocusState private var writing: Bool
    @Environment(\.activityDraftHostArchives) private var hostArchivesDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var stepMarkerSize: CGFloat = 28
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDiscardConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var draftStore = ActivityDraftStore<Draft>(activityID: "scroll-check-in")
    @State private var draftExitAction: ActivityDraftExitAction?
    @State private var didRestoreDraft = false
    @State private var draftSessionEnded = false

    // Reflect: #F4B7D7
    private var pink: Color {
        colorScheme == .dark
            ? Color(red: 0.50, green: 0.25, blue: 0.39)
            : Color(red: 244 / 255, green: 183 / 255, blue: 215 / 255)
    }
    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.76, blue: 0.86)
            : Color(red: 0.51, green: 0.29, blue: 0.40)
    }
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
    private var current: Question { questions[step] }

    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 190
    private var surface: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        colorScheme == .dark ? .black : .white
        #endif
    }
    private var paperColor: Color {
        colorScheme == .dark ? Color(red: 0.17, green: 0.14, blue: 0.16) : Color(red: 1, green: 0.99, blue: 0.97)
    }
    private var hasUnsavedWriting: Bool {
        screen != .complete && (hasDraftContent || draftStore.hasDraft)
    }
    private var hasDraftContent: Bool {
        selections.contains { !$0.isEmpty }
            || notes.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var draftSnapshot: Draft {
        Draft(step: step,
              selections: selections.map { $0.sorted() },
              notes: notes,
              modes: responseModes.map(\.rawValue))
    }

    public var body: some View {
        NavigationStack {
            activityContent
                .navigationTitle("")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(screen == .complete ? .hidden : .visible, for: .navigationBar)
                #endif
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
                    if screen != .complete {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: requestClose) {
                                Label("Close activity", systemImage: "xmark")
                                    .labelStyle(.iconOnly)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.automatic)
                        }
                        ToolbarItem(placement: .principal) {
                            if screen != .instructions { badge }
                        }
                    }
                }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ActivityDraftNotice(store: draftStore,
                                retryTitle: draftExitAction?.retryTitle ?? "Try again",
                                onRetry: retryDraftAction)
        }
        .onAppear(perform: restoreDraft)
        .onChange(of: draftSnapshot) { _, _ in _ = persistDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { _ = persistDraft() }
        }
        .onDisappear { _ = persistDraft() }
        .confirmationDialog("Keep this for later?", isPresented: $showsDiscardConfirmation,
                            titleVisibility: .visible) {
            Button("Save draft and close", action: saveDraftAndClose)
            Button("Keep writing", role: .cancel) { }
            Button("Discard draft", role: .destructive, action: discardDraftAndClose)
        } message: {
            Text("Your draft stays on this device until you finish or discard it.")
        }
        .interactiveDismissDisabled(hasUnsavedWriting)
    }

    private var activityContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .questions:
                        questionPage.frame(minHeight: max(0, geometry.size.height - 12))
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
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var badge: some View {
        Label("Reflect", systemImage: "heart.text.square")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(pink, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollCheckInArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(pink.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("At your pace", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Scroll Check-In")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            instruction(number: "1", text: "Pause and check in with yourself")
            instruction(number: "2", text: "Choose what fits, or write instead.")

            Spacer(minLength: 36)
            if draftStore.hasDraft {
                Text("Your draft is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            pinkButton(draftStore.hasDraft ? "Resume" : "Start") {
                draftSessionEnded = false
                if draftStore.hasDraft, let saved = draftStore.restore() {
                    applySavedDraft(saved)
                } else {
                    step = 0
                    resetAnswers()
                }
                screen = .questions
            }
            Button("Pick something else", action: requestClose)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.footnote)
                .frame(width: stepMarkerSize, height: stepMarkerSize)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var questionPage: some View {
        VStack(spacing: 18) {
            Text("A moment for you")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            Text(current.prompt)
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            Text(responseModes[step] == .choices ? "Choose any that fit." : "Say it in your own words.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("\(step + 1) of 3")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            if responseModes[step] == .choices {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(current.choices, id: \.self) { choice in
                        choiceCard(choice)
                    }
                }
            } else {
                journalEditor
            }

            Button {
                writing = false
                responseModes[step] = responseModes[step] == .choices ? .journal : .choices
            } label: {
                Label(
                    responseModes[step] == .choices ? "Write instead" : "Choose instead",
                    systemImage: responseModes[step] == .choices ? "pencil" : "square.grid.2x2"
                )
                .font(.custom("ComingSoon-Regular", size: 18, relativeTo: .body))
                .frame(minHeight: 44)
            }

            Spacer(minLength: 12)

            pinkButton(step == questions.count - 1 ? "Finish" : "Continue", action: advance)
                .disabled(!hasAnswer(step))
                .opacity(hasAnswer(step) ? 1 : 0.45)

            if step > 0 {
                Button("Back") {
                    writing = false
                    step -= 1
                }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Color.clear.frame(height: 44)
            }
        }
    }

    private func choiceCard(_ choice: String) -> some View {
        let selected = selections[step].contains(choice)
        return Button {
            if selected {
                selections[step].remove(choice)
            } else {
                selections[step].insert(choice)
            }
        } label: {
            HStack(spacing: 8) {
                Text(choice)
                    .font(.custom("ComingSoon-Regular", size: 18, relativeTo: .body))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.light))
                    .foregroundStyle(selected ? ink : ink.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(selected ? pink.opacity(0.75) : pink.opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? ink.opacity(0.55) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(choice)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selected)
    }

    private var journalEditor: some View {
        ZStack(alignment: .topLeading) {
            if notes[step].isEmpty {
                Text("Whatever’s on your mind…")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $notes[step])
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($writing)
                .frame(height: editorHeight)
                .accessibilityLabel("Your thoughts: \(current.prompt)")
        }
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(paperColor)
                .overlay {
                    ScrollCheckInPaperRules()
                        .stroke(pink.opacity(0.45), lineWidth: 0.7)
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(pink.opacity(0.65))
                        .frame(width: 1)
                        .padding(.leading, 17)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            ScrollCheckInArtwork(name: "reflect-scroll-complete")
                .frame(width: 180, height: 200)
                .background {
                    Circle().fill(pink.opacity(0.3)).frame(width: 166, height: 166)
                }

            Text("A little more aware.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
            Text("You don’t have to change anything right now.\nNoticing is a start.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Label("+10 pts", systemImage: "star.fill")
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(pink, in: Capsule())

            Spacer(minLength: 60)
            pinkButton("Back home", action: close)
        }
        .frame(maxWidth: .infinity)
    }

    private func pinkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(pink, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func hasAnswer(_ index: Int) -> Bool {
        switch responseModes[index] {
        case .choices:
            return !selections[index].isEmpty
        case .journal:
            return !notes[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func answer(_ index: Int) -> ScrollCheckInAnswer {
        // Keep inactive drafts locally, but submit only the chosen response mode.
        switch responseModes[index] {
        case .choices:
            return ScrollCheckInAnswer(
                choices: questions[index].choices.filter { selections[index].contains($0) },
                note: ""
            )
        case .journal:
            return ScrollCheckInAnswer(
                choices: [],
                note: notes[index].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func advance() {
        guard screen == .questions, hasAnswer(step) else { return }
        writing = false
        if step < questions.count - 1 {
            step += 1
        } else {
            guard questions.indices.allSatisfy({ hasAnswer($0) }) else { return }
            guard (hostArchivesDraft ? persistDraft() : draftStore.discard()) else {
                draftExitAction = .complete
                return
            }
            draftSessionEnded = true
            screen = .complete
            onSaveAnswers?(ScrollCheckInAnswers(reason: answer(0), feeling: answer(1), nextStep: answer(2)))
            // Choice and journal responses receive the same reward.
            onComplete(10)
        }
    }

    private func resetAnswers() {
        selections = [[], [], []]
        notes = ["", "", ""]
        responseModes = [.choices, .choices, .choices]
        writing = false
    }

    private func restoreDraft() {
        guard !didRestoreDraft else { return }
        defer { didRestoreDraft = true }
        guard let saved = draftStore.restore() else { return }
        applySavedDraft(saved)
    }

    private func applySavedDraft(_ saved: Draft) {
        step = min(max(0, saved.step), questions.count - 1)
        selections = questions.indices.map { index in
            guard saved.selections.indices.contains(index) else { return [] }
            return Set(saved.selections[index]).intersection(questions[index].choices)
        }
        notes = questions.indices.map { saved.notes.indices.contains($0) ? saved.notes[$0] : "" }
        responseModes = questions.indices.map { index in
            guard saved.modes.indices.contains(index) else { return .choices }
            return ResponseMode(rawValue: saved.modes[index]) ?? .choices
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard didRestoreDraft, !draftSessionEnded, screen == .questions else { return true }
        let saved = hasDraftContent ? draftStore.save(draftSnapshot) : draftStore.clearEmptyDraft()
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
        case .some(.complete): advance()
        case .none: draftStore.retryLastOperation()
        }
    }

    private func discardDraftAndClose() {
        guard draftStore.discard() else { draftExitAction = .discardAndClose; return }
        close()
    }

    private func requestClose() {
        writing = false
        if hasUnsavedWriting { showsDiscardConfirmation = true }
        else { close() }
    }

    private func close() {
        draftExitAction = nil
        draftSessionEnded = true
        writing = false
        if let onClose {
            onClose()
        } else {
            dismiss()
            step = 0
            resetAnswers()
            screen = .instructions
        }
    }
}

private struct ScrollCheckInPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 45
        while y < rect.height - 8 {
            path.move(to: CGPoint(x: 22, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 12, y: y))
            y += 34
        }
        return path
    }
}

private struct ScrollCheckInArtwork: View {
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
                    .foregroundStyle(.gray.opacity(0.45))
                    .padding(20)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ScrollCheckInView()
}
