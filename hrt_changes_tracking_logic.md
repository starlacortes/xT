# HRT Changes Tracking Logic — Time Section Deep Dive

## Document Purpose
This document maps the complete logic underlying HRT-related change detection, dose tracking, and time-based state management within the xT app's **Time** section. It traces every code path from user input through pharmacokinetic modeling to UI presentation, with emphasis on how *changes* (dose adjustments, regimen transitions, ester swaps, blood test calibrations) are detected, stored, and surfaced.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   MedicationManager                      │
│              (Single Source of Truth)                    │
│  @Published: doseHistory, lastDoseDate, nextDoseDate,   │
│  hrtStartDate, currentHormoneLevel, recentLevels,       │
│  bloodTestHistory, antiAndrogenInUse, spironolactoneInUse│
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ DoseRecord  │  │BloodTestRecord│  │DoseDatesContainer│ │
│  │ (SwiftData) │  │  (SwiftData)  │  │  (encrypted)    │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
├─────────────────────────────────────────────────────────┤
│            Pharmacokinetic Engine (Bateman)              │
│   • Superposition of all dose contributions              │
│   • Ester-specific absorption/elimination constants      │
│   • Dynamic baseline (suppression taper)                 │
│   • Blood test calibration (α factor)                    │
│   • Spironolactone clearance adjustment                   │
├─────────────────────────────────────────────────────────┤
│                    UI Consumers                          │
│  UnifiedScheduleView  HomeView  JournalView  Settings    │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Core Data Models

### 2.1 `DoseRecord` (`xT/Models/DoseRecord.swift`)
The atomic unit of HRT tracking. Every logged dose creates one record.

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` (UUID) | Unique identifier, prevents duplicates |
| `doseDate` | `Date` | When the dose was administered |
| `medicationType` | `String` | `"Estrogen"` or `"Testosterone"` |
| `ester` | `String` | `"Valerate (EV)"`, `"Cypionate (EC)"`, `"Oral"`, `"Transdermal"` |
| `administrationMethod` | `String` | `"Injectable"`, `"Cream"`, `"Oral"` |
| `doseAmount` | `Double` | Actual mg administered |
| `concentrationMgPerMl` | `Double?` | Vial concentration (for volume computation) |
| `notes` | `String?` | Free-text user notes |
| `isDeleted` | `Bool` | Soft-delete flag (HIPAA-friendly audit trail) |

**Change detection is implicit**: each record carries its own `ester` and `doseAmount`, so comparing consecutive records reveals regimen changes.

Computed properties:
- `isActive`: `!isDeleted` — active doses participate in PK modeling
- `daysSinceDose`: `Date().timeIntervalSince(doseDate) / 86400.0` — used for decay calculations
- `summary`: Human-readable string including mg, mL, ester, and date
- `injectionVolumeMl`: `doseAmount / concentrationMgPerMl` (if concentration known)

### 2.2 `BloodTestRecord` (`xT/Models/BloodTestRecord.swift`)
Lab results used to calibrate the PK model.

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` (UUID) | Unique identifier |
| `drawDate` | `Date` | When blood was drawn |
| `measuredLevel` | `Double` | Lab result (pg/mL for E2, ng/dL for T) |
| `hormoneType` | `String` | `"Estrogen"` or `"Testosterone"` |
| `hoursSinceLastDose` | `Double?` | Auto-computed from dose history |
| `notes` | `String?` | User notes (e.g., "trough draw") |
| `calibrationFactor` | `Double?` | `α = measured / predicted`, clamped to [0.2, 5.0] |

**Change tracking**: Each blood test produces a calibration factor that modifies all subsequent model outputs. A *new* blood test represents a *calibration event* — the model's accuracy changes at that point.

### 2.3 `DoseDatesContainer` (private struct in MedicationManager)
Encrypted persistence wrapper for key dates:

```swift
struct DoseDatesContainer: Codable {
    let lastDoseDate: Date?
    let nextDoseDate: Date?
    let hrtStartDate: Date?
}
```

---

## 3. Enumerations Defining HRT Regimen Parameters

### 3.1 `MedicationEster` (Estrogen esters)
| Ester | Half-Life (days) | EWF | Bioavailability | Scaling Constant |
|---|---|---|---|---|
| Valerate (EV) | 2.0 | 0.764 | 1.0 | 280.0 |
| Cypionate (EC) | 8.5 | 0.687 | 1.0 | 220.0 |
| Oral | 0.5 | 1.0 | 0.05 | 180.0 |
| Transdermal | 1.5 | 1.0 | 0.15 | 120.0 |

