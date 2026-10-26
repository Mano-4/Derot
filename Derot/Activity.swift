import SwiftUI
import Combine

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

    var defaultSteps: [String] {
        switch self {
        case .notice:
            return ["Pause and look up from your screen.", "Notice what is around you.", "Take one slow breath."]
        case .breathe:
            return ["Sit comfortably and relax your shoulders.", "Breathe in slowly through your nose.", "Breathe out even slower."]
        case .reflect:
            return ["Check in with yourself.", "Put it into a few words.", "Be kind to whatever you find."]
        case .move:
            return ["Stand up and get ready.", "Move slowly and gently.", "Finish with a deep breath."]
        case .think:
            return ["Read the puzzle slowly.", "Take a moment to think it through.", "Say your answer out loud."]
        }
    }
}

// MARK: - Activity model

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let minutes: Int
    let description: String
    let category: ActivityCategory
    let imageName: String
    let steps: [String]

    init(_ title: String, _ minutes: Int, _ description: String,
         _ category: ActivityCategory, image: String, steps: [String]? = nil) {
        self.title = title
        self.minutes = minutes
        self.description = description
        self.category = category
        self.imageName = image
        self.steps = steps ?? category.defaultSteps
    }
}

extension ActivityItem {
    static let all: [ActivityItem] = [
        // Notice
        ActivityItem("3 blue things", 1, "Move your attention from the screen to your surroundings.", .notice, image: "blue_things",
                     steps: ["Look up from your screen.", "Find three blue things around you.", "Take a slow breath."]),
        ActivityItem("one good thing", 1, "savor small moments.", .notice, image: "one_good_thing"),
        ActivityItem("54321 senses", 1, "ground yourself when your mind is on autopilot.", .notice, image: "senses_54321",
                     steps: ["Name 5 things you can see.", "Name 4 things you can feel and 3 you can hear.", "Name 2 you can smell and 1 you can taste."]),

        // Breathe
        ActivityItem("Follow the Circle", 2, "Slow your breathing with a guide.", .breathe, image: "follow_circle"),
        ActivityItem("Count 8 Breaths", 2, "Bring your attention back.", .breathe, image: "count_breaths",
                     steps: ["Breathe in and out naturally.", "Count each breath up to 8.", "If you lose count, start again gently."]),
        ActivityItem("Breathing Box", 2, "Find a steady breathing rhythm.", .breathe, image: "breathing_box",
                     steps: ["Breathe in for 4 seconds.", "Hold for 4, breathe out for 4.", "Hold for 4 and repeat."]),

        // Reflect
        ActivityItem("Scroll Check-In", 1, "Notice what brought you here.", .reflect, image: "scroll_checkin"),
        ActivityItem("Make a Plan", 2, "Choose what to do instead of scrolling.", .reflect, image: "make_plan"),
        ActivityItem("Name Your Feeling", 1, "Understand how you're feeling.", .reflect, image: "name_feeling"),
        ActivityItem("Three Good Things", 2, "Notice what's going well.", .reflect, image: "three_good"),

        // Move
        ActivityItem("Neck Reset", 1, "Ease tension from looking down.", .move, image: "neck_reset",
                     steps: ["Tilt your ear toward your right shoulder.", "Switch and tilt toward your left shoulder.", "Roll your chin to your chest, then lift."]),
        ActivityItem("Quick Stretch", 2, "Loosen up after sitting.", .move, image: "quick_stretch",
                     steps: ["Reach both arms overhead.", "Lean gently to each side.", "Roll your shoulders back."]),
        ActivityItem("Eye Break", 1, "Give your eyes a screen break.", .move, image: "eye_break",
                     steps: ["Look at something far away.", "Blink slowly ten times.", "Rest your warm palms over your eyes."]),
        ActivityItem("Dance Break", 3, "Lift your mood through movement.", .move, image: "dance_break",
                     steps: ["Put on a song you love.", "Move however feels good.", "Shake out your arms and legs."]),
        ActivityItem("Window Walk", 2, "Refresh your attention with a change of scenery.", .move, image: "window_walk",
                     steps: ["Stand up and walk to a window.", "Name three things you can see outside.", "Take one slow breath."]),

        // Think
        ActivityItem("Logic Riddle", 2, "Wake your brain up gently.", .think, image: "logic_riddle")
    ]
}

// MARK: - Root

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }

            ActivitiesHomeView()
                .tabItem { Label("Activity", systemImage: "square.grid.2x2") }

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Color(hex: "5B7BD5"))
    }
}

// MARK: - Activities home

