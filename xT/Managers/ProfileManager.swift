//
//  ProfileManager.swift
//  xT
//
//  Created by Cline on 3/6/2026.
//  Profile management system following MedicationManager pattern
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit
import Observation

/// ProfileManager for handling user profile information
@MainActor
@Observable
class ProfileManager {
    static let shared = ProfileManager()

    // MARK: - Constants

    /// JPEG quality used whenever a profile photo is encoded for storage.
    static let imageCompressionQuality: CGFloat = 0.8

    /// Longest accepted profile name, in characters.
    static let maxProfileNameLength = 50

    /// Largest accepted profile image payload (5 MB).
    static let maxProfileImageBytes = 5 * 1024 * 1024

    // Profile information
    var profileName: String = ""
    var profileImage: UIImage?
    var profileImageData: Data?

    /// Date of birth — used to compute age at HRT start for milestone branching
    /// (e.g. bone/cardio guidance differs at 20 vs 45). Stored unencrypted in
    /// UserDefaults (plan §4.3).
    var dateOfBirth: Date?

    // Computed properties for consistent display
    var profileDisplayName: String {
        profileName.isEmpty ? "Your Profile" : profileName
    }

    var hasProfileData: Bool {
        !profileName.isEmpty || profileImageData != nil
    }

    // Image picker state
    var showImagePicker: Bool = false
    var showCamera: Bool = false
    var selectedPhotoItem: PhotosPickerItem?

    /// Injected from xTApp after the ModelContainer is created.
    @ObservationIgnored var modelContext: ModelContext?

    init() {
        loadProfile()
    }

