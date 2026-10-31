import SwiftUI
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The Activities home, All Activities library, category pages, and activity routes.
/// Keep the card PNGs in your app's asset catalog with their existing names.
@MainActor
public struct ActivityLibraryView: View {
    private let onComplete: (Int) -> Void
    private let onChoosePhotos: ((String) -> Void)?
    private let onReturnHome: (() -> Void)?

    public init(
        onComplete: @escaping (Int) -> Void = { _ in },
        onChoosePhotos: ((String) -> Void)? = nil,
        onReturnHome: (() -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onChoosePhotos = onChoosePhotos
        self.onReturnHome = onReturnHome
    }

    @State private var path: [LibraryRoute] = []
    @State private var presentedActivity: LibraryActivity?
    @State private var completionReceived = false
    @StateObject private var journal = LibraryJournalStore()
    @State private var pendingJournal: OfflineJournalEntry?
    @State private var journalSaveFailed = false
    @State private var journalWriteSucceeded = false

    public var body: some View {
        NavigationStack(path: $path) {
            LibraryHomeView()
                .navigationTitle("Activities")
                .navigationDestination(for: LibraryRoute.self) { route in
                    switch route {
                    case .browser(let category):
                        LibraryBrowserView(initial: category, onSelect: open)
                    case .journal:
                        LibrarySavedEntriesView(journal: journal)
                    case .journalEntry(let id):
                        LibrarySavedEntryView(entryID: id, journal: journal)
                    }
                }
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        .tint(.primary)
        #if os(iOS)
        .fullScreenCover(item: $presentedActivity, onDismiss: presentationDismissed) { activity in
            activityPresentation(for: activity)
        }
        #else
        .sheet(item: $presentedActivity, onDismiss: presentationDismissed) { activity in
            activityPresentation(for: activity)
                .frame(minWidth: 390, minHeight: 760)
        }
        #endif
    }

    private func open(_ activity: LibraryActivity) {
        guard presentedActivity == nil else { return }
        completionReceived = false
        pendingJournal = nil
        journalSaveFailed = false
        journalWriteSucceeded = false
        presentedActivity = activity
    }

    private func recordCompletion(_ points: Int) {
        guard presentedActivity != nil, !completionReceived else { return }
        completionReceived = true
        if let entry = pendingJournal {
            pendingJournal = OfflineJournalEntry(id: entry.id, date: Date(),
                                                activityID: entry.activityID,
                                                title: entry.title, sections: entry.sections)
            savePendingJournal()
        }
        // The activity decides its reward, including 0...12 for 6-Word Recall.
        onComplete(points)
    }

    private func closeActivity() {
        if completionReceived, pendingJournal != nil {
            savePendingJournal()
            guard pendingJournal == nil else { return }
        }
        presentedActivity = nil
    }

    private func presentationDismissed() {
        let finished = completionReceived
        completionReceived = false
        pendingJournal = nil
        journalSaveFailed = false
        journalWriteSucceeded = false
        if finished {
            path = []
            onReturnHome?()
        }
    }

    private func activityPresentation(for activity: LibraryActivity) -> some View {
        destination(for: activity)
            .environment(\.activityDraftHostArchives, true)
            .safeAreaInset(edge: .top, spacing: 0) {
                if journalSaveFailed {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(journalWriteSucceeded
                             ? "Your entry is saved. Its draft hasn’t been cleared yet."
                             : "Your entry hasn’t saved yet.")
                            .font(.headline)
                        Text(journalWriteSucceeded
                             ? "Try again so it won’t appear as unfinished."
                             : "Your recovery draft stays on this device. You can try again before leaving.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Try again", action: savePendingJournal)
                                .frame(minHeight: 44)
                            Spacer()
                            Button(journalWriteSucceeded ? "Close" : "Leave without saving",
                                   role: journalWriteSucceeded ? nil : .destructive) {
                                pendingJournal = nil
                                journalSaveFailed = false
                                presentedActivity = nil
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(LibraryPalette.secondaryBackground)
                }
            }
            // Exits use each activity's Close action, preserving its draft confirmation.
            .interactiveDismissDisabled(!completionReceived || journalSaveFailed)
    }

    private func prepareJournal(_ sections: [OfflineJournalSection]) {
        guard let activity = presentedActivity, !completionReceived else { return }
        let cleaned = sections.compactMap { section -> OfflineJournalSection? in
            let text = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : OfflineJournalSection(heading: section.heading, text: text)
        }
        guard !cleaned.isEmpty else { pendingJournal = nil; return }
        pendingJournal = OfflineJournalEntry(activityID: activity.id.rawValue,
                                            title: activity.title, sections: cleaned)
    }

    private func savePendingJournal() {
        guard let entry = pendingJournal else { return }
        do {
            try journal.add(entry)
            journalWriteSucceeded = true
            if let draftID = presentedActivity?.id.draftActivityID {
                try OfflineActivityDraftRepository().remove(activityID: draftID)
            }
            pendingJournal = nil
            journalSaveFailed = false
        } catch {
            // Keep the same entry/UUID in memory so retry cannot add a duplicate.
            journalSaveFailed = true
        }
    }

    private func checkInSection(_ heading: String, _ answer: ScrollCheckInAnswer) -> OfflineJournalSection {
        let text = ([answer.note] + answer.choices)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        return OfflineJournalSection(heading: heading, text: text)
    }

    @ViewBuilder
    private func destination(for activity: LibraryActivity) -> some View {
        // The image comes from the SAME item that draws the card.
        // Typed IDs also keep older asset names independent of renamed titles.
        switch activity.id {
        case .findThreeThings:
            FindThreeThingsView(onComplete: recordCompletion, onClose: closeActivity,
                                onChoosePhotos: onChoosePhotos, introImageName: activity.imageName,
                                onSaveAnswers: { color, answers in
                                    prepareJournal(answers.enumerated().map { index, word in
                                        OfflineJournalSection(heading: "\(color.capitalized) thing \(index + 1)", text: word)
                                    })
                                })
        case .oneGoodThing:
            OneGoodThingView(onComplete: recordCompletion, onClose: closeActivity,
                             onSaveEntry: { text in
                                 prepareJournal([OfflineJournalSection(heading: "One good thing", text: text)])
                             },
                             introImageName: activity.imageName)
        case .hereAndNow:
            HereAndNowView(onComplete: recordCompletion, onClose: closeActivity,
                           introImageName: activity.imageName)
        case .followTheCircle:
            FollowTheCircleView(onComplete: recordCompletion, onClose: closeActivity,
                                introImageName: activity.imageName)
        case .countEightBreaths:
            CountEightBreathsView(onComplete: recordCompletion, onClose: closeActivity,
                                 introImageName: activity.imageName)
        case .breathingBox:
            BreathingBoxView(onComplete: recordCompletion, onClose: closeActivity,
                             introImageName: activity.imageName)
        case .scrollCheckIn:
            ScrollCheckInView(onComplete: recordCompletion, onClose: closeActivity,
                              onSaveAnswers: { answers in
                                  prepareJournal([
                                    checkInSection("What brought me here", answers.reason),
                                    checkInSection("How I feel", answers.feeling),
                                    checkInSection("What I want next", answers.nextStep)
                                  ])
                              },
                              introImageName: activity.imageName)
        case .makeAPlan:
            MakeAPlanView(onComplete: recordCompletion, onClose: closeActivity,
                         onSavePlan: { plan in
                             let time = plan.time == "A little longer" ? "10 minutes" : plan.time
                             prepareJournal([
                                OfflineJournalSection(heading: "My plan", text: plan.action),
                                OfflineJournalSection(heading: "Time I chose", text: time)
                             ])
                         },
                         introImageName: activity.imageName)
        case .nameYourFeeling:
            NameYourFeelingView(onComplete: recordCompletion, onClose: closeActivity,
                                onSaveEntry: { entry in
                                    prepareJournal([
                                        OfflineJournalSection(heading: "Right now, I feel…", text: entry.rightNow),
                                        OfflineJournalSection(heading: "Something on my mind…", text: entry.onMyMind),
                                        OfflineJournalSection(heading: "I notice this feeling most…", text: entry.noticeMost),
                                        OfflineJournalSection(heading: "What I wish I could say…", text: entry.wishCouldSay),
                                        OfflineJournalSection(heading: "More on my mind", text: entry.more),
                                        OfflineJournalSection(heading: "A name for this feeling", text: entry.feelingName ?? "")
                                    ])
                                },
                                introImageName: activity.imageName)
        case .littleThingsKept:
            LittleThingsKeptView(onComplete: recordCompletion, onClose: closeActivity,
                                onSaveThings: { things in
                                    prepareJournal(things.enumerated().map { index, text in
                                        OfflineJournalSection(heading: "Little thing \(index + 1)", text: text)
                                    })
                                },
                                introImageName: activity.imageName)
        case .neckReset:
            NeckResetView(onComplete: recordCompletion, onClose: closeActivity,
                          introImageName: activity.imageName)
        case .sixWordRecall:
            SixWordRecallView(onComplete: recordCompletion, onClose: closeActivity,
                              introImageName: activity.imageName)
        case .quickStretch, .eyeBreak, .danceBreak, .windowWalk, .countBackBySeven, .logicRiddle:
            LibraryComingSoonView(activity: activity, onClose: closeActivity)
        }
    }
}

private enum LibraryRoute: Hashable {
    case browser(LibraryCategory?)
    case journal
    case journalEntry(UUID)
}

private enum LibraryActivityID: String, Hashable {
    case findThreeThings, oneGoodThing, hereAndNow
    case followTheCircle, countEightBreaths, breathingBox
    case scrollCheckIn, makeAPlan, nameYourFeeling, littleThingsKept
    case neckReset, quickStretch, eyeBreak, danceBreak, windowWalk
    case sixWordRecall, countBackBySeven, logicRiddle

    var draftActivityID: String? {
        switch self {
        case .findThreeThings: "find-three-things"
        case .oneGoodThing: "one-good-thing"
        case .scrollCheckIn: "scroll-check-in"
        case .makeAPlan: "make-a-plan"
        case .nameYourFeeling: "name-your-feeling"
        case .littleThingsKept: "little-things-kept"
        default: nil
        }
    }

    var isReady: Bool {
        switch self {
        case .findThreeThings, .oneGoodThing, .hereAndNow,
             .followTheCircle, .countEightBreaths, .breathingBox,
             .scrollCheckIn, .makeAPlan, .nameYourFeeling, .littleThingsKept,
             .neckReset, .sixWordRecall:
            return true
        default:
            return false
        }
    }
}

// MARK: - Typography

private enum LibraryFont {
    /// PostScript name of the Coming Soon font (check in Font Book)
    static let comingSoon = "ComingSoon-Regular"

    private static func coming(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(comingSoon, size: size, relativeTo: style)
    }

    /// Large Title – Coming Soon – main screen titles – 34
    static let largeTitle = coming(34, relativeTo: .largeTitle)

    /// Title – Coming Soon – 28
    static let title = coming(28, relativeTo: .title)

    /// Title 2 – Coming Soon – section titles – 22
    static let title2 = coming(22, relativeTo: .title2)

    static let headline = Font.headline
}

// MARK: - Category

private enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case notice = "Notice"
    case breathe = "Breathe"
    case reflect = "Reflect"
    case move = "Move"
    case think = "Think"

    var id: String { rawValue }

    /// Header colour of the category page
    func headerColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:  return LibraryPalette.color(hex: scheme == .dark ? "443F16" : "F2E52E")
        case .breathe: return LibraryPalette.color(hex: scheme == .dark ? "263447" : "C3D2EE")
        case .reflect: return LibraryPalette.color(hex: scheme == .dark ? "482D3D" : "F7A9D3")
        case .move:    return LibraryPalette.color(hex: scheme == .dark ? "2F3C1F" : "A9D13F")
        case .think:   return LibraryPalette.color(hex: scheme == .dark ? "3C2E46" : "B79BD2")
        }
    }