### 3.2 `TestosteroneEster`
| Ester | Half-Life (days) | EWF | Bioavailability | Scaling Constant |
|---|---|---|---|---|
| Cypionate (TC) | 8.0 | 0.699 | 1.0 | 11.0 |
| Enanthate (TE) | 7.0 | 0.720 | 1.0 | 11.0 |
| Propionate (TP) | 1.0 | 0.837 | 1.0 | 18.0 |
| Undecanoate (TU) | 20.0 | 0.631 | 1.0 | 5.0 |

### 3.3 `AdministrationMethod`
| Method | Frequency (days) |
|---|---|
| Injectable | 7 |
| Cream | 1 |
| Oral | 1 |

### 3.4 `CyclePosition`
Tracks where the user is in their injection cycle:
- `nearPeak` — within ±30% of expected t_max
- `midCycle` — between peak and trough
- `trough` — within 24 hours of next scheduled dose
- `unknown` — insufficient data

### 3.5 `HormoneRange` (target ranges)
**Estrogen (pg/mL)**:
- Very Low: 0–50
- Low: 50–100
- Optimal: 100–200 (200–400 at peak)
- High: 200–500
- Very High: 500–1000

**Testosterone (ng/dL)** for transfeminine HRT:
- Suppressed: 0–50 (target)
- Low (Feminizing): 50–100
- Moderate: 100–300
- Male Range Low: 300–500
- Male Range: 500–1000
- Very High: 1000–9999

---

## 4. The Time Section — Dose Scheduling & Timing

### 4.1 Dose Frequency Computation
```swift
func calculateNextDoseDate(from lastDose: Date) -> Date {
    let method = AdministrationMethod(rawValue: selectedAdministrationMethod!)
    return Calendar.current.date(byAdding: .day, value: method.frequencyDays, to: lastDose)!
}
```
- Injectable: every 7 days
- Cream / Oral: every 1 day

### 4.2 Missed Dose Detection
```swift
var hasMissedDose: Bool {
    guard let next = nextDoseDate else { return false }
    return Date() > next   // current time has passed the scheduled next dose
}

var daysSinceMissedDose: Int? {
    guard hasMissedDose, let next = nextDoseDate else { return nil }
    let days = Calendar.current.dateComponents([.day], from: next, to: Date()).day ?? 0
    return max(1, days)
}
```

### 4.3 HRT Duration Tracking
```swift
var monthsOnHRT: Int {
    let referenceDate = hrtStartDate ?? lastDoseDate
    guard let first = referenceDate else { return 0 }
    return Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0
}
```
- `hrtStartDate` is the user-declared HRT start (may predate app)
- Falls back to `lastDoseDate` if `hrtStartDate` is nil
- Drives the endogenous suppression timeline

### 4.4 Dose Streak
```swift
var currentStreakDays: Int? {
    guard let last = lastDoseDate else { return nil }
    return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
}
```

### 4.5 Cycle Position Detection
```swift
var currentCyclePosition: CyclePosition {
    // Finds most recent active dose for current medication
    // Computes daysSinceDose
    // Determines t_max from ester type
    // Peak window: within ±30% of expected t_max
    // Trough window: within 24h of next scheduled dose
}
```

### 4.6 Notification-Driven Time Tracking
`NotificationManager` schedules daily repeating dose reminders at user-configured hour/minute. The `TimePickerSheet` reusable component allows configuring these times. Notifications are calendar-triggered (`UNCalendarNotificationTrigger`) — they are time-based, not dose-event-based.

---

## 5. How Regimen Changes Are Detected and Tracked

### 5.1 Implicit Change Detection via Dose History
There is **no explicit "change log" or "transition event" data structure**. Instead, changes are detected **implicitly** by comparing consecutive `DoseRecord` entries in `doseHistory`:

```swift
// How MedicationManager determines the current ester:
var currentEster: (ester: String, halfLifeDays: Double)? {
    if let recent = doseHistory
        .first(where: { $0.isActive && $0.medicationType == selectedMedication })
    {
        // Returns the ester from the most recent dose
    }
}
```

