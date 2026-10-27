import SwiftUI
#if os(iOS)
import UIKit

// MARK: - CameraPicker
//
// SwiftUI has no built-in camera screen, so we borrow Apple's ready-made one:
// UIImagePickerController (a UIKit screen).
//
// UIViewControllerRepresentable is the "bridge" that lets a UIKit screen
// be used inside SwiftUI like any other View.
//
// How to use it (see ThreeBlueThingsView.swift):
//     .fullScreenCover(isPresented: $showCamera) {
//         CameraPicker { image in
//             // do something with the photo
//         }
//     }
//
// Before showing it, always check that the device has a camera:
//     UIImagePickerController.isSourceTypeAvailable(.camera)
struct CameraPicker: UIViewControllerRepresentable {
    // Called with the photo after the user taps "Use Photo".
    let onCapture: (UIImage) -> Void

    // SwiftUI's way to close the screen we were presented in (the fullScreenCover).
    @Environment(\.dismiss) private var dismiss

    // 1. SwiftUI calls this once to create the UIKit camera screen.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera               // use the camera, not the photo library
        // Important: without the next three lines the camera showed a black screen on iOS 27.
        // It tried to start in Portrait mode with a lens that doesn't support it.
        picker.mediaTypes = ["public.image"]      // photos only, no video
        picker.cameraCaptureMode = .photo         // start in plain Photo mode
        picker.cameraDevice = .rear               // start with the back camera
        picker.delegate = context.coordinator     // the coordinator receives the result (see below)
        return picker
    }

    // 2. SwiftUI calls this when our data changes. The camera needs no updates, so it stays empty.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // 3. SwiftUI calls this once to create the coordinator.
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator
    //
    // UIKit doesn't return results like SwiftUI does. Instead it calls methods on a "delegate"
    // object. The Coordinator is that delegate: UIKit tells it what happened,
    // and it passes the result back to SwiftUI.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        // UIKit calls this after the user takes a photo and taps "Use Photo".
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // The photo is stored in the info dictionary under .originalImage.
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()   // close the camera and go back to the activity
        }

        // UIKit calls this when the user taps "Cancel". Nothing is saved.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
