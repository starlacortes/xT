
# Calibration Gating + Subscription Entitlement — Implementation Plan

Status: **Draft**
Owner: starla
Last updated: 2026-08-19

> **Update 2026-10-11: calibration display gating superseded.** The Isocline redesign decided to
> **always show the curve**, calibrated or not (decision X8 in
> [`isocline-app-transition.md`](isocline-app-transition.md)). Honesty is carried by a mono
> provenance line under the readout (`MODELED · NO LABS YET` / `MODELED · CALIBRATED TO YOUR LAB
> OF 4 MAR`) instead of by hiding output. So §3.1's `isCalibrationAnchored` is no longer a
> display gate, and the §6.1 suppressions and §7.1 State 1 card don't apply. The "log a blood
> test" prompt can still exist as an invitation. The entitlement axis (§3.2 onward) and the
> safety exemption (§6.3) are unaffected.

## 1. Background & motivation

Two intertwined problems this plan addresses:

1. **Unsafe uncalibrated estimates.** The PK model produces a hormone curve the moment the
   user logs a dose, but until a real blood-test number anchors the model, the curve is a
   population-only prediction. Users (the author included) have self-adjusted dosing against
   this uncalibrated estimate and experienced clinically low estrogen as a result. The
   estimate is not ground truth until α = measured / predicted has been computed from at
   least one lab draw for the selected hormone.

2. **No monetization layer.** The app currently has no IAP. We want to introduce a
   subscription with monthly and yearly tiers, while keeping a genuinely useful free tier
   and not punishing lapsed users by breaking their app.

The two designs compose: a view is shown only when the model is **calibrated** *and* the
user is **entitled**. Calibration is the safety gate; entitlement is the business gate.
They are independent axes, each with its own explanation surfaced to the user.

## 2. Design principles

- **Compute always, display conditionally, be explicit.** The PK engine runs identically
  regardless of state — calibration populates in the background so the moment a lab is
  entered, the curve appears already-shaped and α-aligned. We only suppress the *display*
  of uncalibrated output.
- **Follow the existing gate pattern.** The codebase already gates on `isFullyConfigured`,
  `userTherapeuticTarget != nil`, `showDoseIntensityInsights`, and `TenureTier` thresholds,
  each evaluated at the view that needs it. Calibration and entitlement are two more
  conditions joined to the same `if` statements. No new mechanism, just new conditions.
- **Never gate safety.** Documented clinical threshold overrides (E2 > 1000 pg/mL,
  E2 < 50 at trough, T > 1500 ng/dL, spironolactone-clearance hazards) remain visible
  regardless of calibration or entitlement state. Withholding a dangerous reading behind
  a paywall violates App Review guidelines and basic ethics.
- **Free tier must be genuinely usable.** App Review rejects apps whose free tier is a
  glorified paywall. Journal, dose tracking, application-site tracking, and general Time
  information remain free, useful, and not nagged.
- **Lapse de-emphasizes, never breaks.** A lapsed subscriber keeps functional premium
  features (curve, labs, targets). Only the more-visual layer deactivates. The app reads
  as quieter, not broken — soft incentive to resubscribe.

## 3. The two gating axes

### 3.1 Calibration axis — `isCalibrationAnchored`

A new derived property on `MedicationManager` (`Managers/MedicationManager.swift:279`,
alongside the existing `calibrationFactor`):

```swift
/// True once the user has entered at least one calibrated blood test for the
/// currently selected hormone. The gate that the chart, level overlay, and labs
/// chart key off — population-only estimates are not shown as if they were the
/// user's measured level.
var isCalibrationAnchored: Bool {
    bloodTestHistory.contains {
        $0.isCalibrated && $0.hormoneType == selectedMedication
    }
}
```

The predicate mirrors `calibrationFactor`'s filter (lines 288–289) so the two cannot
disagree. `refreshState()` already recomputes calibration factors on load and after
edits, so `isCalibrationAnchored` flips on the same lifecycle events that
`calibrationFactor` does — no extra wiring.

