import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A complete guided reset. Supply onFinish only to replace the built-in ending.
@MainActor
public struct NeckResetView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onFinish: (() -> Void)?
    private let introImageName: String

    public init(onComplete: @escaping (Int) -> Void = { _ in },
                onClose: (() -> Void)? = nil,
                onFinish: (() -> Void)? = nil,
                introImageName: String = "move-neck-intro") {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onFinish = onFinish
        self.introImageName = introImageName
    }

    private enum Stage: Equatable { case introduction, meetRabbit, practice, complete }
    @State private var stage: Stage = .introduction
    @State private var guide = NeckResetHoldGuide()
    @State private var hasFinished = false
    @State private var isOnScreen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var numberSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var timerMinimumHeight: CGFloat = 64

    private var green: Color {
        colorScheme == .dark
            ? Color(red: 0.28, green: 0.36, blue: 0.13)
            : Color(red: 174 / 255, green: 197 / 255, blue: 109 / 255)
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
    private let ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private var isPracticing: Bool { stage == .practice }
    private var movement: NeckResetMovement { guide.movement }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    public var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Group {
                        switch stage {
                        case .introduction: introduction
                        case .meetRabbit: meetRabbit
                        case .practice: practice
                        case .complete: completion.transition(.opacity)
                        }
                    }
                    .frame(minHeight: max(0, geometry.size.height - 12))
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .background(surface.ignoresSafeArea())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .toolbar {
            if stage != .complete {
                if stage != .introduction {
                    ToolbarItem(placement: .principal) { badge }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close activity")
                    .buttonStyle(.automatic)
                }
            }
        }
        #if os(iOS)
        .toolbar(stage == .complete ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        }
        .onAppear { isOnScreen = true }
        .onReceive(ticker) { _ in
            guard isOnScreen, isPracticing, !hasFinished, scenePhase == .active else { return }
            // A pause/background event can land exactly on the final return boundary.
            if guide.phase == .complete { finish(); return }
            guard !guide.isPaused, guide.phase != .ready else { return }
            guide.update(at: now, reduceMotion: reduceMotion)
            if guide.phase == .complete { finish() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, isPracticing, !hasFinished {
                guide.pause(at: now, reduceMotion: reduceMotion)
            }
        }
        .onChange(of: reduceMotion) { _, _ in
            guard isPracticing, !hasFinished, !guide.isPaused else { return }
            guide.update(at: now, reduceMotion: reduceMotion)
        }
        .onDisappear {
            isOnScreen = false
            if isPracticing { guide.pause(at: now, reduceMotion: reduceMotion) }
        }
    }

    private var badge: some View {
        Label("Move", systemImage: "figure.walk")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(green, in: RoundedRectangle(cornerRadius: 6))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            NeckResetIntroArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(green.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Text("Four gentle holds")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Neck Reset")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            instruction("1", "Sit comfortably. Let your shoulders relax.")
            instruction("2", "Follow Mr. Rabbit as he looks and tilts to each side.")
            instruction("3", "Aim for ten seconds per hold. Pause or move on whenever you’re ready.")

            Text("Keep every movement small and comfortable. Stop if you feel pain or dizziness.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 20)
        }
        .padding(.top, 8)
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.footnote)
                .frame(width: numberSize, height: numberSize)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text)
                .font(.body)
                .frame(minHeight: 28, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var meetRabbit: some View {
        VStack(spacing: 16) {
            Text("Neck Reset")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer(minLength: 20)
            NeckResetAnimationView(isAnimating: false)
                .frame(maxWidth: 340)
                .frame(height: 260)
            Text("Follow Mr. Rabbit")
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
            Text("Get comfortable. Start when you’re ready.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 20)
        }
    }

    private var practice: some View {
        VStack(spacing: 8) {
            Text("Neck Reset")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Text(movement.shortTitle)
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)

            Text(phaseInstruction)
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Spacer(minLength: 12)

            // The activity controls the pose directly. It never uses a repeating animation.
            NeckResetDrawing(movement: movement, amount: guide.amount,
                             showsArrow: guide.phase == .positioning)
                .aspectRatio(360.0 / 370.0, contentMode: .fit)
                .frame(height: 270)
                .frame(maxWidth: 340)

            holdTimer

            Spacer(minLength: 16)
        }
    }

    private var holdTimer: some View {
        Group {
            if guide.phase == .holding || guide.phase == .ready {
                VStack(spacing: 2) {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 2))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 7))
                    layout {
                        Text("\(guide.secondsRemaining)")
                            .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                            .monospacedDigit()
                        Text("seconds")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(guide.isPaused ? "Paused" : (guide.phase == .ready ? "Hold complete" : "Hold gently"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(guide.secondsRemaining) seconds remaining\(guide.isPaused ? ", paused" : "")")
            } else {
                Text(guide.isPaused ? "Paused" : "Move gently")
                    .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: timerMinimumHeight)
    }

    private var phaseInstruction: String {
        if guide.isPaused { return "Continue whenever you’re ready." }
        switch guide.phase {
        case .positioning: return "Move slowly with Mr. Rabbit."
        case .holding: return "Stay here comfortably."
        case .ready: return "Move on whenever you’re ready."
        case .returning, .complete: return "Take your time."
        }
    }

    private var completion: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            Text("A little time for you.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
                .multilineTextAlignment(.center)

            NeckResetDrawing(movement: .lookRight, amount: 0, showsArrow: false)
                .frame(width: 230, height: 236)
                .accessibilityHidden(true)

            Text("You gave your body a moment.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)

            Label("+10 pts", systemImage: "star.fill")
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(green.opacity(0.45), in: Capsule())

            Spacer(minLength: 28)
        }
    }

    private var controls: some View {
        VStack(spacing: 4) {
            switch stage {
            case .practice:
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Button(guide.isPaused ? "Continue" : "Pause") {
                        if guide.isPaused { guide.resume(at: now, reduceMotion: reduceMotion) }
                        else { guide.pause(at: now, reduceMotion: reduceMotion) }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(green.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(green.opacity(0.4), lineWidth: 1))

                    primaryButton(guide.isLast || guide.isFinishing ? "Finish" : "Next", action: next)
                        .disabled(!guide.canAdvance)
                }
                .disabled(hasFinished)

                Button("End early", action: endEarly)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(hasFinished)
            case .meetRabbit:
                primaryButton("I’m ready", action: beginPractice)
            case .introduction:
                primaryButton("Continue", action: showRabbit)
                Button("Pick something else", action: close)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
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
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(green, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func showRabbit() {
        guard stage == .introduction else { return }
        guide = NeckResetHoldGuide()
        hasFinished = false
        stage = .meetRabbit
    }

    private func beginPractice() {
        guard stage == .meetRabbit else { return }
        guide.start(at: now, reduceMotion: reduceMotion)
        stage = .practice
    }

    private func next() {
        guard isPracticing, !hasFinished else { return }
        guide.requestNext(at: now, reduceMotion: reduceMotion)
    }

    private func endEarly() {
        guard isPracticing, !hasFinished else { return }
        guide.requestFinish(at: now, reduceMotion: reduceMotion)
    }

    private func finish() {
        guard isPracticing, !hasFinished else { return }
        hasFinished = true
        guide.pause(at: now, reduceMotion: reduceMotion)
        onComplete(10)
        if let onFinish { onFinish() }
        else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                stage = .complete
            }
        }
    }

    private func close() {
        stage = .introduction
        guide = NeckResetHoldGuide()
        hasFinished = false
        if let onClose { onClose() }
        else { dismiss() }
    }
}

@MainActor
private struct NeckResetIntroArtwork: View {
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
                Image(name).resizable().scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Foreground-only timing. Each hold begins with a fresh full ten seconds.
struct NeckResetHoldGuide {
    enum Phase: Equatable { case positioning, holding, ready, returning, complete }
    static let order: [NeckResetMovement] = [.lookRight, .lookLeft, .tiltRight, .tiltLeft]
    private(set) var index = 0
    private(set) var phase: Phase = .positioning
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPaused = true
    private(set) var isFinishing = false
    private var savedElapsed: TimeInterval = 0
    private var startedAt: TimeInterval?
    private var returnStartAmount: Double = 1

    var movement: NeckResetMovement { Self.order[index] }
    var isLast: Bool { index == Self.order.count - 1 }
    var canAdvance: Bool { phase != .complete }
    var secondsRemaining: Int { max(0, Int(ceil(10 - elapsed))) }
    private var returnDuration: TimeInterval { max(0.12, 2.5 * returnStartAmount) }
    var amount: Double {
        switch phase {
        case .positioning: return Self.ease(min(1, max(0, elapsed / 2.5)))
        case .holding, .ready: return 1
        case .returning: return returnStartAmount * (1 - Self.ease(min(1, max(0, elapsed / returnDuration))))
        case .complete: return 0
        }
    }

    mutating func start(at time: TimeInterval, reduceMotion: Bool) {
        self = Self()
        isPaused = false
        begin(reduceMotion ? .holding : .positioning, at: time)
    }

    mutating func update(at time: TimeInterval, reduceMotion: Bool) {
        guard !isPaused, phase != .ready, phase != .complete else { return }
        if reduceMotion, phase == .positioning { begin(.holding, at: time); return }
        if reduceMotion, phase == .returning { advanceAfterReturn(at: time, reduceMotion: true); return }
        guard let startedAt else { return }
        elapsed = savedElapsed + max(0, time - startedAt)
        switch phase {
        case .positioning:
            if elapsed >= 2.5 {
                // Do not subtract a delayed positioning frame from the user's hold.
                begin(.holding, at: time)
            }
        case .holding:
            if elapsed >= 10 {
                elapsed = 10
                savedElapsed = 10
                phase = .ready
                self.startedAt = nil
            }
        case .returning:
            if elapsed >= returnDuration { advanceAfterReturn(at: time, reduceMotion: reduceMotion) }
        case .ready, .complete:
            break
        }
    }

    mutating func requestNext(at time: TimeInterval, reduceMotion: Bool) {
        guard canAdvance else { return }
        // An in-flight Next request stays one transition, even with repeated taps.
        // Check before update so a tap at the boundary cannot skip the new side.
        if phase == .returning {
            if isPaused { resume(at: time, reduceMotion: reduceMotion) }
            return
        }
        if !isPaused { update(at: time, reduceMotion: reduceMotion) }
        returnStartAmount = amount
        isPaused = false
        // Return from the actual angle, including a partially reached or paused pose.
        begin(.returning, at: time)
    }

    mutating func requestFinish(at time: TimeInterval, reduceMotion: Bool) {
        guard canAdvance else { return }
        isFinishing = true
        requestNext(at: time, reduceMotion: reduceMotion)
    }

    mutating func pause(at time: TimeInterval, reduceMotion: Bool) {
        guard !isPaused else { return }
        update(at: time, reduceMotion: reduceMotion)
        savedElapsed = elapsed
        startedAt = nil
        isPaused = true
    }

    mutating func resume(at time: TimeInterval, reduceMotion: Bool) {
        guard isPaused, phase != .complete else { return }
        isPaused = false
        savedElapsed = elapsed
        startedAt = phase == .ready ? nil : time
        if reduceMotion, phase == .positioning { begin(.holding, at: time) }
        else if reduceMotion, phase == .returning { advanceAfterReturn(at: time, reduceMotion: true) }
    }

    private mutating func begin(_ next: Phase, at time: TimeInterval) {
        phase = next
        elapsed = 0
        savedElapsed = 0
        startedAt = time
    }

    private mutating func advanceAfterReturn(at time: TimeInterval, reduceMotion: Bool) {
        if isFinishing || index == Self.order.count - 1 {
            phase = .complete
            elapsed = 0
            savedElapsed = 0
            startedAt = nil
        } else {
            index += 1
            begin(reduceMotion ? .holding : .positioning, at: time)
        }
    }

    private static func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}

public enum NeckResetMovement: Int, CaseIterable, Hashable {
    case lookLeft, lookRight, tiltLeft, tiltRight

    fileprivate var shortTitle: String {
        switch self {
        case .lookLeft: return "Look left"
        case .lookRight: return "Look right"
        case .tiltLeft: return "Tilt left"
        case .tiltRight: return "Tilt right"
        }
    }

    fileprivate var isTilt: Bool { self == .tiltLeft || self == .tiltRight }
    // Demonstrator's left appears on the viewer's right.
    fileprivate var side: Double { self == .lookLeft || self == .tiltLeft ? 1 : -1 }
    fileprivate var targetHead: Int { self == .lookLeft ? 1 : (self == .lookRight ? 2 : 0) }
    fileprivate var cue: String {
        switch self {
        case .lookLeft: return "Slowly look to your left."
        case .lookRight: return "Slowly look to your right."
        case .tiltLeft: return "Gently tilt toward your left shoulder."
        case .tiltRight: return "Gently tilt toward your right shoulder."
        }
    }
    fileprivate var detail: String {
        isTilt ? "Keep your shoulder down. Let your head move toward it."
               : "Keep your chin level and your shoulders facing forward."
    }
}

/// Reusable demonstration if you also want the rabbit on a custom page.
@MainActor
public struct NeckResetAnimationView: View {
    private let movement: NeckResetMovement
    private let isAnimating: Bool
    private let showsInstructions: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var isVisible = false

    public init(movement: NeckResetMovement = .tiltLeft,
                isAnimating: Bool = true, showsInstructions: Bool = false) {
        self.movement = movement
        self.isAnimating = isAnimating
        self.showsInstructions = showsInstructions
    }

    private var canAnimate: Bool {
        isAnimating && isVisible && scenePhase == .active && !reduceMotion
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !canAnimate)) { context in
            let sample = canAnimate
                ? NeckResetMotion.sample(context.date.timeIntervalSince(startedAt))
                : NeckResetMotion(amount: reduceMotion && isAnimating ? 1 : 0,
                                  returning: false, showsArrow: reduceMotion && isAnimating)
            VStack(spacing: 14) {
                NeckResetDrawing(movement: movement, amount: sample.amount,
                                 showsArrow: sample.showsArrow)
                    .aspectRatio(360.0 / 370.0, contentMode: .fit)
                    .frame(height: showsInstructions ? 260 : nil)
                if showsInstructions {
                    instructionText(returning: sample.returning)
                }
            }
        }
        .onAppear { restart(); isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: movement) { _, _ in restart() }
        .onChange(of: isAnimating) { _, _ in restart() }
        .onChange(of: reduceMotion) { _, _ in restart() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { restart() }
        }
    }

    private func instructionText(returning: Bool) -> some View {
        VStack(spacing: 10) {
            Text(!isAnimating ? "Take a moment." : (returning ? "Take your time." : movement.cue))
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60)
                .fixedSize(horizontal: false, vertical: true)
            Text(!isAnimating ? "Continue whenever you’re ready." :
                    (returning ? "Let your head rest before the next movement." : movement.detail))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    private func restart() { startedAt = Date() }
}

private struct NeckResetMotion {
    let amount: Double
    let returning: Bool
    let showsArrow: Bool

    static func sample(_ elapsed: TimeInterval) -> NeckResetMotion {
        // Begin on the first frame. Keep the outward/return movement gentle.
        let t = max(0, elapsed).truncatingRemainder(dividingBy: 8.5)
        if t < 2.5 {
            return NeckResetMotion(amount: ease(t / 2.5),
                                   returning: false, showsArrow: true)
        }
        if t < 4 { return NeckResetMotion(amount: 1, returning: false, showsArrow: true) }
        if t < 6.5 {
            return NeckResetMotion(amount: 1 - ease((t - 4) / 2.5),
                                   returning: true, showsArrow: false)
        }
        return NeckResetMotion(amount: 0, returning: true, showsArrow: false)
    }

    private static func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}

@MainActor
private struct NeckResetDrawing: View {
    let movement: NeckResetMovement
    let amount: Double
    let showsArrow: Bool
    private let green = Color(red: 174 / 255, green: 197 / 255, blue: 109 / 255)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 370)
            Group {
                if let art = NeckResetArtwork.layers {
                    layers(art, scale: scale)
                } else {
                    missingArtwork
                }
            }
            .frame(width: 360 * scale, height: 370 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func layers(_ art: NeckResetLayers, scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image(decorative: art.shoulders, scale: 1, orientation: .up)
                .resizable().interpolation(.high)
                .frame(width: 220 * scale, height: 68.75 * scale)
                .position(x: 180 * scale, y: 290.375 * scale)

            head(art, scale: scale)
                .rotationEffect(.degrees(movement.isTilt ? movement.side * 10 * amount : 0),
                                anchor: UnitPoint(x: 0.5, y: 0.94))
                .rotation3DEffect(.degrees(movement.isTilt ? 0 : movement.side * 10 * amount),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.15)
                .position(x: 180 * scale, y: (20 + 252 * 570 / 550 / 2) * scale)

            directionCue(scale: scale)
                .opacity(showsArrow ? min(1, amount * 4) * 0.85 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(movement.cue)
    }

    private func head(_ art: NeckResetLayers, scale: CGFloat) -> some View {
        // The turn uses a true three-quarter drawing plus a little perspective motion.
        let blend = movement.isTilt ? 0 : min(1, max(0, amount / 0.15))
        return ZStack {
            headImage(art.heads[0]).opacity(1 - blend)
            if !movement.isTilt {
                headImage(art.heads[movement.targetHead]).opacity(blend)
            }
        }
        .frame(width: 252 * scale, height: (252 * 570 / 550) * scale)
    }

    private func headImage(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 1, orientation: .up)
            .resizable().interpolation(.high)
    }

    @ViewBuilder
    private func directionCue(scale: CGFloat) -> some View {
        let x: CGFloat = movement.side > 0 ? 338 : 22
        if movement.isTilt {
            NeckResetCurvedArrow()
                .stroke(green, style: StrokeStyle(lineWidth: 2.5 * scale,
                                                  lineCap: .round, lineJoin: .round))
                .scaleEffect(x: movement.side > 0 ? -1 : 1, y: 1)
                .frame(width: 28 * scale, height: 60 * scale)
                .position(x: x * scale, y: 151 * scale)
        } else {
            Image(systemName: movement.side > 0 ? "arrow.right" : "arrow.left")
                .font(.system(size: 22 * scale, weight: .medium))
                .foregroundStyle(green)
                .position(x: x * scale, y: 221 * scale)
        }
    }

    private var missingArtwork: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 30, weight: .light))
            #if DEBUG
            Text("Rabbit artwork is missing")
                .font(.system(size: 14, weight: .medium))
            Text("Add NeckResetAssets.xcassets from the download to your app target.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            #endif
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NeckResetCurvedArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let end = CGPoint(x: rect.width * 0.32, y: rect.height * 0.86)
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.1))
        p.addQuadCurve(to: end, control: CGPoint(x: 0, y: rect.height * 0.35))
        p.move(to: CGPoint(x: rect.width * 0.06, y: rect.height * 0.7))
        p.addLine(to: end)
        p.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.77))
        return p
    }
}