    /// Top part of the cards
    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:  return LibraryPalette.color(hex: scheme == .dark ? "565023" : "E9DD2A")
        case .breathe: return LibraryPalette.color(hex: scheme == .dark ? "344660" : "A9BDE3")
        case .reflect: return LibraryPalette.color(hex: scheme == .dark ? "613D52" : "F2A6CF")
        case .move:    return LibraryPalette.color(hex: scheme == .dark ? "3E5127" : "7FA02E")
        case .think:   return LibraryPalette.color(hex: scheme == .dark ? "503B62" : "9B78B8")
        }
    }

    /// Bottom text strip of the cards
    func lightColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:  return LibraryPalette.color(hex: scheme == .dark ? "2E2B18" : "F3F08C")
        case .breathe: return LibraryPalette.color(hex: scheme == .dark ? "202D3D" : "DCE6F6")
        case .reflect: return LibraryPalette.color(hex: scheme == .dark ? "382532" : "F8D3E6")
        case .move:    return LibraryPalette.color(hex: scheme == .dark ? "29331F" : "B5D05F")
        case .think:   return LibraryPalette.color(hex: scheme == .dark ? "302637" : "CFB8E0")
        }
    }

    var homeSubtitle: String {
        switch self {
        case .notice:  return "Tune in to what's around you"
        case .breathe: return "Slow down, take a breath"
        case .reflect: return "a quick check in"
        case .move:    return "Get your body out of the scroll"
        case .think:   return "Wake your brain up, gently"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .breathe: return "calm your body and mind"
        default:       return homeSubtitle
        }
    }

    /// Image shown on the right side of the row in the activities home page
    var homeImageName: String {
        switch self {
        case .notice:  return "Notice"
        case .breathe: return "Breathe"
        case .reflect: return "Reflect"
        case .move:    return "Move"
        case .think:   return "Think"
        }
    }

    /// Image shown on the "All Activities" row (All is not a category, so it lives here)
    static let allHomeImageName = "allActivity"
}

