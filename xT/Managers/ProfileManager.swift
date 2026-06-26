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
import CryptoKit

/// ProfileManager for handling user profile information
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    // Profile information
    @Published var profileName: String = ""
    @Published var profileImage: UIImage?
    @Published var profileImageData: Data?

    // Computed properties for consistent display
    var profileDisplayName: String {
        profileName.isEmpty ? "Your Profile" : profileName
    }

    var hasProfileData: Bool {
        !profileName.isEmpty || profileImageData != nil
    }

    var profileSummary: String {
        "\(profileDisplayName) - \(hasProfileData ? "Complete" : "Incomplete")"
    }

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
        let securityManager = SecurityManager.shared

        // Load profile name with validation and decryption
        if let encryptedNameData = defaults.data(forKey: "encryptedProfileName"),
           let decryptedNameData = try? securityManager.decryptData(encryptedNameData),
           let savedName = String(data: decryptedNameData, encoding: .utf8) {
            profileName = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let savedName = defaults.string(forKey: "profileName") {
            // Fallback for unencrypted data (migration)
            profileName = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
            // Migrate to encrypted storage
            migrateToEncryptedStorage()
        } else {
            profileName = ""
        }

        // Load profile image data with validation and decryption
        if let encryptedImageData = defaults.data(forKey: "encryptedProfileImageData"),
           let decryptedImageData = try? securityManager.decryptData(encryptedImageData) {
            // Validate image data
            if let image = UIImage(data: decryptedImageData) {
                profileImageData = decryptedImageData
                profileImage = image
            } else {
                // Invalid image data, clear it
                defaults.removeObject(forKey: "encryptedProfileImageData")
                profileImageData = nil
                profileImage = nil
            }
        } else if let imageData = defaults.data(forKey: "profileImageData") {
            // Fallback for unencrypted data (migration)
            // Validate image data
            if let image = UIImage(data: imageData) {
                profileImageData = imageData
                profileImage = image
                // Migrate to encrypted storage
                migrateToEncryptedStorage()
            } else {
                // Invalid image data, clear it
                defaults.removeObject(forKey: "profileImageData")
                profileImageData = nil
                profileImage = nil
            }
        }
    }

    /// Migrate existing unencrypted data to encrypted storage
    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Migrate profile name
        if let unencryptedName = defaults.string(forKey: "profileName") {
            if let nameData = unencryptedName.data(using: .utf8),
               let encryptedName = try? securityManager.encryptData(nameData) {
                defaults.set(encryptedName, forKey: "encryptedProfileName")
                defaults.removeObject(forKey: "profileName")
            }
        }

        // Migrate profile image
        if let unencryptedImageData = defaults.data(forKey: "profileImageData") {
            if let encryptedImage = try? securityManager.encryptData(unencryptedImageData) {
                defaults.set(encryptedImage, forKey: "encryptedProfileImageData")
                defaults.removeObject(forKey: "profileImageData")
            }
        }
    }

    func persistProfile() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Save profile name with validation and encryption
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nameData = trimmedName.data(using: .utf8),
           let encryptedName = try? securityManager.encryptData(nameData) {
            defaults.set(encryptedName, forKey: "encryptedProfileName")
        } else {
            defaults.removeObject(forKey: "encryptedProfileName")
        }

        // Save profile image data with validation and encryption
        if let imageData = profileImageData {
            // Validate that the data can be converted to UIImage
            if UIImage(data: imageData) != nil {
                if let encryptedImage = try? securityManager.encryptData(imageData) {
                    defaults.set(encryptedImage, forKey: "encryptedProfileImageData")
                } else {
                    // Encryption failed, clear the data
                    defaults.removeObject(forKey: "encryptedProfileImageData")
                    profileImageData = nil
                    profileImage = nil
                }
            } else {
                // Invalid image data, clear it
                defaults.removeObject(forKey: "encryptedProfileImageData")
                profileImageData = nil
                profileImage = nil
            }
        } else {
            defaults.removeObject(forKey: "encryptedProfileImageData")
        }
    }

    /// Validate profile name
    func validateProfileName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }

    /// Validate profile image data
    func validateProfileImageData(_ data: Data?) -> Bool {
        guard let data = data else { return false }
        return UIImage(data: data) != nil && data.count <= 5 * 1024 * 1024 // 5MB max
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