### 3.2 Entitlement axis — `EntitlementManager.isPremium` / `hasLapsedPremium`

A new `@Observable` singleton mirroring the pattern of `ProfileManager`, `JournalManager`,
etc. (wired through a custom `EnvironmentKey` at `xTApp.swift:120–126`). Exposes:

| Property | True when | Gates |
|---|---|---|
| `isPremium` | Active subscription, grace period, or billing retry | Visual premium + functional premium |
| `hasLapsedPremium` | Past verified transaction now `.expired` or `.revoked` | Functional premium only |
| `hasFunctionalAccess` | `isPremium \|\| hasLapsedPremium` | Convenience for functional gates |
| `currentProductID` | Active sub product ID | Settings display |
| `expirationDate` | Active sub renewal date | Settings display |

## 4. Free vs Paid vs Lapsed feature matrix

| Feature | Free | Premium (active) | Lapsed |
|---|---|---|---|
| Journal (mood, symptoms, text) | ✓ | ✓ | ✓ |
| Dose tracking + recording + scheduling + adherence | ✓ | ✓ | ✓ |
| Injection-site tracking + heat-map + rotation | ✓ | ✓ | ✓ |
| Time view — general body-change info | ✓ | ✓ | ✓ |
| Blood-test recording (the act of logging a lab) | ✓ | ✓ | ✓ |
| Safety overrides (E2 > 1000 etc.) | ✓ (always — never gated) | ✓ | ✓ |
| **Animated entrance / draw / confetti / dot-slide** | ✓ | ✓ | ✓ |
| **Calibrated hormone curve + level number** | — | ✓ | ✓ |
| **Labs chart (measured vs modeled)** | — | ✓ | ✓ |
| **Therapeutic target ranges + status pills** | — | ✓ | ✓ |
| **Scrub interaction on the curve** | — | ✓ | — |
| **Mood markers overlaid on the curve** | — | ✓ | — |
| **Peak/trough reference lines on the chart** | — | ✓ | — |
| **Dose-intensity insights (T5+ copy)** | — | ✓ | — |
| **Tier-specific detailed Time timelines** | — | ✓ | — |

"Lapsed" = `hasLapsedPremium && !isPremium`. The curve and labs remain; the curve feels
quieter — no scrub, no markers, no reference lines, no confetti-adjacent visual layer.
The animated entrance/draw/confetti/dot-slide remains free per product decision; those are
not part of the lapsed-downgrade set.

## 5. Three-axis view gating

Every gated surface evaluates three independent conditions, each with its own prompt:

| Condition | User sees |
|---|---|
| `!isCalibrationAnchored` | Calibration prompt card ("Log a blood test to calibrate") |
| `isCalibrationAnchored && !hasFunctionalAccess` | Subscription prompt card ("Subscribe to unlock your curve") |
| `isCalibrationAnchored && hasFunctionalAccess && !isPremium` | Curve renders, minus scrub / markers / reference lines; small "Resubscribe for the full experience" pill |
| `isCalibrationAnchored && isPremium` | Everything |

Three independent reasons a surface might be hidden, three distinct explanations surfaced.
Same pattern as the existing `userTherapeuticTarget != nil` gate at
`FlatGraphView.swift:118–124`: be explicit about *why* the user is seeing or not seeing
something.

## 6. Files to change — surfaces and gates

### 6.1 Calibration axis (suppress display of uncalibrated output)

