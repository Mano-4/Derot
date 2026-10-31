//
//  ThreePhotosView.swift
//  Derot
//
//  The camera part of Find Three Things.
//  Hessa's FindThreeThingsView (Features/Activities) has the writing mode and a
//  "Take photos" button that calls onChoosePhotos. FindThreeThingsWithCamera
//  connects that button to ThreePhotosView, which takes the three photos with
//  CameraPicker (the native iOS camera).
//

import SwiftUI
#if os(iOS)
import UIKit
import AVFoundation
#endif

// MARK: - FindThreeThingsWithCamera

// Use this instead of FindThreeThingsView so "Take photos" opens the camera.
struct FindThreeThingsWithCamera: View {
    var onComplete: (Int) -> Void = { _ in }
    var onClose: (() -> Void)? = nil
    var introImageName: String = "notice-blue-intro"

    // The color picked by Hessa's screen (e.g. "blue"). nil = photo screen closed.
    @State private var photoColor: PhotoColor?

    var body: some View {
        FindThreeThingsView(
            onComplete: onComplete,
            onClose: onClose,
            onChoosePhotos: { color in photoColor = PhotoColor(name: color) },
            introImageName: introImageName
        )
        .fullScreenCover(item: $photoColor) { color in
            ThreePhotosView(
                colorName: color.name,
                onFinish: {
                    // Three photos taken: give the points, then close the whole activity.
                    onComplete(10)
                    photoColor = nil
                    onClose?()
                },
                onCancel: { photoColor = nil }
            )
        }
    }
}

// fullScreenCover(item:) needs an Identifiable value, so the color name is wrapped.
private struct PhotoColor: Identifiable {
    let name: String
    var id: String { name }
}

// MARK: - ThreePhotosView

struct ThreePhotosView: View {
    let colorName: String
    let onFinish: () -> Void
    let onCancel: () -> Void

    // One optional photo per slot; nil means the slot is still empty.
    @State private var photos: [Image?] = [nil, nil, nil]
    // Camera state: whether the camera screen is open, and which slot (0, 1 or 2) the next photo goes into.
    @State private var showCamera = false
    @State private var cameraSlot = 0
    @State private var showCameraDenied = false
    @State private var showCameraUnavailable = false
    @State private var isComplete = false
    @Environment(\.openURL) private var openURL

    private let yellow = Color(red: 250 / 255, green: 235 / 255, blue: 107 / 255)

    private var photoCount: Int {
        photos.filter { $0 != nil }.count
    }

    private var nextEmptySlot: Int? {
        photos.firstIndex { $0 == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isComplete {
                completion
            } else {
                photoChoice
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        #if os(iOS)
        // Shows Apple's camera full screen when showCamera becomes true.
        // CameraPicker closes itself after a photo is taken or the user cancels.
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { uiImage in
                photos[cameraSlot] = Image(uiImage: uiImage)
            }
            .ignoresSafeArea()
        }
        #endif
        .alert("Camera access is off", isPresented: $showCameraDenied) {
            Button("Open Settings", action: openSettings)
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Allow camera access in Settings to snap your three things, or write them instead.")
        }
        .alert("No camera found", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device doesn't have a camera. You can write your three things instead.")
        }
    }

    private var photoChoice: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .light))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to writing")

            HStack {
                Text("Three things, three photos")
                    .font(.custom("ComingSoon-Regular", size: 22))
                Spacer(minLength: 4)
                Text("\(photoCount) of 3")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Text(nextEmptySlot.map { "Snap something \(colorName) for photo \($0 + 1)" }
                 ?? "All three found. Lovely noticing!")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    photoSlot(index)
                }
            }

            // Pushes the buttons to the bottom of the screen, above the home indicator.
            Spacer(minLength: 24)

            VStack(spacing: 4) {
                if photoCount == 3 {
                    yellowButton("Finish") { isComplete = true }
                } else {
                    yellowButton("Take photos", action: takePhoto)
                }

                Button("Write them instead", action: onCancel)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func photoSlot(_ index: Int) -> some View {
        let isNext = index == nextEmptySlot

        return RoundedRectangle(cornerRadius: 12)
            .fill(yellow.opacity(isNext ? 0.4 : 0.25))
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if let photo = photos[index] {
                    photo
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera")
                            .font(.system(size: 22, weight: .light))
                        Text("Photo \(index + 1)")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(isNext ? .black : .secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if photos[index] != nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(red: 0.44, green: 0.56, blue: 0.35), in: Circle())
                        .padding(6)
                }
            }
            .overlay {
                if isNext {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.black.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photos[index] == nil ? "Photo \(index + 1), not taken yet" : "Photo \(index + 1), taken")
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 36)
            Image("celebratingbunny")
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 190)
                .accessibilityHidden(true)
            Text("Lovely noticing!")
                .font(.custom("ComingSoon-Regular", size: 34, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
            Text("3 \(colorName) things · all found")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("+10 pts", systemImage: "star.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(yellow, in: Capsule())
            Spacer(minLength: 60)
            yellowButton("Back home", action: onFinish)
        }
        .frame(maxWidth: .infinity)
    }

    private func yellowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(yellow, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // Runs when the user taps "Take photos".
    // It checks for a camera and for permission before opening the camera.
    private func takePhoto() {
        // The photo always goes into the first empty slot.
        guard let slot = nextEmptySlot else { return }

        #if os(iOS)
        // Step 1: does this device have a camera at all?
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }
        // Step 2: has the user allowed Derot to use the camera?
        // (The text in the iOS permission popup comes from NSCameraUsageDescription in Info.plist.)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openCamera(for: slot)
        case .notDetermined:
            // Never asked yet: iOS shows its permission popup and waits for the answer.
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    openCamera(for: slot)
                } else {
                    showCameraDenied = true
                }
            }
        default:
            // Denied (or blocked by Screen Time): explain how to turn it on in Settings.
            showCameraDenied = true
        }
        #else
        showCameraUnavailable = true
        #endif
    }

    // Remembers which slot to fill, then opens the camera (see .fullScreenCover in body).
    private func openCamera(for slot: Int) {
        cameraSlot = slot
        showCamera = true
    }

    private func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}
