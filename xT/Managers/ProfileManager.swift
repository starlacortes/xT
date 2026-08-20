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

    /// The user's chosen photo, if one is set; `nil` while on the default avatar.
    /// Single accessor so callers never have to reconcile `profileImage` with a
    /// possibly-stale `profileImageData`.
    var profilePhoto: UIImage? {
        if let image = profileImage { return image }
        if let data = profileImageData { return UIImage(data: data) }
        return nil
    }

    /// Renders the placeholder avatar with the current theme accent (and the
    /// on-accent glyph color) so the default avatar follows the user's chosen
    /// theme hue instead of a hard-coded `systemBlue`.
    private static func renderPlaceholder(accent: UIColor, glyph: UIColor) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            accent.setFill()
            ctx.cgContext.fillEllipse(in: rect)

            if let personImage = UIImage(systemName: "person.fill") {
                let imageRect = CGRect(x: size.width/2 - 40, y: size.height/2 - 40, width: 80, height: 80)
                personImage.withTintColor(glyph).draw(in: imageRect)
            }
        }
    }

    /// Get default profile image (theme-tinted placeholder).
    func getDefaultProfileImage() -> UIImage {
        Self.renderPlaceholder(accent: UIColor(Theme.Colors.accent),
                               glyph: UIColor(Theme.Colors.OnAccent.primary))
    }

    /// Get current profile image (default if none set).
    func getCurrentProfileImage() -> UIImage {
        profilePhoto ?? getDefaultProfileImage()
    }

    /// Loads the picked photo off the main actor, then updates the stored image.
    /// Async so callers can run their "image changed" side effects *after* the
    /// transfer finishes rather than at selection time.
    func handlePhotoSelection() async {
        if let selectedPhotoItem,
           let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            updateProfileImage(image)
        }
        selectedPhotoItem = nil
    }
}

// MARK: - Private Methods
internal extension ProfileManager {

    // MARK: Crypto helpers

    /// utf8 → AES-GCM → base64, or nil when the crypto box is unavailable.
    /// Replaces the four hand-rolled copies of the same chain.
    private func encryptNameToBase64(_ name: String) -> String? {
        guard let data = name.data(using: .utf8),
              let encrypted = try? SecurityManager.shared.encryptData(data) else { return nil }
        return encrypted.base64EncodedString()
    }

    /// Reads a possibly-encrypted profile name: base64 AES-GCM first, plaintext
    /// fallback for records written before encryption or by the write-side
    /// failure fallback.
    private func decryptName(_ stored: String) -> String {
        if let encryptedData = Data(base64Encoded: stored),
           let decryptedData = try? SecurityManager.shared.decryptData(encryptedData),
           let name = String(data: decryptedData, encoding: .utf8) {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return stored.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// utf8 → AES-GCM, or nil when the crypto box is unavailable. The
    /// UserDefaults fallback path stores the raw sealed box (not base64).
    private func encryptNameToData(_ name: String) -> Data? {
        guard let data = name.data(using: .utf8) else { return nil }
        return try? SecurityManager.shared.encryptData(data)
    }

    /// Decrypts image data, accepting unencrypted data written by older versions.
    /// Returns nil when neither path yields a decodable image.
    private func decryptImage(_ stored: Data) -> (data: Data, image: UIImage)? {
        if let decrypted = try? SecurityManager.shared.decryptData(stored),
           let image = UIImage(data: decrypted) {
            return (decrypted, image)
        }
        if let image = UIImage(data: stored) {
            return (stored, image)
        }
        return nil
    }

    func loadProfile() {
        // SwiftData-backed path: reads from UserPreferences, which CloudKit keeps in sync.
        if let context = modelContext,
           let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
            let securityManager = SecurityManager.shared

            // Profile name: try encrypted (base64) first, fall back to plaintext for
            // backward compatibility with data from a prior version or a CloudKit
            // sync from a device that hasn't updated yet.
            profileName = prefs.profileName.map { decryptName($0) } ?? ""

            dateOfBirth = prefs.profileDateOfBirth

            // Profile image: try encrypted first, fall back to plaintext.
            if let storedImageData = prefs.profileImageData,
               let (data, image) = decryptImage(storedImageData) {
                profileImageData = data
                profileImage = image
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
            prefs.profileName = encryptNameToBase64(trimmed) ?? trimmed
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
            } else if let encryptedName = encryptNameToBase64(trimmedName) {
                // No else: a failed encrypt keeps the previously stored name
                // rather than replacing it with plaintext.
                prefs.profileName = encryptedName
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
        if let encryptedName = encryptNameToData(trimmedName) {
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
        return !trimmedName.isEmpty && trimmedName.count <= Self.maxProfileNameLength
    }

    /// Validate profile image data
    func validateProfileImageData(_ data: Data?) -> Bool {
        guard let data = data else { return false }
        return UIImage(data: data) != nil && data.count <= Self.maxProfileImageBytes
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