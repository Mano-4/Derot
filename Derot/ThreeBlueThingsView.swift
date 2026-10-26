import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct FindThreeThingsView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onChoosePhotos: ((String) -> Void)?

    // The team can attach its own photo flow here. No camera code lives in this view.
    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onChoosePhotos: ((String) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onChoosePhotos = onChoosePhotos
    }

    private enum RainbowColor: String, CaseIterable {
        case red, orange, yellow, green, blue, indigo, violet

        var swatch: Color {
            switch self {
            case .red: Color(red: 0.89, green: 0.27, blue: 0.30)
            case .orange: Color(red: 0.96, green: 0.55, blue: 0.22)
            case .yellow: Color(red: 0.90, green: 0.74, blue: 0.12)
            case .green: Color(red: 0.36, green: 0.65, blue: 0.42)
            case .blue: Color(red: 0.33, green: 0.60, blue: 0.84)
            case .indigo: Color(red: 0.36, green: 0.36, blue: 0.68)
            case .violet: Color(red: 0.66, green: 0.43, blue: 0.76)
            }
        }
    }

    private enum Screen { case instructions, activity, complete }
    private enum Mode { case writing, photos }
    @State private var screen: Screen = .instructions
    @State private var mode: Mode = .writing
    @State private var answers = ["", "", ""]
    @State private var selectedColor: RainbowColor = RainbowColor.allCases.randomElement() ?? .blue
    @FocusState private var focusedLine: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let yellow = Color(red: 250 / 255, green: 235 / 255, blue: 107 / 255)
    private var completedCount: Int {
        answers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if screen != .complete {
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .light))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close activity")
                    }

                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 56))
                    case .activity:
                        activity
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
        Label("Notice", systemImage: "eye")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(yellow, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            NoticeBlueArtwork(name: "notice-blue-intro")
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("1m", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            activityTitle

            instruction(number: "1", text: "Find three different \(selectedColor.rawValue) things")
            instruction(number: "2", text: "Write all three, or choose photos")

            Spacer(minLength: 36)
            yellowButton("Start") {
                answers = ["", "", ""]
                mode = .writing
                screen = .activity
            }
            Button("Pick something else", action: close)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var activityTitle: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("3")
            Text(selectedColor.rawValue)
                .padding(.horizontal, 5)
                .background {
                    ZStack {
                        NoticeColorBrush()
                            .fill(selectedColor.swatch.opacity(0.13))
                            .rotationEffect(.degrees(2))
                            .offset(x: 2, y: 2)

                        NoticeColorBrush()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        selectedColor.swatch.opacity(0.12),
                                        selectedColor.swatch.opacity(0.32),
                                        selectedColor.swatch.opacity(0.20)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .rotationEffect(.degrees(-2))

                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(.white.opacity(0.22))
                                .frame(height: 1)
                                .padding(.horizontal, 8)
                                .offset(y: CGFloat(index - 1) * 6)
                                .rotationEffect(.degrees(-1))
                        }
                    }
                    .frame(height: 27)
                    .offset(y: 5)
                    .accessibilityHidden(true)
                }
            Text("things")
        }
        .font(.custom("ComingSoon-Regular", size: 34))
        .foregroundStyle(.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("3 \(selectedColor.rawValue) things")
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

    private var activity: some View {
        VStack(alignment: .leading, spacing: 22) {
            badge
            activityTitle

            if mode == .writing {
                HStack {
                    Text("One thing on each line")
                        .font(.custom("ComingSoon-Regular", size: 22))
                    Spacer(minLength: 4)
                    Text("\(completedCount) of 3")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                paper

                VStack(spacing: 10) {
                    Text("Would you like to snap it instead?")
                        .font(.custom("ComingSoon-Regular", size: 18))
                        .multilineTextAlignment(.center)
                    Button {
                        focusedLine = nil
                        mode = .photos
                    } label: {
                        Label("Use photos instead", systemImage: "camera")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 20)
                            .frame(minHeight: 44)
                            .background(yellow.opacity(0.4), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                yellowButton("Finish", action: finish)
                    .disabled(completedCount != 3)
                    .opacity(completedCount == 3 ? 1 : 0.45)
            } else {
                photoChoice
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: mode)
    }

    private var paper: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.custom("ComingSoon-Regular", size: 22))
                            .foregroundStyle(.secondary)
                            .frame(width: 25, alignment: .leading)

                        TextField("Something \(selectedColor.rawValue)…", text: $answers[index], axis: .vertical)
                            .font(.custom("ComingSoon-Regular", size: 22))
                            .lineLimit(1...3)
                            .focused($focusedLine, equals: index)
                            .submitLabel(index == 2 ? .done : .next)
                            .onSubmit {
                                focusedLine = index < 2 ? index + 1 : nil
                            }
                            .accessibilityLabel("\(selectedColor.rawValue.capitalized) thing \(index + 1)")
                            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

                        if !answers[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && focusedLine != index {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.44, green: 0.56, blue: 0.35))
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                                .accessibilityLabel("Noticed")
                        }
                    }
                    .padding(.vertical, 22)

                    Rectangle()
                        .fill(Color(red: 0.70, green: 0.78, blue: 0.86).opacity(0.35))
                        .frame(height: 1)
                }
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7),
                    value: focusedLine
                )
            }
        }
        .padding(.leading, 25)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 1, green: 0.99, blue: 0.95))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.pink.opacity(0.18))
                        .frame(width: 1)
                        .padding(.leading, 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.black.opacity(0.04), lineWidth: 1)
        }
    }

    private var photoChoice: some View {
        VStack(spacing: 18) {
            Text("Three things, three photos")
                .font(.custom("ComingSoon-Regular", size: 22))
            HStack(spacing: 12) {
                ForEach(1..<4, id: \.self) { number in
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.system(size: 24, weight: .light))
                        Text("Photo \(number)")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // Your friend supplies this callback to open her three-photo flow.
            yellowButton("Take photos") { onChoosePhotos?(selectedColor.rawValue) }
                .disabled(onChoosePhotos == nil)
                .opacity(onChoosePhotos == nil ? 0.45 : 1)

            Button("Write them instead") { mode = .writing }
                .font(.system(size: 14, weight: .medium))
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 36)
            ZStack {
                NoticeBlueConfetti()
                NoticeBlueArtwork(name: "breathe-celebration")
                    .frame(width: 170, height: 190)
                    .offset(y: 15)
            }
            .frame(width: 230, height: 220)

            Text("Lovely noticing!")
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
            Text("3 \(selectedColor.rawValue) things · all found")
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
        .frame(maxWidth: .infinity)
    }

    private func yellowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func finish() {
        guard screen == .activity, mode == .writing, completedCount == 3 else { return }
        focusedLine = nil
        screen = .complete
        onComplete(10)
    }

    private func close() {
        focusedLine = nil
        if let onClose {
            onClose()
        } else {
            dismiss()
            answers = ["", "", ""]
            mode = .writing
            selectedColor = RainbowColor.allCases.randomElement() ?? .blue
            screen = .instructions
        }
    }
}


// Keeps existing ContentView calls working when replacing the original file.
public typealias ThreeBlueThingsView = FindThreeThingsView

// Uneven edges and translucent layers suggest a watercolor highlighter.
private struct NoticeColorBrush: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.025, 0.23))
        path.addLine(to: point(0.08, 0.12))
        path.addLine(to: point(0.30, 0.15))
        path.addQuadCurve(to: point(0.72, 0.09), control: point(0.53, 0.01))
        path.addLine(to: point(0.97, 0.16))
        path.addLine(to: point(0.94, 0.35))
        path.addLine(to: point(1, 0.50))
        path.addLine(to: point(0.96, 0.80))
        path.addLine(to: point(0.80, 0.87))
        path.addQuadCurve(to: point(0.35, 0.90), control: point(0.59, 0.78))
        path.addLine(to: point(0.06, 0.85))
        path.addLine(to: point(0.08, 0.68))
        path.addLine(to: point(0, 0.57))
        path.closeSubpath()
        return path
    }
}

private struct NoticeBlueConfetti: View {
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
                        NoticeBlueCurl()
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

private struct NoticeBlueCurl: Shape {
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

private struct NoticeBlueArtwork: View {
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
    FindThreeThingsView()
}