private struct NeckResetLayers {
    let heads: [CGImage]
    let shoulders: CGImage
}

@MainActor
private enum NeckResetArtwork {
    static let layers: NeckResetLayers? = {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = .module
        #else
        bundle = .main
        #endif
        let original: CGImage?
        #if canImport(UIKit)
        let url = bundle.url(forResource: "neck-reset-motion", withExtension: "png")
            ?? bundle.url(forResource: "neck-reset-motion", withExtension: "png", subdirectory: "Resources")
        let image = UIImage(named: "neck-reset-motion", in: bundle, compatibleWith: nil)
            ?? url.flatMap { UIImage(contentsOfFile: $0.path) }
        original = image?.cgImage
        #elseif canImport(AppKit)
        let url = bundle.url(forResource: "neck-reset-motion", withExtension: "png")
            ?? bundle.url(forResource: "neck-reset-motion", withExtension: "png", subdirectory: "Resources")
        let image = url.flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(named: "neck-reset-motion")
        original = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        original = nil
        #endif
        guard let original else { return nil }
        // Measured crops align the chin in all three heads and preserve both ears.
        let factor = CGFloat(original.width) / 1254
        let rectangles: [CGRect] = [
            CGRect(x: 43, y: 40, width: 550, height: 570),
            CGRect(x: 700, y: 40, width: 550, height: 570),
            CGRect(x: 20, y: 642, width: 550, height: 570),
            CGRect(x: 707, y: 1007, width: 480, height: 150)
        ]
        let frames = rectangles.compactMap { rect in
            original.cropping(to: CGRect(x: rect.minX * factor, y: rect.minY * factor,
                                        width: rect.width * factor, height: rect.height * factor).integral)
        }
        guard frames.count == 4 else { return nil }
        return NeckResetLayers(heads: Array(frames.prefix(3)), shoulders: frames[3])
    }()
}

#Preview {
    NeckResetView()
}


