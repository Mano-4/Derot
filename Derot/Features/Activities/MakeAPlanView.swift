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

@MainActor
public struct MakeAPlanView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSavePlan: ((SmallPlan) -> Void)?
    private let introImageName: String

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSavePlan: ((SmallPlan) -> Void)? = nil,
        introImageName: String = "reflect-plan-intro"
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSavePlan = onSavePlan
        self.introImageName = introImageName
    }

    private enum Screen: String { case instructions, time, plan, note, focus, complete }
    private struct Draft: Codable, Equatable {
        let stage: String
        let time: String?
        let route: String
        let selectedIdea: String?
        let ownPlan: String
        let surpriseIdea: String?
    }
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
    @State private var isClosing = false
    @FocusState private var writing: Bool
    @Environment(\.activityDraftHostArchives) private var hostArchivesDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var stepMarkerSize: CGFloat = 28
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDiscardConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var draftStore = ActivityDraftStore<Draft>(activityID: "make-a-plan")
    @State private var draftExitAction: ActivityDraftExitAction?
    @State private var didRestoreDraft = false
    @State private var draftSessionEnded = false
    @State private var resumeScreen: Screen = .time

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var timerDuration: TimeInterval { selectedTime?.seconds ?? 60 }
    private var remaining: TimeInterval { max(0, timerDuration - elapsed) }

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

    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 170
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 54
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
        colorScheme == .dark ? Color(red: 0.17, green: 0.14, blue: 0.16) : Color(red: 1, green: 0.96, blue: 0.98)
    }
    private var hasUnsavedWriting: Bool {
        screen != .complete && (hasDraftContent || draftStore.hasDraft)
    }
    private var hasDraftContent: Bool {
        selectedTime != nil || selectedIdea != nil || surpriseIdea != nil
            || !ownPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var draftSnapshot: Draft {
        Draft(stage: screen.rawValue, time: selectedTime?.rawValue, route: route.rawValue,
              selectedIdea: selectedIdea, ownPlan: ownPlan, surpriseIdea: surpriseIdea)
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
        .confirmationDialog("Keep this for later?", isPresented: $showsDiscardConfirmation,
                            titleVisibility: .visible) {
            Button("Save draft and close", action: saveDraftAndClose)
            Button("Keep writing", role: .cancel) { }
            Button("Discard draft", role: .destructive, action: discardDraftAndClose)
        } message: {
            Text("Your draft stays on this device. A saved timer will wait for you to start again.")
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
                    case .time:
                        timePage.frame(minHeight: max(0, geometry.size.height - 12))
                    case .plan:
                        planPage.frame(minHeight: max(0, geometry.size.height - 12))
                    case .note:
                        planNote.frame(minHeight: max(0, geometry.size.height - 12))
                    case .focus:
                        timerPage.frame(minHeight: max(0, geometry.size.height - 12))
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
        .onReceive(ticker) { updateTimer(at: $0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { updateTimer(at: Date()) }
            else { _ = persistDraft() }
        }
        .onDisappear {
            // Keep elapsed time accurate if the view is temporarily covered.
            // An explicit close cancels the session in close().
            if screen == .focus { updateTimer(at: Date()) }
            _ = persistDraft()
        }
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
            PlanArtwork(name: introImageName)
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

            Text("Make a Plan")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
            instruction(number: "1", text: "Choose how much time you have")
            instruction(number: "2", text: "Pick one small thing to do next")

            Spacer(minLength: 36)
            if draftStore.hasDraft {
                Text("Your draft is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            pinkButton(draftStore.hasDraft ? "Resume" : "Start") {
                draftSessionEnded = false
                isClosing = false
                if draftStore.hasDraft, let saved = draftStore.restore() {
                    applySavedDraft(saved)
                    screen = resumeScreen
                    // A restored preview needs to prepare the host's journal again.
                    if screen == .note, let time = selectedTime, !activePlan.isEmpty {
                        onSavePlan?(SmallPlan(time: time.rawValue, action: activePlan, source: route.rawValue))
                    }
                } else {
                    reset()
                    screen = .time
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

    private var timePage: some View {
        VStack(spacing: 20) {
            Text("What do you have room for right now?")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
            Text("A little time is enough.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
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
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            Text(selectedTime?.rawValue ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let routeLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 6))
                : AnyLayout(HStackLayout(spacing: 6))
            routeLayout {
                ForEach(Route.allCases, id: \.self) { option in
                    Button {
                        writing = false
                        route = option
                        if option == .surprise, surpriseIdea == nil { drawSurprise() }
                    } label: {
                        Text(option.rawValue)
                            .font(.footnote.weight(.medium))
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
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try another", action: drawSurprise)
                        .font(.body.weight(.medium))
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
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: route)
    }

    private func selectionRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.custom("ComingSoon-Regular", size: 18, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.light))
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
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
            ZStack(alignment: .topLeading) {
                if ownPlan.isEmpty {
                    Text("One small thing…")
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $ownPlan)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($writing)
                    .frame(height: editorHeight)
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
            .fill(paperColor)
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
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "pin")
                    .font(.title3.weight(.light))
                    .foregroundStyle(ink.opacity(0.65))
                    .frame(maxWidth: .infinity)

                Text(selectedTime?.leadIn ?? "")
                    .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(.secondary)
                Text(activePlan)
                    .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background { paperBackground }

            Text("Go give it a little time.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
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
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text(activePlan)
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(pink.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 20)

            Text(timeString(remaining))
                .font(.system(size: timerFontSize, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            ProgressView(value: elapsed, total: timerDuration)
                .tint(pink)
                .padding(.horizontal, 24)

            Text(startedAt == nil ? "Paused. Take your time." : "You can put your phone down.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
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
                    .font(.title3)
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
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)
            Text("You made some room for what you chose.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

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
        isClosing = false
        elapsed = 0
        savedTime = 0
        startedAt = Date()
        screen = .focus
    }

    private func updateTimer(at date: Date) {
        guard screen == .focus, !isClosing, !showsDiscardConfirmation else { return }
        if let start = startedAt {
            elapsed = min(timerDuration, savedTime + max(0, date.timeIntervalSince(start)))
        }
        // A pause may capture the deadline between ticks; it still needs completion.
        if elapsed >= timerDuration { finishSession() }
    }

    private func pauseTimer() {
        guard let start = startedAt else { return }
        elapsed = min(timerDuration, savedTime + max(0, Date().timeIntervalSince(start)))
        savedTime = elapsed
        startedAt = nil
    }

    private func finishSession() {
        guard screen == .focus, !isClosing, !showsDiscardConfirmation else { return }
        pauseTimer()
        guard (hostArchivesDraft ? persistDraft() : draftStore.discard()) else {
            draftExitAction = .complete
            return
        }
        draftSessionEnded = true
        screen = .complete
        // The same reward for finishing early or reaching the timer's end.
        onComplete(10)
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let whole = Int(ceil(seconds))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func reset() {
        isClosing = false
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

    private func restoreDraft() {
        guard !didRestoreDraft else { return }
        defer { didRestoreDraft = true }
        guard let saved = draftStore.restore() else { return }
        applySavedDraft(saved)
    }

    private func applySavedDraft(_ saved: Draft) {
        selectedTime = saved.time.flatMap(TimeChoice.init(rawValue:))
        route = Route(rawValue: saved.route) ?? .ideas
        ownPlan = saved.ownPlan
        let availableIdeas = selectedTime?.ideas ?? []
        selectedIdea = saved.selectedIdea.flatMap { availableIdeas.contains($0) ? $0 : nil }
        surpriseIdea = saved.surpriseIdea.flatMap { availableIdeas.contains($0) ? $0 : nil }
        elapsed = 0
        savedTime = 0
        startedAt = nil
        // Relaunch never starts a timer or grants points in the background.
        switch Screen(rawValue: saved.stage) {
        case .some(.note), .some(.focus):
            resumeScreen = selectedTime != nil && !activePlan.isEmpty ? .note : (selectedTime == nil ? .time : .plan)
        case .some(.plan):
            resumeScreen = selectedTime == nil ? .time : .plan
        default:
            resumeScreen = .time
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard didRestoreDraft, !draftSessionEnded, screen != .instructions, screen != .complete else { return true }
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
        case .some(.complete): finishSession()
        case .none: draftStore.retryLastOperation()
        }
    }

    private func discardDraftAndClose() {
        guard draftStore.discard() else { draftExitAction = .discardAndClose; return }
        close()
    }

    private func requestClose() {
        writing = false
        // Freeze while asking. Dismissing the dialog resumes normal completion checks.
        if screen == .focus { pauseTimer() }
        if hasUnsavedWriting { showsDiscardConfirmation = true }
        else { close() }
    }

    private func close() {
        draftExitAction = nil
        draftSessionEnded = true
        isClosing = true
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
