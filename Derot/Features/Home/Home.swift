//
//  Home.swift
//
//  Created by mona almogren on 11/05/1448 AH.
//

import SwiftUI
import Combine
import UIKit

extension Color {
    static let ink      = Color(hex: 0x1C1C1E)
    static let olive    = Color(hex: 0x7A9A1F)
    static let sunny    = Color(hex: 0xFFE600)
    static let blush    = Color(hex: 0xF4A8CF)
    static let mist     = Color(hex: 0xA9BBD6)
    static let cardGray = Color(hex: 0xF2F2F7)

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}


extension Font {
    static func hand(_ size: CGFloat) -> Font {
        .custom("ComingSoon-Regular", size: size)
    }

    static func rounded(
        _ size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let appLargeTitle = Font.hand(34)
    static let appTitle      = Font.hand(28)
    static let appTitle2     = Font.hand(22)
    static let appHeadline   = Font.hand(17)
    static let appBody       = Font.hand(17)
    static let appCallout    = Font.hand(16)
    static let appFootnote   = Font.hand(13)
    static let appCaption    = Font.hand(12)
}



struct SmallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(
                Color.ink,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}



struct UsageItem: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Int
    let color: Color
}

struct Activity: Identifiable {
    let id = UUID()
    let name: String
    let duration: String
    let detail: String
    let symbol: String
    let artName: String?
    let color: Color
}



struct HomeView: View {
    @EnvironmentObject private var store: CharacterStore

    private let streak = 7
    private let points = 240

    private let usage: [UsageItem] = [
        UsageItem(name: "TikTok", minutes: 38, color: .blush),
        UsageItem(name: "YouTube", minutes: 22, color: .mist),
        UsageItem(name: "Instagram", minutes: 12, color: .olive)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                YourDayCard(items: usage)

                PickCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    StreakFlame()

                    Text("\(streak)")
                        .font(.appHeadline)
                }

                Text("\(points) points")
                    .font(.appCaption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Color.sunny,
                        in: Capsule()
                    )

                Text("Hey, \(store.userName)!")
                    .font(.appLargeTitle)
                    .padding(.top, 8)
            }

            Spacer()

            CharacterBadge(size: 84)
        }
    }
}



struct YourDayCard: View {
    let items: [UsageItem]

    private var total: Int {
        items.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your day")
                    .font(.appHeadline)

                Spacer()

                Text("Today")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
            }

            Text("\(total / 60)h \(total % 60)m")
                .font(.appLargeTitle)

            UsageBar(items: items)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)

                        Text(item.name)
                            .font(.appCallout)

                        Spacer()

                        Text("\(item.minutes)m")
                            .font(.appCallout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.cardGray,
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}



struct UsageBar: View {
    let items: [UsageItem]

    private var total: Double {
        Double(items.reduce(0) { $0 + $1.minutes })
    }

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 2
            let usable = geo.size.width
                - gap * CGFloat(max(items.count - 1, 0))

            HStack(spacing: gap) {
                ForEach(items) { item in
                    item.color
                        .frame(
                            width: total > 0
                                ? usable * CGFloat(
                                    Double(item.minutes) / total
                                )
                                : 0
                        )
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }
}



struct PickCard: View {
    var onStart: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {

       

            Color.mist

            Image(systemName: "wind")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(.top, 20)

           

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Box Breathing")
                            .font(.appHeadline)
                            .foregroundStyle(Color.ink)

                        Label("2 min", systemImage: "clock")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Button(action: onStart) {
                        Text("Start")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(
                                Color.ink,
                                in: RoundedRectangle(cornerRadius: 11)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text("Slow down and focus on your breathing.")
                    .font(.appFootnote)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    topTrailingRadius: 16
                )
                .fill(Color.white)
                .overlay {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        topTrailingRadius: 16
                    )
                    .fill(Color.mist.opacity(0.15))
                }
            }
        }
        .frame(height: 150)
        .clipShape(
            RoundedRectangle(cornerRadius: 24)
        )
    }
}



struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * s,
                y: rect.minY + y * s
            )
        }

        var path = Path()

        path.move(to: p(60, 8))
        path.addCurve(
            to: p(90, 72),
            control1: p(64, 28),
            control2: p(90, 40)
        )
        path.addCurve(
            to: p(60, 112),
            control1: p(90, 96),
            control2: p(76, 112)
        )
        path.addCurve(
            to: p(30, 72),
            control1: p(44, 112),
            control2: p(30, 96)
        )
        path.addCurve(
            to: p(44, 40),
            control1: p(30, 58),
            control2: p(38, 48)
        )
        path.addCurve(
            to: p(54, 54),
            control1: p(46, 50),
            control2: p(50, 54)
        )
        path.addCurve(
            to: p(60, 8),
            control1: p(52, 38),
            control2: p(54, 22)
        )

        path.closeSubpath()
        return path
    }
}

struct FlameInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * s,
                y: rect.minY + y * s
            )
        }

        var path = Path()

        path.move(to: p(60, 60))
        path.addCurve(
            to: p(74, 91),
            control1: p(62, 72),
            control2: p(74, 78)
        )
        path.addCurve(
            to: p(60, 106),
            control1: p(74, 100),
            control2: p(68, 106)
        )
        path.addCurve(
            to: p(46, 91),
            control1: p(52, 106),
            control2: p(46, 100)
        )
        path.addCurve(
            to: p(60, 60),
            control1: p(46, 80),
            control2: p(55, 74)
        )

        path.closeSubpath()
        return path
    }
}



struct StreakFlame: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            FlameShape()
                .fill(Color.sunny)

            FlameInnerShape()
                .fill(Color.blush)

            FlameShape()
                .stroke(
                    Color.ink,
                    style: StrokeStyle(
                        lineWidth: size * 0.06,
                        lineJoin: .round
                    )
                )
        }
        .frame(width: size, height: size)
    }
}



struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            NavigationStack {
                ActivitiesView()
            }
                .tabItem {
                    Label(
                        "Activity",
                        systemImage: "square.grid.2x2"
                    )
                }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(
                    "Profile",
                    systemImage: "person.circle"
                )
            }
        }
        .tint(.blue)
    }
}



// Only Find Three Things is linked for now; add the other activities here later.
struct ActivitiesView: View {
    @State private var showFindThreeThings = false

    var body: some View {
        List {
            Section("Notice") {
                Button {
                    showFindThreeThings = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye")
                            .frame(width: 36, height: 36)
                            .background(Color.sunny, in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Find Three Things")
                                .font(.appHeadline)
                            Label("1 min", systemImage: "clock")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(Color.ink)
                }
            }
        }
        .navigationTitle("Activities")
        .fullScreenCover(isPresented: $showFindThreeThings) {
            FindThreeThingsView(onClose: { showFindThreeThings = false })
        }
    }
}



#Preview {
    MainTabView()
        .environmentObject(CharacterStore())
}
