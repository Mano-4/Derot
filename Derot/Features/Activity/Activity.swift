import SwiftUI

// MARK: - Typography

enum AppFont {
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

    /// Headline – SF Rounded Semibold – card titles, list headers – 17
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
}

// MARK: - Category

enum ActivityCategory: String, CaseIterable, Identifiable {
    case notice = "Notice"
    case breathe = "Breathe"
    case reflect = "Reflect"
    case move = "Move"
    case think = "Think"

    var id: String { rawValue }

    /// Header colour of the category page
    var headerColor: Color {
        switch self {
        case .notice:  return Color(hex: "F2E52E")
        case .breathe: return Color(hex: "C3D2EE")
        case .reflect: return Color(hex: "F7A9D3")
        case .move:    return Color(hex: "A9D13F")
        case .think:   return Color(hex: "B79BD2")
        }
    }

    /// Top part of the cards
    var color: Color {
        switch self {
        case .notice:  return Color(hex: "E9DD2A")
        case .breathe: return Color(hex: "A9BDE3")
        case .reflect: return Color(hex: "F2A6CF")
        case .move:    return Color(hex: "7FA02E")
        case .think:   return Color(hex: "9B78B8")
        }
    }

    /// Bottom text strip of the cards
    var lightColor: Color {
        switch self {
        case .notice:  return Color(hex: "F3F08C")
        case .breathe: return Color(hex: "DCE6F6")
        case .reflect: return Color(hex: "F8D3E6")
        case .move:    return Color(hex: "B5D05F")
        case .think:   return Color(hex: "CFB8E0")
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

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let minutes: Int
    let description: String
    let category: ActivityCategory
    let imageName: String

    init(_ title: String, _ minutes: Int, _ description: String,
         _ category: ActivityCategory, image: String) {
        self.title = title
        self.minutes = minutes
        self.description = description
        self.category = category
        self.imageName = image
    }
}

extension ActivityItem {
    static let all: [ActivityItem] = [
        // Notice
        ActivityItem("Find three things", 1, "Move your attention from the screen to your surroundings.", .notice, image: "3f"),
        ActivityItem("one good thing", 1, "savor small moments.", .notice, image: "one good thing"),
        ActivityItem("54321 senses", 1, "ground yourself when your mind is on autopilot.", .notice, image: "54321 senses"),

        // Breathe
        ActivityItem("Follow the Circle", 2, "Slow your breathing with a guide.", .breathe, image: "Follow the Circle"),
        ActivityItem("Count 8 Breaths", 2, "Bring your attention back.", .breathe, image: "Count 8 Breaths"),
        ActivityItem("Breathing Box", 2, "Find a steady breathing rhythm.", .breathe, image: "Breathing Box"),

        // Reflect
        ActivityItem("Scroll Check-In", 1, "Notice what brought you here.", .reflect, image: "Scroll Check-In"),
        ActivityItem("Make a Plan", 2, "Choose what to do instead of scrolling.", .reflect, image: "Make a Plan"),
        ActivityItem("Name Your Feeling", 1, "Understand how you're feeling.", .reflect, image: "Name Your Feeling"),
        ActivityItem("Three Good Things", 2, "Notice what's going well.", .reflect, image: "Three Good Things"),

        // Move
        ActivityItem("Neck Reset", 1, "Ease tension from looking down.", .move, image: "Neck Reset"),
        ActivityItem("Quick Stretch", 2, "Loosen up after sitting.", .move, image: "Quick Stretch"),
        ActivityItem("Eye Break", 1, "Give your eyes a screen break.", .move, image: "Eye Break"),
        ActivityItem("Dance Break", 3, "Lift your mood through movement.", .move, image: "Dance Break"),
        ActivityItem("Window Walk", 2, "Refresh your attention with a change of scenery.", .move, image: "Window Walk"),

        // Think
        ActivityItem("6-Word Recall", 2, "Challenge your short-term memory.", .think, image: "6-Word Recall"),
        ActivityItem("Count Back by 7", 1, "Give your focus a challenge.", .think, image: "Count Back by 7"),
        ActivityItem("Logic Riddle", 2, "Switch to active problem-solving.", .think, image: "Logic Riddle")
        ]
        }

// MARK: - Activities home
// Shown in the Activity tab of MainTabView (Home.swift).

struct ActivitiesHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("activities")
                                .font(AppFont.largeTitle)
                            Text("small breaks for a busy brain")
                                .font(.system(size: 16))
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(Color(hex: "F6B3D6"))
                            Image(systemName: "hare.fill")
                                .foregroundStyle(.white)
                        }
                        .frame(width: 52, height: 52)
                    }
                    .padding(.bottom, 6)

                    NavigationLink {
                        ActivityBrowserView(initial: nil)
                    } label: {
                        row(title: "All Activities",
                            subtitle: "everything in one place",
                            color: Color(hex: "E9E9E6"),
                            imageName: ActivityCategory.allHomeImageName)
                    }
                    .buttonStyle(.plain)

                    ForEach(ActivityCategory.allCases) { category in
                        NavigationLink {
                            ActivityBrowserView(initial: category)
                        } label: {
                            row(title: category.rawValue,
                                subtitle: category.homeSubtitle,
                                color: category.color,
                                imageName: category.homeImageName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }

    private func row(title: String, subtitle: String, color: Color, imageName: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.title2)
                Text(subtitle)
                    .font(.system(size: 14))
            }

            Spacer(minLength: 0)

            ActivityImage(name: imageName)
                .frame(width: 120, height: 80)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Browser (Activity Library + all category pages in ONE view)
// nil = All (Activity Library), otherwise the chosen category.

struct ActivityBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ActivityCategory?

    init(initial: ActivityCategory?) {
        _selected = State(initialValue: initial)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var items: [ActivityItem] {
        guard let selected else { return ActivityItem.all }
        return ActivityItem.all.filter { $0.category == selected }
    }

    private var titleText: String {
        selected?.rawValue ?? "Activity Library"
    }

    private var subtitleText: String {
        selected?.pageSubtitle ?? "pick whatever feels right for you now"
    }

    private var headerColor: Color {
        selected?.headerColor ?? Color(hex: "F2F2EF")
    }

    private var countText: String {
        let mins = items.map { $0.minutes }
        guard let lo = mins.min(), let hi = mins.max() else { return "" }
        let range = lo == hi ? "\(lo) minute" : "\(lo)-\(hi) minutes"
        let noun = items.count == 1 ? "activity" : "activities"
        return "\(items.count) \(noun). \(range)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { activity in
                        // Display only – no navigation on tap
                        ActivityCard(activity: activity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: selected)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44, alignment: .leading)
            }

            Text(titleText)
                .font(AppFont.largeTitle)

            Text(subtitleText)
                .font(.system(size: 16))

            Text(countText)
                .font(.system(size: 14))
                .opacity(0.7)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selected == nil) {
                        selected = nil
                    }
                    ForEach(ActivityCategory.allCases) { category in
                        FilterChip(title: category.rawValue, isSelected: selected == category) {
                            selected = category
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            headerColor
                .clipShape(RoundedCorner(radius: 40, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Shared components

/// Shows the image from Assets if it exists (same name as `name`),
/// otherwise shows a placeholder box.
struct ActivityImage: View {
    let name: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            ImagePlaceholder()
        }
    }
}

struct ImagePlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.black.opacity(0.25),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.black.opacity(0.3))
        }
        .padding(14)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(hex: "2B2B1E"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Color(hex: "1C1C1E") : .clear))
        }
        .buttonStyle(.plain)
    }
}

struct ActivityCard: View {
    let activity: ActivityItem

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                activity.category.color
                ActivityImage(name: activity.imageName)
            }
            .frame(height: 118)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activity.title)
                        .font(AppFont.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Label("\(activity.minutes)m", systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.55))
                }
                Text(activity.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(activity.category.lightColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted)).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    ActivitiesHomeView()
}
