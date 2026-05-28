//
//  SettingsView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI
import PhotosUI
import SwiftData

struct SettingsView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingProfileSheet = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    NavigationLink(destination: ProfileEditorView()) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text("Profile")
                                Text(profileManager.profileSummary)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } header: {
                    Text("Account")
                }

                // Medication Actions Section
                Section {
                    NavigationLink(destination: UnifiedScheduleView(isFromSettings: true)) {
                        Text("Set Schedule")
                    }

                    Button(action: {
                        medicationManager.recordDose(on: Date())
                    }) {
                        Text("Record Dose")
                    }
                } header: {
                    Text("Medication Actions")
                }

                // Other settings can go here
                Section {
                    Text("App Version: 1.0")
                        .foregroundColor(.gray)
                } header: {
                    Text("About")
                }

                // Development Section
                Section {
                    Button(role: .destructive, action: {
                        showingResetAlert = true
                    }) {
                        Text("Reset App Data")
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Development")
                }
            }
            .navigationTitle("Settings")
            .alert("Are you sure?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {
                    // User cancelled
                }
                Button("Reset", role: .destructive) {
                    resetAppData()
                }
            } message: {
                Text("xT will close and restart the onboarding process.")
            }
        }
    }

    private func resetAppData() {
        // Clear all UserDefaults data
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }

        // Reset managers
        profileManager.clearProfileImage()
        profileManager.updateProfileName("")
        medicationManager.clearSelection()

        // Clear SwiftData
        clearSwiftData()

        // Restart the app by setting onboarding flag to false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        // Close the app
        exit(0)
    }

    private func clearSwiftData() {
        do {
            let container = try ModelContainer(for: Item.self)
            try container.mainContext.delete(model: Item.self)
        } catch {
            print("Error clearing SwiftData: \(error)")
        }
    }
}

// MARK: - Profile Settings Subview
struct ProfileSettingsView: View {
    @Environment(\.profileManager) private var profileManager
    @State private var name: String = ""
    @State private var showingImageSourceOptions = false

    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                // Profile image with change option
                VStack {
                    Image(uiImage: profileManager.getCurrentProfileImage())
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .onTapGesture {
                            showingImageSourceOptions = true
                        }

                    Button(action: {
                        showingImageSourceOptions = true
                    }) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)

                // Name field
                TextField("Your Name", text: $name)
                    .onAppear {
                        name = profileManager.profileName
                    }
                    .onChange(of: name) {
                        profileManager.updateProfileName(name)
                    }
            }

            Section {
                Button(action: {
                    profileManager.clearProfileImage()
                }) {
                    Text("Reset to Default Photo")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    profileManager.updateProfileName("")
                    profileManager.clearProfileImage()
                } label: {
                    Text("Clear All Profile Data")
                }
            }
        }
        .navigationTitle("Profile")
        .actionSheet(isPresented: $showingImageSourceOptions) {
            ActionSheet(
                title: Text("Change Profile Photo"),
                message: Text("Choose a photo source"),
                buttons: [
                    .default(Text("Photo Library")) {
                        profileManager.showImagePicker = true
                    },
                    .default(Text("Take Photo")) {
                        profileManager.showCamera = true
                    },
                    .default(Text("Use Default")) {
                        profileManager.clearProfileImage()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: Binding(
            get: { profileManager.showImagePicker },
            set: { profileManager.showImagePicker = $0 }
        )) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: Binding(
            get: { profileManager.showCamera },
            set: { profileManager.showCamera = $0 }
        )) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .camera)
        }
        .onChange(of: profileManager.selectedPhotoItem) {
            profileManager.handlePhotoSelection()
        }
    }
}

// MARK: - Photo Picker Helper
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.profileManager, ProfileManager.shared)
}