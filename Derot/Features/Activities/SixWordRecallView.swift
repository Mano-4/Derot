import SwiftUI
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Add this file to the app target, then show SixWordRecallView().
@MainActor
public struct SixWordRecallView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let introImageName: String

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        introImageName: String = "think-recall-intro"
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.introImageName = introImageName
    }

    private enum Screen: Equatable {
        case introduction, study, hiding, recall, revealing, reveal, complete
    }
    @State private var screen: Screen = .introduction
    @State private var words: [String] = []
    @State private var answers = Array(repeating: "", count: 6)
    @State private var score = SixWordRecallScore(words: [], answers: [])
    @State private var studyTimer = SixWordRecallStudyTimer()
    @State private var flippedCards: Set<Int> = []
    @State private var hasAwardedPoints = false
    @State private var isOnScreen = false
    @State private var studySeconds = 15
    @State private var showsLeaveRoundConfirmation = false
    @FocusState private var focusedSlot: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var stepMarkerSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var cardHeight = 140.0
    @ScaledMetric(relativeTo: .body) private var countdownDiameter = 46.0

    private var lavender: Color {
        colorScheme == .dark
            ? Color(red: 0.40, green: 0.30, blue: 0.44)
            : Color(red: 189 / 255, green: 171 / 255, blue: 192 / 255)
    }
    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.92, blue: 0.97)
            : Color(red: 0.29, green: 0.23, blue: 0.31)
    }
    private var surface: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        colorScheme == .dark ? .black : .white
        #endif
    }
    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var hasUnfinishedRound: Bool {
        guard screen != .complete, !hasAwardedPoints else { return false }
        return answers.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || screen == .revealing || screen == .reveal
    }

    public var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("recall-top")
                        Group {
                            switch screen {
                            case .introduction: introduction
                            case .study, .hiding, .recall, .revealing, .reveal: gameBoard
                            case .complete: completion
                            }
                        }
                        .frame(
                            minHeight: max(0, geometry.size.height - 12),
                            alignment: .top
                        )
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: screen) { _, _ in
                    proxy.scrollTo("recall-top", anchor: .top)
                }
                .onChange(of: focusedSlot) { _, slot in
                    guard screen == .recall, let slot else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        proxy.scrollTo(slot, anchor: .center)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .background(surface.ignoresSafeArea())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .tint(ink)
        #if os(iOS)
        .toolbar(screen == .complete ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: screen == .reveal && score.total > 0)
        #endif
        .navigationTitle(screen == .introduction || screen == .complete ? "" : "6-Word Recall")
        .toolbar {
            #if os(iOS)
            if focusedSlot != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedSlot = nil }
                        .fontWeight(.semibold)
                        .buttonStyle(.automatic)
                }
            }
            #endif
            if screen != .complete {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: requestClose) {
                        Label("Close activity", systemImage: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.automatic)
                }
            }
        }
        }
        .interactiveDismissDisabled(hasUnfinishedRound)
        .confirmationDialog("Leave this round?", isPresented: $showsLeaveRoundConfirmation,
                            titleVisibility: .visible) {
            Button("Keep playing", role: .cancel) {}
            Button("Leave round", role: .destructive, action: close)
        } message: {
            if screen == .revealing || screen == .reveal {
                Text("Finish adds your round’s points. Leaving now clears the round.")
            } else {
                Text("Your answers will be cleared if you leave.")
            }
        }
        .onAppear { isOnScreen = true }
        .onReceive(ticker) { _ in
            guard isOnScreen, screen == .study, scenePhase == .active else { return }
            studyTimer.update(at: now)
            // Expiry sets isPaused too: handle it before checking pause state.
            if studyTimer.hasExpired { hideCards() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, screen == .study { studyTimer.pause(at: now) }
        }
        .onDisappear {
            isOnScreen = false
            if screen == .study { studyTimer.pause(at: now) }
        }
        .task(id: screen) { await turnCards() }
    }

    private var badge: some View {
        Label("Think", systemImage: "brain")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(lavender, in: RoundedRectangle(cornerRadius: 6))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Add your own transparent Mr. Rabbit image with this asset name.
            RecallArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(lavender.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("\(studySeconds)s to remember", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("6-Word Recall")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)

            instruction("1", "Remember six words and their places before time runs out.")
            instruction("2", "When the cards turn over, tap them to write the words.")
            instruction("3", "Earn 1 point per word, plus 1 for its original spot.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Time to remember")
                    .font(.headline)
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        studyTimePicker.pickerStyle(.menu)
                    } else {
                        studyTimePicker.pickerStyle(.segmented)
                    }
                }
                Text("Choose a little more time if you like.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)
        }
        .padding(.top, 8)
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .frame(width: stepMarkerSize, height: stepMarkerSize)
                .background(Color.primary.opacity(0.07), in: Circle())
            Text(text)
                .font(.body)
                .frame(minHeight: 28, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var studyTimePicker: some View {
        Picker("Time to remember", selection: $studySeconds) {
            Text("15 sec").tag(15)
            Text("30 sec").tag(30)
            Text("60 sec").tag(60)
        }
        .controlSize(.large)
        .frame(minHeight: 44)
        .accessibilityHint("Choose more time if you prefer. The points stay the same.")
    }

    private var gameBoard: some View {
        VStack(spacing: 14) {
            badge
            Text(boardTitle)
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(boardNote)
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 40)

            if screen == .study {
                countdown
            } else if screen == .revealing || screen == .reveal {
                Label("Round score · \(visiblePoints) pts", systemImage: "star.fill")
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(lavender.opacity(0.35), in: Capsule())
                    .accessibilityLabel("Round score, \(visiblePoints) points")
            } else {
                scoringKey
                    .frame(minHeight: 48)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(words.indices, id: \.self) { index in
                    card(index).id(index)
                }
            }

            if screen == .reveal {
                Text("\(score.wordPoints) word points · \(score.positionPoints) spot points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Finish adds these points. Each word counts once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if screen == .recall {
                Text("Leave a card blank if it slips away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 16)
        }
        .padding(.top, 14)
    }

    private var boardTitle: String {
        switch screen {
        case .study: return "Ready, set, remember."
        case .hiding: return "Turning them over…"
        case .recall: return "Bring them back."
        case .revealing: return "Let’s take a look…"
        default: return score.total == 12 ? "Every word, every spot!" : "Your cards, revealed."
        }
    }

    private var boardNote: String {
        switch screen {
        case .study:
            return studyTimer.isPaused ? "Paused. Continue when you’re ready." : "Remember each word and where it belongs."
        case .hiding: return "Six little spaces for your memory."
        case .recall: return "Tap a card and write its word."
        case .revealing: return "A point for the word. Another for its spot."
        default: return "A point for the word. Another for its spot."
        }
    }

    private var countdown: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(lavender.opacity(0.24), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: 1 - studyTimer.progress)
                    .stroke(ink.opacity(0.65), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(studyTimer.secondsRemaining)")
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .monospacedDigit()
            }
            .frame(width: countdownDiameter, height: countdownDiameter)
            Text(studyTimer.isPaused ? "Paused" : "Until the cards turn")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: countdownDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(studyTimer.isPaused
                            ? "Paused, \(studyTimer.secondsRemaining) seconds remaining"
                            : "\(studyTimer.secondsRemaining) seconds until the cards hide")
    }

    private var scoringKey: some View {
        HStack(spacing: 18) {
            Label("Word +1", systemImage: "sparkle")
            Label("Spot +1", systemImage: "mappin")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(ink)
    }

    private var visiblePoints: Int {
        score.entries.indices.reduce(0) { result, index in
            result + (flippedCards.contains(index) ? 0 : score.entries[index].points)
        }
    }

    private func card(_ index: Int) -> some View {
        let isFlipped = flippedCards.contains(index)
        let angle = isFlipped ? 180.0 : 0.0
        let showsResult = screen == .revealing || screen == .reveal
        let frontAccessible = (screen == .study && !studyTimer.isPaused)
            || (showsResult && !isFlipped)
        return ZStack {
            Group {
                if showsResult { resultFace(index) }
                else { wordFace(index) }
            }
            .modifier(RecallCardFace(angle: angle, isBack: false))
            .accessibilityHidden(!frontAccessible)
            .allowsHitTesting(false)

            writingFace(index)
                .modifier(RecallCardFace(angle: angle, isBack: true))
                .accessibilityHidden(screen != .recall)
                .allowsHitTesting(screen == .recall)
        }
        .frame(minHeight: cardHeight)
        .accessibilityElement(children: .contain)
    }

    private func cardNumber(_ index: Int) -> some View {
        Text(String(format: "%02d", index + 1))
            .font(.caption.weight(.medium))
            .foregroundStyle(ink.opacity(0.65))
            .accessibilityHidden(true)
    }

    private func wordFace(_ index: Int) -> some View {
        // The paused/hiding state never leaves readable words underneath a cover.
        let canRead = screen == .study && !studyTimer.isPaused
        return VStack(alignment: .leading, spacing: 12) {
            cardNumber(index)
            Text(canRead ? words[index] : "•••")
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardSurface(isHighlighted: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(canRead ? "Card \(index + 1), \(words[index])" : "Card \(index + 1), hidden")
    }

    private func writingFace(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                cardNumber(index)
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption.weight(.light))
                    .foregroundStyle(ink.opacity(0.6))
                    .accessibilityHidden(true)
            }

            if screen == .recall {
                TextField("Your word", text: $answers[index])
                    .textFieldStyle(.plain)
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    #endif
                    .submitLabel(index == 5 ? .done : .next)
                    .focused($focusedSlot, equals: index)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Word on card \(index + 1)")
                    .onSubmit { focusedSlot = index < 5 ? index + 1 : nil }
            } else {
                Text(answerText(index))
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

            Rectangle()
                .fill(lavender.opacity(focusedSlot == index ? 0.9 : 0.45))
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardSurface(isHighlighted: focusedSlot == index))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .simultaneousGesture(TapGesture().onEnded {
            if screen == .recall { focusedSlot = index }
        })
    }

    private func resultFace(_ index: Int) -> some View {
        // Results are initialized before entering the revealing state.
        let entry = score.entries[index]
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                cardNumber(index)
                Spacer()
                if entry.points > 0 {
                    Text("+\(entry.points)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ink)
                }
            }
            Text(answerText(index))
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .lineLimit(2)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.positionPoint == 1 ? "Right word, right spot" : "Was: \(words[index])")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if entry.wordPoint == 1 { Text("Word +1") }
                if entry.positionPoint == 1 { Text("Spot +1") }
                if entry.points == 0 {
                    Text(entry.isDuplicate ? "Word already counted" : "Another look")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardSurface(isHighlighted: entry.positionPoint == 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(index + 1). You wrote \(answerText(index)). Original word: \(words[index]).")
        .accessibilityValue("\(entry.wordPoint) word point, \(entry.positionPoint) spot point"
                            + (entry.isDuplicate ? ". Word already counted." : ""))
    }

    private func cardSurface(isHighlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark
                  ? (isHighlighted ? Color(red: 0.29, green: 0.22, blue: 0.32)
                                   : Color(red: 0.15, green: 0.13, blue: 0.17))
                  : lavender.opacity(isHighlighted ? 0.38 : 0.14))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(lavender.opacity(isHighlighted ? 0.9 : 0.4), lineWidth: 1)
            }
            .allowsHitTesting(false)
    }

    private func answerText(_ index: Int) -> String {
        let text = answers[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "—" : text
    }

    private var completion: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            Text("A moment for your mind.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            // Add your own transparent completion rabbit with this asset name.
            RecallArtwork(name: "think-recall-complete")
                .frame(width: 170, height: 190)

            Text("You gave your attention something new.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)

            Label("+\(score.total) pts", systemImage: "star.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(lavender, in: Capsule())

            Text("\(score.wordPoints) word points + \(score.positionPoints) spot points")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 4) {
            switch screen {
            case .introduction:
                primaryButton("Start", action: start)
                Button("Pick something else", action: close)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .study:
                HStack(spacing: 12) {
                    Button(studyTimer.isPaused ? "Continue" : "Pause", action: toggleStudyPause)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(lavender.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                    primaryButton("Hide now", action: hideCards)
                }
            case .hiding:
                primaryButton("Turning cards…", action: {})
                    .disabled(true)
            case .recall:
                primaryButton("Turn & check", action: revealWords)
            case .revealing:
                primaryButton("Checking cards…", action: {})
                    .disabled(true)
            case .reveal:
                primaryButton("Finish", action: finish)
            case .complete:
                primaryButton("Back home", action: close)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(surface)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(lavender, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func start() {
        guard screen == .introduction else { return }
        words = SixWordRecallWords.makeSet()
        answers = Array(repeating: "", count: 6)
        score = SixWordRecallScore(words: [], answers: [])
        flippedCards = []
        hasAwardedPoints = false
        studyTimer = SixWordRecallStudyTimer(duration: TimeInterval(studySeconds))
        studyTimer.start(at: now)
        screen = .study
    }

    private func toggleStudyPause() {
        guard screen == .study else { return }
        if studyTimer.isPaused { studyTimer.resume(at: now) }
        else { studyTimer.pause(at: now) }
        if studyTimer.hasExpired { hideCards() }
    }

    private func hideCards() {
        guard screen == .study else { return }
        studyTimer.pause(at: now)
        focusedSlot = nil
        screen = .hiding
    }

    private func revealWords() {
        guard screen == .recall else { return }
        focusedSlot = nil
        score = SixWordRecallScore(words: words, answers: answers)
        screen = .revealing
    }

    private func finish() {
        guard screen == .reveal, !hasAwardedPoints else { return }
        hasAwardedPoints = true
        screen = .complete
        onComplete(score.total)
    }

    private func requestClose() {
        focusedSlot = nil
        if hasUnfinishedRound { showsLeaveRoundConfirmation = true }
        else { close() }
    }

    private func close() {
        focusedSlot = nil
        screen = .introduction
        words = []
        answers = Array(repeating: "", count: 6)
        score = SixWordRecallScore(words: [], answers: [])
        studyTimer = SixWordRecallStudyTimer()
        flippedCards = []
        hasAwardedPoints = false
        if let onClose { onClose() }
        else { dismiss() }
    }

    private func turnCards() async {
        let transition = screen
        guard transition == .hiding || transition == .revealing else { return }
        let hiding = transition == .hiding
        if reduceMotion {
            flippedCards = hiding ? Set(words.indices) : []
        } else {
            for index in words.indices {
                guard !Task.isCancelled, screen == transition else { return }
                guard flippedCards.contains(index) != hiding else { continue }
                withAnimation(.easeInOut(duration: 0.32)) {
                    if hiding { _ = flippedCards.insert(index) }
                    else { _ = flippedCards.remove(index) }
                }
                do { try await Task.sleep(for: .milliseconds(120)) }
                catch { return }
            }
            do { try await Task.sleep(for: .milliseconds(320)) }
            catch { return }
        }
        guard !Task.isCancelled, screen == transition else { return }
        screen = hiding ? .recall : .reveal
    }
}

/// Each face is visible for its own half of the turn, so text never appears mirrored.
private struct RecallCardFace: AnimatableModifier {
    var angle: Double
    let isBack: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(isBack ? (angle >= 90 ? 1 : 0) : (angle < 90 ? 1 : 0))
            .rotation3DEffect(.degrees(isBack ? angle - 180 : angle),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

@MainActor
private struct RecallArtwork: View {
    let name: String

    private var exists: Bool {
        #if canImport(UIKit)
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
                Image(name)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}


/// Session vocabulary and exact, order-independent recall matching.
enum SixWordRecallWords {
    static let pool: [String] = [
        "apple", "bag", "basket", "bench", "boat", "book", "bottle", "box",
        "brush", "bucket", "button", "candle", "chair", "cherry", "clock", "cloud",
        "coin", "cookie", "cup", "daisy", "desk", "drum", "feather", "fork",
        "glove", "grape", "guitar", "hammer", "hat", "helmet", "jacket", "kite",
        "ladder", "lamp", "leaf", "lemon", "mirror", "mug", "orange", "pencil",
        "pillow", "plate", "pocket", "pumpkin", "rabbit", "ribbon", "robot", "rock",
        "scarf", "shell", "shoe", "spoon", "star", "stone", "table", "ticket",
        "towel", "tree", "window", "zipper"
    ]

    static func makeSet() -> [String] {
        Array(pool.shuffled().prefix(6))
    }

    static func normalize(_ value: String) -> String {
        let edgeCharacters = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let trimmed = value.trimmingCharacters(in: edgeCharacters)
        let locale = Locale(identifier: "en_US_POSIX")
        let folded = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .lowercased(with: locale)

        // A slot contains one whole word. Never extract a target from a phrase,
        // comma-separated list, or another longer word.
        guard !folded.isEmpty,
              folded.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) })
        else { return "" }
        return folded
    }

    static func rememberedWords(in words: [String], answers: [String]) -> Set<String> {
        let submitted = Set(answers.map(normalize).filter { !$0.isEmpty })
        return Set(words.filter { word in
            let normalized = normalize(word)
            return !normalized.isEmpty && submitted.contains(normalized)
        })
    }
}

/// One point for a unique recalled word, plus one for its original position.
struct SixWordRecallScore {
    struct Entry {
        let wordPoint: Int
        let positionPoint: Int
        let targetIndex: Int?
        let isDuplicate: Bool
        var points: Int { wordPoint + positionPoint }
    }

    let entries: [Entry]
    var wordPoints: Int { entries.reduce(0) { $0 + $1.wordPoint } }
    var positionPoints: Int { entries.reduce(0) { $0 + $1.positionPoint } }
    var total: Int { wordPoints + positionPoints }

    init(words: [String], answers: [String]) {
        // The game has six cards. Extra external entries cannot inflate the reward.
        let targets = Array(words.prefix(6)).map(SixWordRecallWords.normalize)
        let recalled = targets.indices.map { index in
            answers.indices.contains(index) ? SixWordRecallWords.normalize(answers[index]) : ""
        }
        var creditedTargets = Array<Int?>(repeating: nil, count: targets.count)
        var uniqueTargets: Set<String> = []

        for targetIndex in targets.indices {
            let target = targets[targetIndex]
            guard !target.isEmpty, uniqueTargets.insert(target).inserted else { continue }
            let matchingSlots = recalled.indices.filter { recalled[$0] == target }
            // Prefer the original slot even if a duplicate appears earlier.
            guard let slot = matchingSlots.contains(targetIndex)
                    ? targetIndex : matchingSlots.first else { continue }
            creditedTargets[slot] = targetIndex
        }

        entries = targets.indices.map { index in
            let targetIndex = creditedTargets[index]
            let isRecognizedWord = !recalled[index].isEmpty && uniqueTargets.contains(recalled[index])
            return Entry(
                wordPoint: targetIndex == nil ? 0 : 1,
                positionPoint: targetIndex == index ? 1 : 0,
                targetIndex: targetIndex,
                isDuplicate: isRecognizedWord && targetIndex == nil
            )
        }
    }
}

/// A foreground-only study clock. The view pauses it when inactive or off-screen.
struct SixWordRecallStudyTimer {
    let duration: TimeInterval
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPaused = true
    private(set) var hasExpired = false
    private var savedElapsed: TimeInterval = 0
    private var startedAt: TimeInterval?

    init(duration: TimeInterval = 15) {
        self.duration = duration.isFinite && duration > 0 ? duration : 15
    }

    var secondsRemaining: Int { max(0, Int(ceil(duration - elapsed))) }
    var progress: Double { min(1, max(0, elapsed / duration)) }

    mutating func start(at time: TimeInterval) {
        self = SixWordRecallStudyTimer(duration: duration)
        isPaused = false
        startedAt = time
    }

    mutating func update(at time: TimeInterval) {
        guard !isPaused, !hasExpired, let startedAt else { return }
        let candidate = savedElapsed + max(0, time - startedAt)
        elapsed = max(elapsed, min(duration, candidate))
        if elapsed >= duration {
            elapsed = duration
            savedElapsed = duration
            self.startedAt = nil
            hasExpired = true
            isPaused = true
        }
    }

    mutating func pause(at time: TimeInterval) {
        guard !isPaused, !hasExpired else { return }
        update(at: time)
        savedElapsed = elapsed
        startedAt = nil
        isPaused = true
    }

    mutating func resume(at time: TimeInterval) {
        guard isPaused, !hasExpired else { return }
        savedElapsed = elapsed
        startedAt = time
        isPaused = false
    }
}

#Preview {
    SixWordRecallView()
}
