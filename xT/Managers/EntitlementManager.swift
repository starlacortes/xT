//
//  EntitlementManager.swift
//  xT
//
//  Owns the Isocline Plus entitlement (calibration-and-subscriptions plan
//  §3.2, §8). StoreKit is the source of truth; the keychain copy exists only
//  so the gate is right on the first frame and offline. When the two
//  disagree (say, a refund processed server-side before this device has seen
//  `Transaction.updates`), StoreKit wins on the next `refresh()`. Don't add a
//  second source of truth.
//
//  Gates read `isPremium` (the visual layer: active subscribers only) or
//  `hasFunctionalAccess` (active or lapsed). Safety overrides are never
//  gated (§6.3).
//

import Foundation
import Observation
import Security
import StoreKit
import SwiftUI

@MainActor
@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()

    private(set) var access: PlusAccess = .free
    /// The active subscription's product, for the Settings plan line.
    private(set) var currentProductID: String?
    /// The active subscription's renewal (or grace-period end) date.
    private(set) var expirationDate: Date?

    var isPremium: Bool { access == .active }
    var hasLapsedPremium: Bool { access == .lapsed }
    var hasFunctionalAccess: Bool { access != .free }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private init() {
        loadCached()
        // Renewals, lapses, refunds, family-sharing changes and purchases
        // made on another device all arrive here.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Re-reads the entitlement from StoreKit. Works offline: StoreKit
    /// answers from the device's signed transaction cache.
    func refresh() async {
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  PlusProduct.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            let newest = (transaction.expirationDate ?? .distantPast)
                > (active?.expirationDate ?? .distantPast)
            if active == nil || newest { active = transaction }
        }

        var hasPast = false
        if active == nil {
            for productID in PlusProduct.all {
                if let latest = await Transaction.latest(for: productID),
                   case .verified = latest {
                    hasPast = true
                    break
                }
            }
        }

        access = PlusAccess.resolve(hasActive: active != nil, hasPastTransaction: hasPast)
        currentProductID = active?.productID
        expirationDate = active?.expirationDate
        saveCached()
    }

    /// Restore Purchases: asks the App Store to resync this Apple ID's
    /// transactions (it may prompt for sign-in), then re-reads.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            print("[Entitlement] AppStore.sync failed: \(error)")
        }
        await refresh()
    }

    // MARK: - Keychain cache

    private struct Cached: Codable {
        var access: PlusAccess
        var productID: String?
        var expiration: Date?
    }

    private static let keychainService = "com.starlacortes.isocline.entitlement"
    private static let keychainAccount = "plus"

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
    }

    private func loadCached() {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let cached = try? JSONDecoder().decode(Cached.self, from: data) else { return }
        access = cached.access
        currentProductID = cached.productID
        expirationDate = cached.expiration
    }

    private func saveCached() {
        let cached = Cached(access: access, productID: currentProductID, expiration: expirationDate)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var add = keychainQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

// MARK: - Environment

@MainActor
struct EntitlementManagerKey: @MainActor EnvironmentKey {
    // EnvironmentValues is MainActor-isolated, so this default is always read
    // on the main actor.
    static var defaultValue: EntitlementManager { .shared }
}

extension EnvironmentValues {
    @MainActor
    var entitlementManager: EntitlementManager {
        get { self[EntitlementManagerKey.self] }
        set { self[EntitlementManagerKey.self] = newValue }
    }
}
