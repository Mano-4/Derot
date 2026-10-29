import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Instructions + guided exercise. Your app supplies the ending through onFinish.
@MainActor
public struct NeckResetView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onFinish: (() -> Void)?

    public init(onComplete: @escaping (Int) -> Void = { _ in },
                onClose: (() -> Void)? = nil,
                onFinish: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onFinish = onFinish
    }

    @State private var isPracticing = false
    @State private var step = 0
    @State private var isPaused = false
    @State private var hasFinished = false
    @Environment(\.dismiss) private var dismiss

    private let green = Color(red: 174 / 255, green: 197 / 255, blue: 109 / 255)
    private let movements = NeckResetMovement.allCases
    private var movement: NeckResetMovement { movements[step] }
    private var isLast: Bool { step == movements.count - 1 }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    Group {
                        if isPracticing { practice }
                        else { introduction }
                    }
                    .frame(minHeight: max(0, geometry.size.height - 56))
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var topBar: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .light))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close activity")
            Spacer()
            if isPracticing { badge }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var badge: some View {
        Label("Move", systemImage: "figure.walk")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(green, in: RoundedRectangle(cornerRadius: 6))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            NeckResetAnimationView(isAnimating: false)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(green.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("About 1m · at your pace", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Neck Reset")
                .font(.custom("ComingSoon-Regular", size: 34))

            instruction("1", "Sit comfortably. Let your shoulders relax.")
            instruction("2", "Slowly look left and right, then gently tilt toward each shoulder.")
            instruction("3", "Return to center between movements. Choose Next when you’re ready.")

            Text("Keep every movement small and comfortable. Stop if you feel pain or dizziness.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 20)
        }
        .padding(.top, 8)
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.07), in: Circle())
            Text(text)
                .font(.system(size: 13))
                .frame(minHeight: 28, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var practice: some View {
        VStack(spacing: 16) {
            Text("Neck Reset")
                .font(.custom("ComingSoon-Regular", size: 34))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer(minLength: 16)

            NeckResetAnimationView(movement: movement,
                                   isAnimating: !isPaused && !hasFinished,
                                   showsInstructions: true)
                .id(movement)
                .frame(maxWidth: 340)

            ProgressView(value: Double(step + 1), total: Double(movements.count))
                .tint(green)
                .frame(width: 130)
                .accessibilityLabel("Movement \(step + 1) of \(movements.count)")
            Text("\(step + 1) of \(movements.count)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.black, in: Circle())
            }
            .accessibilityLabel(isPaused ? "Resume demonstration" : "Pause demonstration")
            .disabled(hasFinished)
        }
    }

    private var controls: some View {
        VStack(spacing: 4) {
            if isPracticing {
                primaryButton(isLast ? "Finish" : "Next", action: next)
                    .disabled(hasFinished)
                HStack {
                    Button("Skip this movement", action: next)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    if !isLast {
                        Button("Finish", action: finish)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .disabled(hasFinished)
            } else {
                primaryButton("Start") {
                    step = 0
                    isPaused = false
                    hasFinished = false
                    isPracticing = true
                }
                Button("Pick something else", action: close)
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(green, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func next() {
        guard isPracticing, !hasFinished else { return }
        if isLast { finish() }
        else {
            step += 1
            isPaused = false
        }
    }

    private func finish() {
        guard isPracticing, !hasFinished else { return }
        hasFinished = true
        isPaused = true
        onComplete(10)
        if let onFinish { onFinish() }
        else { close() }
    }

    private func close() {
        isPracticing = false
        step = 0
        isPaused = false
        hasFinished = false
        if let onClose { onClose() }
        else { dismiss() }
    }
}

public enum NeckResetMovement: Int, CaseIterable, Hashable {
    case lookLeft, lookRight, tiltLeft, tiltRight

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
            Text(returning ? "Slowly return to center." : movement.cue)
                .font(.custom("ComingSoon-Regular", size: 22))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60)
                .fixedSize(horizontal: false, vertical: true)
            Text(returning ? "Let your head rest before the next movement." : movement.detail)
                .font(.system(size: 13))
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
        let t = max(0, elapsed).truncatingRemainder(dividingBy: 10)
        if t < 1 { return NeckResetMotion(amount: 0, returning: false, showsArrow: false) }
        if t < 3.5 {
            return NeckResetMotion(amount: ease((t - 1) / 2.5),
                                   returning: false, showsArrow: true)
        }
        if t < 5.5 { return NeckResetMotion(amount: 1, returning: false, showsArrow: true) }
        if t < 8 {
            return NeckResetMotion(amount: 1 - ease((t - 5.5) / 2.5),
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
        let blend = movement.isTilt ? 0 : min(1, max(0, (amount - 0.35) / 0.3))
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
                .font(.system(size: 12))
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

