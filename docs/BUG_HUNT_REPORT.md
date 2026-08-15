# Comprehensive Bug Hunt Report — xT

**Date:** August 15, 2026
**Scope:** Full codebase audit — pharmacokinetics, data models, persistence, SwiftUI views, medication management, security, notifications, theming.

---

## Table of Contents

1. [Critical Bugs](#critical-bugs)
2. [High-Severity Bugs](#high-severity-bugs)
3. [Medium-Severity Bugs](#medium-severity-bugs)
4. [Low-Severity Bugs](#low-severity-bugs)
5. [Cross-Cutting Themes](#cross-cutting-themes)

---

## Critical Bugs

### C1. Keychain read failure destroys encryption key → permanent data loss
**File:** `xT/Managers/SecurityManager.swift:26-34`

```swift
func getEncryptionKey() throws -> SymmetricKey {
    if let keyData = try? getKeyFromKeychain() {
        return SymmetricKey(data: keyData)
    }
    let newKey = SymmetricKey(size: .bits256)
    let keyData = newKey.withUnsafeBytes { Data($0) }
    try saveKeyToKeychain(keyData)
    return newKey
}
```

`try?` swallows all keychain errors. If the keychain is transiently unavailable (device locked, `errSecAuthFailed`), a **brand-new key** is generated and `saveKeyToKeychain` **deletes the old key** before inserting the new one. All previously-encrypted health data becomes permanently undecryptable.

**Fix:** Distinguish `errSecItemNotFound` (create new key) from other errors (throw, do not regenerate). Never `SecItemDelete` an existing key unless creation is confirmed absent.

---

### C2. Aromatization factor 10× too small — E2 estimation can never report "in range"
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:921-923`

```swift
func estimatedE2FromTestosterone(_ testosteroneLevel: Double) -> Double {
    return testosteroneLevel * 0.002
}
```

A 0.2% mass-fraction aromatization requires a ×10 factor to convert ng/dL → pg/mL (1 ng/dL = 10 pg/mL). The correct factor is `0.02`. With the current `0.002`:
- Normal T (600 ng/dL) → E2 ≈ 1.2 pg/mL (below the 10-40 reference range)
- Trans-man therapeutic T (500-1000 ng/dL) → E2 ≈ 1-2 pg/mL (always "below range")

The feature can essentially never report "within the male reference range" for any realistic testosterone level.

**Fix:** Change `0.002` to `0.02`.

---

### C3. Calibration factor applied to endogenous baseline → incorrectly scaled levels
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:805-807`

```swift
let rawValue = baseLevel + cumulativeSpike
let calibratedValue = rawValue * alpha
```

`alpha = measured / predicted` corrects the *exogenous* drug-contribution prediction. Multiplying the entire sum (including `baseLevel`) by `alpha` also scales the physiological endogenous baseline. A user with `alpha = 2` gets their baseline doubled; a user with `alpha = 0.2` (clamped minimum) gets their baseline shrunk to 1/5.

**Fix:** `let calibratedValue = baseLevel + cumulativeSpike * alpha`

---

### C4. Fabricated phantom backfilled doses with unit mismatch (concentration used as dose amount)
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:750-762`

```swift
let accumulatedDose = baseLevel * 0.5
while d >= lookbackStart {
    doseEvents.append(contentsOf: makeDoseEvents(date: d,
                                                 ester: defaultEsterName,
                                                 route: methodStr,
                                                 amount: accumulatedDose))
    ...
}
```

`baseLevel` is a concentration (pg/mL or ng/dL). `baseLevel * 0.5` is passed as `amount` (mg of dose) into the Bateman function. For estrogen, ~50 "mg" of EV (vs. a real 2-5 mg dose) is 10-25× a therapeutic dose, predicting levels in the thousands of pg/mL. This fallback fires when `doseHistory` is empty but `lastDoseDate` is set — which can be triggered by `updateSelection` stamping a fake `lastDoseDate` (see H5 below).

**Fix:** Remove this fallback or use a properly-scaled placeholder dose. Do not mix concentration units into a dose amount field.

---

### C5. Profile name/image stored unencrypted in SwiftData + synced to iCloud
**File:** `xT/Managers/ProfileManager.swift:209-221`

```swift
func persistProfile() {
    if let context = modelContext,
       let prefs = try? context.fetch(FetchDescriptor<UserPreferences>()).first {
        prefs.profileName = profileName.isEmpty ? nil : profileName
        prefs.profileImageData = profileImageData
        ...
        try? context.save()
        return
    }
    persistProfileToUserDefaults()  // this path encrypts
}
```

The legacy UserDefaults path encrypts profile name and image with AES-GCM via `SecurityManager`. The new SwiftData path stores them in **plaintext**, and with CloudKit enabled, that plaintext syncs to iCloud. This is a security/privacy regression.

**Fix:** Encrypt before storing in SwiftData, or explicitly document the threat-model change.

---

## High-Severity Bugs

### H1. Fresh-install auto-lock defaults to "Immediately" (0s) instead of 5 minutes
**File:** `xT/Managers/AuthenticationManager.swift:87`

```swift
var autoLockTimeout: TimeInterval = UserDefaults.standard.double(forKey: Keys.autoLockTimeout)
```

`UserDefaults.double(forKey:)` returns `0.0` for a missing key. `AutoLockTimeout(rawValue: 0)` matches `.immediately`, so the documented `.fallback` (`.fiveMinutes`) is never used. A new user who enables authentication gets **immediate locking on every background**.

**Fix:** Use `defaults.object(forKey:) as? Double ?? 300` to distinguish "missing" from "0".

---

### H2. Migration flag set BEFORE migration succeeds → never retries
**File:** `xT/Managers/ProfileManager.swift:178-207`

```swift
defaults.set(true, forKey: "profileCloudKitMigrationDone")  // set FIRST
guard let context = modelContext, ... else { return }        // flag already true
...
try? context.save()  // failure swallowed, flag already true
```

If the context fetch fails, `context.save()` fails, or any intermediate step throws, the flag is already `true` and the migration will never retry. The user's encrypted UserDefaults profile data is stranded.

**Fix:** Only set the flag after `context.save()` succeeds.

---

### H3. `updateSelection` stamps a fake `lastDoseDate` of "now"
**File:** `xT/Managers/Medication/MedicationManager+Dosing.swift:151-158`

```swift
func updateSelection(type: MedicationType, method: AdministrationMethod) {
    ...
    updateDoseDates(last: Date(), next: next)  // stamps a fake last dose
    refreshState()
}
```

`lastDoseDate` is consumed by `monthsOnHRT` (fallback), `dynamicBaseline` (fallback), and `hasMissedDose`. Switching medication/method stamps `lastDoseDate = Date()` even though no dose was taken, silently re-anchoring the user's HRT timeline and baseline suppression.

**Fix:** Do not mutate `lastDoseDate` when the user changes medication/method selection.

---

### H4. `currentCyclePosition` uses fixed 7-day cycle for all injectables (TU misclassification)
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:138-139`

```swift
let daysSinceDose = now.timeIntervalSince(lastDose.doseDate) / 86400.0
let cycleLength = Double(method.frequencyDays)  // always 7 for injectables
```

Testosterone undecanoate (TU) is dosed every ~70 days. With `cycleLength = 7`, a TU user is classified as `.trough` for 64 of 70 days, including the rising limb and peak. Should use `effectivePKIntervalDays(ester:route:medication:)`.

---

### H5. `currentCyclePosition` trough detection picks t≈0, not the pre-next-dose trough
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:160-181`

The Bateman contribution is always ≥ 0, so the minimum level is at t≈0 (right at the dose). `min(by: value)` returns the first minimal point, not the actual trough. `troughHoursAfterDose ≈ 0` makes the curve-based trough trigger always false — dead code. Trough is decided solely by the wrong day-6 heuristic.

**Fix:** Restrict trough search to the post-peak tail.

---

### H6. Journal entries lost when save fails or context is nil
**File:** `xT/Managers/JournalManager.swift:29-38`

```swift
func addEntry(_ entry: JournalEntry) {
    entries.insert(entry, at: 0)  // in-memory mutation
    guard let context = modelContext else { return }  // entry silently vanishes on next load
    context.insert(entry)
    do { try context.save() } catch { print(...) }  // unsaved, lost on relaunch
}
```

If `modelContext` is nil, the entry is inserted into `entries` but never persisted. If `context.save()` throws, the entry is in the context but unsaved, and lost on next launch while the user saw it in the list.

**Fix:** Insert into context first, save, and only insert into `entries` on success.

---

### H7. Double-fire tap action in `RegionDetailCard`
**File:** `xT/Elements/Home/MoodMindDetailView.swift:71-124`

```swift
Button(action: onTap) { ... }
.buttonStyle(.plain)
.onTapGesture { withAnimation { isExpanded.toggle() }; onTap() }
```

A `Button(action: onTap)` and `.onTapGesture { ... onTap() }` are stacked. A single tap fires `onTap` **twice** and toggles `isExpanded` in addition. The bug propagates to `BodyArchitectureDetailView.swift:217-229`.

**Fix:** Remove either the `Button` wrapper or the `.onTapGesture`.

---

### H8. Double presentation of photo picker in onboarding
**File:** `xT/Elements/Onboarding/OnboardingView.swift:1143-1146`

```swift
.sheet(isPresented: $showImagePicker) {
    PhotosPicker(selection: ..., matching: .images) { EmptyView() }
}
.photosPicker(isPresented: $showImagePicker, selection: ..., matching: .images)
```

Both `.sheet` and `.photosPicker` are bound to the same `$showImagePicker` flag. Tapping "Library" presents both an empty sheet and the system photo picker.

**Fix:** Remove the `.sheet` wrapper.

---

### H9. `ForEach` id reuses array indices for mutable content
**File:** `xT/Elements/Home/AdherenceView.swift:216-218`

```swift
ForEach(Array(zip(medicationManager.regimenTransitionHistory.indices,
                  medicationManager.regimenTransitionHistory.reversed())),
        id: \.0) { _, segment in ... }
```

When a new segment is appended, the element keyed by id `0` changes content. SwiftUI thinks it's the same identity, producing stale/missing card transitions or a card displaying another segment's data.

**Fix:** Use a stable id from `RegimenSegment` if `Identifiable`, or derive from content.

---

### H10. `recordDose`/`skipDose` ignore `selectedEster`, use hardcoded default
**File:** `xT/Managers/Medication/MedicationManager+Dosing.swift:231-238`

```swift
let ester = lastLoggedDose?.ester
    ?? (medType == "Estrogen" ? "Valerate (EV)" : "Cypionate (TC)")
```

A user who picked EC during onboarding and taps "Record dose" gets a Valerate (EV) dose logged instead. `selectedEster` exists on the manager but this path never consults it.

**Fix:** Use `selectedEster ?? (medType == "Estrogen" ? "Valerate (EV)" : "Cypionate (TC)")`.

---

### H11. `replaceDoseWithCorrectedSite` reads properties from deleted SwiftData object
**File:** `xT/Managers/Medication/MedicationManager+Sites.swift:106-122`

```swift
softDeleteDose(id: originalId)  // context.delete + save + loadDoseHistory
addDose(
    date: originalDose.doseDate,          // read AFTER deletion
    type: originalDose.medicationType,   // read AFTER deletion
    ...
)
```

After `softDeleteDose` calls `context.delete()` and `loadDoseHistory()`, `originalDose` is a deleted managed object. Property access on it may fault, return nil/zero, or raise, producing a corrupted replacement dose.

**Fix:** Capture all needed values into local variables BEFORE `softDeleteDose`.

---

### H12. Heat-map cache race: stale entry written after invalidation
**File:** `xT/Managers/Medication/MedicationManager+Sites.swift:48-80`

```swift
let snapshot = doseHistory.filter { $0.isActive }...
let counts = await Task.detached(priority: .utility) { ... }.value
heatMapCache[cacheKey] = counts  // write AFTER await — may be stale
```

During the `await`, `addDose` → `invalidateHeatMapCache()` can clear the cache. When the detached task completes, it writes a stale entry computed from pre-dose data. This stale entry is served until the next dose.

**Fix:** Re-check cache validity after the await, or use a generation counter.

---

## Medium-Severity Bugs

### M1. `@Transient` missing — `calibrationFactor` persisted contrary to comment
**File:** `xT/Models/BloodTestRecord.swift:26-27`
The comment says "transient, not persisted to disk" but SwiftData persists all stored properties unless annotated `@Transient`. Stale values risk being shown on next launch.

### M2. `getCurrentHormoneLevel` samples 1 hour in the past
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:446-448`
With `stepDays = 1.0`, the loop produces one point at `now - 3600s`. The displayed "current" level is systematically 1 hour stale.

### M3. Division by zero in `DoseRecord.summary`
**File:** `xT/Models/DoseRecord.swift:114-116`
`if let conc = concentrationMgPerMl` only checks non-nil. If `conc == 0`, `doseAmount / 0` → `+inf`. The sibling `injectionVolumeMl` correctly guards `conc > 0`.

### M4. `try?` decoding masks type-mismatch corruption in InjectionSite
**File:** `xT/Models/InjectionSite.swift:207-216`
`try? decode(...) ?? default` swallows type-mismatch errors. A corrupted `normalizedX` stored as a String silently becomes `0.5` instead of surfacing the error.

### M5. `lastUsedDate` falls back to `Date()` on decode failure
**File:** `xT/Models/InjectionSite.swift:215`
A corrupt record is treated as "used right now," contaminating rotation-safety logic. Should use `.distantPast`.

### M6. Symptoms getter/setter silently loses data
**File:** `xT/Models/JournalModels.swift:23-39`
Decode failure returns `[]` (symptoms vanish from UI). Encode failure in the setter overwrites stored JSON with `"[]"`, **destroying previously-stored symptoms**.

### M7. `loadEntries` wipes in-memory state on transient fetch failure
**File:** `xT/Managers/JournalManager.swift:53-56`
A transient SwiftData error sets `entries = []`. The user's journal disappears even though data is still on disk.

### M8. `authenticate()` bypasses `allowPasscodeFallback` setting
**File:** `xT/Managers/AuthenticationManager.swift:114-129`
When biometrics are unavailable, the else branch falls back to `.deviceOwnerAuthentication` (passcode) unconditionally, regardless of the `allowPasscodeFallback` setting.

### M9. `authenticate()` doesn't check `canEvaluatePolicy` for passcode branch
**File:** `xT/Managers/AuthenticationManager.swift:121-124`
The passcode branch calls `evaluatePolicy(.deviceOwnerAuthentication)` without first checking `canEvaluatePolicy`. If no passcode is set, it throws raw `LAError` instead of the typed `XAuthenticationError.passcodeNotSet`.

### M10. `persistProfileToUserDefaults` silently clears in-memory image on encryption failure
**File:** `xT/Managers/ProfileManager.swift:273-279`
If `securityManager.encryptData` throws (keychain temporarily unavailable while device locked), the else branch clears `profileImageData` and `profileImage`. The user's photo vanishes from the UI.

### M11. Never-stopped repeat-forever animations
**File:** `xT/Elements/Home/Components/NextDoseRowView.swift:86-96`
`isPulsing` / `todayDotPulsing` are set to `true` and never reset. Once the missed-dose condition clears, the `repeatForever` animation keeps running indefinitely.

### M12. Opacity > 1 collapses to 1, removing selected/unselected distinction
**File:** `xT/Shared/Components/SelectableOptionRow.swift:99`
```swift
case .onAccent:
    return Theme.Colors.OnAccent.fill.opacity(isSelected ? 1.6 : 1)
```
`1.6` clamps to `1.0`, making selected and unselected fills identical. Only the stroke changes.

### M13. `fullScreenCover` triggered from `onAppear` (racy presentation)
**File:** `xT/ContentView.swift:27-47`
Presenting a `fullScreenCover` during the first `onAppear` can be skipped on some launches.

### M14. Manual `Binding` to non-owned `authManager.showAuthentication`
**File:** `xT/ContentView.swift:50-56`
The binding's `get` only re-evaluates when `ContentView`'s body re-runs. If `AuthenticationManager` flips the flag on its own, the cover may not present/dismiss reliably.

### M15. `sheet(item:)`-emulating binding races the optional
**File:** `xT/Elements/Settings/BloodTestHistoryView.swift:90-100`, `ScreeningHistoryView.swift:84-91`
When the composer dismisses itself, `composerMode` is set to `nil` and SwiftUI re-evaluates the sheet content mid-dismiss, flashing an empty sheet.

### M16. `onAppear` overwrites in-progress edits in `ProfileEditorView`
**File:** `xT/Elements/Profile/ProfileEditorView.swift:196-202`
If `onAppear` fires more than once (returning from a child sheet), the user's typed name is silently overwritten and `hasChanges` is reset.

### M17. Uncancelled `DispatchQueue.main.asyncAfter` closures
**Files:** `HomeView.swift:135-141`, `OnboardingView.swift:1563-1585`, `TimeBodyExplorerView.swift:70-76`, `QuickDoseSheet.swift:559-561`, `RecordDoseView.swift:38-46`
Multiple views use `asyncAfter` without cancellation. If the user navigates away, the closures still fire, mutating state on stale/destroyed views or causing visible glitches.

### M18. Missing `withAnimation` around state change with `.transition`
**File:** `xT/Elements/Home/Components/RecordDoseView.swift:38-46`
`showingConfirmation = true` is set without `withAnimation`, so the `.transition(.opacity)` never animates.

### M19. `Spacer()` inside `ScrollView` is a no-op
**File:** `xT/Elements/Home/UnifiedScheduleView.swift:81`
The spacer collapses to zero height; the bottom of the form sits flush under the last section.

### M20. Debug `print` statements left in production code
**File:** `xT/Managers/ThemeManager.swift:347, 381`
Two `[ThemeDebug]` print statements log on every `seedHue` mutation (dozens/sec during drag).

### M21. `seedHue` didSet recomputes entire palette on every drag tick
**File:** `xT/Managers/ThemeManager.swift:345-350`
A heavy OKLab/contrast-math operation over ~30+ color recipes runs dozens of times per second during a hue-dial drag.

### M22. `removeAllPendingNotificationRequests()` cancels ALL notifications
**File:** `xT/Managers/NotificationManager.swift:125`
`scheduleAllReminders()` cancels every pending notification in the app, not just the ones this manager owns.

### M23. Reminder hour/minute default to midnight on fresh install
**File:** `xT/Managers/NotificationManager.swift:42-46`
`UserDefaults.integer(forKey:)` returns 0 for missing keys. Reminders fire at 00:00 if user enables without setting a time.

### M24. `contextualRange` allows `peakCeiling` < `scaledPeakMin` (inverted range)
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:358-378`
A user who sets a low `peakCeiling` while on a high-intensity dose gets `min = 400, max = 100` — an inverted range that produces nonsense classifications.

### M25. `relativeDoseIntensity` ignores route/ester
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:863-881`
A 50 mg T-gel dose (F=0.10, ~5 mg systemic) and a 50 mg T-cypionate injection (F=1.0, ~35 mg systemic) both count as "1.0× standard." The intensity drives target range scaling and timeline, so gel and injectable users at the same raw mg get the same ranges.

### M26. `safetyOverride` returns early, masking spiro flag
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:419-425`
For an estrogen+spironolactone user with a trough level of 40, both `.subTherapeuticTrough` and `.spironolactoneClearance` conditions are true, but only `.subTherapeuticTrough` is returned. The clinically actionable spiro signal is suppressed.

### M27. `dynamicBaseline` produces inflated baseline for negative `daysOnHRT`
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:44-57`
If `hrtStartDate` is in the future, `progress` is negative, `suppressionFactor` is negative, and the baseline goes **above** `fullBaseline`. For a 10-week-future start: ~49,000 pg/mL for estrogen.

### M28. `DoseRecord.summary` has unbalanced parenthesis
**File:** `xT/Models/DoseRecord.swift:116`
Format string: `"...mg/mL) \(ester)..."` — stray `)` after `mg/mL`.

---

## Low-Severity Bugs

### L1. `recomputeRegimenHistory` uses exact `!=` for Double concentration comparison
**File:** `xT/Managers/Medication/MedicationManager+Schedule.swift:74, 89`
`newConc != currentConc` spurs spuriously for values like `40.0` vs `40.00000001` from JSON round-tripping or CloudKit merges.

### L2. `suggestedBloodTestMonth` reports "1 month" for an already-overdue test
**File:** `xT/Managers/Medication/MedicationManager+Schedule.swift:199-201`
`max(monthsFromNow, 1)` masks negative values. An overdue test is shown as "next test due in 1 month."

### L3. `LabsChartSeries.range` can return negative y-axis minimum
**File:** `xT/Shared/LabsChartSeries.swift:45-48`
`lo - padding` is unconstrained. For low hormone levels near zero, the chart's y-axis extends below zero.

### L4. `estimatedLevels` can infinite-loop if `stepDays <= 0`
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:768, 809`
If `stepDays` is 0, `cursor` never advances. All current callers pass a positive step, but the public API has no guard.

### L5. Generic fallback path produces predictions in mg, not pg/mL / ng/dL
**File:** `xT/Managers/Medication/MedicationManager+Pharmacokinetics.swift:603-614`
The fallback sets `scaling: 1.0`, so `cumulativeSpike = amount * exp(-ka dt)` is in mg, a magnitude error of ~1000×.

### L6. Integer truncation in `currentAge` computation
**File:** `xT/Models/TimeContentData.swift:586`
`activeMonthsOnHRT / 12` is integer division. A user 11 months on HRT at age 40 shows "age 40" instead of "nearly 41."

### L7. `id` derived from `title`/`label` risks SwiftUI identity collisions
**File:** `xT/Models/TimeContentTypes.swift:141-150, 154-160`
`TimeMilestone.id = title`, `TimeChange.id = label`. Duplicate localized strings produce duplicate ids, causing rendering glitches in `ForEach`.

### L8. `Symptom` equality based only on `id`
**File:** `xT/Models/JournalModels.swift:88-100`
Two symptoms with the same `name`/`icon` but different `id`s are unequal. Selection UI cannot find/deselect duplicates.

### L9. Sentinel value `-1` for "no medication selected"
**File:** `xT/Models/UserPreferences.swift:31-32`
`medicationRow = -1` as sentinel. Used as array index without checking → crash risk.

### L10. `ForEach(…, id: \.offset)` for mutable content
**File:** `xT/Elements/Settings/PreferredZonesListView.swift:37`
When `medicationRouteCombos` changes, the array content changes but id (offset 0) stays the same.

### L11. `@State` initialized from `UserDefaults` at declaration time
**File:** `xT/Elements/Settings/SettingsView.swift:34`
`@State` initializers run once per view identity. If `UserDefaults` changes externally, the `@State` holds the stale value.

### L12. `phaseAnimator` re-runs from `.idle` on every trigger increment
**File:** `xT/Theme/Motion.swift:163-182`
Two rapid celebrations restart from idle, snapping back to no-glow before re-blooming.

### L13. Accessibility: Action buttons have no accessibility labels
**File:** `xT/Elements/Home/Components/ActionBarView.swift:24-54`
VoiceOver reads meaningless/unlabeled elements.

### L14. Brain-region chips missing `isSelected` accessibility trait
**File:** `xT/Elements/Home/TimeBodyExplorerView.swift:244-265`
Toggling doesn't expose selected state to VoiceOver.

### L15. `ConstellationView` redraws every frame continuously
**File:** `xT/Elements/Home/Components/Constellation/ConstellationView.swift:57`
`TimelineView(.animation)` drives a full Canvas redraw on every display refresh, even while the user reads static text.

### L16. Scrub gesture does linear scan per frame
**File:** `xT/Elements/Home/FlatGraphView.swift:229-250`
`densePoints.min(by:)` runs on every dragged frame over hundreds of points, 60-120 times/sec.

### L17. Empty `onChange` is a no-op
**File:** `xT/Elements/Home/FlatGraphView.swift:174`
`.onChange(of: …) { _, _ in }` does nothing. Reference lines don't update when target changes.

### L18. `oneTimeTrigger` uses `Calendar.current` (timezone/DST-sensitive)
**File:** `xT/Managers/NotificationManager.swift:218-239`
Cross-timezone travel or DST transitions can shift dose reminders by an hour.

### L19. `rescheduleAfterDose` ignores `nextDoseDate` for daily users
**File:** `xT/Managers/NotificationManager.swift:191-203`
For `freq <= 1`, a generic repeating trigger is used, ignoring the actual `nextDoseDate`.

### L20. Temp files from data export never cleaned up
**File:** `xT/Elements/Settings/DataExportView.swift:186-200`
Each export writes a fresh timestamped file to the temp directory, never deleted.

### L21. Global `Array` extension in a view file
**File:** `xT/Elements/Onboarding/OnboardingView.swift:13-17`
`subscript(safe:)` is declared globally, risking collisions.

### L22. Settings views read singleton in `init` while using `@Environment` in `body`
**File:** `xT/Elements/Settings/DoseScheduleSettingsView.swift:32-43`
Initial state is captured from the singleton, which may differ from the environment-injected manager in previews/tests.

### L23. `recomputeAdherenceRate` caps at 1.0, hiding over-adherence
**File:** `xT/Managers/Medication/MedicationManager+Schedule.swift:129`
`min(1.0, ...)` silently discards excess doses. Over-dosing is a safety concern.

### L24. `recomputeOnTimeStreak` does not break on skipped dose
**File:** `xT/Managers/Medication/MedicationManager+Schedule.swift:140-143`
A skipped dose is invisible to the streak, which jumps over it and rewards the user.

### L25. `NotificationCenter` observer closure not annotated for actor isolation
**File:** `xT/Managers/ThemeManager.swift:369-374`
Under Swift 6 strict concurrency, assigning to a `@MainActor` property from a non-isolated closure may warn or error.

### L26. `antiAndrogenInUse` migration clobbers `spironolactoneInUse`
**File:** `xT/Managers/Medication/MedicationManager+Persistence.swift:71-75`
If `antiAndrogenInUse` key exists but `spironolactoneInUse` does not, the latter defaults to `false` and overwrites any existing value.

### L27. Migration completion flag written even when `context.save()` failed
**File:** `xT/Managers/Medication/MedicationManager+Persistence.swift:117-119`
`try? context.save()` swallows the error, but `defaults.set(true, ...)` runs unconditionally.

### L28. Validation constants duplicated as magic numbers
**File:** `xT/Managers/ProfileManager.swift:304, 310`
`50` and `5 * 1024 * 1024` are hardcoded instead of using `Self.maxProfileNameLength` and `Self.maxProfileImageBytes`.

### L29. `handlePhotoSelection` silently swallows decode failures
**File:** `xT/Managers/ProfileManager.swift:141-151`
If `loadTransferable` throws or `UIImage(data:)` returns nil, nothing happens — no error, no UI feedback.

### L30. `loadDoseHistory` filters deleted records in memory, not in the store
**File:** `xT/Managers/Medication/MedicationManager+Persistence.swift:270-276`
The `!$0.isDeleted` filter is a correctness crutch. If any code only flips an `isDeleted` flag without calling `context.delete`, the record stays in the store forever.

---

## Cross-Cutting Themes

### 1. `try? ... ?? default` masks data corruption
Used pervasively in `InjectionSite` decoding, `JournalModels` symptoms, `UserPreferences` enum accessors. For health data, prefer throwing decoders and explicit migration. Silent defaults mask corruption until it's too late.

### 2. Enum-backed String fields without computed accessors
`DoseRecord.doseStatus`, `UserPreferences.suppressionSpeed`, `UserPreferences.bodyTypeRaw` are stored as raw strings. Consumers must re-implement `Enum(rawValue:) ?? fallback` everywhere. `ScreeningRecord` does it right — use that pattern.

### 3. Singleton `shared` constructed before dependencies exist
`JournalManager.shared`, `ProfileManager.shared`, `MedicationManager.shared` are created before `modelContext` is injected. Observers that read state between first access and context injection see stale "no data" state.

### 4. Uncancelled `DispatchQueue.main.asyncAfter`
Multiple views use `asyncAfter` for delays without cancellation. Use `Task` stored on the view and cancel in `onDisappear`.

### 5. Date handling uses `Calendar.current` without timezone pinning
Fine for "now"-relative math, but problematic for notification scheduling and cross-timezone dose reminders.

### 6. `lastDoseDate` overloaded as both "real dose" and "schedule anchor"
`updateSelection` stamps a fake `lastDoseDate`. Unconfigured `recordDose` advances it without creating a `DoseRecord`. The fallback `estimatedLevels` path uses it to fabricate phantom backfilled doses.

### 7. No ester-aware scheduling
`effectiveFrequencyDays` returns the method default (7 for injectables) regardless of ester. TU users (~70-day interval) get "next dose in 7 days" unless they set a custom frequency.

---

## Recommended Fix Priority

| Priority | Bug IDs | Impact |
|----------|--------|--------|
| **P0 — Fix now** | C1, C2, C3, C4, C5 | Data loss, security, clinically wrong outputs |
| **P1 — Fix before release** | H1-H12 | Crash risks, lost data, wrong schedules, UI defects |
| **P2 — Fix soon** | M1-M28 | Data integrity, UX issues, performance |
| **P3 — Fix when time permits** | L1-L30 | Hardening, consistency, accessibility |