| File | Current gate | Change |
|---|---|---|
| `HomeView.swift:55–63` (FlatGraphView) | `isFullyConfigured` | Replace chart with `CalibrationPromptCard` when `!isCalibrationAnchored` |
| `HomeView.swift:65–69` (LevelOverlayView) | `isFullyConfigured` | Don't render numeric badge until `isCalibrationAnchored` |
| `LevelOverlayView.swift:81–108` (numeric block) | `displayLevel != nil` | Wrap in `if medicationManager.isCalibrationAnchored` |
| `FlatGraphView.swift:111` (empty state) | `points.isEmpty` | Add a second empty state: `points` non-empty but `!isCalibrationAnchored` → "Log a blood test to calibrate your curve" |
| `InsightRowView.swift:31` | `currentHormoneLevel != nil` | Also requires `isCalibrationAnchored`; otherwise a one-line "Estimates are hidden until you add a lab result" row |
| `LabsChartView.swift` (Settings) | n/a | Hide entirely until anchored; replace with prompt |
| `JournalComposerView.swift:69` | `isFullyConfigured` | Don't offer hormone-level row until anchored |

### 6.2 Entitlement axis (functional vs visual)

| File | Gate | Condition |
|---|---|---|
| `HomeView.swift:55–63` (chart) | functional | `hasFunctionalAccess` |
| `LevelOverlayView.swift:81–108` (number) | functional | `hasFunctionalAccess` |
| `InsightRowView.swift:31` | functional | `hasFunctionalAccess` |
| `LabsChartView.swift` | functional | `hasFunctionalAccess` |
| `JournalComposerView.swift:69` (level row) | functional | `hasFunctionalAccess` |
| `FlatGraphView.swift` — scrub gesture overlay | visual | `isPremium` |
| `FlatGraphView.swift` — `journalMoodMarkers` | visual | `isPremium` |
| `FlatGraphView.swift` — `therapeuticReferenceLines` (already gated on `userTherapeuticTarget`) | visual | `isPremium` |
| `InsightRowView` dose-intensity copy | visual | `isPremium` |
| `TimeView.swift` tier-specific detail (T5+ copy, `unlockedChanges` deep dives) | visual | `isPremium` |

### 6.3 Safety exemption

`MedicationManager+Pharmacokinetics.swift:419` (`safetyOverride`) stays visible through
both gates. In `LevelOverlayView`, the safety pill is rendered **before** the
calibration/entitlement `if` checks, so a dangerous uncalibrated estimate still surfaces
as a safety note even when the numeric estimate is hidden.

## 7. New components

### 7.1 `CalibrationPromptCard`

A single reusable card used by Home (in place of the chart) and Settings (in place of
the labs chart). Three states, selected by the gating axis:

```
State 1 — needs calibration:
  [icon: drop.fill]
  Calibrate your model
  Your curve is hidden until you log at least one
  blood-test result for [Estrogen|Testosterone].
  Estimates are population-based and can drift low or
  high without a real number to anchor to.
  [  Add a blood test  ]   [  Why this matters  ]

State 2 — calibrated, needs entitlement:
  [icon: chart.line.uptrend.xyaxis]
  Your model is ready
  You've calibrated with a lab result. Subscribe to
  unlock your hormone curve, labs chart, and target ranges.
  [  $1.99 / month  ]   [  $14.99 / year  ]
  7-day free trial with yearly.
  [  Restore Purchases  ]   [  Why this matters  ]

State 3 — lapsed (calibrated + hasFunctionalAccess + !isPremium):
  Inline pill on the curve, not a replacement card.
  "Resubscribe for the full experience — scrub, markers,
   reference lines, and detailed timelines."
  [  Resubscribe  ]
```

The "Why this matters" sheet is the risk-disclosure surface — explicit language about
the inherited risk of self-adjusting doses against an uncalibrated or lapsed-state
estimate. Required by App Review and by the safety design.

### 7.2 `EntitlementManager`

Path: `xT/Managers/EntitlementManager.swift`. Sketch (full implementation in §8):

```swift
@MainActor @Observable
final class EntitlementManager {
    private(set) var isPremium: Bool = false
    private(set) var hasLapsedPremium: Bool = false
    private(set) var currentProductID: String?
    private(set) var expirationDate: Date?

    var hasFunctionalAccess: Bool { isPremium || hasLapsedPremium }

    init() {
        loadFromKeychain()                // instant gate on launch, works offline
        Task { await refreshFromStore() } // re-verify against the source of truth
        startTransactionUpdates()        // listen for renewals / refunds / lapse
    }

    func refreshFromStore() async { /* see §8 */ }
    func purchase(_ productID: String) async throws { /* see §8 */ }
    func restore() async { await refreshFromStore() }

    private func startTransactionUpdates() { /* see §8 */ }
    private func setIsPremium(...) { /* persists to keychain */ }
}
```

