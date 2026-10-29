// xcode: set sdk=iOS
//
//  Profile.swift
//  
//
//  Created by mona almogren on 11/05/1448 AH.
//

import SwiftUI
import Combine
import AVFoundation
import Photos
import UserNotifications
import UIKit

enum BunnyPose: String, CaseIterable, Identifiable {
    case happy, tired, angry, surprised

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var imageNames: [String] {
        switch self {
        case .happy: return ["Happy", "expression_02_happy"]
        case .tired: return ["Tired"]
        case .angry: return ["Angry"]
        case .surprised: return ["Surprised"]
        }
    }

    var resolvedName: String? {
        imageNames.first { UIImage(named: $0) != nil }
    }
}

enum CharacterColor: String, CaseIterable, Identifiable {
    case pink, yellow, blue, olive, plum

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink: return .blush
        case .yellow: return .sunny
        case .blue: return .mist
        case .olive: return .olive
        case .plum: return .plum
        }
    }
}

extension Color {
    static let plum = Color(hex: 0xA67FAE)
}

final class CharacterStore: ObservableObject {
    @Published var pose: BunnyPose {
        didSet {
            UserDefaults.standard.set(pose.rawValue, forKey: "character.pose")
        }
    }

    @Published var color: CharacterColor {
        didSet {
            UserDefaults.standard.set(color.rawValue, forKey: "character.color")
        }
    }

    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "user.name")
        }
    }

    init() {
        let d = UserDefaults.standard

        pose = BunnyPose(
            rawValue: d.string(forKey: "character.pose") ?? ""
        ) ?? .happy

        color = CharacterColor(
            rawValue: d.string(forKey: "character.color") ?? ""
        ) ?? .pink

        userName = d.string(forKey: "user.name") ?? "You"
    }
}

struct BunnyImage: View {
    let pose: BunnyPose

    var body: some View {
        if let name = pose.resolvedName {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            VStack(spacing: 4) {
                Text("🐰")
                    .font(.system(size: 36))

                Text(pose.label)
                    .font(.appCaption)
            }
        }
    }
}

struct CharacterHero: View {
    let pose: BunnyPose
    let color: Color
    var height: CGFloat = 200

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(
                    width: height * 0.62,
                    height: height * 0.62
                )
                .offset(y: -height * 0.02)

            BunnyImage(pose: pose)
                .frame(
                    width: height * 0.8,
                    height: height
                )
        }
        .frame(
            width: height * 0.9,
            height: height
        )
    }
}

struct CharacterBadge: View {
    @EnvironmentObject private var store: CharacterStore
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .fill(store.color.color)

            BunnyImage(pose: store.pose)
                .frame(
                    width: size * 0.86,
                    height: size * 0.96
                )
                .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct LargePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Color.sunny,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SettingsRowLabel<Trailing: View>: View {
    let title: String
    let tint: Color
    let trailing: () -> Trailing

    init(
        title: String,
        tint: Color,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9)
                .fill(tint)
                .frame(width: 32, height: 32)

            Text(title)
                .font(.appBody)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(
            Color.cardGray,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(Color.ink)
    }
}

struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}



struct ProfileView: View {
    @EnvironmentObject private var store: CharacterStore
    @AppStorage("notificationsOn") private var notificationsOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Profile")
                    .font(.appLargeTitle)