**What constitutes a "change":**
1. **Ester change**: A new dose with a different `ester` string than the previous dose
2. **Dose amount change**: A new dose with a different `doseAmount`
3. **Method change**: A new `administrationMethod`  
4. **Concentration change**: A new `concentrationMgPerMl`
5. **Medication type change**: Switching from Estrogen to Testosterone (or vice versa)
6. **Anti-androgen toggle**: Enabling/disabling `antiAndrogenInUse` or `spironolactoneInUse`
7. **HRT start date**: Setting/changing `hrtStartDate` alters the suppression timeline
8. **Blood test**: Adding a `BloodTestRecord` changes the calibration factor

### 5.2 How a Regimen Change Propagates

When a user logs a dose with **different parameters** than before:

1. `addDose()` creates a new `DoseRecord` with the new parameters
2. If the `type` matches `selectedMedication` AND `method` matches `selectedAdministrationMethod`:
   - `lastDoseDate` is updated to the new dose date
   - `nextDoseDate` is recalculated from the new date using frequency
3. `persistDoseDates()` encrypts and saves to UserDefaults
4. `refreshState()` is called:
   - `currentHormoneLevel` is recomputed via `getCurrentHormoneLevel()`
   - `recentLevels` is recomputed via `estimatedLevels(from: -7 days, to: now)`
5. The PK model now uses the **new ester's parameters** (ka, ke, scaling constant, effective dose factor) for *that specific dose event* going forward
6. **Previous doses retain their original parameters** — the superposition model treats each dose independently

### 5.3 Ester-Specific PK Parameter Resolution
```swift
// Each dose event carries its own PK parameters:
for dose in activeDoses {
    let effAmount = dose.doseAmount * dosePotencyFactor(for: dose)
    if isInjectable, let pk = pkParams(ester: dose.ester, medication: medication) {
        doseEvents.append(DoseEvent(date: dose.doseDate, amount: effAmount,
                                    ka: pk.ka, ke: pk.ke, scaling: pk.scaling))
    }
}
```
This means if a user switches from EV (half-life 2 days) to EC (half-life 8.5 days), both doses coexist in the model — the EV contribution decays rapidly while EC decays slowly.

### 5.4 When `updateSelection()` Is Called
```swift
func updateSelection(type: MedicationType, method: AdministrationMethod) {
    selectedMedication = type.rawValue
    selectedAdministrationMethod = method.rawValue
    persistSelection()
    let next = calculateNextDoseDate(from: Date())
    updateDoseDates(last: Date(), next: next)
    refreshState()
}
```
This is a **hard reset** of the tracking state — it sets `lastDoseDate` to *now* and recomputes `nextDoseDate`. Typically called during onboarding or when the user reconfigures their medication type.

---

## 6. The Pharmacokinetic Model — How Time Affects Hormone Levels

### 6.1 Bateman Biexponential Model (Injectable)
```
C_i(t) = D_i_eff × S × (ka / (ka - ke)) × (e^(-ke × Δt) - e^(-ka × Δt))
```
Where:
- `D_i_eff` = dose × EWF × bioavailability (effective systemic mg)
- `ka` = ln(2) / terminal_half_life (absorption rate, days⁻¹)
- `ke` = ln(2) / elimination_half_life (clearance rate, days⁻¹)
- `S` = pre-tuned scaling constant
- `Δt` = days since dose administration

### 6.2 Single-Exponential Model (Oral/Transdermal)
```
C_i(t) = D_i_eff × e^(-ka × Δt)
```

### 6.3 Superposition
The total level at any time `t` is:
```
Level(t) = baseline + Σ C_i(t)   for all doses where doseDate_i ≤ t
```
Then multiplied by the calibration factor `α`.

### 6.4 Dynamic Baseline (Suppression Taper)
```swift
func dynamicBaseline(for type: MedicationType) -> Double {
    if type == .testosterone && antiAndrogenInUse {
        return suppressedBaseline  // near-zero immediately
    }
    let weeksOnHRT = Double(daysOnHRT) / 7.0
    if weeksOnHRT >= hrtSuppressionWeeks {  // 4 weeks
        return suppressedBaseline
    }
    // Linear taper from full baseline → suppressed
    let fraction = weeksOnHRT / Double(hrtSuppressionWeeks)
    return fullBaseline + (suppressedBaseline - fullBaseline) * fraction
}
```
- Estrogen: baseline tapers from 100 → 5 pg/mL over 4 weeks
- Testosterone (with AA): immediate drop to ~20 ng/dL
- Testosterone (without AA): tapers from 500 → 20 ng/dL over 4 weeks

