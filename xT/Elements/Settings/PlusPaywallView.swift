//
//  PlusPaywallView.swift
//  xT
//
//  The Isocline Plus paywall, presented as a sheet. StoreKit's
//  `SubscriptionStoreView` draws the plan picker, the trial line, the
//  purchase button, Restore Purchases and the Terms / Privacy links (from
//  App Store Connect metadata), so prices are always the storefront's own.
//  The header above it is ours: what Plus adds, and what stays free.
//

import StoreKit
import SwiftUI

struct PlusPaywallView: View {
    @Environment(\.entitlementManager) private var entitlementManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: PlusProduct.all) {
            PlusPaywallHeader()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases, .policies, .cancellation)
        .tint(Theme.Colors.accent)
        .containerBackground(Theme.Colors.appBackground, for: .subscriptionStoreFullHeight)
        .onInAppPurchaseCompletion { _, result in
            // Handling completion ourselves means finishing the transaction
            // ourselves too.
            if case .success(.success(let verification)) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
            }
            await entitlementManager.refresh()
            if await entitlementManager.isPremium {
                await MainActor.run { dismiss() }
            }
        }
        .onDisappear {
            // Covers Restore Purchases, which the store view runs itself.
            Task { await entitlementManager.refresh() }
        }
    }
}

/// Eyebrow, serif title, what Plus adds, and the free-tier promise.
private struct PlusPaywallHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Isocline")
                    .eyebrow()
                Text("Isocline Plus")
                    .font(Theme.Fonts.serifTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PlusFeatureRow(icon: "hand.draw",
                               title: "Read any moment of your curve",
                               detail: "Drag across the curve to see your modeled level on any day.")
            }

            Text("Dose logging, reminders, site rotation, labs and your journal stay free.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.Gutter.screen)
        .padding(.top, Theme.Spacing.xl)
    }
}

private struct PlusFeatureRow: View {
    let icon: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.card) {
            SettingsIconTile(icon: icon)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    PlusPaywallView()
}
#endif
