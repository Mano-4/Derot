import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct SmallPlan: Equatable {
    public let time: String
    public let action: String
    public let source: String
}

public struct MakeAPlanView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSavePlan: ((SmallPlan) -> Void)?

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSavePlan: ((SmallPlan) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSavePlan = onSavePlan
    }

    private enum Screen { case instructions, time, plan, note, focus, complete }
    private enum Route: String, CaseIterable {
        case ideas = "Choose an idea"
        case own = "Write my own"
        case surprise = "Surprise me"
    }
    private enum TimeChoice: String, CaseIterable {
        case minute = "One minute"
        case five = "Five minutes"
        case longer = "A little longer"

        var seconds: TimeInterval {
            switch self {
            case .minute: 60
            case .five: 300
            case .longer: 600
            }
        }

        var timerLabel: String {
            switch self {
            case .minute: "One minute"
            case .five: "Five minutes"
            case .longer: "A little longer · 10 minutes"
            }
        }

        var leadIn: String {
            switch self {
            case .minute: "For the next minute, I’m going to…"
            case .five: "For the next five minutes, I’m going to…"
            case .longer: "For a little while, I’m going to…"
            }
        }

        var ideas: [String] {
            switch self {
            case .minute: [
                "Stretch gently for a moment.",
                "Get a glass of water.",
                "Look out of a window.",
                "Put away one thing nearby.",
                "Write down one thing to return to."
            ]
            case .five: [
                "Step outside for some fresh air.",
                "Make a drink and enjoy it slowly.",
                "Send someone a thoughtful hello.",
                "Tidy one small corner.",
                "Return to one small part of a task."
            ]
            case .longer: [
                "Take a walk at my own pace.",
                "Read a few pages of a book.",
                "Make something simple to eat.",
                "Spend some time on a hobby.",
                "Sit down with something I’ve been putting off."
            ]
            }
        }
    }

    @State private var screen: Screen = .instructions
    @State private var selectedTime: TimeChoice?
    @State private var route: Route = .ideas
    @State private var selectedIdea: String?
    @State private var ownPlan = ""
    @State private var surpriseIdea: String?
    @State private var elapsed: TimeInterval = 0
    @State private var savedTime: TimeInterval = 0
    @State private var startedAt: Date?
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var timerDuration: TimeInterval { selectedTime?.seconds ?? 60 }
    private var remaining: TimeInterval { max(0, timerDuration - elapsed) }

    private let pink = Color(red: 244 / 255, green: 183 / 255, blue: 215 / 255)
    private let ink = Color(red: 0.51, green: 0.29, blue: 0.40)
    private var ideas: [String] { selectedTime?.ideas ?? [] }
    private var activePlan: String {
        let value: String
        switch route {
        case .ideas: value = selectedIdea ?? ""
        case .own: value = ownPlan
        case .surprise: value = surpriseIdea ?? ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                            if screen != .instructions { badge }
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 56))
                    case .time:
                        timePage.frame(minHeight: max(0, geometry.size.height - 56))
                    case .plan:
                        planPage.frame(minHeight: max(0, geometry.size.height - 56))
                    case .note:
                        planNote.frame(minHeight: max(0, geometry.size.height - 56))
                    case .focus:
                        timerPage.frame(minHeight: max(0, geometry.size.height - 56))
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
        .onReceive(ticker) { updateTimer(at: $0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { updateTimer(at: Date()) }
        }
        .onDisappear {
            // Keep elapsed time accurate if the view is temporarily covered.
            // An explicit close cancels the session in close().
            if screen == .focus { updateTimer(at: Date()) }
        }
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
            PlanArtwork(name: "reflect-plan-intro")
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

            Text("Make a Plan")
                .font(.custom("ComingSoon-Regular", size: 34))
            instruction(number: "1", text: "Choose how much time you have")
            instruction(number: "2", text: "Pick one small thing to do next")

            Spacer(minLength: 36)
            pinkButton("Start") {
                reset()
                screen = .time
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

    private var timePage: some View {
        VStack(spacing: 20) {
            Text("What do you have room for right now?")
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
            Text("A little time is enough.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            ForEach(TimeChoice.allCases, id: \.self) { time in
                selectionRow(time.timerLabel, selected: selectedTime == time) {
                    if selectedTime != time {
                        selectedIdea = nil
                        surpriseIdea = nil
                    }
                    selectedTime = time
                }
            }

            Spacer(minLength: 24)
            pinkButton("Continue") { screen = .plan }
                .disabled(selectedTime == nil)
                .opacity(selectedTime == nil ? 0.45 : 1)
        }
    }

    private var planPage: some View {
        VStack(spacing: 18) {
            Text("One small next step")
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            Text(selectedTime?.rawValue ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Route.allCases, id: \.self) { option in
                    Button {
                        writing = false
                        route = option
                        if option == .surprise, surpriseIdea == nil { drawSurprise() }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(route == option ? pink : pink.opacity(0.18),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityAddTraits(route == option ? .isSelected : [])
                }
            }

            switch route {
            case .ideas:
                VStack(spacing: 10) {
                    ForEach(ideas, id: \.self) { idea in
                        selectionRow(idea, selected: selectedIdea == idea) { selectedIdea = idea }
                    }
                }
            case .own:
                ownPlanPaper
            case .surprise:
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(ink)
                    Text(surpriseIdea ?? "")
                        .font(.custom("ComingSoon-Regular", size: 22))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try another", action: drawSurprise)
                        .font(.system(size: 13, weight: .medium))
                        .frame(minHeight: 44)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(pink.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            }

            Spacer(minLength: 16)
            pinkButton("This is my plan", action: finish)
                .disabled(activePlan.isEmpty)
                .opacity(activePlan.isEmpty ? 0.45 : 1)
            Button("Back") {
                writing = false
                screen = .time
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: route)
    }

    private func selectionRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.custom("ComingSoon-Regular", size: 18))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(selected ? ink : ink.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? pink.opacity(0.75) : pink.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? ink.opacity(0.5) : .clear, lineWidth: 1)
            }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var ownPlanPaper: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I’m going to…")
                .font(.custom("ComingSoon-Regular", size: 22))
            ZStack(alignment: .topLeading) {
                if ownPlan.isEmpty {
                    Text("One small thing…")
                        .font(.custom("ComingSoon-Regular", size: 22))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $ownPlan)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($writing)
                    .frame(height: 170)
                    .accessibilityLabel("Your next small step")
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .padding(.vertical, 20)
        .background { paperBackground }
    }

    private var paperBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(red: 1, green: 0.96, blue: 0.98))
            .overlay {
                PlanPaperRules().stroke(pink.opacity(0.6), lineWidth: 0.7)
            }
            .overlay(alignment: .leading) {
                Rectangle().fill(pink.opacity(0.65)).frame(width: 1).padding(.leading, 17)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var planNote: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 36)
            Text("A little plan, just for now.")
                .font(.custom("ComingSoon-Regular", size: 28))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "pin")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(ink.opacity(0.65))
                    .frame(maxWidth: .infinity)

                Text(selectedTime?.leadIn ?? "")
                    .font(.custom("ComingSoon-Regular", size: 16))
                    .foregroundStyle(.secondary)
                Text(activePlan)
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background { paperBackground }

            Text("Go give it a little time.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 36)
            pinkButton("Start my time", action: startTimer)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerPage: some View {
        VStack(spacing: 20) {
            Text("A little time for your plan")
                .font(.custom("ComingSoon-Regular", size: 28))
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text(activePlan)
                .font(.custom("ComingSoon-Regular", size: 22))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(pink.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 20)

            Text(timeString(remaining))
                .font(.system(size: 54, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            ProgressView(value: elapsed, total: timerDuration)
                .tint(pink)
                .padding(.horizontal, 24)

            Text(startedAt == nil ? "Paused. Take your time." : "You can put your phone down.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 20)

            Button {
                if startedAt == nil {
                    startedAt = Date()
                } else {
                    pauseTimer()
                }
            } label: {
                Image(systemName: startedAt == nil ? "play.fill" : "pause.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black, in: Circle())
            }
            .accessibilityLabel(startedAt == nil ? "Resume timer" : "Pause timer")

            pinkButton("I’m done", action: finishSession)
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            PlanArtwork(name: "reflect-plan-complete")
                .frame(width: 180, height: 200)
                .background {
                    Circle().fill(pink.opacity(0.3)).frame(width: 166, height: 166)
                }
            Text("A little time, well spent.")
                .font(.custom("ComingSoon-Regular", size: 28))
                .multilineTextAlignment(.center)
            Text("You made some room for what you chose.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

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

    private func drawSurprise() {
        let alternatives = ideas.filter { $0 != surpriseIdea }
        surpriseIdea = (alternatives.isEmpty ? ideas : alternatives).randomElement()
    }

    private func finish() {
        guard screen == .plan, let time = selectedTime, !activePlan.isEmpty else { return }
        writing = false
        let plan = SmallPlan(time: time.rawValue, action: activePlan, source: route.rawValue)
        screen = .note
        onSavePlan?(plan)
    }

    private func startTimer() {
        guard screen == .note, selectedTime != nil else { return }
        elapsed = 0
        savedTime = 0
        startedAt = Date()
        screen = .focus
    }

    private func updateTimer(at date: Date) {
        guard screen == .focus, let start = startedAt else { return }
        elapsed = min(timerDuration, savedTime + max(0, date.timeIntervalSince(start)))
        if elapsed >= timerDuration { finishSession() }
    }

    private func pauseTimer() {
        guard let start = startedAt else { return }
        elapsed = min(timerDuration, savedTime + max(0, Date().timeIntervalSince(start)))
        savedTime = elapsed
        startedAt = nil
    }

    private func finishSession() {
        guard screen == .focus else { return }
        pauseTimer()
        screen = .complete
        // The same reward for finishing early or reaching the timer's end.
        onComplete(10)
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let whole = Int(ceil(seconds))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func reset() {
        elapsed = 0
        savedTime = 0
        startedAt = nil
        writing = false
        selectedTime = nil
        route = .ideas
        selectedIdea = nil
        ownPlan = ""
        surpriseIdea = nil
    }

    private func close() {
        startedAt = nil
        writing = false
        if let onClose {
            onClose()
        } else {
            dismiss()
            reset()
            screen = .instructions
        }
    }
}

private struct PlanPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 74
        while y < rect.height - 12 {
            path.move(to: CGPoint(x: 23, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 14, y: y))
            y += 34
        }
        return path
    }
}

private struct PlanArtwork: View {
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
    MakeAPlanView()
}
