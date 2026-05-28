//
//  SecurityManager.swift
//  xT
//
//  Created by Cline on 4/16/2026.
//  Security management system for encryption and authentication
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit

class SecurityManager {
    static let shared = SecurityManager()

    // Keychain service identifier
    private let serviceName = "com.starlacortes.xT.security"

    // Encryption key tag
    private let encryptionKeyTag = "xTEncryptionKey"

    // Biometric authentication context
    private let authContext = LAContext()

    /// Generate or retrieve encryption key from Keychain
    func getEncryptionKey() -> SymmetricKey? {
        // Check if key exists in Keychain
        if let keyData = getKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }

        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // Store new key in Keychain
        if saveKeyToKeychain(keyData) {
            return newKey
        }

        return nil
    }

    /// Encrypt data using AES-256-GCM
    func encryptData(_ data: Data) -> Data? {
        guard let key = getEncryptionKey() else { return nil }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption failed: \(error)")
            return nil
        }
    }

    /// Decrypt data using AES-256-GCM
    func decryptData(_ encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else { return nil }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            print("Decryption failed: \(error)")
            return nil
        }
    }

    /// Check if biometric authentication is available
    func canUseBiometrics() -> Bool {
        var error: NSError?
        return authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Authenticate using biometrics
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        var error: NSError?

        if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    completion(success, authenticationError)
                }
            }
        } else {
            completion(false, error)
        }
    }

    /// Check if device passcode is set
    func isPasscodeSet() -> Bool {
        return authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // MARK: - Private Keychain Methods

    private func saveKeyToKeychain(_ keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing key first
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }

        return nil
    }

    private func deleteKeyFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}