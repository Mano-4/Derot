import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct FeelingJournalEntry: Equatable {
    public let rightNow: String
    public let onMyMind: String
    public let noticeMost: String
    public let wishCouldSay: String
    public let more: String
    public let feelingName: String?
}

@MainActor
public struct NameYourFeelingView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveEntry: ((FeelingJournalEntry) -> Void)?
    private let introImageName: String

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveEntry: ((FeelingJournalEntry) -> Void)? = nil,
        introImageName: String = "reflect-feeling-intro"
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveEntry = onSaveEntry
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, journal, name, complete }
    private struct Draft: Codable, Equatable {
        let responses: [String]
        let more: String
        let moreExpanded: Bool
        let feelingName: String
        let isNaming: Bool
    }
    private let starters = [
        "Right now, I feel…",
        "Something that’s been on my mind is…",
        "I notice this feeling most when…",
        "What I wish I could say is…"
    ]

    @StateObject private var draftStore = ActivityDraftStore<Draft>(activityID: "name-your-feeling")
    @State private var draftExitAction: ActivityDraftExitAction?
    @State private var resumeScreen: Screen = .journal
    @State private var draftLoaded = false
    @State private var sessionEnded = false
    @State private var screen: Screen = .instructions
    @State private var responses = ["", "", "", ""]
    @State private var more = ""
    @State private var moreExpanded = false
    @State private var feelingName = ""
    @FocusState private var focusedField: Int?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.activityDraftHostArchives) private var hostArchivesDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var stepMarkerSize: CGFloat = 28
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDiscardConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    private var cleanName: String {
        feelingName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        colorScheme == .dark ? Color(red: 0.17, green: 0.14, blue: 0.16) : Color(red: 1, green: 0.99, blue: 0.98)
    }
    private var hasUnsavedWriting: Bool {
        screen != .complete && (responses.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !more.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !cleanName.isEmpty)
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
                    if focusedField != nil {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focusedField = nil }
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
        .confirmationDialog("Keep this for later?", isPresented: $showsDiscardConfirmation,
                            titleVisibility: .visible) {
            Button("Save draft and close", action: saveDraftAndClose)
            Button("Discard draft", role: .destructive, action: discardDraftAndClose)
            Button("Keep writing", role: .cancel) { }
        } message: {
            Text("Your draft stays on this device until you finish or discard it.")
        }
        .interactiveDismissDisabled(hasUnsavedWriting || draftStore.hasDraft)
        .safeAreaInset(edge: .top, spacing: 0) {
            ActivityDraftNotice(store: draftStore,
                                retryTitle: draftExitAction?.retryTitle ?? "Try again",
                                onRetry: retryDraftAction)
        }
        .onAppear(perform: restoreDraft)
        .onChange(of: draftSnapshot) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistDraft() }
        }
        .onDisappear { persistDraft() }
    }

    private var activityContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .journal:
                        journal.padding(.top, 12)
                    case .name:
                        naming.frame(minHeight: max(0, geometry.size.height - 12))
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
            FeelingArtwork(name: introImageName)
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

            Text("Name Your Feeling")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
            instruction(number: "1", text: "Finish any sentence that speaks to you")
            instruction(number: "2", text: "Share more, or give the feeling a name")

            Spacer(minLength: 36)
            if draftStore.hasDraft {
                Text("Your draft is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            pinkButton(draftStore.hasDraft ? "Resume" : "Start") {
                sessionEnded = false
                if draftStore.hasDraft, let saved = draftStore.restore() {
                    applySavedDraft(saved)
                    screen = resumeScreen
                } else {
                    reset()
                    screen = .journal
                }
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

    private var journal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Start wherever you like.")
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(starters.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(starters[index])
                            .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("", text: $responses[index], axis: .vertical)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .textFieldStyle(.plain)
                            .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                            .lineLimit(1...6)
                            .focused($focusedField, equals: index)
                            .accessibilityLabel(starters[index])
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)

                        Rectangle()
                            .fill(pink.opacity(focusedField == index ? 0.9 : 0.4))
                            .frame(height: 1)
                            .allowsHitTesting(false)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded { focusedField = index }
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(paperColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pink.opacity(0.16), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
            }

            Button {
                moreExpanded.toggle()
                if !moreExpanded, focusedField == 4 { focusedField = nil }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.light))
                    Text("There’s more on my mind…")
                    Spacer()
                    Image(systemName: moreExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            }
            .accessibilityLabel(moreExpanded ? "Collapse extra writing" : "Share more")
            .accessibilityValue(more.isEmpty ? "" : "Contains your writing")

            if moreExpanded {
                extraWriting
            }

            pinkButton("Continue") {
                focusedField = nil
                screen = .name
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: moreExpanded)
    }

    private var extraWriting: some View {
        ZStack(alignment: .topLeading) {
            if more.isEmpty {
                Text("There’s room for more here…")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $more)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: 4)
                .frame(height: editorHeight)
                .accessibilityLabel("Anything else on your mind")
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .background { paper }
    }

    private var naming: some View {
        VStack(spacing: 20) {
            Text("Give it a name")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .padding(.top, 18)
            Text("Only if you’d like.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            TextField("A word, or a name of your own…", text: $feelingName, axis: .vertical)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .lineLimit(2...5)
                .focused($focusedField, equals: 5)
                .accessibilityLabel("An optional name for this feeling")
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .background { paper }

            Text("It doesn’t have to be the perfect word.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 24)
            pinkButton("Finish", action: finish)
            Button("Back to my words") {
                focusedField = nil
                screen = .journal
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var paper: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(paperColor)
            .overlay {
                FeelingPaperRules().stroke(pink.opacity(0.35), lineWidth: 0.7)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(pink.opacity(0.6))
                    .frame(width: 1)
                    .padding(.leading, 17)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.045), radius: 7, y: 3)
            .allowsHitTesting(false)
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)

            FeelingArtwork(name: "reflect-feeling-complete")
                .frame(width: 170, height: 190)
                .background {
                    Circle().fill(pink.opacity(0.28)).frame(width: 166, height: 166)
                }

            if !cleanName.isEmpty {
                Text(cleanName)
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(pink.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("You named this feeling \(cleanName)")
            }

            Text("There’s room for this, too.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
            Text("You don’t have to explain it perfectly\nfor it to matter.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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

    private func finish() {
        guard screen == .name else { return }
        guard (hostArchivesDraft ? persistDraft() : draftStore.discard()) else {
            draftExitAction = .complete
            return
        }
        sessionEnded = true
        focusedField = nil
        let cleaned = responses.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let savedEntry = FeelingJournalEntry(
            rightNow: cleaned[0],
            onMyMind: cleaned[1],
            noticeMost: cleaned[2],
            wishCouldSay: cleaned[3],
            more: more.trimmingCharacters(in: .whitespacesAndNewlines),
            feelingName: cleanName.isEmpty ? nil : cleanName
        )
        screen = .complete
        onSaveEntry?(savedEntry)
        onComplete(10)
    }

    private func reset() {
        responses = ["", "", "", ""]
        more = ""
        moreExpanded = false
        feelingName = ""
        focusedField = nil
    }

    private func requestClose() {
        focusedField = nil
        if screen != .complete && (hasUnsavedWriting || draftStore.hasDraft) {
            showsDiscardConfirmation = true
        } else {
            close()
        }
    }

    private var draftSnapshot: Draft {
        Draft(responses: responses, more: more, moreExpanded: moreExpanded,
              feelingName: feelingName, isNaming: screen == .name)
    }

    private func restoreDraft() {
        guard !draftLoaded else { return }
        draftLoaded = true
        guard let saved = draftStore.restore() else { return }
        applySavedDraft(saved)
    }

    private func applySavedDraft(_ saved: Draft) {
        responses = Array((saved.responses + Array(repeating: "", count: starters.count)).prefix(starters.count))
        more = saved.more
        moreExpanded = saved.moreExpanded || !saved.more.isEmpty
        feelingName = saved.feelingName
        resumeScreen = saved.isNaming ? .name : .journal
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard draftLoaded, !sessionEnded, screen != .complete else { return true }
        // Merely opening the welcome page must not replace a restored draft.
        guard screen != .instructions else { return true }
        let saved = hasUnsavedWriting ? draftStore.save(draftSnapshot) : draftStore.clearEmptyDraft()
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

    private func close() {
        draftExitAction = nil
        sessionEnded = true
        focusedField = nil
        if let onClose {
            onClose()
        } else {
            dismiss()
            resumeScreen = screen == .name ? .name : .journal
            if !draftStore.hasDraft { reset() }
            screen = .instructions
        }
    }
}

private struct FeelingPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 52
        while y < rect.height - 8 {
            path.move(to: CGPoint(x: 23, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 14, y: y))
            y += 34
        }
        return path
    }
}

private struct FeelingArtwork: View {
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
    NameYourFeelingView()
}
