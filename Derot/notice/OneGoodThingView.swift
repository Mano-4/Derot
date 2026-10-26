import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct OneGoodThingView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveEntry: ((String) -> Void)?

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveEntry: ((String) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveEntry = onSaveEntry
    }

    private enum Screen { case instructions, journal, complete }
    @State private var screen: Screen = .instructions
    @State private var entry = ""
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    private let yellow = Color(red: 250 / 255, green: 235 / 255, blue: 107 / 255)
    private var trimmedEntry: String {
        entry.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
                    case .journal:
                        journal
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
            GoodThingArtwork(name: "notice-good-intro")
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                badge
                Label("At your pace", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text("One good thing")
                .font(.custom("ComingSoon-Regular", size: 34))

            instruction(number: "1", text: "Think of something good, big or small")
            instruction(number: "2", text: "Write a little about it, in your own words")

            Spacer(minLength: 36)
            yellowButton("Start") {
                entry = ""
                screen = .journal
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

    private var journal: some View {
        VStack(alignment: .leading, spacing: 20) {
            badge
            Text("One good thing")
                .font(.custom("ComingSoon-Regular", size: 34))

            Text("What’s one good thing you’d like to remember?")
                .font(.custom("ComingSoon-Regular", size: 22))

            Text("A kind interaction, a small win, or something you’re glad is in your life.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("A little good")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 5)

                ZStack(alignment: .topLeading) {
                    if entry.isEmpty {
                        Text("It can be something small…")
                            .font(.custom("ComingSoon-Regular", size: 22))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $entry)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .font(.custom("ComingSoon-Regular", size: 22))
                        .lineSpacing(8)
                        .scrollContentBackground(.hidden)
                        .focused($writing)
                        .frame(height: 320)
                        .accessibilityLabel("Your one good thing")
                }
            }
            .padding(.leading, 28)
            .padding(.trailing, 18)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 1, green: 0.99, blue: 0.95))
                    .overlay {
                        GoodThingPaperRules()
                            .stroke(Color(red: 0.70, green: 0.78, blue: 0.86).opacity(0.3), lineWidth: 0.7)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.pink.opacity(0.18))
                            .frame(width: 1)
                            .padding(.leading, 18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }

            Text("A few words are enough. More is welcome, too.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            yellowButton("Finish", action: finish)
                .disabled(trimmedEntry.isEmpty)
                .opacity(trimmedEntry.isEmpty ? 0.45 : 1)
        }
        .padding(.top, 10)
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)

            ZStack {
                Circle()
                    .fill(yellow.opacity(0.22))
                    .frame(width: 166, height: 166)
                GoodThingArtwork(name: "notice-good-listening")
                    .frame(width: 170, height: 190)
                Image(systemName: "heart")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color(red: 0.83, green: 0.60, blue: 0.24))
                    .rotationEffect(.degrees(12))
                    .offset(x: 85, y: -62)
                Image(systemName: "heart")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color(red: 0.83, green: 0.60, blue: 0.24).opacity(0.65))
                    .rotationEffect(.degrees(-15))
                    .offset(x: -82, y: -42)
            }
            .frame(height: 220)

            Text("That matters.")
                .font(.custom("ComingSoon-Regular", size: 28))
            Text("Thank you for sharing your good thing.\nBig or small, it deserves to be remembered.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

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
        guard screen == .journal, !trimmedEntry.isEmpty else { return }
        writing = false
        let finishedEntry = trimmedEntry
        screen = .complete
        onSaveEntry?(finishedEntry)
        onComplete(10)
    }

    private func close() {
        writing = false
        if let onClose {
            onClose()
        } else {
            dismiss()
            entry = ""
            screen = .instructions
        }
    }
}

private struct GoodThingPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 75
        while y < rect.height - 12 {
            path.move(to: CGPoint(x: 24, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 12, y: y))
            y += 36
        }
        return path
    }
}

private struct GoodThingArtwork: View {
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
    OneGoodThingView()
}
