import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Activities library

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

    public var body: some View {
        NavigationStack(path: $path) {
            LibraryHomeView()
                .navigationTitle("Activities")
                .navigationDestination(for: LibraryRoute.self) { route in
                    switch route {
                    case .browser(let category):
                        LibraryBrowserView(
                            initial: category,
                            onSelect: open
                        )
                    }
                }
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        .tint(.primary)

        #if os(iOS)
        .fullScreenCover(
            item: $presentedActivity,
            onDismiss: presentationDismissed
        ) { activity in
            activityPresentation(for: activity)
        }
        #else
        .sheet(
            item: $presentedActivity,
            onDismiss: presentationDismissed
        ) { activity in
            activityPresentation(for: activity)
                .frame(minWidth: 390, minHeight: 760)
        }
        #endif
    }

    private func open(_ activity: LibraryActivity) {
        guard presentedActivity == nil else { return }

        completionReceived = false
        presentedActivity = activity
    }

    private func recordCompletion(_ points: Int) {
        guard presentedActivity != nil,
              !completionReceived else {
            return
        }

        completionReceived = true
        onComplete(points)
    }

    private func closeActivity() {
        presentedActivity = nil
    }

    private func presentationDismissed() {
        let finished = completionReceived

        completionReceived = false

        if finished {
            path = []
            onReturnHome?()
        }
    }

    private func activityPresentation(
        for activity: LibraryActivity
    ) -> some View {
        destination(for: activity)
            .environment(\.activityDraftHostArchives, false)
            .interactiveDismissDisabled(!completionReceived)
    }

    @ViewBuilder
    private func destination(
        for activity: LibraryActivity
    ) -> some View {
        switch activity.id {
        case .findThreeThings:
            // Lama's camera flow (Features/notice/ThreePhotosView.swift) runs behind "Take photos".
            FindThreeThingsWithCamera(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .oneGoodThing:
            OneGoodThingView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .hereAndNow:
            HereAndNowView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .followTheCircle:
            FollowTheCircleView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .countEightBreaths:
            CountEightBreathsView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .breathingBox:
            BreathingBoxView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .scrollCheckIn:
            ScrollCheckInView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .makeAPlan:
            MakeAPlanView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .nameYourFeeling:
            NameYourFeelingView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .littleThingsKept:
            LittleThingsKeptView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .neckReset:
            NeckResetView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .sixWordRecall:
            SixWordRecallView(
                onComplete: recordCompletion,
                onClose: closeActivity,
                introImageName: activity.imageName
            )

        case .quickStretch,
             .eyeBreak,
             .danceBreak,
             .windowWalk,
             .countBackBySeven,
             .logicRiddle:
            LibraryComingSoonView(
                activity: activity,
                onClose: closeActivity
            )
        }
    }
}

// MARK: - Navigation

private enum LibraryRoute: Hashable {
    case browser(LibraryCategory?)
}

private enum LibraryActivityID: String, Hashable {
    case findThreeThings
    case oneGoodThing
    case hereAndNow

    case followTheCircle
    case countEightBreaths
    case breathingBox

    case scrollCheckIn
    case makeAPlan
    case nameYourFeeling
    case littleThingsKept

    case neckReset
    case quickStretch
    case eyeBreak
    case danceBreak
    case windowWalk

    case sixWordRecall
    case countBackBySeven
    case logicRiddle

    var isReady: Bool {
        switch self {
        case .findThreeThings,
             .oneGoodThing,
             .hereAndNow,
             .followTheCircle,
             .countEightBreaths,
             .breathingBox,
             .scrollCheckIn,
             .makeAPlan,
             .nameYourFeeling,
             .littleThingsKept,
             .neckReset,
             .sixWordRecall:
            return true

        default:
            return false
        }
    }
}

// MARK: - Typography

private enum LibraryFont {
    static let comingSoon = "ComingSoon-Regular"

    private static func coming(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle
    ) -> Font {
        .custom(
            comingSoon,
            size: size,
            relativeTo: style
        )
    }

    static let largeTitle = coming(
        34,
        relativeTo: .largeTitle
    )

    static let title = coming(
        28,
        relativeTo: .title
    )

    static let title2 = coming(
        22,
        relativeTo: .title2
    )

    static let headline = Font.headline
}

// MARK: - Categories

private enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case notice = "Notice"
    case breathe = "Breathe"
    case reflect = "Reflect"
    case move = "Move"
    case think = "Think"

    var id: String {
        rawValue
    }

    func headerColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:
            return LibraryPalette.color(
                hex: scheme == .dark ? "443F16" : "F2E52E"
            )

        case .breathe:
            return LibraryPalette.color(
                hex: scheme == .dark ? "263447" : "C3D2EE"
            )

        case .reflect:
            return LibraryPalette.color(
                hex: scheme == .dark ? "482D3D" : "F7A9D3"
            )

        case .move:
            return LibraryPalette.color(
                hex: scheme == .dark ? "2F3C1F" : "A9D13F"
            )

        case .think:
            return LibraryPalette.color(
                hex: scheme == .dark ? "3C2E46" : "B79BD2"
            )
        }
    }

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:
            return LibraryPalette.color(
                hex: scheme == .dark ? "565023" : "E9DD2A"
            )

        case .breathe:
            return LibraryPalette.color(
                hex: scheme == .dark ? "344660" : "A9BDE3"
            )

        case .reflect:
            return LibraryPalette.color(
                hex: scheme == .dark ? "613D52" : "F2A6CF"
            )

        case .move:
            return LibraryPalette.color(
                hex: scheme == .dark ? "3E5127" : "7FA02E"
            )

        case .think:
            return LibraryPalette.color(
                hex: scheme == .dark ? "503B62" : "9B78B8"
            )
        }
    }

    func lightColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .notice:
            return LibraryPalette.color(
                hex: scheme == .dark ? "2E2B18" : "F3F08C"
            )

        case .breathe:
            return LibraryPalette.color(
                hex: scheme == .dark ? "202D3D" : "DCE6F6"
            )

        case .reflect:
            return LibraryPalette.color(
                hex: scheme == .dark ? "382532" : "F8D3E6"
            )

        case .move:
            return LibraryPalette.color(
                hex: scheme == .dark ? "29331F" : "B5D05F"
            )

        case .think:
            return LibraryPalette.color(
                hex: scheme == .dark ? "302637" : "CFB8E0"
            )
        }
    }

    var homeSubtitle: String {
        switch self {
        case .notice:
            return "Tune in to what's around you"

        case .breathe:
            return "Slow down, take a breath"

        case .reflect:
            return "a quick check in"

        case .move:
            return "Get your body out of the scroll"

        case .think:
            return "Wake your brain up, gently"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .breathe:
            return "calm your body and mind"

        default:
            return homeSubtitle
        }
    }

    var homeImageName: String {
        switch self {
        case .notice:
            return "Notice"

        case .breathe:
            return "Breathe"

        case .reflect:
            return "Reflect"

        case .move:
            return "Move"

        case .think:
            return "Think"
        }
    }

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

    init(
        _ id: LibraryActivityID,
        _ title: String,
        _ duration: LibraryDuration,
        _ description: String,
        _ category: LibraryCategory,
        image: String
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.description = description
        self.category = category
        self.imageName = image
    }
}