Wired into the environment in `xTApp.swift:120–126` alongside the other managers.

### 7.3 `Products.storekit`

A StoreKit configuration file (Xcode → Product → Add StoreKit Configuration File) for
local testing in the simulator. Declares:
- `com.starlacortes.xT.pro.monthly` — auto-renewable, $1.99/mo
- `com.starlacortes.xT.pro.yearly` — auto-renewable, $14.99/yr
- 7-day free trial introductory offer on yearly
- Family-sharing scenario for testing

Referenced in the scheme's Run options → StoreKit Configuration so local purchases work
without network.

### 7.4 `KeychainStore` extension

The entitlement persistence layer. Stores `isPremium`, `hasLapsedPremium`,
`expirationDate` in the keychain so the gate is instant on launch and survives
reinstall. Re-verified against `Transaction.currentEntitlements` on every app launch
and on every `Transaction.updates` event.

## 8. EntitlementManager — StoreKit 2 specifics

```swift
import StoreKit

@MainActor @Observable
final class EntitlementManager {
    private(set) var isPremium: Bool = false
    private(set) var hasLapsedPremium: Bool = false
    private(set) var currentProductID: String?
    private(set) var expirationDate: Date?

    var hasFunctionalAccess: Bool { isPremium || hasLapsedPremium }

    private var updatesTask: Task<Void, Never>?

    init() {
        loadFromKeychain()
        Task { await refreshFromStore() }
        startTransactionUpdates()
    }

    func refreshFromStore() async {
        // Product.subscriptionStatus is the canonical answer to "is this user
        // currently premium" and handles grace/billing-retry/expired for us.
        let statuses = await Product.subscriptionStatus(for: ProductIDs.group)
        guard let status = statuses.first else {
            setIsPremium(false, lapsed: hasLapsedPremium, productID: nil, expiration: nil)
            return
        }
        switch status.state {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            if case .verified(let txn) = status.transaction,
               let exp = txn.expirationDate {
                setIsPremium(true, lapsed: false,
                             productID: txn.productID, expiration: exp)
            }
        case .expired, .revoked:
            setIsPremium(false, lapsed: true, productID: nil, expiration: nil)
        case .none, .notSubscribed:
            setIsPremium(false, lapsed: hasLapsedPremium, productID: nil, expiration: nil)
        @unknown default:
            setIsPremium(false, lapsed: hasLapsedPremium, productID: nil, expiration: nil)
        }
    }

    func purchase(_ productID: String) async throws {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw StoreError.unknown }
        let result = try await product.purchase()
        if case .success(let verification) = result,
           case .verified(let txn) = verification {
            await txn.finish()
            await refreshFromStore()
        }
        // .userCancelled and .pending fall through — UI stays as-is.
    }

    func restore() async { await refreshFromStore() }

    private func startTransactionUpdates() {
        updatesTask = Task.detached { [weak self] in
            // Transaction.updates is the background stream that fires on renewal,
            // lapse, refund, and family-sharing changes — the only required listener.
            for await update in Transaction.updates {
                if case .verified(let txn) = update {
                    await txn.finish()
                    await self?.refreshFromStore()
                }
            }
        }
    }

    private func setIsPremium(_ premium: Bool, lapsed: Bool,
                              productID: String?, expiration: Date?) {
        isPremium = premium
        hasLapsedPremium = lapsed
        currentProductID = productID
        expirationDate = expiration
        KeychainStore.shared.writeEntitlement(premium: premium, lapsed: lapsed,
                                              expiration: expiration)
    }

    private func loadFromKeychain() {
        let stored = KeychainStore.shared.readEntitlement()
        isPremium = stored.premium
        hasLapsedPremium = stored.lapsed
        expirationDate = stored.expiration
    }
}

enum ProductIDs {
    static let group = "com.starlacortes.xT.pro"
    static let monthly = "com.starlacortes.xT.pro.monthly"
    static let yearly = "com.starlacortes.xT.pro.yearly"
}
```

