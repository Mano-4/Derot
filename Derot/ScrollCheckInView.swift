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

public struct ScrollCheckInView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveAnswers: ((ScrollCheckInAnswers) -> Void)?

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveAnswers: ((ScrollCheckInAnswers) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveAnswers = onSaveAnswers
    }

    private enum Screen { case instructions, questions, complete }
    private enum ResponseMode { case choices, journal }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Reflect: #F4B7D7
    private let pink = Color(red: 244 / 255, green: 183 / 255, blue: 215 / 255)
    private let ink = Color(red: 0.51, green: 0.29, blue: 0.40)
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var current: Question { questions[step] }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if screen != .complete {
                        HStack {
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .light))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Close activity")
                            Spacer()
                            if screen == .questions { badge }
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 56))
                    case .questions:
                        questionPage.frame(minHeight: max(0, geometry.size.height - 56))
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
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var badge: some View {
        Label("Reflect", systemImage: "heart.text.square")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(pink, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollCheckInArtwork(name: "reflect-scroll-intro")
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(pink.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("At your pace", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Scroll Check-In")
                .font(.custom("ComingSoon-Regular", size: 34))

            instruction(number: "1", text: "Pause and check in with yourself")
            instruction(number: "2", text: "Choose what fits, or write instead.")

            Spacer(minLength: 36)
            pinkButton("Start") {
                step = 0
                resetAnswers()
                screen = .questions
            }
            Button("Pick something else", action: close)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.07), in: Circle())
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var questionPage: some View {
        VStack(spacing: 18) {
            Text("A moment for you")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            Text(current.prompt)
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            Text(responseModes[step] == .choices ? "Choose any that fit." : "Say it in your own words.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("\(step + 1) of 3")
                .font(.system(size: 11))
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
                .font(.custom("ComingSoon-Regular", size: 18))
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
                    .font(.system(size: 13))
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
                    .font(.custom("ComingSoon-Regular", size: 18))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .light))
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
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $notes[step])
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($writing)
                .frame(height: 190)
                .accessibilityLabel("Your thoughts: \(current.prompt)")
        }
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 1, green: 0.99, blue: 0.97))
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
                .font(.custom("ComingSoon-Regular", size: 28))
                .multilineTextAlignment(.center)
            Text("You don’t have to change anything right now.\nNoticing is a start.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Label("+10 pts", systemImage: "star.fill")
                .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 14, weight: .medium))
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

    private func close() {
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