    /// Wire the SwiftData context, migrate any existing encrypted UserDefaults data,
    /// then reload so CloudKit-synced data takes precedence.
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        migrateProfileToUserPreferences()
        loadProfile()
    }

    /// Update profile name.
    /// - Returns: `false` when `name` fails validation, in which case the stored
    ///   profile is left untouched.
    @discardableResult
    func updateProfileName(_ name: String) -> Bool {
        guard validateProfileName(name) else {
            print("[ProfileManager] Rejected profile name: must be 1–\(Self.maxProfileNameLength) characters")
            return false
        }
        profileName = name
        persistProfile()
        return true
    }

    /// Update profile image.
    /// - Returns: `false` when the encoded image fails validation (unencodable or
    ///   over `maxProfileImageBytes`), in which case the stored profile is left untouched.
    @discardableResult
    func updateProfileImage(_ image: UIImage) -> Bool {
        let data = image.jpegData(compressionQuality: Self.imageCompressionQuality)
        guard validateProfileImageData(data) else {
            print("[ProfileManager] Rejected profile image: unencodable or over \(Self.maxProfileImageBytes) bytes")
            return false
        }
        profileImageData = data
        profileImage = image
        persistProfile()
        return true
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
        // SwiftData-backed path: reads from UserPreferences, which CloudKit keeps in sync.
        if let context = modelContext,
           let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
            let securityManager = SecurityManager.shared

            // Profile name: try encrypted (base64) first, fall back to plaintext for
            // backward compatibility with data from a prior version or a CloudKit
            // sync from a device that hasn't updated yet.
            if let storedName = prefs.profileName {
                if let encryptedData = Data(base64Encoded: storedName),
                   let decryptedData = try? securityManager.decryptData(encryptedData),
                   let name = String(data: decryptedData, encoding: .utf8) {
                    profileName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    profileName = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                profileName = ""
            }

            dateOfBirth = prefs.profileDateOfBirth

            // Profile image: try encrypted first, fall back to plaintext.
            if let storedImageData = prefs.profileImageData {
                if let decryptedData = try? securityManager.decryptData(storedImageData),
                   let image = UIImage(data: decryptedData) {
                    profileImageData = decryptedData
                    profileImage = image
                } else if let image = UIImage(data: storedImageData) {
                    profileImageData = storedImageData
                    profileImage = image
                } else {
                    profileImageData = nil
                    profileImage = nil
                }
            } else {
                profileImageData = nil
                profileImage = nil
            }
            return
        }
        // Fallback: encrypted UserDefaults (pre-context or pre-migration path).
        loadProfileFromUserDefaults()
    }

    /// One-time migration: copy encrypted UserDefaults profile data into UserPreferences
    /// SwiftData so it becomes CloudKit-synced. Guarded by a UserDefaults flag.
    func migrateProfileToUserPreferences() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "profileCloudKitMigrationDone") else { return }

        guard let context = modelContext,
              let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first
        else { return }

        // Don't overwrite data that arrived from CloudKit on this device.
        guard prefs.profileName == nil && prefs.profileImageData == nil else { return }

        let securityManager = SecurityManager.shared

        if let encryptedNameData = defaults.data(forKey: "encryptedProfileName"),
           let decryptedNameData = try? securityManager.decryptData(encryptedNameData),
           let savedName = String(data: decryptedNameData, encoding: .utf8) {
            let trimmed = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let nameData = trimmed.data(using: .utf8),
               let encrypted = try? securityManager.encryptData(nameData) {
                prefs.profileName = encrypted.base64EncodedString()
            } else {
                prefs.profileName = trimmed
            }
        }

        if let encryptedImageData = defaults.data(forKey: "encryptedProfileImageData"),
           let decryptedImageData = try? securityManager.decryptData(encryptedImageData),
           UIImage(data: decryptedImageData) != nil {
            if let encrypted = try? securityManager.encryptData(decryptedImageData) {
                prefs.profileImageData = encrypted
            } else {
                prefs.profileImageData = decryptedImageData
            }
        }

        // Don't overwrite DOB that arrived from CloudKit.
        if prefs.profileDateOfBirth == nil {
            prefs.profileDateOfBirth = defaults.object(forKey: "profileDateOfBirth") as? Date
        }

        do {
            try context.save()
            defaults.set(true, forKey: "profileCloudKitMigrationDone")
        } catch {
            print("[ProfileManager] Migration save failed: \(error) — will retry next launch")
        }
    }

    func persistProfile() {
        // SwiftData-backed path (synced via CloudKit).  Profile name and image
        // are encrypted before storage so they are not readable at rest or in
        // an iCloud backup.  The encryption key is device-local (keychain), so
        // encrypted blobs synced via CloudKit are not decryptable on another
        // device — but they remain protected if a device or backup is compromised.
        if let context = modelContext,
           let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
            let securityManager = SecurityManager.shared
            let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedName.isEmpty {
                prefs.profileName = nil
            } else if let nameData = trimmedName.data(using: .utf8),
                      let encrypted = try? securityManager.encryptData(nameData) {
                prefs.profileName = encrypted.base64EncodedString()
            }

            if let imageData = profileImageData,
               let encrypted = try? securityManager.encryptData(imageData) {
                prefs.profileImageData = encrypted
            } else {
                prefs.profileImageData = nil
            }

            prefs.profileDateOfBirth = dateOfBirth
            try? context.save()
            return
        }
        // Fallback: encrypted UserDefaults (no context yet).
        persistProfileToUserDefaults()
    }

    // MARK: - UserDefaults fallback (migration source, no longer primary storage)

    private func loadProfileFromUserDefaults() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        if let encryptedNameData = defaults.data(forKey: "encryptedProfileName"),
           let decryptedNameData = try? securityManager.decryptData(encryptedNameData),
           let savedName = String(data: decryptedNameData, encoding: .utf8) {
            profileName = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let savedName = defaults.string(forKey: "profileName") {
            profileName = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
            migrateToEncryptedStorage()
        } else {
            profileName = ""
        }

        dateOfBirth = defaults.object(forKey: "profileDateOfBirth") as? Date

        if let encryptedImageData = defaults.data(forKey: "encryptedProfileImageData"),
           let decryptedImageData = try? securityManager.decryptData(encryptedImageData),
           let image = UIImage(data: decryptedImageData) {
            profileImageData = decryptedImageData
            profileImage = image
        } else if let imageData = defaults.data(forKey: "profileImageData"),
                  let image = UIImage(data: imageData) {
            profileImageData = imageData
            profileImage = image
            migrateToEncryptedStorage()
        }
    }

    private func persistProfileToUserDefaults() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        if let dob = dateOfBirth {
            defaults.set(dob, forKey: "profileDateOfBirth")
        } else {
            defaults.removeObject(forKey: "profileDateOfBirth")
        }

        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nameData = trimmedName.data(using: .utf8),
           let encryptedName = try? securityManager.encryptData(nameData) {
            defaults.set(encryptedName, forKey: "encryptedProfileName")
        } else {
            defaults.removeObject(forKey: "encryptedProfileName")
        }

        if let imageData = profileImageData, UIImage(data: imageData) != nil,
           let encryptedImage = try? securityManager.encryptData(imageData) {
            defaults.set(encryptedImage, forKey: "encryptedProfileImageData")
        } else {
            defaults.removeObject(forKey: "encryptedProfileImageData")
        }
    }

    /// Migrate existing unencrypted UserDefaults data to encrypted UserDefaults storage.
    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        if let unencryptedName = defaults.string(forKey: "profileName"),
           let nameData = unencryptedName.data(using: .utf8),
           let encryptedName = try? securityManager.encryptData(nameData) {
            defaults.set(encryptedName, forKey: "encryptedProfileName")
            defaults.removeObject(forKey: "profileName")
        }

        if let unencryptedImageData = defaults.data(forKey: "profileImageData"),
           let encryptedImage = try? securityManager.encryptData(unencryptedImageData) {
            defaults.set(encryptedImage, forKey: "encryptedProfileImageData")
            defaults.removeObject(forKey: "profileImageData")
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