                Text("Appearance")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)

                appearanceCard

                Text("Settings")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                settingsRows
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearanceCard: some View {
        let others = BunnyPose.allCases.filter { $0 != store.pose }

        return VStack(spacing: 8) {
            ZStack {
                CharacterHero(
                    pose: store.pose,
                    color: store.color.color,
                    height: 200
                )
                .id(store.pose)
                .transition(
                    .scale(scale: 0.9).combined(with: .opacity)
                )
                .offset(y: -40)

                if others.count >= 3 {
                    thumb(others[0])
                        .offset(x: -125, y: 40)

                    thumb(others[1])
                        .offset(x: 0, y: 95)

                    thumb(others[2])
                        .offset(x: 125, y: 48)
                }
            }
            .frame(height: 270)

            swatches
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            Color.cardGray,
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func thumb(_ pose: BunnyPose) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35)) {
                store.pose = pose
            }
        } label: {
            BunnyImage(pose: pose)
                .frame(width: 64, height: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pose.label)
    }

    private var swatches: some View {
        HStack(spacing: 18) {
            ForEach(CharacterColor.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.color = option
                    }
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.ink,
                                    lineWidth: store.color == option ? 2.5 : 0
                                )
                                .padding(-5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
            }
        }
        .padding(.vertical, 6)
    }

    private var settingsRows: some View {
        VStack(spacing: 8) {
            SettingsRowLabel(title: "Notifications", tint: .olive) {
                Toggle("", isOn: $notificationsOn)
                    .labelsHidden()
                    .tint(.green)
            }

            NavigationLink {
                PermissionsView()
            } label: {
                SettingsRowLabel(title: "App permissions", tint: .mist) {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                TrackedAppsView()
            } label: {
                SettingsRowLabel(title: "Tracked apps", tint: .plum) {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }
}



struct TrackedAppsView: View {
    @Environment(\.dismiss) private var dismiss

    private let apps: [(name: String, on: Bool, limit: Double)] = [
        ("Snapchat", true, 45),
        ("Instagram", false, 30),
        ("TikTok", true, 30),
        ("YouTube", false, 60)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tracked apps")
                    .font(.appLargeTitle)

                VStack(spacing: 8) {
                    ForEach(apps, id: \.name) { app in
                        TrackedAppRow(
                            name: app.name,
                            defaultOn: app.on,
                            defaultLimit: app.limit
                        )
                    }
                }
                .padding(.top, 4)

                Button("+ Add more apps") {
                    // Add-app action can be implemented here.
                }
                .font(.appHeadline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button("Save") {
                dismiss()
            }
            .buttonStyle(LargePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(Color.white)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrackedAppRow: View {
    let name: String

    @AppStorage private var isOn: Bool
    @AppStorage private var limit: Double

    init(name: String, defaultOn: Bool, defaultLimit: Double) {
        self.name = name
        _isOn = AppStorage(
            wrappedValue: defaultOn,
            "tracked.\(name)"
        )
        _limit = AppStorage(
            wrappedValue: defaultLimit,
            "limit.\(name)"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)

                Text(name)
                    .font(.appBody)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.green)
            }
            .frame(height: 52)

            if isOn {
                VStack(spacing: 6) {
                    HStack {
                        Text("Daily limit")
                            .font(.appCallout)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(label(limit))
                            .font(.appTitle2)
                    }

                    Slider(value: $limit, in: 5...180, step: 5)
                        .tint(.olive)

                    HStack {
                        Text("5 min")
                        Spacer()
                        Text("3 h")
                    }
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
                .transition(
                    .opacity.combined(with: .move(edge: .top))
                )
            }
        }
        .padding(.horizontal, 12)
        .background(
            Color.cardGray,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(Color.ink)
        .animation(.easeInOut(duration: 0.25), value: isOn)
    }

    private func label(_ minutes: Double) -> String {
        let m = Int(minutes)

        if m < 60 {
            return "\(m) min"
        }

        let h = m / 60
        let r = m % 60

        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }
}



enum PermissionKind {
    case screenTime, camera, notifications, photos
}

@MainActor
final class PermissionsModel: ObservableObject {
    @Published var screenTime = false
    @Published var camera = false
    @Published var notifications = false
    @Published var photos = false

    func refresh() async {
        camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized

        let p = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photos = p == .authorized || p == .limited

        let settings = await UNUserNotificationCenter.current()
            .notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notifications = true
        default:
            notifications = false
        }
    }

    func handleTap(_ kind: PermissionKind) async {
        switch kind {
        case .camera:
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                await refresh()
            } else {
                openAppSettings()
            }

        case .photos:
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                await refresh()
            } else {
                openAppSettings()
            }

        case .notifications:
            let settings = await UNUserNotificationCenter.current()
                .notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])

                await refresh()
            } else {
                open(UIApplication.openNotificationSettingsURLString)
            }

        case .screenTime:
            openAppSettings()
        }
    }

    func openAppSettings() {
        open(UIApplication.openSettingsURLString)
    }

    private func open(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

struct PermissionsView: View {
    @StateObject private var model = PermissionsModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("App permissions")
                    .font(.appLargeTitle)

                VStack(spacing: 8) {
                    row(
                        .screenTime,
                        "Screen Time access",
                        "Needed to count minutes in apps",
                        model.screenTime
                    )

                    row(
                        .camera,
                        "Camera",
                        "For activities that use a photo",
                        model.camera
                    )

                    row(
                        .notifications,
                        "Notifications",
                        "So your buddy can nudge you",
                        model.notifications
                    )

                    row(
                        .photos,
                        "Photos",
                        "Pick pictures from your library",
                        model.photos
                    )
                }
                .padding(.top, 4)

                Text("Your data never leaves your phone")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button("Open Settings") {
                model.openAppSettings()
            }
            .buttonStyle(LargePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(Color.white)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            Task {
                await model.refresh()
            }
        }
    }

    private func row(
        _ kind: PermissionKind,
        _ title: String,
        _ subtitle: String,
        _ allowed: Bool
    ) -> some View {
        Button {
            Task {
                await model.handleTap(kind)
            }
        } label: {
            PermissionRow(
                title: title,
                subtitle: subtitle,
                allowed: allowed
            )
        }
        .buttonStyle(.plain)
    }
}

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let allowed: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appBody)

                Text(subtitle)
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(allowed ? "Allowed" : "Not allowed")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(
                    allowed
                    ? Color(hex: 0x5B7415)
                    : Color(hex: 0xA23A72)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    allowed
                    ? Color(hex: 0xE6EEC8)
                    : Color(hex: 0xFBD9EA),
                    in: Capsule()
                )
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(
            Color.cardGray,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(Color.ink)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(CharacterStore())
}