### 6.5 Spironolactone Clearance Adjustment
```swift
if spironolactoneInUse { ke *= 1.15 }  // 15% faster E2 clearance
```

---

## 7. Blood Test Calibration — When Model Accuracy Changes

### 7.1 Calibration Factor Computation
```swift
func computeCalibrationFactor(for record: BloodTestRecord) {
    // Run model at draw time (±30 min window)
    let modelPoints = estimatedLevels(from: drawDate - 30min, to: drawDate + 30min)
    let predicted = modelPoints.last?.value
    let alpha = measuredLevel / predicted
    record.calibrationFactor = max(0.2, min(5.0, alpha))  // clamped
}
```

### 7.2 Active Calibration Factor
```swift
var calibrationFactor: Double? {
    // Returns most recent calibrated blood test's α
}
```
Applied as a multiplier to all PK model outputs: `calibratedValue = rawValue × alpha`

### 7.3 Recalibration on Init
`recomputeCalibrationFactors()` re-derives α for all stored blood tests on app launch, ensuring calibration consistency after data reloads.

---

## 8. The `refreshState()` Cascade — When Things Change

`refreshState()` is the central recomputation trigger called after:
- `addDose()` — new dose logged
- `removeDose()` — dose soft-deleted
- `recordDose()` — backward-compat dose recording
- `updateSelection()` — medication type/method changed
- `addBloodTest()` — new lab result
- `removeBloodTest()` — lab result removed

It recomputes:
1. `currentHormoneLevel` — the real-time level + range + explanation
2. `recentLevels` — the 7-day time series for charts

---

## 9. Persistence Layer — What Survives App Restarts

| Data | Storage | Encryption |
|---|---|---|
| `doseHistory` | SwiftData (`@Model DoseRecord`) | No (SwiftData managed) |
| `bloodTestHistory` | SwiftData (`@Model BloodTestRecord`) | No (SwiftData managed) |
| `selectedMedication`, `selectedAdministrationMethod` | UserDefaults key `encryptedMedicationSelection` | AES via SecurityManager |
| `lastDoseDate`, `nextDoseDate`, `hrtStartDate` | UserDefaults key `encryptedDoseDates` | AES via SecurityManager |
| Notification settings (`doseReminderEnabled`, hour, minute) | UserDefaults (multiple keys) | No |

---

## 10. UI Integration — Where Time Data Is Presented

### 10.1 `UnifiedScheduleView`
- Displays: medication status card, next dose date, last dose date, schedule summary
- Date picker for backdating doses
- Quick dose recording button
- Calls `medicationManager.addDose()` or `medicationManager.recordDose()`
- Does NOT display dose history changes explicitly — only current state

### 10.2 Journal Integration
- `JournalManager` feeds into the journal system
- Journal entries can reference dose timing
- `JournalCardView` renders individual entries

### 10.3 Notification System
- `NotificationManager` schedules daily repeating reminders
- Independent of dose events — purely time-based
- Configured via `TimePickerSheet`

---

## 11. Summary: The Complete Change Detection Flow

```
USER ACTION                    SYSTEM RESPONSE
────────────                   ────────────────
Log dose with new ester    →   New DoseRecord saved with new ester string
                               PK model now uses new ka/ke/EWF for this dose
                               Old dose contributions still decay per their parameters
                               currentEster reflects most recent dose's ester
                               Cycle position recalculated

Log dose with new amount   →   New DoseRecord with new doseAmount
                               effectiveDoseFactor applied per ester
                               PK model adjusts peak height

Change administration
method (injectable→oral)   →   updateSelection() resets dose dates
                               Frequency changes from 7→1 day
                               PK switches from Bateman→single-exponential

Add blood test result      →   BloodTestRecord created
                               α computed: measured ÷ predicted
                               All subsequent model outputs × α

Toggle spironolactone      →   ke × 1.15 for E2 doses
                               Levels drop ~15% faster

Toggle anti-androgen       →   Testosterone baseline → near-zero immediately
                               Months-on-HRT taper overridden

Change hrtStartDate        →   monthsOnHRT recalculated
                               Suppression timeline shifts
                               Dynamic baseline adjusts
```

---