struct ActivitiesHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("activities")
                                .font(.system(size: 40, weight: .regular, design: .rounded))
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
                        ActivityLibraryView()
                    } label: {
                        row(title: "All Activities",
                            subtitle: "everything in one place",
                            color: Color(hex: "E9E9E6"))
                    }
                    .buttonStyle(.plain)

                    ForEach(ActivityCategory.allCases) { category in
                        NavigationLink {
                            CategoryView(category: category)
                        } label: {
                            row(title: category.rawValue,
                                subtitle: category.homeSubtitle,
                                color: category.color)
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

    private func row(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .regular, design: .rounded))
            Text(subtitle)
                .font(.system(size: 14))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Category page (Notice / Breathe / Reflect / Move / Think)

struct CategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: ActivityCategory

    init(category: ActivityCategory) {
        _category = State(initialValue: category)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var items: [ActivityItem] {
        ActivityItem.all.filter { $0.category == category }
    }

    private var rangeText: String {
        let mins = items.map { $0.minutes }
        guard let lo = mins.min(), let hi = mins.max() else { return "" }
        return lo == hi ? "\(lo) minute" : "\(lo)-\(hi) minutes"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { activity in
                        NavigationLink {
                            ActivityFlowView(activity: activity)
                        } label: {
                            ActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
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
        .animation(.easeInOut(duration: 0.25), value: category)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44, alignment: .leading)
            }

            Text(category.rawValue)
                .font(.system(size: 44, weight: .regular, design: .rounded))

            Text(category.pageSubtitle)
                .font(.system(size: 16))

            Text("\(items.count) activities. \(rangeText)")
                .font(.system(size: 14))
                .opacity(0.7)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: false) { dismiss() }
                    ForEach(ActivityCategory.allCases) { c in
                        FilterChip(title: c.rawValue, isSelected: c == category) {
                            category = c
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
            category.headerColor
                .clipShape(RoundedCorner(radius: 40, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Activity Library (all)

struct ActivityLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ActivityCategory? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var filtered: [ActivityItem] {
        guard let selected else { return ActivityItem.all }
        return ActivityItem.all.filter { $0.category == selected }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { activity in
                        NavigationLink {
                            ActivityFlowView(activity: activity)
                        } label: {
                            ActivityCard(activity: activity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.25), value: selected)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44, alignment: .leading)
            }

            Text("Activity Library")
                .font(.system(size: 40, weight: .regular, design: .rounded))

            Text("pick whatever feels right for you now")
                .font(.system(size: 16))

            Text("\(ActivityItem.all.count) activities. 1-3 minutes")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

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
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(hex: "F2F2EF")
                .clipShape(RoundedCorner(radius: 40, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Activity in progress

struct ActivityFlowView: View {
    let activity: ActivityItem

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0
    @State private var remaining = 0
    @State private var isPaused = false
    @State private var finished = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var secondsPerStep: Int {
        max(10, activity.minutes * 60 / max(activity.steps.count, 1))
    }

    private var isLastStep: Bool { stepIndex == activity.steps.count - 1 }

    var body: some View {
        Group {
            if finished {
                ActivityCompleteView(activity: activity) { dismiss() }
            } else {
                session
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { remaining = secondsPerStep }
        .onReceive(timer) { _ in tick() }
    }

    private var session: some View {
        VStack(spacing: 20) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
                Text("Step \(stepIndex + 1) of \(activity.steps.count)")
                    .font(.system(size: 14, weight: .semibold))
            }

            Text(activity.title)
                .font(.system(size: 34, weight: .regular, design: .rounded))

            dots
            ring

            Text(activity.steps[stepIndex])
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(activity.category.lightColor.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            Spacer(minLength: 0)

            PillButton(title: isLastStep ? "Finish" : "Next") { advance() }

            Button(isPaused ? "Resume" : "Pause") { isPaused.toggle() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [activity.category.headerColor.opacity(0.45), .white],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<activity.steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == stepIndex ? activity.category.color : activity.category.lightColor)
                    .frame(width: i == stepIndex ? 28 : 10, height: 10)
            }
        }
    }

    private var ring: some View {
        let progress = CGFloat(remaining) / CGFloat(secondsPerStep)
        return ZStack {
            Circle()
                .stroke(activity.category.lightColor, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(activity.category.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 52, weight: .regular, design: .rounded))
        }
        .frame(width: 210, height: 210)
    }

    private func tick() {
        guard !finished, !isPaused else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            advance()
        }
    }

    private func advance() {
        if stepIndex < activity.steps.count - 1 {
            stepIndex += 1
            remaining = secondsPerStep
        } else {
            finished = true
        }
    }
}

// MARK: - Activity complete

struct ActivityCompleteView: View {
    let activity: ActivityItem
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle().fill(activity.category.lightColor)
                BunnyArt(name: activity.imageName)
                    .padding(30)
            }
            .frame(width: 200, height: 200)

            Text("Great job!")
                .font(.system(size: 44, weight: .regular, design: .rounded))

            Text("You finished \(activity.title). A small break, a calmer you.")
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Label("+20 pts", systemImage: "star.fill")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "F2DD3F"), in: Capsule())

            Spacer()

            PillButton(title: "Done", action: onDone)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - Shared components

struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color(hex: "F2DD3F"), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct BunnyArt: View {
    let name: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "hare.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56)
                .foregroundStyle(.black.opacity(0.25))
        }
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
                BunnyArt(name: activity.imageName)
                    .padding(.top, 8)
            }
            .frame(height: 118)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activity.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
    ContentView()
}