// MARK: - Activity model

private struct LibraryActivity: Identifiable {
    let id: LibraryActivityID
    let title: String
    let duration: LibraryDuration
    let description: String
    let category: LibraryCategory
    let imageName: String

    init(_ id: LibraryActivityID, _ title: String, _ duration: LibraryDuration, _ description: String,
         _ category: LibraryCategory, image: String) {
        self.id = id
        self.title = title
        self.duration = duration
        self.description = description
        self.category = category
        self.imageName = image
    }
}

private enum LibraryDuration {
    case oneMinute, aboutOneMinute, atYourPace, planChoices, comingSoon

    var label: String? {
        switch self {
        case .oneMinute: return "1 min"
        case .aboutOneMinute: return "About 1 min"
        case .atYourPace: return "At your pace"
        case .planChoices: return "1, 5 or 10 min"
        case .comingSoon: return nil
        }
    }
}

private extension LibraryActivity {
    static let all: [LibraryActivity] = [
        // Notice
        LibraryActivity(.findThreeThings, "Find three things", .atYourPace, "Move your attention from the screen to your surroundings.", .notice, image: "3f"),
        LibraryActivity(.oneGoodThing, "one good thing", .atYourPace, "savor small moments.", .notice, image: "one good thing"),
        LibraryActivity(.hereAndNow, "Here & Now", .atYourPace, "ground yourself when your mind is on autopilot.", .notice, image: "54321 senses"),

        // Breathe
        LibraryActivity(.followTheCircle, "Follow the Circle", .oneMinute, "Slow your breathing with a guide.", .breathe, image: "Follow the Circle"),
        LibraryActivity(.countEightBreaths, "Count 8 Breaths", .atYourPace, "Bring your attention back.", .breathe, image: "Count 8 Breaths"),
        LibraryActivity(.breathingBox, "Breathing Box", .aboutOneMinute, "Find a steady breathing rhythm.", .breathe, image: "Breathing Box"),

        // Reflect
        LibraryActivity(.scrollCheckIn, "Scroll Check-In", .atYourPace, "Notice what brought you here.", .reflect, image: "Scroll Check-In"),
        LibraryActivity(.makeAPlan, "Make a Plan", .planChoices, "Choose what to do instead of scrolling.", .reflect, image: "Make a Plan"),
        LibraryActivity(.nameYourFeeling, "Name Your Feeling", .atYourPace, "Understand how you're feeling.", .reflect, image: "Name Your Feeling"),
        LibraryActivity(.littleThingsKept, "Little Things, Kept", .atYourPace, "Notice what's going well.", .reflect, image: "Three Good Things"),

        // Move
        LibraryActivity(.neckReset, "Neck Reset", .aboutOneMinute, "Ease tension from looking down.", .move, image: "Neck Reset"),
        LibraryActivity(.quickStretch, "Quick Stretch", .comingSoon, "Loosen up after sitting.", .move, image: "Quick Stretch"),
        LibraryActivity(.eyeBreak, "Eye Break", .comingSoon, "Give your eyes a screen break.", .move, image: "Eye Break"),
        LibraryActivity(.danceBreak, "Dance Break", .comingSoon, "Lift your mood through movement.", .move, image: "Dance Break"),
        LibraryActivity(.windowWalk, "Window Walk", .comingSoon, "Refresh your attention with a change of scenery.", .move, image: "Window Walk"),

        // Think
        LibraryActivity(.sixWordRecall, "6-Word Recall", .atYourPace, "Challenge your short-term memory.", .think, image: "6-Word Recall"),
        LibraryActivity(.countBackBySeven, "Count Back by 7", .comingSoon, "Give your focus a challenge.", .think, image: "Count Back by 7"),
        LibraryActivity(.logicRiddle, "Logic Riddle", .comingSoon, "Switch to active problem-solving.", .think, image: "Logic Riddle")
        ]
        }

