import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct FeelingJournalEntry: Equatable {
    public let rightNow: String
    public let onMyMind: String
    public let noticeMost: String
    public let wishCouldSay: String
    public let more: String
    public let feelingName: String?
}

public struct NameYourFeelingView: View {
    private let onComplete: (Int) -> Void
    private let onClose: (() -> Void)?
    private let onSaveEntry: ((FeelingJournalEntry) -> Void)?

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onClose: (() -> Void)? = nil,
        onSaveEntry: ((FeelingJournalEntry) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onClose = onClose
        self.onSaveEntry = onSaveEntry
    }

    private enum Screen { case instructions, journal, name, complete }
    private let starters = [
        "Right now, I feel…",
        "Something that’s been on my mind is…",
        "I notice this feeling most when…",
        "What I wish I could say is…"
    ]

    @State private var screen: Screen = .instructions
    @State private var responses = ["", "", "", ""]
    @State private var more = ""
    @State private var moreExpanded = false
    @State private var feelingName = ""
    @FocusState private var focusedField: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pink = Color(red: 244 / 255, green: 183 / 255, blue: 215 / 255)
    private let ink = Color(red: 0.51, green: 0.29, blue: 0.40)
    private var cleanName: String {
        feelingName.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    case .journal:
                        journal.padding(.top, 12)
                    case .name:
                        naming.frame(minHeight: max(0, geometry.size.height - 56))
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
        Label("Reflect", systemImage: "heart.text.square")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(pink, in: RoundedRectangle(cornerRadius: 6))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 18) {
            FeelingArtwork(name: "reflect-feeling-intro")
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

            Text("Name Your Feeling")
                .font(.custom("ComingSoon-Regular", size: 34))
            instruction(number: "1", text: "Finish any sentence that speaks to you")
            instruction(number: "2", text: "Share more, or give the feeling a name")

            Spacer(minLength: 36)
            pinkButton("Start") {
                reset()
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
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Start wherever you like.")
                .font(.custom("ComingSoon-Regular", size: 22))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(starters.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(starters[index])
                            .font(.custom("ComingSoon-Regular", size: 16))
                            .foregroundStyle(ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("", text: $responses[index], axis: .vertical)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .textFieldStyle(.plain)
                            .font(.custom("ComingSoon-Regular", size: 22))
                            .lineLimit(1...6)
                            .focused($focusedField, equals: index)
                            .accessibilityLabel(starters[index])
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)

                        Rectangle()
                            .fill(pink.opacity(focusedField == index ? 0.9 : 0.4))
                            .frame(height: 1)
                            .allowsHitTesting(false)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded { focusedField = index }
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 1, green: 0.99, blue: 0.98))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pink.opacity(0.16), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
            }

            Button {
                moreExpanded.toggle()
                if !moreExpanded, focusedField == 4 { focusedField = nil }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .light))
                    Text("There’s more on my mind…")
                    Spacer()
                    Image(systemName: moreExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            }
            .accessibilityLabel(moreExpanded ? "Collapse extra writing" : "Share more")
            .accessibilityValue(more.isEmpty ? "" : "Contains your writing")

            if moreExpanded {
                extraWriting
            }

            pinkButton("Continue") {
                focusedField = nil
                screen = .name
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: moreExpanded)
    }

    private var extraWriting: some View {
        ZStack(alignment: .topLeading) {
            if more.isEmpty {
                Text("There’s room for more here…")
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $more)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: 4)
                .frame(height: 190)
                .accessibilityLabel("Anything else on your mind")
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .background { paper }
    }

    private var naming: some View {
        VStack(spacing: 20) {
            Text("Give it a name")
                .font(.custom("ComingSoon-Regular", size: 34))
                .padding(.top, 18)
            Text("Only if you’d like.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            TextField("A word, or a name of your own…", text: $feelingName, axis: .vertical)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .font(.custom("ComingSoon-Regular", size: 22))
                .lineLimit(2...5)
                .focused($focusedField, equals: 5)
                .accessibilityLabel("An optional name for this feeling")
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .background { paper }

            Text("It doesn’t have to be the perfect word.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 24)
            pinkButton("Finish", action: finish)
            Button("Back to my words") {
                focusedField = nil
                screen = .journal
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var paper: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(red: 1, green: 0.99, blue: 0.98))
            .overlay {
                FeelingPaperRules().stroke(pink.opacity(0.35), lineWidth: 0.7)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(pink.opacity(0.6))
                    .frame(width: 1)
                    .padding(.leading, 17)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.045), radius: 7, y: 3)
            .allowsHitTesting(false)
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 36)

            FeelingArtwork(name: "reflect-feeling-complete")
                .frame(width: 170, height: 190)
                .background {
                    Circle().fill(pink.opacity(0.28)).frame(width: 166, height: 166)
                }

            if !cleanName.isEmpty {
                Text(cleanName)
                    .font(.custom("ComingSoon-Regular", size: 22))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(pink.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("You named this feeling \(cleanName)")
            }

            Text("There’s room for this, too.")
                .font(.custom("ComingSoon-Regular", size: 28))
                .multilineTextAlignment(.center)
            Text("You don’t have to explain it perfectly\nfor it to matter.")
                .font(.custom("ComingSoon-Regular", size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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

    private func finish() {
        guard screen == .name else { return }
        focusedField = nil
        let cleaned = responses.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let savedEntry = FeelingJournalEntry(
            rightNow: cleaned[0],
            onMyMind: cleaned[1],
            noticeMost: cleaned[2],
            wishCouldSay: cleaned[3],
            more: more.trimmingCharacters(in: .whitespacesAndNewlines),
            feelingName: cleanName.isEmpty ? nil : cleanName
        )
        screen = .complete
        onSaveEntry?(savedEntry)
        onComplete(10)
    }

    private func reset() {
        responses = ["", "", "", ""]
        more = ""
        moreExpanded = false
        feelingName = ""
        focusedField = nil
    }

    private func close() {
        focusedField = nil
        if let onClose {
            onClose()
        } else {
            dismiss()
            reset()
            screen = .instructions
        }
    }
}

private struct FeelingPaperRules: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 52
        while y < rect.height - 8 {
            path.move(to: CGPoint(x: 23, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - 14, y: y))
            y += 34
        }
        return path
    }
}

private struct FeelingArtwork: View {
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
    NameYourFeelingView()
}
