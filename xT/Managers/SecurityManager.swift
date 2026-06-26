import Foundation
import Security
import LocalAuthentication
import CryptoKit
import OSLog

private let log = Logger(subsystem: "com.starlacortes.xT", category: "security")

enum SecurityError: Error {
    case keyGenerationFailed
    case keychainSaveFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case biometricNotAvailable
    case authenticationFailed(Error)
    case passcodeNotSet
}

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
            return sealedBox.combined!
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

    func canUseBiometrics() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticateWithBiometrics(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                throw SecurityError.authenticationFailed(error)
            }
            throw SecurityError.biometricNotAvailable
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            guard success else {
                throw SecurityError.authenticationFailed(LAError(.userCancel))
            }
        } catch {
            throw SecurityError.authenticationFailed(error)
        }
    }

    func authenticateWithDevicePasscode(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                try await authenticateWithBiometrics(reason: reason)
            }
            throw SecurityError.passcodeNotSet
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            guard success else {
                throw SecurityError.authenticationFailed(LAError(.userCancel))
            }
        } catch {
            throw SecurityError.authenticationFailed(error)
        }
    }

    func isPasscodeSet() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
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

    private func deleteKeyFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: encryptionKeyTag
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw SecurityError.keychainDeleteFailed(status)
        }
    }
}