// MARK: - Activities home

@MainActor
private struct LibraryHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("activities")
                                .font(LibraryFont.largeTitle)
                            Text("small breaks for a busy brain")
                                .font(.body)
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(LibraryPalette.color(hex: colorScheme == .dark ? "583449" : "F6B3D6"))
                            Image(systemName: "hare.fill")
                                .foregroundStyle(.white)
                        }
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    }
                    .padding(.bottom, 6)

                    NavigationLink(value: LibraryRoute.journal) {
                        HStack(spacing: 14) {
                            Image(systemName: "book.closed")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saved entries")
                                    .font(LibraryFont.title2)
                                Text("Your words, kept on this device")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                        .background(LibraryPalette.secondaryBackground,
                                    in: RoundedRectangle(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: LibraryRoute.browser(nil)) {
                        row(title: "All Activities",
                            subtitle: "everything in one place",
                            color: LibraryPalette.secondaryBackground,
                            imageName: LibraryCategory.allHomeImageName)
                    }
                    .buttonStyle(.plain)

                    ForEach(LibraryCategory.allCases) { category in
                        NavigationLink(value: LibraryRoute.browser(category)) {
                            row(title: category.rawValue,
                                subtitle: category.homeSubtitle,
                                color: category.color(for: colorScheme),
                                imageName: category.homeImageName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(LibraryPalette.background.ignoresSafeArea())
    }

    private func row(title: String, subtitle: String, color: Color, imageName: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rowText(title: title, subtitle: subtitle)
                    LibraryImage(name: imageName)
                        .frame(width: 120, height: 80)
                }
                .padding(.vertical, 18)
            } else {
                HStack(spacing: 12) {
                    rowText(title: title, subtitle: subtitle)
                    Spacer(minLength: 0)
                    LibraryImage(name: imageName)
                        .frame(width: 120, height: 80)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func rowText(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(LibraryFont.title2)
            Text(subtitle)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Browser (Activity Library + all category pages in ONE view)
// nil = All (Activity Library), otherwise the chosen category.

@MainActor
private struct LibraryBrowserView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: LibraryCategory?
    let onSelect: (LibraryActivity) -> Void

    init(initial: LibraryCategory?, onSelect: @escaping (LibraryActivity) -> Void) {
        _selected = State(initialValue: initial)
        self.onSelect = onSelect
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private var items: [LibraryActivity] {
        guard let selected else { return LibraryActivity.all }
        return LibraryActivity.all.filter { $0.category == selected }
    }

    private var titleText: String {
        selected?.rawValue ?? "Activity Library"
    }

    private var subtitleText: String {
        selected?.pageSubtitle ?? "pick whatever feels right for you now"
    }

    private var headerColor: Color {
        selected?.headerColor(for: colorScheme) ?? LibraryPalette.secondaryBackground
    }

    private var countText: String {
        let noun = items.count == 1 ? "activity" : "activities"
        return "\(items.count) \(noun)"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At large text sizes the header scrolls too, leaving room to reach every card.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        activityGrid
                    }
                }
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) { activityGrid }
                }
            }
        }
        .background(LibraryPalette.background.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(headerColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selected)
    }

    private var activityGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { activity in
                Button { onSelect(activity) } label: {
                    LibraryCard(activity: activity)
                }
                .buttonStyle(.plain)
                .accessibilityHint(activity.id.isReady ? "Opens this activity" : "Coming soon")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleText)
                .font(LibraryFont.largeTitle)
                .accessibilityAddTraits(.isHeader)

            Text(subtitleText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Text(countText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LibraryFilterChip(title: "All", isSelected: selected == nil) {
                        selected = nil
                    }
                    ForEach(LibraryCategory.allCases) { category in
                        LibraryFilterChip(title: category.rawValue, isSelected: selected == category) {
                            selected = category
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            headerColor
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40))
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Shared components

/// Shows the image from Assets if it exists (same name as `name`),
/// otherwise shows a placeholder box.
@MainActor
private struct LibraryImage: View {
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
                Image(name)
                    .resizable()
                    .scaledToFit()
            } else {
                LibraryImagePlaceholder()
            }
        }
        .accessibilityHidden(true)
    }
}

@MainActor
private struct LibraryImagePlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.25),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

@MainActor
private struct LibraryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isSelected ? LibraryPalette.background : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44)
                .background(Capsule().fill(isSelected ? Color.primary : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

@MainActor
private struct LibraryCard: View {
    let activity: LibraryActivity
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                activity.category.color(for: colorScheme)
                LibraryImage(name: activity.imageName)
            }
            .frame(height: 118)
            .overlay(alignment: .topTrailing) {
                if !activity.id.isReady {
                    Text("Coming soon")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(LibraryPalette.background.opacity(0.95), in: Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(activity.title)
                    .font(LibraryFont.title2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let duration = activity.duration.label {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(activity.category.lightColor(for: colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

private enum LibraryPalette {
    static var background: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.clear
        #endif
    }

    static var secondaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    static func color(hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted)).scanHexInt64(&value)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

@MainActor
private struct LibraryComingSoonView: View {
    let activity: LibraryActivity
    let onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LibraryImage(name: activity.imageName)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .background(activity.category.lightColor(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 12))
                    Text(activity.title)
                        .font(LibraryFont.largeTitle)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("This activity is coming soon.")
                        .font(.custom(LibraryFont.comingSoon, size: 16, relativeTo: .body))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onClose) {
                    Text("Back to activities")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(activity.category.lightColor(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: 520)
                .padding(16)
                .background(LibraryPalette.background)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.automatic)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(LibraryPalette.background.ignoresSafeArea())
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
        }
    }
}

/// Local completed entries. No account, network, or cloud service is involved.
struct OfflineJournalSection: Codable, Equatable {
    let heading: String
    let text: String
}

struct OfflineJournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let activityID: String
    let title: String
    let sections: [OfflineJournalSection]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        activityID: String,
        title: String,
        sections: [OfflineJournalSection]
    ) {
        self.id = id
        self.date = date
        self.activityID = activityID
        self.title = title
        self.sections = sections
    }
}

enum OfflineJournalRepositoryError: LocalizedError, Equatable {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "These saved entries use a newer format. Your existing file has been kept."
        }
    }
}

/// Preserves entry and section order exactly. The history UI can sort newest first.
struct OfflineJournalRepository {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
            let appID = Bundle.main.bundleIdentifier ?? "BreathingExercise"
            self.fileURL = support
                .appendingPathComponent(appID, isDirectory: true)
                .appendingPathComponent("ActivityJournal", isDirectory: true)
                .appendingPathComponent("entries.json", isDirectory: false)
        }
    }

    func load() throws -> [OfflineJournalEntry] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError
            where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        }
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        guard header.version == 1 else {
            throw OfflineJournalRepositoryError.unsupportedVersion(header.version)
        }
        return try decoder.decode(Document.self, from: data).entries
    }

    func write(_ entries: [OfflineJournalEntry]) throws {
        // Refuse to replace an unreadable or newer file with an empty/new history.
        // A failed load therefore cannot silently erase the person's existing entries.
        _ = try load()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 1, entries: entries))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    private struct VersionHeader: Decodable {
        let version: Int
    }

    private struct Document: Codable {
        let version: Int
        let entries: [OfflineJournalEntry]
    }
}