## 9. Onboarding change

`commitOnboarding()` at `OnboardingView.swift:210` currently sets HRT start, AA flags,
ester, dose, last dose — all of it. Add a **final pre-review step** between current
Step 11 and the review screen:

> "You're all set up. Want to add a lab result now to unlock your level curve?"
> [  Add a blood test  ]   [  Skip for now  ]

`Skip for now` is allowed — that's the "not locked" part — but should require a
**tap-and-hold or confirm sheet** stating the same risk language as the
`CalibrationPromptCard` "Why this matters" sheet. This is the intentional-risk
inheritance moment: the user cannot accidentally skip past calibration without
acknowledging the model is unanchored.

If they skip, the post-onboarding Home screen shows the calibration prompt card
where the chart would be. If they add a lab, the chart appears immediately (subject
to the entitlement gate in §5).

This step does **not** mention the subscription. Subscription is surfaced
contextually via the calibration prompt card's State 2 after a lab is logged.
Mixing "add a lab" and "pay" in the same onboarding step muddies both messages.

## 10. Settings changes

In `SettingsView+Sections.swift`, near the existing blood-test history entry:

- A **status banner** when `!isCalibrationAnchored`:
  "Charts and level estimates are hidden. Add a blood test to calibrate."
  (Mirrors the existing per-ester "peak timing pending calibration" copy at
  `OnboardingView+StepsDose.swift:647`.)
- A **Premium section** with:
  - Current plan + renewal date (from `expirationDate`) or "Lapsed" badge
  - Two purchase buttons: Monthly / Yearly, yearly shows the savings framing and
    the 7-day trial badge if eligible
  - "Manage Subscription" button → opens Apple's sheet via
    `showManageSubscriptions(in:)` (iOS 15+ StoreKit API)
  - "Restore Purchases" button → `await entitlementManager.restore()`
  - The lapsed state shows "Resubscribe" instead of "Subscribe"

## 11. App Store Connect setup (not code)

1. Sign the Paid Applications Agreement; complete banking + tax information.
2. Create a **Subscription Group** named "xT Pro".
3. Add two products:
   - `com.starlacortes.xT.pro.monthly` — auto-renewable, $1.99/mo
   - `com.starlacortes.xT.pro.yearly` — auto-renewable, $14.99/yr
4. Configure a **7-day free trial introductory offer** on the yearly product.
5. Submit the subscription products alongside the next app binary; IAPs review in
   lockstep with the app.

## 12. Implementation order

1. **`isCalibrationAnchored`** on `MedicationManager` — single derived property,
   no behavior change yet. Unit-testable in isolation.
2. **`CalibrationPromptCard`** — three states, but only State 1 (needs calibration)
   wired initially.
3. **Calibration gate applied** to Home / LevelOverlay / FlatGraphView empty state /
   InsightRow / LabsChart / JournalComposer. Verify the uncalibrated user sees the
   prompt and the calibrated user sees the curve (still ignoring entitlement).
4. **`EntitlementManager` + `KeychainStore` extension + `Products.storekit`** —
   the entitlement infrastructure, not yet wired to any view.
5. **Three-axis gating** rework of the calibration prompt card into its full
   3-state machine (States 1, 2, 3).
6. **`hasFunctionalAccess` gate** applied to Home / Labs / Journal / Time functional
   surfaces.
7. **`isPremium`-only gate** applied to scrub / markers / reference lines /
   dose-intensity / tier-specific Time detail.
8. **Safety override exemption** verified in `LevelOverlayView` — dangerous readings
   remain visible through both gates.