## 12. The "Changes Unlocked" Section — Month-Driven Change Badges

### 12.1 Data Structure
```swift
struct BloomChange: Identifiable {
    let id = UUID()
    let label: String       // e.g., "Skin softening", "Voice deepening"
    let unlocked: Bool      // driven by months-on-HRT threshold
}
```

### 12.2 Unlock Thresholds (Estrogen)
| Change | Unlocked at Month |
|---|---|
| Skin softening | 1 |
| Breast growth | 2 |
| Fat redistribution | 3 |
| Hair thinning slows | 6 |
| Body hair softens | 6 |
| Muscle mass shifts | 9 |

### 12.3 Unlock Thresholds (Testosterone)
| Change | Unlocked at Month |
|---|---|
| Voice deepening | 2 |
| Clitoral growth | 1 |
| Body hair growth | 3 |
| Fat redistribution | 3 |
| Muscle growth | 4 |
| Skin oiliness | 1 |

### 12.4 Computation
```swift
var unlockedChanges: [BloomChange] {
    if medication == "Estrogen" {
        return estrogenChanges(months: months)
    } else {
        return testosteroneChanges(months: months)
    }
}

private func estrogenChanges(months: Int) -> [BloomChange] {
    [
        BloomChange(label: "Skin softening",      unlocked: months >= 1),
        BloomChange(label: "Breast growth",       unlocked: months >= 2),
        BloomChange(label: "Fat redistribution",  unlocked: months >= 3),
        BloomChange(label: "Hair thinning slows", unlocked: months >= 6),
        BloomChange(label: "Body hair softens",   unlocked: months >= 6),
        BloomChange(label: "Muscle mass shifts",  unlocked: months >= 9),
    ]
}
```

Each `BloomChange` is instantiated fresh every render — the `unlocked` boolean is a **pure function of `months`** (from `medicationManager.monthsOnHRT`, which is `hrtStartDate → now`). There is no persisted "unlocked" state; items become unlocked automatically as `monthsOnHRT` advances.

### 12.5 UI Rendering (`BloomChangesRow`)
- Header: "CHANGES UNLOCKED" with count — `"X of Y"` (e.g., "3 of 6")
- Unlocked items: green checkmark icon (`checkmark`), green accent background
- Locked items: gray clock icon (`clock`), secondary background
- Horizontal scroll of capsule-shaped badges

### 12.6 Relationship to MedicationManager
The only MedicationManager input is `monthsOnHRT` (computed from `hrtStartDate`). No dose history, blood tests, or cycle position affect this section. Changes "unlock" purely by calendar time elapsed since HRT start.

---

## 13. The "Your Body" Section — Body Systems With Progress Tracking

### 13.1 Data Structure
```swift
struct BloomBodySystem: Identifiable {
    let id = UUID()
    let title: String            // e.g., "Mood & mind", "Voice"
    let subtitle: String         // descriptive explanation
    let icon: String             // SF Symbol name
    let palette: BloomPalette    // color scheme
    let progressFraction: Double // 0.0–1.0 for progress bar
    let progressLabel: String    // phase label (e.g., "Settling in", "Day 3 of 7")
}
```

### 13.2 Palette System
Six predefined palettes (`pink`, `purple`, `teal`, `amber`, `neutral`, `optimal`), each with `surface`, `border`, `accent`, `title`, `progress`, and `iconBorder` colors — all hardcoded hex values.

### 13.3 Estrogen Body Systems

| System | Icon | Palette | Progress Formula | Progress Labels |
|---|---|---|---|---|
| Mood & mind | brain | purple | `min(months / 18, 1.0)` | <6mo: "Settling in", <12mo: "Stabilising", ≥12mo: "Well-established" |
| Skin & glow | sparkles | teal | `min(months / 12, 1.0)` | <3mo: "Just starting", <9mo: "Well underway", ≥9mo: "Ongoing" |
| Body shape | body-scan | amber | `min(months / 24, 1.0)` | <6mo: "Early changes", <18mo: "Still in progress", ≥18mo: "Mature changes" |
| Your cycle | heart-rate-monitor | pink | `1.0 (injectable) or 1.0 (others)` | "Day X of Y" (cycle day / cycle length) |

### 13.4 Testosterone Body Systems

