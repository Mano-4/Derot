import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct BreathingBoxView: View {
    // The team app can use these to save points and return to Home.
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?

    public init(onComplete: @escaping (Int) -> Void = { _ in }, onClose: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onClose = onClose
    }

    private enum Screen { case instructions, breathing, complete }
    @State private var screen: Screen = .instructions
    @State private var elapsed: TimeInterval = 0
    @State private var savedTime: TimeInterval = 0
    @State private var startedAt: Date? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: TimeInterval = 64
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let blue = Color(red: 0.67, green: 0.75, blue: 0.84)
    private let yellow = Color(red: 1, green: 0.90, blue: 0)

    private var phaseIndex: Int { Int(elapsed / 4) % 4 }
    private var phaseTitle: String {
        ["Breathe in", "Hold softly", "Breathe out", "Rest a moment"][phaseIndex]
    }
    private var phaseMessage: String {
        [
            "Let your breath arrive.",
            "A quiet pause.",
            "Let your shoulders soften.",
            "No rush. Begin again."
        ][phaseIndex]
    }
    private var secondsLeft: Int { 4 - Int(elapsed.truncatingRemainder(dividingBy: 4)) }

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
                            if screen == .breathing { categoryBadge }
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 56))
                    case .breathing:
                        breathing.frame(minHeight: max(0, geometry.size.height - 56))
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
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .onReceive(ticker) { date in
            guard screen == .breathing, let start = startedAt else { return }
            elapsed = min(duration, savedTime + max(0, date.timeIntervalSince(start)))
            if elapsed >= duration {
                finish()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pause() }
        }
        .onDisappear { pause() }
    }

    private var categoryBadge: some View {
        Label("Breathe", systemImage: "wind")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(blue, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            BoxRabbitArtwork(name: "breathe-intro")
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(blue.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                categoryBadge
                Label("About 1m", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Breathing Box")
                .font(.custom("ComingSoon-Regular", size: 34))

            instruction(number: "1", text: "Follow the light around the box")
            instruction(number: "2", text: "In for 4 · hold for 4 · out for 4 · hold for 4")
            Text("Keep it comfortable. You can pause or finish anytime.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 36)

            yellowButton("Start", action: start)
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
            Text(text).font(.system(size: 13))
        }
    }

    private var breathing: some View {
        VStack(spacing: 14) {
            Text("Breathing Box")
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer(minLength: 28)

            BoxBreathingGuide(
                elapsed: elapsed,
                secondsLeft: secondsLeft,
                title: phaseTitle,
                color: blue,
                reduceMotion: reduceMotion,
                paused: startedAt == nil
            )
            .frame(width: 280, height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(startedAt == nil ? "Paused" : phaseTitle)
            .accessibilityValue("\(secondsLeft) seconds")

            Text(startedAt == nil ? "Resume whenever you’re ready." : phaseMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Text("Round \(min(4, Int(elapsed / 16) + 1)) of 4")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer(minLength: 28)

            VStack(spacing: 8) {
                Button {
                    if startedAt == nil {
                        startedAt = Date()
                    } else {
                        pause()
                    }
                } label: {
                    Image(systemName: startedAt == nil ? "play.fill" : "pause.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.black, in: Circle())
                }
                .accessibilityLabel(startedAt == nil ? "Resume breathing" : "Pause breathing")

                Button("Finish", action: finish)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.bottom, 8)
        }
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 36)
            ZStack {
                BoxCelebrationConfetti()
                BoxRabbitArtwork(name: "breathe-celebration")
                    .frame(width: 170, height: 190)
                    .offset(y: 15)
            }
            .frame(width: 230, height: 220)
            Text("Good job!")
                .font(.custom("ComingSoon-Regular", size: 34))
            Text("Breathing Box · \(timeString(elapsed))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Label("+10 pts", systemImage: "star.fill")
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(yellow, in: Capsule())

            Spacer(minLength: 60)

            yellowButton("Back home", action: close)
        }
    }

    private func yellowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func start() {
        elapsed = 0
        savedTime = 0
        startedAt = Date()
        screen = .breathing
    }

    private func finish() {
        // Both the timer and Finish use this guard, awarding once per session.
        guard screen == .breathing else { return }
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


private struct BoxBreathingGuide: View {
    let elapsed: TimeInterval
    let secondsLeft: Int
    let title: String
    let color: Color
    let reduceMotion: Bool
    let paused: Bool

    private let side: CGFloat = 248
    private let radius: CGFloat = 28
    private var progress: Double { elapsed.truncatingRemainder(dividingBy: 16) / 16 }

    // Each four-second phase follows one edge and its rounded corner.
    private var marker: CGPoint {
        let quarter = CGFloat(progress * 4)
        let edge = Int(quarter)
        let fraction = quarter - CGFloat(edge)
        let straight = side - 2 * radius
        let distance = fraction * (straight + .pi * radius / 2)
        let point: CGPoint
        if distance <= straight {
            point = CGPoint(x: radius + distance, y: 0)
        } else {
            let angle = -.pi / 2 + (distance - straight) / radius
            point = CGPoint(
                x: side - radius + radius * cos(angle),
                y: radius + radius * sin(angle)
            )
        }
        switch edge {
        case 1: return CGPoint(x: side - point.y, y: point.x)
        case 2: return CGPoint(x: side - point.x, y: side - point.y)
        case 3: return CGPoint(x: point.y, y: side - point.x)
        default: return point
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                BoxBreathingTrack()
                    .stroke(color.opacity(0.25),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                BoxBreathingTrack()
                    .trim(from: 0, to: reduceMotion ? 1 : progress)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))

                if !reduceMotion {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .blur(radius: 3)
                        .overlay {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(color, lineWidth: 2))
                                .shadow(color: color.opacity(0.6), radius: 5)
                        }
                        .position(marker)
                }
            }
            .frame(width: side, height: side)
            // Skip the wraparound animation when a new round begins.
            .animation(
                reduceMotion || progress < 0.01 ? nil : .linear(duration: 0.1),
                value: elapsed
            )

            VStack(spacing: 12) {
                Text(paused ? "A little pause" : title)
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)

                Text(paused ? "—" : "\(secondsLeft)")
                    .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.53, blue: 0.67))
                    .monospacedDigit()

                Text(paused ? "take your time" : "seconds")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 200)
        }
    }
}

// Start at the top left and follow the square clockwise.
private struct BoxBreathingTrack: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(28, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct BoxCelebrationConfetti: View {
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
                        BoxConfettiCurl()
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

private struct BoxConfettiCurl: Shape {
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

private struct BoxRabbitArtwork: View {
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
    BreathingBoxView()
}
