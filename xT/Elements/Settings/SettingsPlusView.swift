//
//  SettingsPlusView.swift
//  xT
//
//  Settings → Isocline Plus (calibration-and-subscriptions plan §10). Active
//  subscribers see their plan, renewal date and Manage Subscription (Apple's
//  own sheet). Everyone else sees what Plus adds and a button to the
//  paywall; a lapsed subscriber's reads "Resubscribe". Restore Purchases is
//  always here.
//

import StoreKit
import SwiftUI

struct SettingsPlusView: View {
    @Environment(\.entitlementManager) private var entitlementManager

    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                if entitlementManager.isPremium {
                    planGroup
                } else {
                    offerGroup
                }
                restoreGroup
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Isocline Plus")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PlusPaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: showingManageSubscriptions) { _, isShowing in
            if !isShowing { Task { await entitlementManager.refresh() } }
        }
        .task { await entitlementManager.refresh() }
    }

    // MARK: - Active plan

    private var planGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(text: "Your plan", emphasis: .accent)
            SettingsGroup {
                SettingsRow(icon: "seal",
                            title: "Isocline Plus",
                            subtitle: planSubtitle)
                SettingsGroupDivider()
                Button {
                    showingManageSubscriptions = true
                } label: {
                    SettingsRow(icon: "creditcard",
                                title: "Manage subscription",
                                subtitle: "Change plan or cancel") {
                        SettingsChevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var planSubtitle: LocalizedStringResource {
        let plan = entitlementManager.currentProductID == PlusProduct.monthly
            ? String(localized: "Monthly", comment: "Isocline Plus billing period")
            : String(localized: "Yearly", comment: "Isocline Plus billing period")
        guard let date = entitlementManager.expirationDate else {
            return LocalizedStringResource("\(plan)", comment: "Isocline Plus plan line with no renewal date")
        }
        let renews = date.formatted(date: .abbreviated, time: .omitted)
        return LocalizedStringResource(
            "\(plan) · renews \(renews)",
            comment: "Isocline Plus plan line: billing period and renewal date"
        )
    }

    // MARK: - Offer

    private var offerGroup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Group {
                if entitlementManager.hasLapsedPremium {
                    Text("Your Plus subscription has ended. Your curve, labs and targets stay; resubscribe to scrub the curve again.")
                } else {
                    Text("Plus lets you drag across the curve to read your modeled level on any day. Dose logging, reminders, site rotation, labs and your journal stay free.")
                }
            }
            .font(Theme.Fonts.callout)
            .foregroundStyle(Theme.Colors.textSecondary)
            ActionPill(title: entitlementManager.hasLapsedPremium ? "Resubscribe" : "See plans") {
                showingPaywall = true
            }
        }
    }

    // MARK: - Restore

    private var restoreGroup: some View {
        SettingsGroup {
            Button {
                Task {
                    isRestoring = true
                    await entitlementManager.restore()
                    isRestoring = false
                }
            } label: {
                SettingsRow(icon: "arrow.clockwise",
                            title: "Restore purchases",
                            subtitle: "Already subscribed on this Apple Account") {
                    if isRestoring {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsPlusView()
    }
}
#endif
