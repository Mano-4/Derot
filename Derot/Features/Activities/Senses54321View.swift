import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
public struct HereAndNowView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let introImageName: String

    public init(onComplete: @escaping (Int) -> Void = { _ in }, onClose: (() -> Void)? = nil,
                introImageName: String = "notice-senses-intro") {
        self.onComplete = onComplete
        self.onClose = onClose
        self.introImageName = introImageName
    }

    private enum Screen { case instructions, noticing, complete }
    private struct Sense {
        let count: Int
        let name: String
        let prompt: String
        let hint: String
        let symbol: String
    }

    private let senses = [
        Sense(count: 5, name: "See",
              prompt: "Find five things you can see.",
              hint: "Look away from the screen. Let your eyes wander.",
              symbol: "eye"),
        Sense(count: 4, name: "Feel",
              prompt: "Notice four things you can feel.",
              hint: "Your feet on the floor. Fabric on your skin. What else?",
              symbol: "hand.raised"),
        Sense(count: 3, name: "Hear",
              prompt: "Listen for three things you can hear.",
              hint: "A sound nearby. A sound farther away. Take your time.",
              symbol: "ear"),
        Sense(count: 2, name: "Smell",
              prompt: "Notice two things you can smell.",
              hint: "Only what’s already around you. Nothing to find? You can skip.",
              symbol: "nose"),
        Sense(count: 1, name: "Taste",
              prompt: "Notice one thing you can taste.",
              hint: "Simply notice a taste already in your mouth, or skip.",
              symbol: "mouth")
    ]

    @State private var screen: Screen = .instructions
    @State private var step = 0
    @State private var noticed = 0
    @State private var cardPulse = false
    @ScaledMetric(relativeTo: .title2) private var counterHeight: CGFloat = 110
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var numberBadgeSize: CGFloat = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var yellow: Color {
        colorScheme == .dark
            ? Color(red: 0.38, green: 0.35, blue: 0.12)
            : Color(red: 250 / 255, green: 235 / 255, blue: 107 / 255)
    }
    private var surface: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        colorScheme == .dark ? .black : .white
        #endif
    }
    private var current: Sense { senses[step] }

    public var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    switch screen {
                    case .instructions:
                        instructions.frame(minHeight: max(0, geometry.size.height - 12))
                    case .noticing:
                        noticing.frame(minHeight: max(0, geometry.size.height - 12))
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if screen != .complete {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.automatic)
                    .accessibilityLabel("Close activity")
                }
            }
            ToolbarItem(placement: .principal) {
                if screen == .noticing { badge }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(screen == .complete ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        }
    }

    private var badge: some View {
        Label("Notice", systemImage: "eye")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(yellow, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            SensesArtwork(name: introImageName)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("At your pace", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("Here & Now")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))

            Text("Notice five things you can see, four things you can feel, three things you can hear, two things you can smell, and one thing you can taste.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                instruction(number: "1", text: "Notice one thing around you.")
                instruction(number: "2", text: "Take your time.")
                instruction(number: "3", text: "Tap the hand for each thing you notice.")
                instruction(number: "4", text: "Move to the next sense when you’re ready.")
            }

            Spacer(minLength: 12)
            yellowButton("Start") {
                step = 0
                noticed = 0
                screen = .noticing
            }
            Button("Pick something else", action: close)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func instruction(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.semibold))
                .frame(width: numberBadgeSize, height: numberBadgeSize)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(text)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noticing: some View {
        VStack(spacing: 20) {
            Text(current.prompt)
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, 18)

            Spacer(minLength: 30)

            counterCard

            Spacer(minLength: 30)

            yellowButton(step == senses.count - 1 ? "Finish" : "Next sense", action: advance)
                .disabled(noticed < current.count)
                .opacity(noticed == current.count ? 1 : 0.45)

            Button("Skip this sense", action: skip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var noticedMessage: String {
        switch noticed {
        case 1: return "One noticed"
        case 2: return "Two noticed"
        case 3: return "Three noticed"
        case 4: return "Four noticed"
        case 5: return "Five noticed"
        default: return "Ready?"
        }
    }

    private var counterCard: some View {
        Button {
            guard noticed < current.count else { return }
            cardPulse = false
            noticed += 1
        } label: {
            ZStack(alignment: .top) {
                // The card intentionally masks the wrist and palm.
                SensesCountingHand(count: noticed)
                    .frame(width: 190, height: 210)
                    .offset(y: -100)
                    .rotationEffect(.degrees(reduceMotion || noticed == 0 ? 0 : (noticed.isMultiple(of: 2) ? -1.5 : 1.5)))
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: noticed)

                VStack(spacing: 12) {
                    Text(noticedMessage)
                        .font(.custom("ComingSoon-Regular", size: 22, relativeTo: .title2))
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: noticed)

                    Image(systemName: noticed == current.count ? "checkmark" : "hand.tap")
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: counterHeight)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color(red: 0.25, green: 0.23, blue: 0.10) : Color(red: 1, green: 0.96, blue: 0.74))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.07), radius: 14, y: 7)
                }
            }
            .frame(minHeight: counterHeight + 32)
            .padding(.top, 100)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 340 : 230)
            .contentShape(Rectangle())
        }
        .buttonStyle(SensesCounterPressStyle(reduceMotion: reduceMotion))
        .scaleEffect(cardPulse && noticed == 0 ? 1.018 : 1)
        .frame(maxWidth: .infinity)
        .disabled(noticed == current.count)
        .accessibilityLabel("Count something you noticed")
        .accessibilityValue("\(noticed) of \(current.count)")
        .accessibilityHint("Activate after noticing one thing in your surroundings")
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: noticed)
        #endif
        .task(id: step) {
            cardPulse = false
            guard !reduceMotion else { return }
            // Two gentle invitations, then stay still so attention can return outside.
            for _ in 0..<2 {
                guard noticed == 0 else { return }
                withAnimation(.easeInOut(duration: 0.5)) { cardPulse = true }
                do { try await Task.sleep(for: .seconds(0.5)) } catch { return }
                withAnimation(.easeInOut(duration: 0.5)) { cardPulse = false }
                do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            }
        }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)
            SensesArtwork(name: "notice-senses-complete")
                .frame(width: 180, height: 200)
                .background {
                    Circle()
                        .fill(yellow.opacity(0.23))
                        .frame(width: 166, height: 166)
                }

            Text("You’re here.")
                .font(.custom("ComingSoon-Regular", size: 28, relativeTo: .title))
            Text("Feel your feet against the ground.\nStay a moment if you’d like.")
                .font(.custom("ComingSoon-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            Label("+10 pts", systemImage: "star.fill")
                .font(.subheadline.weight(.medium))
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
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func advance() {
        guard screen == .noticing, noticed == current.count else { return }
        moveToNextSense()
    }

    private func skip() {
        guard screen == .noticing else { return }
        moveToNextSense()
    }

    private func moveToNextSense() {
        if step < senses.count - 1 {
            step += 1
            noticed = 0
        } else {
            screen = .complete
            onComplete(10)
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
            step = 0
            noticed = 0
            screen = .instructions
        }
    }
}

// Existing ContentView calls keep working when replacing the original file.
public typealias Senses54321View = HereAndNowView

// Six illustrated hand poses replace the previous separate finger shapes.
// Add senses-counting-hands.png to the app target, or its named image set in Assets.
private struct SensesCountingHand: View {
    let count: Int

    private static let frames: [CGImage] = {
        let url: URL?
        #if SWIFT_PACKAGE
        url = Bundle.module.url(forResource: "senses-counting-hands", withExtension: "png")
        #else
        url = Bundle.main.url(forResource: "senses-counting-hands", withExtension: "png")
        #endif

        let original: CGImage?
        #if os(iOS)
        let sheet = UIImage(named: "senses-counting-hands") ??
            url.flatMap { UIImage(contentsOfFile: $0.path) }
        original = sheet?.cgImage
        #elseif canImport(AppKit)
        let sheet = NSImage(named: "senses-counting-hands") ??
            url.flatMap { NSImage(contentsOf: $0) }
        original = sheet?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        original = nil
        #endif
        guard let original else { return [] }

        // Bounds account for the full thumb on the five-finger illustration.
        let cuts: [CGFloat] = [0, 0.165, 0.325, 0.49, 0.655, 0.815, 1]
        let width = CGFloat(original.width)
        let height = CGFloat(original.height)
        return (0..<6).compactMap { index in
            original.cropping(to: CGRect(
                x: cuts[index] * width,
                y: height * 0.10,
                width: (cuts[index + 1] - cuts[index]) * width,
                height: height * 0.78
            ).integral)
        }
    }()

    var body: some View {
        ZStack {
            if Self.frames.count == 6 {
                Image(decorative: Self.frames[min(5, max(0, count))], scale: 1)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 5)
                    .id(count)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Image(systemName: "hand.raised")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SensesCounterPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SensesArtwork: View {
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
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HereAndNowView()
}
