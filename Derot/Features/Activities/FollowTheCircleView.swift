import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct FollowTheCircleView: View {
    // The team app can use these to save points and return to Home.
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let introImageName: String

    public init(onComplete: @escaping (Int) -> Void = { _ in }, onClose: (() -> Void)? = nil,
                introImageName: String = "breathe-intro") {
        self.onComplete = onComplete
        self.onClose = onClose
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, breathing, complete }
    @State private var screen: Screen = .instructions
    @State private var elapsed: TimeInterval = 0
    @State private var savedTime: TimeInterval = 0
    @State private var startedAt: Date? = nil
    @State private var isOnScreen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var instructionNumberSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var pauseDiameter: CGFloat = 52
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: TimeInterval = 60
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var blue: Color {
        colorScheme == .dark
            ? Color(red: 0.55, green: 0.68, blue: 0.84)
            : Color(red: 0.67, green: 0.75, blue: 0.84)
    }
    private var surface: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.08, blue: 0.10) : .white
    }
    private let yellow = Color(red: 1, green: 0.90, blue: 0)

    private var breathingIn: Bool { elapsed.truncatingRemainder(dividingBy: 10) < 5 }
    private var circleScale: CGFloat {
        if reduceMotion { return 1 }
        let cycle = elapsed.truncatingRemainder(dividingBy: 10)
        let growth = cycle < 5 ? cycle / 5 : (10 - cycle) / 5
        return 0.64 + 0.36 * growth
    }

    public var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if screen != .complete {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: close) {
                                Label("Close activity", systemImage: "xmark")
                                    .labelStyle(.iconOnly)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.automatic)
                        }
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(screen == .complete ? .hidden : .visible, for: .navigationBar)
                #endif
        }
    }

    private var content: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if screen == .breathing {
                        categoryBadge.padding(.vertical, 8)
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .breathing:
                        breathing.frame(minHeight: max(0, geometry.size.height - 52))
                    case .complete:
                        completion.frame(minHeight: max(0, geometry.size.height - 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(surface.ignoresSafeArea())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .onAppear { isOnScreen = true }
        .onReceive(ticker) { date in
            guard isOnScreen, screen == .breathing, scenePhase == .active else { return }
            if let start = startedAt {
                elapsed = min(duration, savedTime + max(0, date.timeIntervalSince(start)))
            }
            // Pause can capture the deadline between ticks. Settle it even with no start date.
            if elapsed >= duration {
                finish()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pause() }
        }
        .onDisappear {
            isOnScreen = false
            pause()
        }
    }

    private var categoryBadge: some View {
        Label("Breathe", systemImage: "wind")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(blue, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.black)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            RabbitArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(blue.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                categoryBadge
                Label("1m", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Follow the circle")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            instruction(number: "1", text: "Breathe in as the circle grows")
            instruction(number: "2", text: "Breathe out as it shrinks")

            Spacer(minLength: 36)

            yellowButton("Start", action: start)
            Button("Pick something else", action: close)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.footnote)
                .frame(width: instructionNumberSize, height: instructionNumberSize)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var breathing: some View {
        VStack(spacing: 16) {
            Text("Follow the circle")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)

            Spacer(minLength: 30)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.045))
                ZStack {
                    Circle().fill(blue)
                    RabbitArtwork(name: "breathe-circle")
                        .padding(10)
                }
                .frame(width: 172, height: 172)
                .scaleEffect(circleScale)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: elapsed)
            }
            .frame(width: 240, height: 240)
            .accessibilityLabel(breathingIn ? "Breathe in" : "Breathe out")

            Spacer(minLength: 30)

            Text(startedAt == nil ? "Take your time" : (breathingIn ? "Make a little space" : "Let the tension go"))
                .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
            Text(startedAt == nil ? "Resume whenever you’re ready" : (breathingIn ? "Breathe in slowly" : "Breathe out gently"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 5) {
                ProgressView(value: elapsed, total: duration)
                    .tint(.cyan)
                HStack {
                    Text(timeString(elapsed))
                    Spacer()
                    Text("1:00")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding(.horizontal, 24)

            Button {
                if startedAt == nil {
                    startedAt = Date()
                } else {
                    pause()
                }
            } label: {
                Image(systemName: startedAt == nil ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                    .frame(width: pauseDiameter, height: pauseDiameter)
                    .background(colorScheme == .dark ? Color.white : Color.black, in: Circle())
            }
            .accessibilityLabel(startedAt == nil ? "Resume breathing" : "Pause breathing")

            Button("Finish", action: finish)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHint("Ends the session and shows your completion screen")
        }
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 36)
            ZStack {
                CelebrationConfetti()
                RabbitArtwork(name: "breathe-celebration")
                    .frame(width: 170, height: 190)
                    .offset(y: 15)
            }
            .frame(width: 230, height: 220)
            Text("Good job!")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
            Text("Follow the circle · \(timeString(elapsed))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label("+10 pts", systemImage: "star.fill")
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(yellow, in: Capsule())
                .foregroundStyle(.black)

            Spacer(minLength: 60)

            yellowButton("Back home", action: close)
        }
    }

    private func yellowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.black)
        }
    }

    private func start() {
        isOnScreen = true
        elapsed = 0
        savedTime = 0
        startedAt = Date()
        screen = .breathing
    }

    private func finish() {
        // Both the timer and Finish use this guard, awarding once per session.
        guard isOnScreen, screen == .breathing else { return }
        pause()
        screen = .complete
        onComplete(10)
    }

    private func pause() {
        guard let start = startedAt else { return }
        elapsed = min(duration, savedTime + max(0, Date().timeIntervalSince(start)))
        savedTime = elapsed
        startedAt = nil
    }

    private func close() {
        // Cancel immediately; a queued timer tick must never award points after X.
        isOnScreen = false
        pause()
        if let onClose {
            onClose()
        } else {
            dismiss()
            // Allows the standalone Xcode preview to be used again, too.
            screen = .instructions
            elapsed = 0
            savedTime = 0
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}


private struct CelebrationConfetti: View {
    private let colors: [Color] = [
        Color(red: 1, green: 0.80, blue: 0),
        Color(red: 0.95, green: 0.25, blue: 0.65),
        Color(red: 0.15, green: 0.70, blue: 0.95),
        Color(red: 0.25, green: 0.78, blue: 0.35)
    ]
    // Positions surround the rabbit's head, leaving its face clear.
    private let positions: [CGPoint] = [
        CGPoint(x: 0.13, y: 0.31), CGPoint(x: 0.22, y: 0.18),
        CGPoint(x: 0.34, y: 0.10), CGPoint(x: 0.47, y: 0.06),
        CGPoint(x: 0.62, y: 0.10), CGPoint(x: 0.76, y: 0.17),
        CGPoint(x: 0.87, y: 0.29), CGPoint(x: 0.10, y: 0.43),
        CGPoint(x: 0.18, y: 0.54), CGPoint(x: 0.85, y: 0.48),
        CGPoint(x: 0.91, y: 0.38), CGPoint(x: 0.30, y: 0.26),
        CGPoint(x: 0.71, y: 0.31), CGPoint(x: 0.82, y: 0.07),
        CGPoint(x: 0.23, y: 0.07), CGPoint(x: 0.12, y: 0.20)
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(positions.indices, id: \.self) { index in
                Group {
                    if index % 3 == 0 {
                        ConfettiCurl()
                            .stroke(colors[index % colors.count],
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 8, height: 15)
                    } else if index % 3 == 1 {
                        Capsule()
                            .fill(colors[index % colors.count])
                            .frame(width: 3, height: 9)
                    } else {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 4, height: 4)
                    }
                }
                .rotationEffect(.degrees(Double(index * 37)))
                .position(x: positions[index].x * geometry.size.width,
                          y: positions[index].y * geometry.size.height)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct ConfettiCurl: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.7),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.3)
        )
        return path
    }
}

private struct RabbitArtwork: View {
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
                // Add the transparent PNG with this name to Assets.xcassets.
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
    FollowTheCircleView()
}
