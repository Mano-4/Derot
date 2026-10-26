import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct CountEightBreathsView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?

    public init(onComplete: @escaping (Int) -> Void = { _ in }, onClose: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onClose = onClose
    }

    private enum Screen { case instructions, counting, complete }
    @State private var screen: Screen = .instructions
    @State private var count = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let blue = Color(red: 0.67, green: 0.75, blue: 0.84)
    private let yellow = Color(red: 1, green: 0.90, blue: 0)

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
                        }
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 56))
                    case .counting:
                        counting.frame(minHeight: max(0, geometry.size.height - 56))
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
        .task(id: count) {
            guard count == 8, screen == .counting else { return }
            // Let the user see the eighth petal before showing the celebration.
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
            guard screen == .counting, count == 8 else { return }
            screen = .complete
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            CountBreathsArtwork(name: "breathe-intro")
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(blue.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Label("Breathe", systemImage: "wind")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(blue, in: RoundedRectangle(cornerRadius: 6))
                Label("1m", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Count 8 Breaths")
                    .font(.custom("ComingSoon-Regular", size: 34))
                Text("Bring your attention back")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            instruction(number: "1", text: "Breathe at your own pace")
            instruction(number: "2", text: "Tap anywhere after each breath out")

            Spacer(minLength: 36)
            yellowButton("Start") {
                count = 0
                screen = .counting
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
            Text(text).font(.system(size: 13))
        }
    }

    private var counting: some View {
        Button(action: recordBreath) {
            VStack(spacing: 12) {
                Spacer(minLength: 24)

                CountBreathsArtwork(name: "count-breaths-rabbit")
                    .frame(width: 140, height: 140)

                Text("\(count) of 8 breaths")
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .monospacedDigit()
                    .padding(.top, 6)

                Text(count == 8 ? "A little calm, in full bloom." : "One breath, one petal.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                CountBreathsFlower(count: count, color: blue)
                    .frame(maxWidth: .infinity)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.8),
                        value: count
                    )

                Text(count == 8 ? "Your flower is complete" : "Tap after each breath out")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Count a breath")
        .accessibilityValue("\(count) of 8 breaths")
        .accessibilityHint("Activate after breathing out")
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 36)
            ZStack {
                CountBreathsConfetti()
                CountBreathsArtwork(name: "breathe-celebration")
                    .frame(width: 170, height: 190)
                    .offset(y: 15)
            }
            .frame(width: 230, height: 220)

            Text("Excellent!")
                .font(.custom("ComingSoon-Regular", size: 34))
            Text("Count 8 breaths · 8 breaths completed")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Label("+15 pts", systemImage: "star.fill")
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

    private func recordBreath() {
        guard screen == .counting, count < 8 else { return }
        count += 1
        if count == 8 {
            onComplete(15)
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
            screen = .instructions
            count = 0
        }
    }
}

private struct CountBreathsFlower: View {
    let count: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.96, green: 0.97, blue: 1))
                .frame(width: 192, height: 192)
                .offset(y: -25)

            // A gently curved stem and two small sage-green leaves.
            CountBreathsStem()
                .stroke(Color(red: 0.53, green: 0.67, blue: 0.48),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 28, height: 135)
                .offset(x: 4, y: 38)

            Ellipse()
                .fill(Color(red: 0.72, green: 0.82, blue: 0.64).gradient)
                .frame(width: 38, height: 17)
                .rotationEffect(.degrees(35))
                .offset(x: -12, y: 56)
            Ellipse()
                .fill(Color(red: 0.65, green: 0.77, blue: 0.59).gradient)
                .frame(width: 38, height: 17)
                .rotationEffect(.degrees(-35))
                .offset(x: 21, y: 78)

            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    if index < count {
                        CountBreathsPetal()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.87, blue: 0.98),
                                        color
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay {
                                CountBreathsPetal()
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            }
                            .overlay(alignment: .center) {
                                Capsule()
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 1, height: 22)
                                    .offset(y: 12)
                            }
                            .frame(width: 42, height: 66)
                            .offset(y: -39)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .shadow(color: color.opacity(0.18), radius: 3, y: 2)
                            .transition(.scale(scale: 0.1).combined(with: .opacity))
                    }
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1, green: 0.93, blue: 0.59),
                                Color(red: 1, green: 0.79, blue: 0.22)
                            ],
                            center: .topLeading, startRadius: 2, endRadius: 42
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle().stroke(.white.opacity(0.75), lineWidth: 1.5)
                    }
                    .shadow(color: .orange.opacity(0.12), radius: 4, y: 2)

                // Tiny golden seeds give the center a little texture.
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(Color(red: 0.85, green: 0.59, blue: 0.16).opacity(0.45))
                        .frame(width: 2, height: 2)
                        .offset(y: -11)
                        .rotationEffect(.degrees(Double(index) * 360 / 7))
                }
            }
            .offset(y: -32)
        }
        .frame(width: 220, height: 260)
        .accessibilityHidden(true)
    }
}

private struct CountBreathsPetal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX - rect.width * 0.15, y: rect.height * 0.66),
            control2: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY),
            control2: CGPoint(x: rect.maxX + rect.width * 0.15, y: rect.height * 0.66)
        )
        return path
    }
}

private struct CountBreathsStem: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.35),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.65)
        )
        return path
    }
}

private struct CountBreathsConfetti: View {
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
                        CountBreathsCurl()
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

private struct CountBreathsCurl: Shape {
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

private struct CountBreathsArtwork: View {
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
    CountEightBreathsView()
}
