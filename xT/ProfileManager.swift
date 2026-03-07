//
//  ProfileManager.swift
//  xT
//
//  Created by Cline on 3/6/2026.
//  Profile management system following MedicationManager pattern
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// ProfileManager for handling user profile information
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    // Profile information
    @Published var profileName: String = ""
    @Published var profileImage: UIImage?
    @Published var profileImageData: Data?

    // Image picker state
    @Published var showImagePicker: Bool = false
    @Published var showCamera: Bool = false
    @Published var selectedPhotoItem: PhotosPickerItem?

    init() {
        loadProfile()
    }

    /// Update profile name
    func updateProfileName(_ name: String) {
        profileName = name
        persistProfile()
    }

    /// Update profile image
    func updateProfileImage(_ image: UIImage) {
        profileImageData = image.jpegData(compressionQuality: 0.8)
        profileImage = image
        persistProfile()
    }

    /// Clear profile image (use default)
    func clearProfileImage() {
        profileImage = nil
        profileImageData = nil
        persistProfile()
    }

    /// Get default profile image
    func getDefaultProfileImage() -> UIImage {
        // Create a simple default profile icon
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            // Draw a circle with initials or simple icon
            let rect = CGRect(origin: .zero, size: size)
            UIColor.systemBlue.setFill()
            ctx.cgContext.fillEllipse(in: rect)

            // Add a simple person icon
            if let personImage = UIImage(systemName: "person.fill") {
                let imageRect = CGRect(x: size.width/2 - 40, y: size.height/2 - 40, width: 80, height: 80)
                personImage.draw(in: imageRect)
            }
        }
    }

    /// Get current profile image (default if none set)
    func getCurrentProfileImage() -> UIImage {
        if let image = profileImage {
            return image
        } else if let imageData = profileImageData, let image = UIImage(data: imageData) {
            return image
        } else {
            return getDefaultProfileImage()
        }
    }

    /// Handle photo picker selection
    func handlePhotoSelection() {
        Task {
            if let selectedPhotoItem,
               let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                if let image = UIImage(data: data) {
                    updateProfileImage(image)
                }
            }
            selectedPhotoItem = nil
        }
    }
}

// MARK: - Private Methods
internal extension ProfileManager {
    func loadProfile() {
        let defaults = UserDefaults.standard

        // Load profile name
        profileName = defaults.string(forKey: "profileName") ?? ""

        // Load profile image data
        if let imageData = defaults.data(forKey: "profileImageData") {
            profileImageData = imageData
            profileImage = UIImage(data: imageData)
        }
    }

    func persistProfile() {
        let defaults = UserDefaults.standard

        // Save profile name
        defaults.set(profileName, forKey: "profileName")

        // Save profile image data
        defaults.set(profileImageData, forKey: "profileImageData")
    }
}

// MARK: - Environment Key
@MainActor
struct ProfileManagerKey: @MainActor EnvironmentKey {
    static let defaultValue: ProfileManager = ProfileManager.shared
}

extension EnvironmentValues {
    @MainActor
    var profileManager: ProfileManager {
        get { self[ProfileManagerKey.self] }
        set { self[ProfileManagerKey.self] = newValue }
    }
}