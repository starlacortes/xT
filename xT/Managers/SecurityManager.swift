import Foundation
import Security
import CryptoKit
import OSLog

private let log = Logger(subsystem: "com.starlacortes.xT", category: "security")

enum SecurityError: Error {
    case keychainSaveFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    /// AES-GCM produced a sealed box with no `combined` representation.
    case sealedBoxUnavailable
}

/// Owns the app's data-at-rest encryption key and the AES-GCM envelope used for
/// every piece of persisted health data. Interactive authentication lives in
/// ``AuthenticationManager``.
final class SecurityManager: Sendable {
    static let shared = SecurityManager()

    private let serviceName = "com.starlacortes.xT.security"
    private let encryptionKeyTag = "xTEncryptionKey"

    func getEncryptionKey() throws -> SymmetricKey {
        if let keyData = try? getKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try saveKeyToKeychain(keyData)
        return newKey
    }

    func encryptData(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            // `combined` is nil only for nonces that are not 96 bits. `seal` without an
            // explicit nonce always produces one, so this is unreachable — but health
            // data is not worth a force unwrap.
            guard let combined = sealedBox.combined else {
                throw SecurityError.sealedBoxUnavailable
            }
            return combined
        } catch let error as SecurityError {
            throw error
        } catch {
            throw SecurityError.encryptionFailed(error)
        }
    }

    func decryptData(_ encryptedData: Data) throws -> Data {
        let key = try getEncryptionKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityError.decryptionFailed(error)
        }
    }

    // MARK: - Keychain

    private func saveKeyToKeychain(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainSaveFailed(status)
        }
    }

    private func getKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            throw SecurityError.keychainReadFailed(status)
        }
        return data
    }

}