| System | Icon | Palette | Progress Formula | Progress Labels |
|---|---|---|---|---|
| Voice | microphone | purple | `min(months / 24, 1.0)` | <3mo: "Early changes", <12mo: "Still shifting", ≥12mo: "Settled" |
| Skin & hair | sparkles | amber | `min(months / 12, 1.0)` | <3mo: "Just starting", ≥3mo: "Ongoing" |
| Muscle & strength | body-scan | teal | `min(months / 18, 1.0)` | <6mo: "Building", ≥6mo: "Growing" |
| Your cycle | heart-rate-monitor | pink | `1.0` (always full) | "Day X of Y" |

### 13.5 Progress Computation

Each body system has a **progress fraction** that maps `monthsOnHRT` to a 0–1 value, capped at 1.0:

```
progressFraction = min(months / maxMonths, 1.0)
```

Where `maxMonths` varies by system:
- **Fast changes** (skin): 12 months to full
- **Medium changes** (mood, muscle): 18 months to full
- **Slow changes** (body shape, voice): 24 months to full
- **Cycle-aware** (your cycle): always 1.0 (it's about where you are *now*, not cumulative progress)

The progress bar animates on appear (`easeOut, 0.9s, delay 0.25s`) from 0 to `progressFraction`.

### 13.6 Cycle Day Computation
```swift
let cycleDay: Int = {
    guard let last = medicationManager.lastDoseDate,
          let methodStr = medicationManager.selectedAdministrationMethod,
          let adm = MedicationManager.AdministrationMethod(rawValue: methodStr) else { return 1 }
    let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
    return (elapsed % adm.frequencyDays) + 1
}()

var cycleLengthDays: Int {
    switch method {
    case "Injectable": return 7
    case "Patch": return 3
    default: return 1
    }
}
```

The "Your cycle" system displays `"Day \(dayOfCycle) of \(cycleLengthDays)"`, giving the user context about where they are in their current dose interval.

### 13.7 Relationship to MedicationManager
- `monthsOnHRT` → drives all progress fractions and labels
- `lastDoseDate` + `selectedAdministrationMethod` → drives cycle day computation
- `selectedMedication` → selects estrogen vs testosterone body system set
- No dose history or blood tests needed for this section

---

## 14. The "Coming Up" Section — Future Milestones

### 14.1 Data Structure
```swift
struct BloomMilestone: Identifiable {
    let id = UUID()
    let title: String           // e.g., "Month 12 milestone"
    let description: String     // educational content
    let icon: String            // "clock", "test-pipe" (flask), "star"
    let palette: BloomPalette   // color scheme (always .neutral or .purple)
    let badge: String?          // timeframe label (e.g., "3 months away", "Suggested: month 6")
}
```

### 14.2 Estrogen Milestones

| Condition | Title | Badge | Description |
|---|---|---|---|
| `months < 12` | Month 12 milestone | "X months away" | Hair regrowth typically begins, breast growth enters new phase |
| `months < 24` | 2-year milestone | "X months away" | Most permanent changes developed, skin and fat redistribution near complete |
| Always shown | Your next blood test | "Suggested: month X" | At month X check E2, T, and full panel (X = next multiple of 3 after current month) |

### 14.3 Testosterone Milestones

| Condition | Title | Badge | Description |
|---|---|---|---|
| `months < 6` | Voice changes begin | "X months away" (capped: `max(0, 3 - months)`) | Voice deepening between months 3–6 |
| `months < 12` | Month 12 check-in | "X months away" | Reassess dose, review changes with provider |
| Always shown | Your next blood test | "Suggested: month X" | Check T, hematocrit, liver enzymes |

### 14.4 Blood Test Milestone Computation
```swift
let bloodTestMonth = ((months / 3) + 1) * 3
```
Integer division floors `months / 3`, then `+1` advances to the *next* 3-month block, multiplied back. Examples:
- Month 2 → `((2/3)+1)*3 = (0+1)*3 = 3`
- Month 5 → `((5/3)+1)*3 = (1+1)*3 = 6`
- Month 11 → `((11/3)+1)*3 = (3+1)*3 = 12`

This suggests blood testing every 3 months.

### 14.5 Milestone Progression
Milestones **disappear** once their condition is no longer met:
- When `months >= 12`, the "Month 12 milestone" vanishes
- When `months >= 24`, the "2-year milestone" vanishes  
- When `months >= 6` (for T), the "Voice changes begin" milestone vanishes
- The blood test milestone **always remains** (no conditional gate), continuously updating its suggested month

### 14.6 UI Rendering (`BloomMilestonesSection`)
- Header: "COMING UP"
- Vertical stack of milestone rows, each with:
  - Circular icon container (secondary background)
  - Title + timeframe badge (right-aligned)
  - Description text

### 14.7 Relationship to MedicationManager
- `monthsOnHRT` → drives which milestones appear and their "X months away" badges
- `selectedMedication` → selects estrogen vs testosterone milestone set
- Blood test milestone uses only `months`, independent of actual `bloodTestHistory`

---

## 15. The `BloomContentEngine` — Single Render-Time Assembly

### 15.1 Construction
```swift
// BloomView builds a fresh engine on every body evaluation:
private var engine: BloomContentEngine {
    BloomContentEngine(
        medication: medicationManager.selectedMedication ?? "Estrogen",
        method: medicationManager.selectedAdministrationMethod ?? "Injectable",
        months: medicationManager.monthsOnHRT,
        currentLevel: medicationManager.estimatedRecentLevels(days: 1).last?.value,
        dayOfCycle: cycleDay  // computed from lastDoseDate
    )
}
```

The engine is a **value type** (struct), built fresh every SwiftUI render cycle. No mutation, no caching — pure function of MedicationManager's `@Published` state.

### 15.2 Timeline Header
The hero section displays a phase-appropriate title based on `months`:
| Months | Title |
|---|---|
| 0–1 | "Day one — welcome ✦" |
| 1–3 | "Early days ✦" |
| 3–6 | "Things are shifting ✦" |
| 6–12 | "You're in full swing ✦" |
| 12–24 | "A year and counting ✦" |
| 24+ | "Deeply rooted ✦" |

Subtitle: `"Month X on HRT"`

### 15.3 Hormone Insight (BloomHormoneRow)
An optional row showing current estimated level, unit, range label with color-coded badge, and a body description that varies by level range. This is the *consequence* of the PK model — it surfaces `estimatedRecentLevels(days: 1).last?.value`.

### 15.4 Complete Data Flow
```
MedicationManager (@Published)           BloomContentEngine (struct)        BloomView (SwiftUI)
────────────────────────────             ────────────────────────           ────────────────────
monthsOnHRT              ──────────►   months: Int
selectedMedication       ──────────►   medication: String
selectedAdministrationMethod ──────►   method: String
lastDoseDate             ──────┬──►   dayOfCycle: Int
estimatedRecentLevels()  ──────┴──►   currentLevel: Double?
                                        │
                                        ├── timelineTitle / timelineSubtitle
                                        ├── unlockedChanges: [BloomChange]
                                        ├── hormoneInsight: BloomHormoneInsight?
                                        ├── bodySystems: [BloomBodySystem]
                                        └── upcomingMilestones: [BloomMilestone]
```

### 15.5 Key Insight: No Persisted "Bloom" State
The Bloom tab has **zero persistent state** of its own. Every badge, progress bar, milestone, and label is computed at render time from `MedicationManager`'s existing state. "Changes unlocked" doesn't store an unlock event — it just checks `months >= threshold`. "Your Body" doesn't store progress — it computes `min(months / maxMonths, 1.0)`. "Coming Up" doesn't store milestone completion — it checks `months < threshold` to decide visibility.

This means:
- If a user backdates their `hrtStartDate`, all sections instantly reflect the new timeline
- If `monthsOnHRT` advances past a threshold, items unlock/lock automatically
- There is no "acknowledgment" or "dismissal" mechanism — milestones simply appear and disappear based on time

---

## 16. Key Insight: Change Tracking Is Implicit, Not Explicit

The xT app does **not** maintain an explicit "change log" or "regimen transition" record. Instead:

1. **Every dose is self-describing** — it carries its own ester, amount, method, and concentration
2. **The PK model handles heterogeneity** — each dose's contribution is computed independently using its own parameters
3. **Change detection happens at query time** — comparing consecutive `DoseRecord` entries reveals what changed
4. **The dose history IS the change history** — the sequence of `DoseRecord` objects, sorted by `doseDate`, is the complete audit trail
5. **Time-based state is derived**, not stored — `hasMissedDose`, `daysSinceMissedDose`, `monthsOnHRT`, `currentCyclePosition` are all computed properties evaluated at access time

---

*Document generated from source code analysis of xT app, build commit 3e932fb.*