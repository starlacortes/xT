import SwiftUI
import PhotosUI

/// Camera capture bridge for the profile photo pickers in Profile and
/// Onboarding. (Moved out of `PhotoPicker.swift`, which was misnamed — it
/// never contained a PhotosPicker, only this camera bridge.)
struct CameraPicker: UIViewControllerRepresentable {
    /// Delivers the captured `UIImage`. Handing the raw image up (instead of a
    /// `Data?` binding) lets callers route it through `updateProfileImage`, which
    /// sets both `profileImage` and `profileImageData`, validates, and persists.
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Profile photo pickers

/// Wires the library picker sheet, camera sheet, and photo-selection handler
/// that the profile-photo flows in Onboarding and `ProfileEditorView` carried
/// as hand-copied binding trios. The two screens keep their own trigger UI
/// (inline buttons vs. action sheet); this owns only the shared plumbing.
struct ProfilePhotoPickersModifier: ViewModifier {
    @Environment(\.profileManager) private var profileManager
    @Binding var libraryPresented: Bool
    @Binding var cameraPresented: Bool
    /// Called when a new image lands, from either source (e.g. Profile uses it
    /// to refresh its has-changes flag).
    var onImageChanged: () -> Void = {}

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $libraryPresented,
                          selection: Binding(
                              get: { profileManager.selectedPhotoItem },
                              set: { profileManager.selectedPhotoItem = $0 }),
                          matching: .images)
            .sheet(isPresented: $cameraPresented) {
                CameraPicker { image in
                    profileManager.updateProfileImage(image)
                    onImageChanged()
                }
            }
            .onChange(of: profileManager.selectedPhotoItem) { _, _ in
                Task {
                    await profileManager.handlePhotoSelection()
                    onImageChanged()
                }
            }
    }
}

extension View {
    func profilePhotoPickers(libraryPresented: Binding<Bool>,
                             cameraPresented: Binding<Bool>,
                             onImageChanged: @escaping () -> Void = {}) -> some View {
        modifier(ProfilePhotoPickersModifier(
            libraryPresented: libraryPresented,
            cameraPresented: cameraPresented,
            onImageChanged: onImageChanged
        ))
    }
}