private enum LibraryDuration {
    case oneMinute
    case aboutOneMinute
    case atYourPace
    case planChoices
    case comingSoon

    var label: String? {
        switch self {
        case .oneMinute:
            return "1 min"

        case .aboutOneMinute:
            return "About 1 min"

        case .atYourPace:
            return "At your pace"

        case .planChoices:
            return "1, 5 or 10 min"

        case .comingSoon:
            return nil
        }
    }
}

private extension LibraryActivity {
    static let all: [LibraryActivity] = [
        // Notice
        LibraryActivity(
            .findThreeThings,
            "Find three things",
            .atYourPace,
            "Move your attention from the screen to your surroundings.",
            .notice,
            image: "3f"
        ),
        LibraryActivity(
            .oneGoodThing,
            "one good thing",
            .atYourPace,
            "savor small moments.",
            .notice,
            image: "one good thing"
        ),
        LibraryActivity(
            .hereAndNow,
            "Here & Now",
            .atYourPace,
            "ground yourself when your mind is on autopilot.",
            .notice,
            image: "54321 senses"
        ),

        // Breathe
        LibraryActivity(
            .followTheCircle,
            "Follow the Circle",
            .oneMinute,
            "Slow your breathing with a guide.",
            .breathe,
            image: "Follow the Circle"
        ),
        LibraryActivity(
            .countEightBreaths,
            "Count 8 Breaths",
            .atYourPace,
            "Bring your attention back.",
            .breathe,
            image: "Count 8 Breaths"
        ),
        LibraryActivity(
            .breathingBox,
            "Breathing Box",
            .aboutOneMinute,
            "Find a steady breathing rhythm.",
            .breathe,
            image: "Breathing Box"
        ),

        // Reflect
        LibraryActivity(
            .scrollCheckIn,
            "Scroll Check-In",
            .atYourPace,
            "Notice what brought you here.",
            .reflect,
            image: "Scroll Check-In"
        ),
        LibraryActivity(
            .makeAPlan,
            "Make a Plan",
            .planChoices,
            "Choose what to do instead of scrolling.",
            .reflect,
            image: "Make a Plan"
        ),
        LibraryActivity(
            .nameYourFeeling,
            "Name Your Feeling",
            .atYourPace,
            "Understand how you're feeling.",
            .reflect,
            image: "Name Your Feeling"
        ),
        LibraryActivity(
            .littleThingsKept,
            "Little Things, Kept",
            .atYourPace,
            "Notice what's going well.",
            .reflect,
            image: "Three Good Things"
        ),

        // Move
        LibraryActivity(
            .neckReset,
            "Neck Reset",
            .aboutOneMinute,
            "Ease tension from looking down.",
            .move,
            image: "Neck Reset"
        ),
        LibraryActivity(
            .quickStretch,
            "Quick Stretch",
            .comingSoon,
            "Loosen up after sitting.",
            .move,
            image: "Quick Stretch"
        ),
        LibraryActivity(
            .eyeBreak,
            "Eye Break",
            .comingSoon,
            "Give your eyes a screen break.",
            .move,
            image: "Eye Break"
        ),
        LibraryActivity(
            .danceBreak,
            "Dance Break",
            .comingSoon,
            "Lift your mood through movement.",
            .move,
            image: "Dance Break"
        ),
        LibraryActivity(
            .windowWalk,
            "Window Walk",
            .comingSoon,
            "Refresh your attention with a change of scenery.",
            .move,
            image: "Window Walk"
        ),

        // Think
        LibraryActivity(
            .sixWordRecall,
            "6-Word Recall",
            .atYourPace,
            "Challenge your short-term memory.",
            .think,
            image: "6-Word Recall"
        ),
        LibraryActivity(
            .countBackBySeven,
            "Count Back by 7",
            .comingSoon,
            "Give your focus a challenge.",
            .think,
            image: "Count Back by 7"
        ),
        LibraryActivity(
            .logicRiddle,
            "Logic Riddle",
            .comingSoon,
            "Switch to active problem-solving.",
            .think,
            image: "Logic Riddle"
        )
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
                        Circle()
                            .fill(
                                LibraryPalette.color(
                                    hex: colorScheme == .dark
                                    ? "583449"
                                    : "F6B3D6"
                                )
                            )

                        Image(systemName: "hare.fill")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                }
                .padding(.bottom, 6)