@MainActor
private final class LibraryJournalStore: ObservableObject {
    @Published private(set) var entries: [OfflineJournalEntry] = []
    @Published private(set) var loadFailed = false
    private let repository = OfflineJournalRepository()

    init() { reload() }

    func reload() {
        do {
            entries = try repository.load().sorted { $0.date > $1.date }
            loadFailed = false
        } catch {
            // Keep any already-loaded entries; never replace the on-device file.
            loadFailed = true
        }
    }

    func add(_ entry: OfflineJournalEntry) throws {
        var updated = try repository.load().filter { $0.id != entry.id }
        updated.append(entry)
        updated.sort { $0.date > $1.date }
        try repository.write(updated)
        entries = updated
        loadFailed = false
    }

    func remove(_ id: UUID) throws {
        let updated = try repository.load().filter { $0.id != id }
        try repository.write(updated)
        entries = updated.sorted { $0.date > $1.date }
        loadFailed = false
    }
}

@MainActor
private struct LibrarySavedEntriesView: View {
    @ObservedObject var journal: LibraryJournalStore

    var body: some View {
        Group {
            if journal.loadFailed {
                ContentUnavailableView {
                    Label("Couldn’t open saved entries", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your saved file has been kept. You can try opening it again.")
                } actions: {
                    Button("Try again", action: journal.reload)
                }
            } else if journal.entries.isEmpty {
                ContentUnavailableView {
                    Label("Your words belong here.", systemImage: "book.closed")
                } description: {
                    Text("Finish a writing activity to keep it on this device.")
                }
            } else {
                List(journal.entries) { entry in
                    NavigationLink(value: LibraryRoute.journalEntry(entry.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.title)
                                .font(LibraryFont.title2)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let first = entry.sections.first {
                                Text(first.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Saved entries")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .background(LibraryPalette.background.ignoresSafeArea())
        .onAppear(perform: journal.reload)
    }
}

@MainActor
private struct LibrarySavedEntryView: View {
    let entryID: UUID
    @ObservedObject var journal: LibraryJournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var asksToDelete = false
    @State private var deleteFailed = false

    private var entry: OfflineJournalEntry? {
        journal.entries.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(entry.title)
                            .font(LibraryFont.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(entry.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(Array(entry.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                if !section.heading.isEmpty {
                                    Text(section.heading)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(section.text)
                                    .font(.custom(LibraryFont.comingSoon, size: 22, relativeTo: .body))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("Saved on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("This entry is no longer here.",
                                       systemImage: "book.closed")
            }
        }
        .navigationTitle("Your entry")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .background(LibraryPalette.background.ignoresSafeArea())
        .foregroundStyle(.primary)
        .toolbar {
            if entry != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { asksToDelete = true } label: {
                        Label("Delete entry", systemImage: "trash")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.automatic)
                }
            }
        }
        .confirmationDialog("Delete this saved entry?", isPresented: $asksToDelete,
                            titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) {
                do {
                    try journal.remove(entryID)
                    dismiss()
                } catch {
                    deleteFailed = true
                }
            }
            Button("Keep entry", role: .cancel) {}
        } message: {
            Text("This removes it from the journal on this device.")
        }
        .alert("Couldn’t delete this entry", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your entry is still here. Please try again.")
        }
    }
}

#Preview {
    ActivityLibraryView()
}
