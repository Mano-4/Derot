import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
public struct LittleThingsKeptView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveThings: (([String]) -> Void)?
    private let preferredAccent: Color
    private let introImageName: String

    public init(
        accentColor: Color = Color(red: 244 / 255, green: 183 / 255, blue: 215 / 255),
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveThings: (([String]) -> Void)? = nil,
        introImageName: String = "three-good-things-intro"
    ) {
        preferredAccent = accentColor
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveThings = onSaveThings
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, collecting, complete }
    private struct Draft: Codable, Equatable {
        let things: [String]
        let words: String
    }
    private enum FoldPhase: Int { case flat, square, firstCrease, secondCrease, origami, mouth, landed }
    private struct FoldJob: Identifiable {
        let id = UUID()
        let words: String
        let index: Int
        let finishAfterLanding: Bool
    }
    private struct OpenedThing: Identifiable {
        let id: Int
        let words: String
    }

    @StateObject private var draftStore = ActivityDraftStore<Draft>(activityID: "little-things-kept")
    @State private var draftExitAction: ActivityDraftExitAction?
    @State private var draftLoaded = false
    @State private var sessionEnded = false
    @State private var screen: Screen = .instructions
    @State private var things: [String] = []
    @State private var draft = ""
    @State private var pendingFold: FoldJob?
    @State private var foldPhase: FoldPhase = .flat
    @State private var openedThing: OpenedThing?
    @FocusState private var writing: Bool
    @Environment(\.activityDraftHostArchives) private var hostArchivesDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var stepMarkerSize: CGFloat = 28
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDiscardConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let maximumThings = 10
    private var isFolding: Bool { pendingFold != nil }
    private var cleanDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasContent: Bool { !things.isEmpty || !cleanDraft.isEmpty }
    private let colors: [Color] = [
        Color(red: 0.93, green: 0.65, blue: 0.68),
        Color(red: 0.67, green: 0.68, blue: 0.89),
        Color(red: 0.91, green: 0.72, blue: 0.40),
        Color(red: 0.54, green: 0.74, blue: 0.66),
        Color(red: 0.56, green: 0.73, blue: 0.87)
    ]

    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 84
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
        colorScheme == .dark ? Color(red: 0.17, green: 0.14, blue: 0.16) : Color(red: 1, green: 0.98, blue: 0.95)
    }
    private var accent: Color {
        colorScheme == .dark ? preferredAccent.opacity(0.55) : preferredAccent
    }
    private var badge: some View {
        Label("Reflect", systemImage: "heart.text.square")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(accent, in: RoundedRectangle(cornerRadius: 6))
    }
    private var hasUnsavedWriting: Bool {
        screen != .complete && hasContent
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
    }

    private var activityContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .collecting:
                        collecting
                    case .complete:
                        completion.frame(minHeight: max(0, geometry.size.height - 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollDisabled(isFolding)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if screen == .collecting {
                VStack(spacing: 4) {
                    primaryButton(isFolding ? "Folding…" : "Done", action: finish)
                        .disabled(!hasContent || isFolding)
                        .opacity(hasContent ? 1 : 0.45)

                    if !hasContent && !isFolding {
                        Button("Skip for now", action: requestClose)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(surface)
            }
        }
        .background(surface.ignoresSafeArea())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .task(id: pendingFold?.id) {
            guard let job = pendingFold else { return }
            await animateFold(job)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelFold()
                persistDraft()
            }
        }
        .onDisappear {
            cancelFold()
            persistDraft()
        }
        .sheet(item: $openedThing) { thing in
            VStack(spacing: 20) {
                OrigamiKeepsake(kind: thing.id % 5, color: colors[thing.id % colors.count])
                    .frame(width: 54, height: 48)
                    .padding(.top, 18)
                Text("A moment you kept")
                    .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                ScrollView {
                    Text(thing.words)
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                primaryButton("Close") { openedThing = nil }
            }
            .padding(20)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            GoodThingsArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(accent.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            Label("At your pace", systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Text("Little Things, Kept")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
            instruction("1", "Think of something you’re glad is in your day or life")
            instruction("2", "Fold it into a keepsake. Gather up to ten.")
            Spacer(minLength: 36)
            if draftStore.hasDraft {
                Text("Your draft is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            primaryButton(draftStore.hasDraft ? "Resume" : "Start") {
                sessionEnded = false
                cancelFold()
                if draftStore.hasDraft, let saved = draftStore.restore() {
                    applySavedDraft(saved)
                } else {
                    things = []
                    draft = ""
                }
                screen = .collecting
            }
            Button("Pick something else", action: requestClose)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(_ number: String, _ text: String) -> some View {
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

    private var collecting: some View {
        VStack(spacing: 14) {
            Text("Little Things, Kept")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .padding(.top, 6)

            if things.count < maximumThings {
                Text("What’s something you’re glad to have?")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)

                writingNote
                    .anchorPreference(key: KeepsakeAnchors.self, value: .bounds) { ["note": $0] }
                    .opacity(isFolding ? 0 : 1)

                primaryButton(isFolding ? "Folding…" : "Fold & keep") {
                    beginFold(finishAfterLanding: false)
                }
                .disabled(cleanDraft.isEmpty || isFolding)
                .opacity(cleanDraft.isEmpty && !isFolding ? 0.45 : 1)
            } else {
                Text("Your jar is full.")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .foregroundStyle(.secondary)
            }

            jarDisplay
                .anchorPreference(key: KeepsakeAnchors.self, value: .bounds) { ["jar": $0] }

        }
        .overlayPreferenceValue(KeepsakeAnchors.self) { anchors in
            GeometryReader { geometry in
                if let job = pendingFold,
                   let noteAnchor = anchors["note"],
                   let jarAnchor = anchors["jar"] {
                    let note = geometry[noteAnchor]
                    let jar = geometry[jarAnchor]
                    let target = keepsakePosition(job.index)
                    let position: CGPoint = {
                        switch foldPhase {
                        case .flat, .square, .firstCrease, .secondCrease, .origami:
                            return CGPoint(x: note.midX, y: note.midY)
                        case .mouth:
                            return CGPoint(x: jar.midX, y: jar.minY + 38)
                        case .landed:
                            return CGPoint(x: jar.midX - 125 + target.x, y: jar.minY + target.y)
                        }
                    }()
                    FoldingKeepsake(
                        color: colors[job.index % colors.count],
                        kind: job.index % 5,
                        phase: foldPhase.rawValue,
                        words: job.words
                    )
                    .frame(width: foldPhase == .flat ? note.width : flightSize,
                           height: foldPhase == .flat ? note.height : flightSize)
                    .rotationEffect(.degrees(foldPhase == .landed ? (job.index.isMultiple(of: 2) ? -6 : 6) : 0))
                    .position(position)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private var flightSize: CGFloat {
        switch foldPhase {
        case .flat, .square, .firstCrease: 118
        case .secondCrease: 102
        case .origami: 78
        case .mouth: 50
        case .landed: 40
        }
    }

    private var writingNote: some View {
        ZStack(alignment: .topLeading) {
            if draft.isEmpty {
                Text("A person, a moment, something small…")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .scrollContentBackground(.hidden)
                .focused($writing)
                .frame(height: editorHeight)
                .disabled(isFolding)
                .accessibilityLabel("Something you’re grateful for")
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(paperColor)
                .shadow(color: .black.opacity(0.055), radius: 10, y: 5)
                .overlay(alignment: .topTrailing) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 14, y: 14))
                        path.addLine(to: CGPoint(x: 14, y: 0))
                        path.closeSubpath()
                    }
                    .fill(accent.opacity(0.3))
                    .frame(width: 14, height: 14)
                }
        }
    }

    private var jarDisplay: some View {
        ZStack {
            KeepsakeJarGlass()
                .frame(width: 238, height: 250)
                .allowsHitTesting(false)

            // The artwork supplies the glass, while every paper keepsake stays interactive.
            ForEach(things.indices, id: \.self) { index in
                Button {
                    guard !isFolding else { return }
                    writing = false
                    openedThing = OpenedThing(id: index, words: things[index])
                } label: {
                    OrigamiKeepsake(kind: index % 5, color: colors[index % colors.count])
                        .frame(width: 40, height: 36)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -6 : 6))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .position(keepsakePosition(index))
                .disabled(isFolding)
                .accessibilityLabel("Open \(OrigamiKeepsake.names[index % 5]), good thing \(index + 1)")
            }

            // Thin front glints make the paper appear inside rather than pasted on.
            Capsule().fill(.white.opacity(0.7))
                .frame(width: 2, height: 100).offset(x: -106, y: 20)
                .allowsHitTesting(false)
            Capsule().fill(.white.opacity(0.6))
                .frame(width: 2, height: 70).offset(x: 106, y: 28)
                .allowsHitTesting(false)
        }
        .frame(width: 250, height: 260)
        .frame(maxWidth: .infinity)
    }

    private var completion: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)
            Text("These little things count.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
            jarDisplay
            Text("Moments worth keeping.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
            Text("Tap a keepsake to revisit your words.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 36)
            primaryButton("Back home", action: close)
        }
        .frame(maxWidth: .infinity)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(accent, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func keepsakePosition(_ index: Int) -> CGPoint {
        if index == 9 { return CGPoint(x: 125, y: 55) }
        let row = index / 3
        let x = row == 2 ? 75 + CGFloat(index % 3) * 50 : 64 + CGFloat(index % 3) * 61
        return CGPoint(x: x, y: 207 - CGFloat(row) * 51)
    }

    private func beginFold(finishAfterLanding: Bool) {
        guard screen == .collecting, !isFolding,
              things.count < maximumThings, !cleanDraft.isEmpty else { return }
        writing = false
        foldPhase = .flat
        pendingFold = FoldJob(words: cleanDraft, index: things.count, finishAfterLanding: finishAfterLanding)
    }

    @MainActor
    private func wait(_ seconds: Double, for job: FoldJob) async throws {
        try await Task.sleep(for: .seconds(seconds))
        try Task.checkCancellation()
        guard pendingFold?.id == job.id, screen == .collecting else { throw CancellationError() }
    }

    @MainActor
    private func animateFold(_ job: FoldJob) async {
        do {
            if !reduceMotion {
                try await wait(0.18, for: job)
                withAnimation(.easeInOut(duration: 0.26)) { foldPhase = .square }
                try await wait(0.28, for: job)
                withAnimation(.easeInOut(duration: 0.48)) { foldPhase = .firstCrease }
                try await wait(0.50, for: job)
                withAnimation(.easeInOut(duration: 0.42)) { foldPhase = .secondCrease }
                try await wait(0.44, for: job)
                withAnimation(.easeInOut(duration: 0.28)) { foldPhase = .origami }
                try await wait(0.30, for: job)
                withAnimation(.easeInOut(duration: 0.40)) { foldPhase = .mouth }
                try await wait(0.42, for: job)
                withAnimation(.interpolatingSpring(stiffness: 130, damping: 16)) { foldPhase = .landed }
                try await wait(0.64, for: job)
            }
            try Task.checkCancellation()
            guard pendingFold?.id == job.id, screen == .collecting,
                  things.count == job.index, things.count < maximumThings else { return }
            // A single commit happens only after landing. Cancellation preserves the draft.
            things.append(job.words)
            draft = ""
            pendingFold = nil
            foldPhase = .flat
            if job.finishAfterLanding { completeSession() }
        } catch {
            if pendingFold?.id == job.id { cancelFold() }
        }
    }

    private func cancelFold() {
        pendingFold = nil
        foldPhase = .flat
    }

    private func finish() {
        guard screen == .collecting, hasContent, !isFolding else { return }
        if !cleanDraft.isEmpty, things.count < maximumThings {
            beginFold(finishAfterLanding: true)
        } else {
            completeSession()
        }
    }

    private func completeSession() {
        guard screen == .collecting, !isFolding, (1...maximumThings).contains(things.count),
              (hostArchivesDraft ? persistDraft() : draftStore.discard()) else {
            draftExitAction = .complete
            return
        }
        sessionEnded = true
        writing = false
        screen = .complete
        onSaveThings?(things)
        onComplete(10)
    }

    private func requestClose() {
        writing = false
        cancelFold()
        if screen != .complete && (hasUnsavedWriting || draftStore.hasDraft) {
            showsDiscardConfirmation = true
        } else {
            close()
        }
    }

    private var draftSnapshot: Draft {
        // A pending animation never becomes a saved keepsake until it lands.
        Draft(things: things, words: draft)
    }

    private func restoreDraft() {
        guard !draftLoaded else { return }
        draftLoaded = true
        guard let saved = draftStore.restore() else { return }
        applySavedDraft(saved)
    }

    private func applySavedDraft(_ saved: Draft) {
        things = Array(saved.things.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.prefix(maximumThings))
        draft = things.count < maximumThings ? saved.words : ""
        cancelFold()
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard draftLoaded, !sessionEnded, screen == .collecting else { return true }
        let saved = hasContent ? draftStore.save(draftSnapshot) : draftStore.clearEmptyDraft()
        if saved { draftExitAction = nil }
        return saved
    }

    private func saveDraftAndClose() {
        cancelFold()
        guard persistDraft() else { draftExitAction = .saveAndClose; return }
        close()
    }

    private func retryDraftAction() {
        switch draftExitAction {
        case .some(.saveAndClose): saveDraftAndClose()
        case .some(.discardAndClose): discardDraftAndClose()
        case .some(.complete): completeSession()
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
        cancelFold()
        writing = false
        openedThing = nil
        if let onClose {
            onClose()
        } else {
            dismiss()
            screen = .instructions
            if !draftStore.hasDraft {
                things = []
                draft = ""
            }
        }
    }
}

public typealias ThreeGoodThingsView = LittleThingsKeptView

private struct KeepsakeAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

// The paper has two separate hinged flaps. It does not just shrink the editor.
private struct FoldingKeepsake: View {
    @Environment(\.colorScheme) private var colorScheme
    private var paperColor: Color {
        colorScheme == .dark ? Color(red: 0.19, green: 0.16, blue: 0.18) : Color(red: 1, green: 0.98, blue: 0.95)
    }
    let color: Color
    let kind: Int
    let phase: Int
    let words: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(paperColor)
                .overlay(alignment: .topLeading) {
                    Text(words)
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .lineLimit(3)
                        .padding(16)
                }
                .opacity(phase == 0 ? 1 : 0)

            ZStack {
                FoldTriangle(lower: false)
                    .fill(paperColor)
                    .overlay {
                        Text(words)
                            .font(.custom("ComingSoon-Regular", size: 14, relativeTo: .footnote))
                            .lineLimit(3)
                            .padding(10)
                            .clipShape(FoldTriangle(lower: false))
                    }

                FoldTriangle(lower: true)
                    .fill(phase >= 2 ? color.opacity(0.9) : paperColor)
                    .overlay {
                        FoldTriangle(lower: true).stroke(color.opacity(0.3), lineWidth: 0.7)
                    }
                    .rotation3DEffect(.degrees(phase >= 2 ? -178 : 0),
                                      axis: (x: 1, y: -1, z: 0), anchor: .center, perspective: 0.45)

                FoldTriangle(lower: false)
                    .fill(color.opacity(0.65))
                    .scaleEffect(0.5, anchor: .topLeading)
                    .rotation3DEffect(.degrees(phase >= 3 ? 176 : 0),
                                      axis: (x: 1, y: 1, z: 0), anchor: .center, perspective: 0.45)
                    .opacity(phase >= 3 ? 1 : 0)
            }
            .rotationEffect(.degrees(phase >= 3 ? -40 : 0))
            .scaleEffect(phase >= 3 ? 0.72 : 1)
            .opacity(phase >= 1 && phase < 4 ? 1 : 0)

            OrigamiKeepsake(kind: kind, color: color)
                .opacity(phase >= 4 ? 1 : 0)
                .scaleEffect(phase >= 4 ? 1 : 0.55)
        }
        .shadow(color: .black.opacity(phase >= 5 ? 0.08 : 0.12), radius: 5, y: 5)
    }
}

private struct FoldTriangle: Shape {
    let lower: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: lower
                     ? CGPoint(x: rect.maxX, y: rect.maxY)
                     : CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct KeepsakeJarGlass: View {
    private var url: URL? {
        #if SWIFT_PACKAGE
        Bundle.module.url(forResource: "keepsake-jar", withExtension: "png")
        #else
        Bundle.main.url(forResource: "keepsake-jar", withExtension: "png")
        #endif
    }

    var body: some View {
        #if os(iOS)
        if let image = UIImage(named: "keepsake-jar") ?? url.flatMap({ UIImage(contentsOfFile: $0.path) }) {
            Image(uiImage: image).resizable()
        } else {
            jarFallback
        }
        #elseif canImport(AppKit)
        if let image = NSImage(named: "keepsake-jar") ?? url.flatMap({ NSImage(contentsOf: $0) }) {
            Image(nsImage: image).resizable()
        } else {
            jarFallback
        }
        #else
        jarFallback
        #endif
    }

    private var jarFallback: some View {
        RoundedRectangle(cornerRadius: 44)
            .fill(Color(red: 0.96, green: 0.98, blue: 0.98))
            .overlay {
                RoundedRectangle(cornerRadius: 44).stroke(.gray.opacity(0.25), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                Capsule().stroke(.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 150, height: 12).offset(y: -5)
            }
    }
}


private struct OrigamiKeepsake: View {
    let kind: Int
    let color: Color
    static let names = ["star", "bird", "boat", "heart", "butterfly"]

    var body: some View {
        OrigamiOutline(kind: kind)
            .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                GeometryReader { geometry in
                    Path { path in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: h))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.48))
                        path.addLine(to: CGPoint(x: w, y: 0))
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.48))
                        path.addLine(to: CGPoint(x: w, y: h))
                    }
                    .stroke(.white.opacity(0.65), lineWidth: 0.9)
                }
                .clipShape(OrigamiOutline(kind: kind))
            }
            .overlay {
                OrigamiOutline(kind: kind).stroke(color.opacity(0.8), lineWidth: 0.6)
            }
            .shadow(color: color.opacity(0.2), radius: 2, y: 2)
    }
}

private struct OrigamiOutline: Shape {
    let kind: Int

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        let points: [CGPoint]
        switch kind {
        case 0:
            points = (0..<10).map { index in
                let angle = Double(index) * .pi / 5 - .pi / 2
                let radius: CGFloat = index.isMultiple(of: 2) ? 0.48 : 0.23
                return p(0.5 + radius * cos(angle), 0.5 + radius * sin(angle))
            }
        case 1: // Folded crane: high wing, pointed tail and bent neck.
            points = [p(0.04,0.75), p(0.27,0.43), p(0.26,0.04), p(0.57,0.40),
                      p(0.82,0.28), p(0.88,0.12), p(0.99,0.25), p(0.89,0.24),
                      p(0.84,0.57), p(0.58,0.72), p(0.32,0.65)]
        case 2:
            points = [p(0.03,0.56), p(0.20,0.85), p(0.79,0.85), p(0.98,0.56),
                      p(0.69,0.56), p(0.49,0.11), p(0.30,0.56)]
        case 3:
            points = [p(0.50,0.94), p(0.05,0.47), p(0.07,0.20), p(0.28,0.06),
                      p(0.50,0.25), p(0.72,0.06), p(0.93,0.20), p(0.95,0.47)]
        default:
            points = [p(0.49,0.41), p(0.10,0.05), p(0.02,0.44), p(0.31,0.58),
                      p(0.10,0.91), p(0.45,0.77), p(0.50,0.95), p(0.55,0.77),
                      p(0.90,0.91), p(0.69,0.58), p(0.98,0.44), p(0.90,0.05),
                      p(0.51,0.41)]
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

private struct GoodThingsArtwork: View {
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
    LittleThingsKeptView()
}