                NavigationLink(
                    value: LibraryRoute.browser(nil)
                ) {
                    row(
                        title: "All Activities",
                        subtitle: "everything in one place",
                        color: LibraryPalette.secondaryBackground,
                        imageName: LibraryCategory.allHomeImageName
                    )
                }
                .buttonStyle(.plain)

                ForEach(LibraryCategory.allCases) { category in
                    NavigationLink(
                        value: LibraryRoute.browser(category)
                    ) {
                        row(
                            title: category.rawValue,
                            subtitle: category.homeSubtitle,
                            color: category.color(for: colorScheme),
                            imageName: category.homeImageName
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            LibraryPalette.background.ignoresSafeArea()
        )
    }

    private func row(
        title: String,
        subtitle: String,
        color: Color,
        imageName: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rowText(
                        title: title,
                        subtitle: subtitle
                    )

                    LibraryImage(name: imageName)
                        .frame(width: 120, height: 80)
                }
                .padding(.vertical, 18)
            } else {
                HStack(spacing: 12) {
                    rowText(
                        title: title,
                        subtitle: subtitle
                    )

                    Spacer(minLength: 0)

                    LibraryImage(name: imageName)
                        .frame(width: 120, height: 80)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .frame(
            maxWidth: .infinity,
            minHeight: 100,
            alignment: .leading
        )
        .background(
            color,
            in: RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    private func rowText(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(LibraryFont.title2)

            Text(subtitle)
                .font(.subheadline)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
    }
}

// MARK: - All Activities and category pages

@MainActor
private struct LibraryBrowserView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selected: LibraryCategory?

    let onSelect: (LibraryActivity) -> Void

    init(
        initial: LibraryCategory?,
        onSelect: @escaping (LibraryActivity) -> Void
    ) {
        _selected = State(initialValue: initial)
        self.onSelect = onSelect
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: 12,
                alignment: .top
            ),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    private var items: [LibraryActivity] {
        guard let selected else {
            return LibraryActivity.all
        }

        return LibraryActivity.all.filter {
            $0.category == selected
        }
    }

    private var titleText: String {
        selected?.rawValue ?? "Activity Library"
    }

    private var subtitleText: String {
        selected?.pageSubtitle
            ?? "pick whatever feels right for you now"
    }

    private var headerColor: Color {
        selected?.headerColor(for: colorScheme)
            ?? LibraryPalette.secondaryBackground
    }

    private var countText: String {
        let noun = items.count == 1
            ? "activity"
            : "activities"

        return "\(items.count) \(noun)"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        activityGrid
                    }
                }
            } else {
                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        activityGrid
                    }
                }
            }
        }
        .background(
            LibraryPalette.background.ignoresSafeArea()
        )

        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(
            headerColor,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        #endif

        .animation(
            reduceMotion
            ? nil
            : .easeInOut(duration: 0.25),
            value: selected
        )
    }

    private var activityGrid: some View {
        LazyVGrid(
            columns: columns,
            spacing: 12
        ) {
            ForEach(items) { activity in
                Button {
                    onSelect(activity)
                } label: {
                    LibraryCard(activity: activity)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    activity.id.isReady
                    ? "Opens this activity"
                    : "Coming soon"
                )
            }
        }
        .padding(.horizontal, 16)
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
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Text(countText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 8) {
                    LibraryFilterChip(
                        title: "All",
                        isSelected: selected == nil
                    ) {
                        selected = nil
                    }

                    ForEach(LibraryCategory.allCases) { category in
                        LibraryFilterChip(
                            title: category.rawValue,
                            isSelected: selected == category
                        ) {
                            selected = category
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 38)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            headerColor
                .clipShape(
                    LibraryHeaderShape(curveDepth: 24)
                )
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Wide category header curve

private struct LibraryHeaderShape: Shape {
    let curveDepth: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        let depth = min(
            max(0, curveDepth),
            rect.height
        )

        let edgeY = rect.maxY - depth

        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: edgeY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX,
                y: edgeY
            ),
            control: CGPoint(
                x: rect.midX,
                y: rect.maxY + depth
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Shared images

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
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .strokeBorder(
                .primary.opacity(0.25),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    dash: [6, 4]
                )
            )

            Image(systemName: "photo")
                .font(
                    .system(
                        size: 28,
                        weight: .regular
                    )
                )
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }
}

// MARK: - Category filters

@MainActor
private struct LibraryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(
                    isSelected
                    ? LibraryPalette.background
                    : Color.primary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(
                    minWidth: 44,
                    minHeight: 44
                )
                .background(
                    Capsule()
                        .fill(
                            isSelected
                            ? Color.primary
                            : .clear
                        )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }
}

// MARK: - Fixed square cards

@MainActor
private struct LibraryCard: View {
    let activity: LibraryActivity

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        activity.category.color(for: colorScheme)

                        VStack(spacing: 0) {
                            LibraryImage(name: activity.imageName)
                                .padding(.horizontal, 8)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height * 0.60,
                                    alignment: .bottom
                                )

                            Spacer(minLength: 0)
                        }
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )

                        caption
                            .frame(
                                height: geometry.size.height * 0.48
                            )
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if !activity.id.isReady {
                    Text("Coming soon")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            LibraryPalette.background.opacity(0.95),
                            in: Capsule()
                        )
                        .padding(8)
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 40,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(0.06),
                radius: 6,
                y: 3
            )
            .accessibilityElement(children: .combine)
    }

    private var compactDuration: String? {
        switch activity.duration {
        case .oneMinute:
            "1m"

        case .aboutOneMinute:
            "~1m"

        case .atYourPace:
            "Any\npace"

        case .planChoices:
            "1/5/10m"

        case .comingSoon:
            nil
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(activity.title)
                    .font(LibraryFont.title2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                if let compactDuration {
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: 2
                    ) {
                        Image(systemName: "clock")

                        Text(compactDuration)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(
                        horizontal: true,
                        vertical: true
                    )
                }
            }

            Text(activity.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    activity.category
                        .lightColor(for: colorScheme)
                        .opacity(0.55)
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .strokeBorder(
                    .white.opacity(
                        colorScheme == .dark ? 0.12 : 0.65
                    ),
                    lineWidth: 0.7
                )
            }
        }
        .clipped()
    }
}

// MARK: - Colors

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

        Scanner(
            string: hex.trimmingCharacters(
                in: .alphanumerics.inverted
            )
        )
        .scanHexInt64(&value)

        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Coming soon

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
                        .background(
                            activity.category.lightColor(
                                for: colorScheme
                            ),
                            in: RoundedRectangle(
                                cornerRadius: 12
                            )
                        )

                    Text(activity.title)
                        .font(LibraryFont.largeTitle)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("This activity is coming soon.")
                        .font(
                            .custom(
                                LibraryFont.comingSoon,
                                size: 16,
                                relativeTo: .body
                            )
                        )
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
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 48
                        )
                        .background(
                            activity.category.lightColor(
                                for: colorScheme
                            ),
                            in: RoundedRectangle(
                                cornerRadius: 12
                            )
                        )
                }
                .frame(maxWidth: 520)
                .padding(16)
                .background(
                    LibraryPalette.background
                )
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onClose) {
                        Label(
                            "Close",
                            systemImage: "xmark"
                        )
                        .frame(
                            minWidth: 44,
                            minHeight: 44
                        )
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.automatic)
                }
            }

            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif

            .background(
                LibraryPalette.background.ignoresSafeArea()
            )
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ActivityLibraryView()
}