9. **Onboarding calibration step** + risk-confirmation sheet.
10. **Settings Premium section** + status banner + manage/restore UI.
11. **End-to-end sandbox testing** via the StoreKit configuration file (purchase,
    lapse via accelerated sandbox renewals, refund, family sharing, restore on a
    fresh install).

Steps 1–3 ship value (safety) independently of steps 4–11 (business). If the
subscription work slips, the calibration gate still goes out.

## 13. Risks & open decisions

- **Sandbox testing is slow and fiddly.** Subscriptions renew on accelerated time
  (5 min × N) only in sandbox; production renewals follow real calendar time. Use
  the `Products.storekit` configuration file for deterministic local testing; use a
  sandbox Apple ID on a real device for App-Review-quality testing.
- **Refunds.** A refunded sub transitions to `.revoked`, which the current sketch
  treats as `hasLapsedPremium = true` (user keeps functional access). **Open
  decision:** should a refunded user lose functional access too? Stricter behavior
  treats `.revoked` like `.notSubscribed` and clears both flags. Recommended
  default: keep lapsed (matches the "lapse de-emphasizes" principle); revisit if
  refund abuse appears.
- **Family Sharing.** Auto-renewable subs are family-shareable by default.
  `Transaction.currentEntitlements` reports shared transactions so entitlement
  "just works," but the household shares the same `hasLapsedPremium` destiny. Be
  aware; no action needed unless we want to disable family sharing in App Store
  Connect.
- **Apple's 30% cut** (15% under the Small Business Program until $1M/yr). For
  low-priced monthly subs, this is a meaningful take. Price accordingly; consider
  raising monthly to $2.99 if 15% of $1.99 feels too thin.
- **Review.** Free tier must be genuinely usable (ours is — journal, doses, sites,
  general Time info). Reviewers reject apps that hide too much behind a paywall or
  whose free tier is a glorified paywall. Our free tier passes this bar.
- **Lapsed-state copy.** The "Resubscribe for the full experience" pill should be
  informational, not naggy. One pill on the curve, one line in Settings. No
  recurring prompts, no modal interruptions.
- **Keychain persistence vs. StoreKit truth.** The keychain is the instant-launch
  gate; StoreKit is the source of truth. If they disagree (e.g. refund processed
  server-side but the device hasn't seen `Transaction.updates` yet), StoreKit wins
  on the next `refreshFromStore()`. Document this in `EntitlementManager` so
  future contributors don't add a second source of truth.
- **What counts as "visual" for the lapsed tier.** This list is fixed in §4. Adding
  to it later is a product decision, not an engineering one — the gates are
  already in place. The animated entrance/draw/confetti/dot-slide is **explicitly
  excluded** from the lapsed-downgrade set per product decision; those remain free
  regardless of state.

## 14. What does not change

- The PK engine (`estimatedLevels`, `predictedLevel`, `recomputeCalibrationFactors`)
  runs identically — the "prefilled in the background" requirement. Calibration
  populates regardless of display state.
- `recentLevels`, `currentHormoneLevel`, `calibrationFactor` all populate as
  today; they just aren't *rendered* until anchored and entitled.
- Dose recording, scheduling, adherence, injection-site tracking, journal mood
  tracking — all unaffected. Only the *interpretive* layer (level numbers, curve,
  status pills, tier-detail copy) is gated.
- The animated entrance / line draw / confetti / dot-slide remain free per
  product decision. These are part of the app's identity, not a premium lever.
- Safety overrides remain visible through both gates.

## 15. Out of scope for v1

- Lifetime / non-consumable unlock SKU. Can be added later; the
  `EntitlementManager` abstracts which SKU is checked.
- Promotional offers / win-back offers. Configure in App Store Connect when we
  have lapsed-user data to optimize against.
- Cross-platform sync of entitlement via CloudKit. Not needed for iOS-only;
  StoreKit's `Transaction.currentEntitlements` already handles multi-device
  within the same Apple ID.
- Referral / gift codes. Future work.
