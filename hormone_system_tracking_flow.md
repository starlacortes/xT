# Hormone System Tracking Flow Diagram

A comprehensive, detailed flow diagram for every component of the xT hormone tracking system, organized into logical phases.

---

## TABLE OF CONTENTS

1. [Phase 1: Data Foundation & Initialization](#phase-1-data-foundation--initialization)
2. [Phase 2: Medication Configuration Flow](#phase-2-medication-configuration-flow)
3. [Phase 3: Pharmacokinetic Modeling Engine](#phase-3-pharmacokinetic-modeling-engine)
4. [Phase 4: Hormone Level Estimation Pipeline](#phase-4-hormone-level-estimation-pipeline)
5. [Phase 5: Current Level Assessment & Range Classification](#phase-5-current-level-assessment--range-classification)
6. [Phase 6: Journal & Symptom Correlation](#phase-6-journal--symptom-correlation)
7. [Phase 7: UI Reactivity & State Propagation](#phase-7-ui-reactivity--state-propagation)
8. [Phase 8: Dose Scheduling & Reminders](#phase-8-dose-scheduling--reminders)
9. [Phase 9: Data Persistence Layer](#phase-9-data-persistence-layer)
10. [Phase 10: Analytics & Insights Generation](#phase-10-analytics--insights-generation)

---

## PHASE 1: DATA FOUNDATION & INITIALIZATION

### 1.1 App Launch → Manager Initialization Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        xTApp INITIALIZATION                                  │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────┐
  │   xTApp (SwiftUI App)       │
  │   @main entry point         │
  └─────────────┬───────────────┘
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │   init()                                                             │
  │   ─────────                                                            │
  │   • Create ModelContainer(for: [JournalEntry, DoseRecord,           │
  │                            UserPreferences])                         │
  │   • Inject EnvironmentObjects:                                     │
  │     - MedicationManager.shared                                      │
  │     - JournalManager.shared                                         │
  │     - ProfileManager.shared                                         │
  │     - NotificationManager.shared                                    │
  │     - AuthenticationManager.shared                                  │
  │     - SecurityManager.shared                                        │
  │   • Configure UNUserNotificationCenter                               │
  │   • Call NotificationManager.setupNotificationCategories()          │
  └─────────────┬───────────────────────────────────────────────────────┘
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │   ContentView loads                                                  │
  │   ─────────────                                                      │
  │   • Checks hasCompletedOnboarding (UserDefaults)                    │
  │   • Checks AuthenticationManager.isAuthenticated                     │
  │   ┌──────────────┐  ┌──────────────┐                               │
  │   │ First Launch │  │ Returning    │                               │
  │   │ (no onboarding│  │ User         │                               │
  │   │  completed)  │  │ (completed)  │                               │
  │   └──────┬───────┘  └──────┬───────┘                               │
  │          │                 │                                        │
  │          ▼                 ▼                                        │
  │   ┌─────────────┐   ┌─────────────┐                               │
  │   │Onboarding   │   │  MainTabView│                               │
  │   │View         │   │  (Home/Jrn/ │                               │
  │   │             │   │   Time/Set) │                               │
  │   └─────────────┘   └─────────────┘                               │
  └──────────────────────────────────────────────────────────────────────┘
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │   MedicationManager.init() (Singleton)                               │
  │   ─────────────────────────────────                                  │
  │   1. loadSelection()                                                 │
  │      ├─→ Check encrypted UserDefaults                               │
  │      ├─→ Decrypt & parse "medication|method"                         │
  │      └─→ Fallback: plain UserDefaults                               │
  │   2. loadDoseDates()                                                 │
  │      ├─→ Decrypt JSON container:                                   │
  │      │    {lastDoseDate, nextDoseDate, hrtStartDate}                │
  │      └─→ Restore @Published dates                                   │
  │   3. loadDoseHistory()                                               │
  │      ├─→ FetchDescriptor<DoseRecord> from SwiftData                 │
  │      ├─→ Sort by doseDate ascending                                  │
  │      └─→ Filter out isDeleted=true records                          │
  │   4. migrateToEncryptedStorage()                                    │
  │      ├─→ If no encrypted keys exist                                │
  │      └─→ Persist all raw data to encrypted storage                 │
  │   5. refreshState()                                                  │
  │      ├─→ getCurrentHormoneLevel()                                   │
  │      └─→ estimatedLevels(from: -7d, to: now)                       │
  └──────────────────────────────────────────────────────────────────────┘
```

### 1.2 State Diagram: MedicationManager Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MedicationManager STATE MACHINE                    │
└─────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │     UNINITIALIZED   │
                    │  (no medication     │
                    │   configured)       │
                    └──────────┬──────────┘
                               │
                    updateSelection(type, method)
                               │
                               ▼
                    ┌─────────────────────┐
                    │   PARTIALLY         │
                    │   CONFIGURED        │
                    │  (med OR method     │
                    │   set, but not both)│
                    └──────────┬──────────┘
                               │
                    updateSelection(type, method)
                               │
                               ▼
                    ┌─────────────────────┐
                    │   FULLY             │
                    │   CONFIGURED        │
                    │  (med + method set) │
                    └──────────┬──────────┘
                               │
                    recordDose() / addDose()
                               │
                               ▼
                    ┌─────────────────────┐
                    │   DOSE LOGGED       │
                    │  (lastDoseDate set, │
                    │   nextDoseDate calc)│
                    └──────────┬──────────┘
                               │
              hasMissedDose? ──┴──┐
               (Date() > next)     │
              YES                  NO
               │                    │
               ▼                    ▼
     ┌─────────────────┐   ┌─────────────────┐
     │ MISSED DOSE     │   │ ACTIVE / ON     │
     │ STATE           │   │ SCHEDULE        │
     │ (prompt user)   │   │                 │
     └────────┬────────┘   └────────┬────────┘
              │                     │
              │ recordDose()        │ wait for nextDose
              │                     │
              └─────────┬───────────┘
                        ▼
              ┌─────────────────┐
              │ REFRESH STATE   │
              │ • recalc level  │
              │ • update graph  │
              │ • notify UI     │
              └─────────────────┘
```

---

## PHASE 2: MEDICATION CONFIGURATION FLOW

### 2.1 Onboarding Medication Setup Pipeline

```
┌────────────────────────────────────────────────────────────────────────┐
│                 MEDICATION SETUP FLOW (Onboarding Step 4)              │
└────────────────────────────────────────────────────────────────────────┘

  User enters Step 4 → "Let's set up your tracking"
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4A: SELECT MEDICATION TYPE                                │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   Options:                                                        │
  │   ┌──────────────────────┐  ┌──────────────────────┐             │
  │   │ ○ Estrogen           │  │ ○ Testosterone       │             │
  │   │  baseline: 100 pg/mL │  │  baseline: 500 ng/dL │             │
  │   │  default ester: EV   │  │  default ester: TC   │             │
  │   └──────────────────────┘  └──────────────────────┘             │
  │                                                                   │
  │   On Select:                                                     │
  │   • Store selectedMedication = type.rawValue                     │
  │   • Filter administration methods (same options for both)        │
  │   • Enable next step                                             │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4B: SELECT ADMINISTRATION METHOD                          │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   Options (filtered, all available):                             │
  │   ┌──────────────────────┐  ┌──────────────────────┐             │
  │   │ ○ Injectable         │  │ ○ Cream              │             │
  │   │  frequency: 7 days   │  │  frequency: 1 day    │             │
  │   └──────────────────────┘  └──────────────────────┘             │
  │   ┌──────────────────────┐                                        │
  │   │ ○ Oral               │                                        │
  │   │  frequency: 1 day    │                                        │
  │   └──────────────────────┘                                        │
  │                                                                   │
  │   On Select:                                                     │
  │   • Store selectedAdministrationMethod = method.rawValue         │
  │   • If injectable → show ester selection                         │
  │   • Enable next step                                             │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4C: SELECT ESTER (if injectable selected)                 │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   Estrogen Esters:                                               │
  │   ┌──────────────────────────────────────────────────────────┐   │
  │   │ ○ Valerate (EV)    t½=2.0d    potency=1.00              │   │
  │   │ ○ Cypionate (EC)   t½=8.5d    potency=0.75              │   │
  │   └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │   Testosterone Esters:                                           │
  │   ┌──────────────────────────────────────────────────────────┐   │
  │   │ ○ Cypionate (TC)   t½=8.0d    potency=0.86              │   │
  │   │ ○ Enanthate (TE)   t½=7.0d    potency=0.86              │   │
  │   │ ○ Propionate (TP)  t½=1.0d    potency=1.00              │   │
  │   │ ○ Undecanoate (TU) t½=20.0d   potency=0.95              │   │
  │   └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │   On Select:                                                     │
  │   • Store ester in DoseRecord (when dose logged)                 │
  │   • halfLife available for PK calculations                      │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4D: ENTER DOSE AMOUNT                                     │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   Input: [ 2.0 ] mg                                              │
  │   Stepper: +/- 0.1 increments                                    │
  │   Quick select: [0.5] [1] [2] [4] [6]                            │
  │                                                                   │
  │   Stored as: doseAmount (Double) in DoseRecord                   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4E: HRT HISTORY                                           │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   ┌────────────────────────┐  ┌────────────────────────┐         │
  │   │ Just starting          │  │ I've been on it        │         │
  │   │ (first time user)      │  │ (continuing HRT)       │         │
  │   └────────────────────────┘  └────────────────────────┘         │
  │                    │                    │                         │
  │                    │                    ▼                         │
  │                    │          ┌───────────────────────┐           │
  │                    │          │ Date picker: Month ▼  │           │
  │                    │          │ Slider: [────24────]  │           │
  │                    │          │ → "24 Months"         │           │
  │                    │          └───────────────────────┘           │
  │                    │                    │                         │
  │                    │                    ▼                         │
  │                    │          hrtStartDate = now - duration       │
  │                    │                                                  │
  └────────────────────┴──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  STEP 4F: COMPLETION                                            │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │   User taps "You're all set"                                     │
  │                                                                   │
  │   Actions:                                                       │
  │   1. addDose(                                                    │
  │        date: now,                                                │
  │        type: selectedMedication,                                 │
  │        ester: selectedEster,                                     │
  │        method: selectedAdministrationMethod,                     │
  │        doseAmount: enteredDose                                   │
  │      )                                                           │
  │   2. persistSelection() → encrypted UserDefaults                 │
  │   3. persistDoseDates() → lastDoseDate = now,                    │
  │                                nextDoseDate = now + frequency    │
  │   4. refreshState() → compute hormone levels                     │
  │   5. UserDefaults.hasCompletedOnboarding = true                  │
  │   6. Navigate to MainTabView (Home tab)                          │
  │                                                                   │
  │   DoseRecord created:                                            │
  │   ┌──────────────────────────────────────────────────────┐       │
  │   │ DoseRecord:                                          │       │
  │   │   id: UUID()                                         │       │
  │   │   doseDate: now                                      │       │
  │   │   medicationType: "Estrogen"                         │       │
  │   │   ester: "Valerate (EV)"                             │       │
  │   │   administrationMethod: "Injectable"                 │       │
  │   │   doseAmount: 2.0                                    │       │
  │   │   notes: nil                                         │       │
  │   │   isDeleted: false                                   │       │
  │   └──────────────────────────────────────────────────────┘       │
  └──────────────────────────────────────────────────────────────────┘
```

### 2.2 Ester & Half-Life Reference Table

```
┌────────────────────────────────────────────────────────────────────┐
│                    ESTER CONFIGURATION REFERENCE                    │
└────────────────────────────────────────────────────────────────────┘

  Medication Type: ESTROGEN
  ┌──────────────────┬───────────┬──────────────┬───────────────┐
  │ Ester            │ Half-Life │ Frequency    │ Potency Factor│
  │                  │ (days)    │ (days)       │ (ester/base)  │
  ├──────────────────┼───────────┼──────────────┼───────────────┤
  │ Valerate (EV)    │   2.0     │     7        │    1.00       │
  │ Cypionate (EC)   │   8.5     │     7        │    0.75       │
  │ Oral             │   0.5     │     1        │    0.50       │
  │ Transdermal      │   1.5     │     1        │    0.70       │
  └──────────────────┴───────────┴──────────────┴───────────────┘

  Medication Type: TESTOSTERONE
  ┌──────────────────┬───────────┬──────────────┬───────────────┐
  │ Ester            │ Half-Life │ Frequency    │ Potency Factor│
  │                  │ (days)    │ (days)       │ (ester/base)  │
  ├──────────────────┼───────────┼──────────────┼───────────────┤
  │ Cypionate (TC)   │   8.0     │     7-10     │    0.86       │
  │ Enanthate (TE)   │   7.0     │     7-10     │    0.86       │
  │ Propionate (TP)  │   1.0     │     2-3      │    1.00       │
  │ Undecanoate (TU) │  20.0     │     10-14    │    0.95       │
  └──────────────────┴───────────┴──────────────┴───────────────┘
```

---

## PHASE 3: PHARMACOKINETIC MODELING ENGINE

### 3.1 Dose Stacking & Exponential Decay Pipeline

```
┌────────────────────────────────────────────────────────────────────────┐
│              PHARMACOKINETIC (PK) MODEL - DOSE STACKING ENGINE         │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  INPUT: DoseHistory (array of DoseRecord, sorted chrono)        │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  [DoseRecord_1] → [DoseRecord_2] → ... → [DoseRecord_N]        │
  │  (oldest)                       (most recent)                    │
  │                                                                   │
  │  Each DoseRecord contains:                                       │
  │  • doseDate: Date                                                │
  │  • doseAmount: Double (actual mg logged)                        │
  │  • ester: String (e.g., "Valerate (EV)")                        │
  │  • medicationType: String                                        │
  │  • isActive: Bool (!isDeleted)                                   │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  STEP 1: DETERMINE ESTER & HALF-LIFE                            │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  1. Filter doseHistory for active doses of selected medication  │
  │     doseHistory.filter { isActive && medicationType == target }  │
  │                                                                   │
  │  2. Sort chronologically (oldest first)                          │
  │     .sorted { $0.doseDate < $1.doseDate }                        │
  │                                                                   │
  │  3. Get most recent dose → extract ester                         │
  │     let recentDose = doseHistory.first { ... }                   │
  │                                                                   │
  │  4. Look up half-life from ester enum:                          │
  │     MedicationEster(rawValue: ester)?.halfLifeDays               │
  │     → EV: 2.0 days, EC: 8.5 days                                │
  │                                                                   │
  │  5. Compute decay constant (lambda):                             │
  │     λ = ln(2) / halfLifeDays                                     │
  │     EV: λ = 0.693/2.0 = 0.347/day                                │
  │     EC: λ = 0.693/8.5 = 0.081/day                                │
  │                                                                   │
  │  6. Get baseline value from medication type:                     │
  │     Estrogen: 100.0 pg/mL                                        │
  │     Testosterone: 500.0 ng/dL                                    │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  STEP 2: COMPUTE POTENCY-ADJUSTED DOSE AMOUNTS                  │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  For each dose event:                                            │
  │                                                                   │
  │  potencyFactor = dosePotencyFactor(for: dose)                    │
  │  effectiveAmount = doseAmount × potencyFactor                    │
  │                                                                   │
  │  Example (Estrogen EV @ 2.0mg):                                  │
  │  • potencyFactor = 1.00 (EV is baseline)                         │
  │  • effectiveAmount = 2.0 × 1.00 = 2.0                           │
  │                                                                   │
  │  Example (Estrogen EC @ 2.0mg):                                  │
  │  • potencyFactor = 0.75 (EC is 25% less potent)                  │
  │  • effectiveAmount = 2.0 × 0.75 = 1.5                           │
  │                                                                   │
  │  Result: [(date: D1, amount: A1), (date: D2, amount: A2), ...]  │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  STEP 3: TIME-COURSE EVALUATION (Cursor Iteration)              │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  Input: start date, end date, stepDays (default 1)               │
  │                                                                   │
  │  cursor = start                                                  │
  │  while cursor <= end:                                            │
  │                                                                   │
  │    cumulativeSpike = 0.0                                         │
  │                                                                   │
  │    for each doseEvent in doseEvents:                              │
  │      diff_days = (cursor - doseEvent.date) / 86400               │
  │                                                                   │
  │      if diff_days >= 0:  // future doses ignored                  │
  │        decay = exp(-λ × diff_days)                               │
  │        contribution = doseEvent.amount × decay                   │
  │        cumulativeSpike += contribution                           │
  │                                                                   │
  │    hormoneValue = baselineValue + cumulativeSpike               │
  │                                                                   │
  │    append (date: cursor, value: hormoneValue) to points         │
  │                                                                   │
  │    cursor = cursor + stepDays                                    │
  │                                                                   │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  STEP 4: OUTPUT → [EstimatedPoint]                              │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  EstimatedPoint struct:                                          │
  │  ┌──────────────────────────────────────────────────────┐       │
  │  │ • id: UUID()                                         │       │
  │  │ • date: Date                                          │       │
  │  │ • value: Double (hormone level)                      │       │
  │  │ • medication: String                                 │       │
  │  │ • method: String                                     │       │
  │  └──────────────────────────────────────────────────────┘       │
  │                                                                   │
  │  Output array represents the hormone concentration curve        │
  │  over the requested time window.                                 │
  │                                                                   │
  │  EV curve: Sharp peaks after dose, rapid decay (sawtooth)        │
  │  EC curve: Blunted peaks, slow decay (flatter)                   │
  └─────────────────────────────────────────────────────────────────┘

  ───────────────────────────────────────────────────────────────────
  MATHEMATICAL FORMULA:
  ───────────────────────────────────────────────────────────────────

  C(t) = C_base + Σ [D_i × potency_i × e^(-λ × (t - t_i))]

  Where:
    C(t)       = Total hormone concentration at time t
    C_base     = Baseline endogenous level
    D_i        = Dose amount of i-th dose event (in mg)
    potency_i  = Ester potency factor (relative to base)
    λ          = Decay constant = ln(2) / t½
    t          = Current time (cursor)
    t_i        = Time of i-th dose
    (t - t_i)  = Time elapsed since i-th dose (in days)

  The summation iterates over ALL previous active dose events.
  Each dose contributes a decaying spike proportional to its amount,
  adjusted by ester potency, and衰减 by the exponential function.
```

### 3.2 PK Model State Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                    PK MODEL STATE MACHINE                           │
└────────────────────────────────────────────────────────────────────┘

  ┌───────────────────┐
  │  NO DOSES LOGGED  │
  │  (empty history)  │
  └────────┬──────────┘
           │
           │ User adds first dose
           │ addDose(...)
           ▼
  ┌───────────────────┐     ┌───────────────────┐
  │  DOSES LOGGED     │────→│  REFRESH STATE    │
  │  (active records) │     │                   │
  └────────┬──────────┘     │  • Rebuild dose   │
           │                │    events         │
           │ Dose updated   │  • Recompute λ    │
           │ or added       │  • Re-eval curve  │
           │                │  • Update UI      │
           ▼                └───────────────────┘
  ┌───────────────────┐
  │  DOSE HISTORY     │
  │  CHANGED          │
  │                   │
  │  • New dose       │
  │  • Removed dose   │
  │  • Ester changed  │
  │  • Amount changed │
  └────────┬──────────┘
           │
           └────────────┐
                        │
                        ▼
              ┌───────────────────┐
              │  RECALCULATE      │
              │  estimatedLevels  │
              └───────────────────┘
```

---

## PHASE 4: HORMONE LEVEL ESTIMATION PIPELINE

### 4.1 estimatedLevels() Method Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              estimatedLevels(from: Date, to: Date, stepDays: Int)      │
│                         Method Flow Diagram                            │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  ENTRY: estimatedLevels(from: start, to: end, stepDays: 1)      │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  VALIDATION CHECK                                               │
  │  ─────────────────────                                          │
  │                                                                   │
  │  guard let medication = selectedMedication                      │
  │        && let methodStr = selectedAdministrationMethod           │
  │                                                                   │
  │  ┌──────────────┐    ┌──────────────────┐                       │
  │  │ VALID        │    │ INVALID           │                       │
  │  │ (both set)   │    │ (missing fields)  │                       │
  │  └──────┬───────┘    └────────┬─────────┘                       │
  │         │                     │                                  │
  │         ▼                     ▼                                  │
  │   Continue computation   return []                              │
  └─────────┬───────────────────────────────────────────────────────┘
            │
            ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  RESOLVE HALF-LIFE & BASELINE                                   │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  1. Parse medication enum:                                      │
  │     let medicationEnum = MedicationType(rawValue: medication)    │
  │     baselineValue = medicationEnum?.baselineValue ?? 100.0       │
  │                                                                   │
  │  2. Find most recent dose for ester:                            │
  │     recentDose = doseHistory                                    │
  │       .filter { isActive && medType == target }                  │
  │       .sorted { $0.doseDate > $1.doseDate }  // newest first    │
  │       .first                                                     │
  │                                                                   │
  │  3. Extract half-life:                                          │
  │     if medication == "Estrogen":                                │
  │       ester = MedicationEster(rawValue: recentDose.ester)        │
  │       halfLife = ester?.halfLifeDays ?? 2.0 (EV default)         │
  │     else if medication == "Testosterone":                       │
  │       ester = TestosteroneEster(rawValue: recentDose.ester)      │
  │       halfLife = ester?.halfLifeDays ?? 8.0 (TC default)         │
  │                                                                   │
  │  4. Compute decay constant:                                     │
  │     λ = ln(2) / halfLife                                        │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  BUILD DOSE EVENTS ARRAY                                        │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  if !doseHistory.isEmpty:                                        │
  │    // REAL DOSE HISTORY PATH                                     │
  │    activeDoses = doseHistory                                    │
  │      .filter { isActive && medType == target }                   │
  │      .sorted { $0.doseDate < $1.doseDate }  // chrono            │
  │                                                                   │
  │    for dose in activeDoses:                                      │
  │      potency = dosePotencyFactor(for: dose)                      │
  │      effectiveAmount = dose.doseAmount × potency                 │
  │      doseEvents.append((date: dose.doseDate,                      │
  │                          amount: effectiveAmount))                │
  │                                                                   │
  │  else:                                                           │
  │    // FALLBACK: ESTIMATED DOSES (backward compat)                │
  │    if let last = lastDoseDate:                                   │
  │      lookbackStart = start - 60 days                             │
  │      accumulatedDose = baselineValue × 0.5                       │
  │      d = last                                                    │
  │      while d >= lookbackStart:                                   │
  │        doseEvents.append((date: d, amount: accumulatedDose))     │
  │        d = d - 7 days  // injection frequency                   │
  │                                                                   │
  │  Sort doseEvents by date ascending                               │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  CURSOR ITERATION - POINT GENERATION                            │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  var points = [EstimatedPoint]()                                 │
  │  cursor = start                                                  │
  │  calendar = Calendar.current                                     │
  │                                                                   │
  │  while cursor <= end:                                            │
  │                                                                   │
  │    cumulativeSpike = 0.0                                         │
  │                                                                   │
  │    for doseEvent in doseEvents:                                   │
  │      diff = (cursor - doseEvent.date) / 86400.0  // in days     │
  │                                                                   │
  │      if diff >= 0:  // only past doses                           │
  │        contribution = doseEvent.amount × exp(-λ × diff)         │
  │        cumulativeSpike += contribution                           │
  │                                                                   │
  │    totalValue = baselineValue + cumulativeSpike                  │
  │                                                                   │
  │    points.append(EstimatedPoint(                                 │
  │      date: cursor,                                               │
  │      value: totalValue,                                          │
  │      medication: medication,                                     │
  │      method: methodStr                                           │
  │    ))                                                            │
  │                                                                   │
  │    cursor = calendar.date(byAdding: .day, value: stepDays,      │
  │                           to: cursor)                             │
  │                                                                   │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  OUTPUT: [EstimatedPoint]                                       │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  Example output (Estrogen EV, 7-day cycle, 14 days):            │
  │                                                                   │
  │  Day 0:  200.00 pg/mL  ← baseline(100) + spike(100)             │
  │  Day 1:  269.31 pg/mL  ← 100 + 100×e^(-0.347×1)                 │
  │  Day 2:  238.91 pg/mL  ← 100 + 100×e^(-0.347×2)                 │
  │  Day 3:  212.94 pg/mL  ← 100 + 100×e^(-0.347×3)                 │
  │  Day 4:  189.65 pg/mL  ← 100 + 100×e^(-0.347×4)                 │
  │  Day 5:  168.97 pg/mL  ← 100 + 100×e^(-0.347×5)                 │
  │  Day 6:  150.45 pg/mL  ← 100 + 100×e^(-0.347×6)                 │
  │  Day 7:  250.45 pg/mL  ← 100 + 100×e^(-0.347×0) + prev decay   │
  │     ...                                                           │
  │                                                                   │
  │  → Returns to caller (refreshState → recentLevels)              │
  └─────────────────────────────────────────────────────────────────┘
```

### 4.2 Data Flow: From Dose Logging to Graph Display

```
┌────────────────────────────────────────────────────────────────────────┐
│              COMPLETE DATA FLOW: DOSE ENTRY → GRAPH RENDERING          │
└────────────────────────────────────────────────────────────────────────┘

  User Action: Tap "Record Dose"
                │
                ▼
  ┌──────────────────────────────────────┐
  │  MedicationManager.addDose()         │
  │  ─────────────────────────────       │
  │  1. Create DoseRecord               │
  │  2. Append to doseHistory           │
  │  3. Insert into SwiftData           │
  │  4. Update lastDoseDate             │
  │  5. Calculate nextDoseDate          │
  │  6. Call refreshState()             │
  └──────────────┬───────────────────────┘
                 │
                 │ @Published triggers
                 ▼
  ┌──────────────────────────────────────┐
  │  refreshState()                      │
  │  ──────────────                      │
  │  1. getCurrentHormoneLevel()         │
  │     → updates currentHormoneLevel    │
  │  2. estimatedLevels(from: -7d,       │
  │                    to: now)           │
  │     → updates recentLevels           │
  └──────────────┬───────────────────────┘
                 │
                 │ @Published updates
                 ▼
  ┌──────────────────────────────────────┐
  │  SwiftUI View Invalidates            │
  │  ──────────────────────────          │
  │  HomeView → GraphView                │
  │  ┌────────────────────────────────┐  │
  │  │ recentLevels loop:             │  │
  │  │  for point in recentLevels:    │  │
  │  │    drawLine(point.date,        │  │
  │  │              point.value)      │  │
  │  └────────────────────────────────┘  │
  └──────────────────────────────────────┘
```

---

## PHASE 5: CURRENT LEVEL ASSESSMENT & RANGE CLASSIFICATION

### 5.1 getCurrentHormoneLevel() Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              getCurrentHormoneLevel() → (value, unit, range,          │
│                                        explanation)                    │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  ENTRY: getCurrentHormoneLevel()                                │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  VALIDATION CHECK                                               │
  │  ─────────────────────                                          │
  │                                                                   │
  │  guard let medication = selectedMedication                      │
  │        && _ = selectedAdministrationMethod                       │
  │                                                                   │
  │  ┌──────────────┐    ┌──────────────────┐                       │
  │  │ VALID        │    │ INVALID           │                       │
  │  │ (med set)    │    │ (no med)          │                       │
  │  └──────┬───────┘    └────────┬─────────┘                       │
  │         │                     │                                  │
  │         ▼                     ▼                                  │
  │   Continue          return nil                                 │
  └─────────┬───────────────────────────────────────────────────────┘
            │
            ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  SAMPLE RECENT LEVEL (Last Hour)                                │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  recent = estimatedLevels(                                       │
  │    from: now - 1 hour,                                           │
  │    to: now                                                       │
  │  )                                                               │
  │                                                                   │
  │  guard let latestLevel = recent.last                            │
  │                                                                   │
  │  latestLevel: EstimatedPoint                                     │
  │  → value in pg/mL (estrogen) or ng/dL (testosterone)             │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  DETERMINE UNIT OF MEASUREMENT                                  │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  medicationEnum = MedicationType(rawValue: medication)           │
  │                                                                   │
  │  if medicationEnum == .estrogen:                                 │
  │    unit = "pg/mL"                                                │
  │  else:                                                           │
  │    unit = "ng/dL"                                                │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  RANGE CLASSIFICATION                                           │
  │  ────────────────────────────                                   │
  │                                                                   │
  │  if medicationEnum == .estrogen:                                 │
  │    ranges = estrogenRanges:                                      │
  │      ┌────────────┬───────┬───────┬──────────┐                  │
  │      │ Label      │ Min   │ Max   │ Color    │                  │
  │      ├────────────┼───────┼───────┼──────────┤                  │
  │      │ Very Low   │   0   │  50   │ bloom    │                  │
  │      │ Low        │  50   │ 100   │ bloom    │                  │
  │      │ Optimal    │ 100   │ 200   │ success  │                  │
  │      │ High       │ 200   │ 500   │ cycle    │                  │
  │      │ Very High  │ 500   │1000   │ cycle    │                  │
  │      └────────────┴───────┴───────┴──────────┘                  │
  │                                                                   │
  │  else (testosterone):                                            │
  │    ranges = testosteroneRanges:                                  │
  │      ┌───────────────┬───────┬───────┬──────────┐                │
  │      │ Label         │ Min   │ Max   │ Color    │                │
  │      ├───────────────┼───────┼───────┼──────────┤                │
  │      │ Suppressed    │   0   │  50   │ success  │                │
  │      │ Low (Fem)     │  50   │ 100   │ success  │                │
  │      │ Moderate      │ 100   │ 300   │ warning  │                │
  │      │ Male Low      │ 300   │ 500   │ cycle    │                │
  │      │ Male Range    │ 500   │1000   │ cycle    │                │
  │      │ Very High     │1000   │9999   │ cycle    │                │
  │      └───────────────┴───────┴───────┴──────────┘                │
  │                                                                   │
  │  rangeInfo = ranges.first {                                      │
  │    value >= $0.min && value < $0.max                             │
  │  } ?? unknownRange                                               │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  GENERATE PLAIN-LANGUAGE EXPLANATION                            │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  if estrogen:                                                    │
  │    switch rangeInfo.label:                                       │
  │      "Very Low" → "mood swings, limited changes"                │
  │      "Low"      → "some emotional/physical changes, subtle"     │
  │      "Optimal"  → "emotionally stable, ongoing skin changes"    │
  │      "High"     → "significant changes, monitor side effects"   │
  │      default  → "consult your provider"                         │
  │                                                                   │
  │  else (testosterone):                                            │
  │    if value < 50: "testosterone effectively suppressed"         │
  │    else: "this is a low male range"                             │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  OUTPUT: Tuple                                                    │
  │  ────────────                                                   │
  │                                                                   │
  │  return (                                                      │
  │    value: latestLevel.value,   // e.g., 150.00                   │
  │    unit: unit,               // "pg/mL" or "ng/dL"               │
  │    range: rangeInfo.label,   // "Optimal"                        │
  │    explanation: explanation    // user-friendly text             │
  │  )                                                               │
  │                                                                   │
  │  ← Bound to @Published currentHormoneLevel                       │
  │  ← Consumed by HeroView, SettingsView, UnifiedScheduleView       │
  └─────────────────────────────────────────────────────────────────┘
```

### 5.2 Range Classification Decision Tree

```
┌────────────────────────────────────────────────────────────────────┐
│               HORMONE LEVEL → RANGE DECISION TREE                  │
└────────────────────────────────────────────────────────────────────┘

                    Start: hormoneValue
                          │
                          ▼
              ┌───────────────────┐
              │ Estrogen or       │
              │ Testosterone?    │
              └────────┬──────────┘
                       │
            ┌──────────┴──────────┐
            │                     │
      ┌─────▼──────┐      ┌──────▼──────────┐
      │ Estrogen   │      │ Testosterone     │
      │ (pg/mL)    │      │ (ng/dL)          │
      └─────┬──────┘      └──────┬───────────┘
            │                    │
            ▼                    ▼
    value < 50?          value < 50?
            │                    │
     YES ───┴── NO         YES ───┴── NO
            │                    │
    ┌───────▼───────┐   ┌───────▼──────────┐
    │ Very Low      │   │ Suppressed ✓     │
    │ (bloomBody)   │   └──────────────────┘
    └───────────────┘          │
            │                   │
    50 ≤ val < 100?    50 ≤ val < 100?
            │                   │
     YES ───┴── NO         YES ───┴── NO
            │                   │
    ┌───────▼───────┐   ┌───────▼──────┐
    │ Low           │   │ Low (Fem) ✓  │
    │ (bloomBody)   │   └──────────────┘
    └───────────────┘          │
            │                   │
    100 ≤ val < 200?   100 ≤ val < 300?
            │                   │
     YES ───┴── NO         YES ───┴── NO
            │                   │
    ┌───────▼───────┐   ┌───────▼──────┐
    │ Optimal ✓     │   │ Moderate     │
    │ (success)     │   │ (warning)    │
    └───────────────┘   └───────┬──────┘
            │                   │
    200 ≤ val < 500?   300 ≤ val < 500?
            │                   │
     YES ───┴── NO         YES ───┴── NO
            │                   │
    ┌───────▼───────┐   ┌───────▼──────┐
    │ High          │   │ Male Low     │
    │ (bloomCycle)  │   │ (bloomCycle) │
    └───────────────┘   └───────┬──────┘
            │                   │
    val ≥ 500?           500 ≤ val < 1000?
            │                   │
     YES ───┴── NO         YES ───┴── NO
            │                   │
    ┌───────▼───────┐   ┌───────▼──────────┐
    │ Very High     │   │ Male Range       │
    │ (bloomCycle)  │   │ (bloomCycle)     │
    └───────────────┘   └────────┬─────────┘
                                │
                          val ≥ 1000?
                                │
                         YES ───┴── NO
                                │       │
                       ┌────────▼──┐  ┌──▼──────────┐
                       │ Very High │  │ Unknown      │
                       │ (bloom)   │  │ (fallback)   │
                       └───────────┘  └──────────────┘

  ✓ = successColor (healthy range)
```

---

## PHASE 6: JOURNAL & SYMPTOM CORRELATION

### 6.1 Journal Entry Creation Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              JOURNAL ENTRY CREATION FLOW (JournalComposerView)         │
└────────────────────────────────────────────────────────────────────────┘

  Trigger: User taps "new entry…" or + button
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  JournalComposerView Opens (Sheet)                              │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  ┌──────────────────────────────────────────────────────────┐    │
  │  │ [Cancel]        New entry        [Save] (disabled)       │    │
  │  └──────────────────────────────────────────────────────────┘    │
  │                                                                   │
  │  Mood Selection:                                                 │
  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐      │
  │  │ 😊  │ │ 😐  │ │ 😌  │ │ 😔  │ │ 😰  │ │ 😢  │ │ ⚡  │      │
  │  │Happy│ │Neut │ │Calm │ │Tired│ │Anx  │ │Sad  │ │Energ│      │
  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘      │
  │      ▲         ▲         ▲         ▲         ▲         ▲         │
  │      │         │         │         │         │         │         │
  │   @Published currentMood in JournalManager                    │
  │                                                                   │
  │  Text Input:                                                     │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ Write how you're feeling...                              │   │
  │  │                                                          │   │
  │  │ [User types entry]                                       │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  Symptom Chips:                                                  │
  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
  │  │ 🤲 skin     │ │ 🌡️ hot     │ │ 🛏️ fatigue  │               │
  │  │   changes   │ │  flashes    │ │             │               │
  │  └─────────────┘ └─────────────┘ └─────────────┘               │
  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
  │  │ 🧠 headache │ │ ⚡ energy   │ │ 🎭 mood     │               │
  │  │             │ │  boost      │ │  swings     │               │
  │  └─────────────┘ └─────────────┘ └─────────────┘               │
  │  ┌─────────────────────┐ ┌─────────────┐                        │
  │  │ 💓 breast tender.   │ │ 🤢 nausea   │                        │
  │  └─────────────────────┘ └─────────────┘                        │
  │                                                                   │
  │  Current Symptoms: Set<Symptom> = tapped chips                  │
  │  (tapping toggles selection)                                    │
  │                                                                   │
  │  Hormone Context Display:                                        │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 📈 Today's level: 150 pg/mL [Optimal]                    │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  Save Button State:                                              │
  │  • Enabled when text.count > 0                                  │
  │  • Disabled when text.isEmpty                                   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 │ User taps [Save]
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  JournalManager.createNewEntry()                                │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  let entry = JournalEntry(                                       │
  │    date: Date(),                                                 │
  │    mood: currentMood,   // from user selection                   │
  │    text: userInputText,   // from text field                     │
  │    symptoms: currentSymptoms  // from chip selection             │
  │  )                                                               │
  │                                                                   │
  │  JournalEntry structure:                                         │
  │  ┌──────────────────────────────────────────────────────┐       │
  │  │ • id: UUID()                                         │       │
  │  │ • date: Date()                                       │       │
  │  │ • mood: Mood (enum)                                  │       │
  │  │ • text: String                                       │       │
  │  │ • symptoms: Set<Symptom>                             │       │
  │  └──────────────────────────────────────────────────────┘       │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  JournalManager.addEntry(entry)                                 │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  1. entries.insert(entry, at: 0)  // prepend (newest first)     │
  │  2. modelContext?.insert(entry)   // SwiftData persistence      │
  │  3. try? modelContext?.save()      // commit to database        │
  │                                                                   │
  │  UI Updates:                                                     │
  │  • JournalComposerView dismissed                                │
  │  • JournalView refreshes timeline                               │
  │  • New entry appears at top of "TODAY" group                    │
  └──────────────────────────────────────────────────────────────────┘
```

### 6.2 Journal Entry Display & Timeline Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              JOURNAL VIEW - ENTRY DISPLAY & TIMELINE                   │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  JournalManager.loadEntries()                                   │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  1. FetchDescriptor<JournalEntry> from SwiftData                 │
  │  2. Sort by date DESC (newest first)                             │
  │  3. entries = sorted array                                       │
  │                                                                   │
  │  If entries.isEmpty:                                             │
  │    currentMood = .neutral                                        │
  │  else:                                                           │
  │    currentMood = entries.first?.mood                             │
  │    currentSymptoms = entries.first?.symptoms                     │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  Group Entries by Date (for Timeline View)                      │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  entries (sorted by date DESC):                                  │
  │  [E1: Jun 28], [E2: Jun 28], [E3: Jun 27], [E4: Jun 25]        │
  │                                                                   │
  │  Grouped:                                                        │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ TODAY (Jun 28)                                            │   │
  │  │  • E1: 😊 Happy · [skin changes, energy boost] 9:41 AM  │   │
  │  │  • E2: 😰 Anxious · [hot flashes] 7:30 AM               │   │
  │  ├──────────────────────────────────────────────────────────┤   │
  │  │ YESTERDAY (Jun 27)                                        │   │
  │  │  • E3: 😌 Calm · [fatigue, hot flashes] 10:00 AM        │   │
  │  ├──────────────────────────────────────────────────────────┤   │
  │  │ JUNE 25                                                   │   │
  │  │  • E4: 😐 Neutral · [] (no symptoms) 2:00 PM            │   │
  │  └──────────────────────────────────────────────────────────┘   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  JournalCardView Rendering (per entry)                          │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ ● "Skin has been so soft this week..."                   │   │
  │  │ Happy · Skin changes, Energy boost    9:41 AM →         │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  Card structure:                                                 │
  │  • Leading: Mood icon (● or emoji)                              │
  │  • Title: Preview text (first 60 chars + "…")                   │
  │  • Subtitle: mood.label · symptom.names · time                  │
  │  • Trailing: chevron →                                        │
  │                                                                   │
  │  Tap behavior:                                                   │
  │  ├─→ Opens JournalDetailSheet (full view)                       │
  │  └─→ Shows all symptoms, full text, edit/delete options         │
  └──────────────────────────────────────────────────────────────────┘
```

### 6.3 Mood & Symptom Data Model

```
┌────────────────────────────────────────────────────────────────────┐
│                   MOOD & SYMPTOM ENUMERATIONS                       │
└────────────────────────────────────────────────────────────────────┘

  Mood Enum (7 states):                                             
  ┌──────────┬────────┬──────────────────┬──────────────────┐       
  │ Case     │ Label  │ SF Symbol        │ Color            │       
  ├──────────┼────────┼──────────────────┼──────────────────┤       
  │ .happy   │ Happy  │ face.smiling     │ successColor     │       
  │ .calm    │ Calm   │ moon             │ bloomMindColor   │       
  │ .neutral │ Neutral│ minus.circle     │ primary          │       
  │ .tired   │ Tired  │ zzz              │ secondary        │       
  │ .anxious │ Anxious│ waveform.path.ecg│ warningColor     │       
  │ .sad     │ Sad    │ cloud.drizzle    │ bloomBodyColor   │       
  │ .energetic│Energetic│ bolt            │ successColor     │       
  └──────────┴────────┴──────────────────┴──────────────────┘

  Symptom Enum (8 common symptoms):                                
  ┌─────────────────────────┬──────────┬──────────────────────┐     
  │ Name                    │ Icon     │ Category              │     
  ├─────────────────────────┼──────────┼──────────────────────┤     
  │ skin changes            │ hand     │ Physical Changes    │     
  │ hot flashes             │ therm    │ Systemic            │     
  │ fatigue                 │ bed      │ Energy              │     
  │ headache                │ brain    │ Neurological        │     
  │ energy boost            │ bolt     │ Energy              │     
  │ mood swings             │ arrow-up │ Emotional           │     
  │ breast tenderness       │ heart    │ Physical Changes    │     
  │ nausea                  │ allergens│ Gastrointestinal    │     
  └─────────────────────────┴──────────┴──────────────────────┘
```

---

## PHASE 7: UI REACTIVITY & STATE PROPAGATION

### 7.1 Reactive State Update Cascade

```
┌────────────────────────────────────────────────────────────────────────┐
│              UI REACTIVITY PIPELINE - @Published Cascade               │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  CHANGE TRIGGER                                                 │
  │  ──────────────                                                 │
  │                                                                   │
  │  Possible triggers:                                              │
  │  • addDose() called                                             │
  │  • recordDose() called                                          │
  │  • updateSelection() called                                     │
  │  • JournalManager.addEntry() called                             │
  │  • Notification user action                                     │
  │  • Timer / periodic refresh                                     │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  MedicationManager @Published Updates                           │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  doseHistory.append(record)  → @Published                       │
  │  lastDoseDate = date        → @Published                        │
  │  nextDoseDate = date        → @Published                        │
  │                                                                   │
  │  These changes trigger SwiftUI's reactivity system                │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 │ onChange fires
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  refreshState() Auto-Invocation                                 │
  │  ───────────────────────                                        │
  │                                                                   │
  │  Called at end of every mutation:                                │
  │                                                                   │
  │  func refreshState() {                                          │
  │    // 1. Compute current level                                  │
  │    currentHormoneLevel = getCurrentHormoneLevel()                │
  │       → @Published (value, unit, range, explanation)             │
  │                                                                   │
  │    // 2. Recompute 7-day level history                           │
  │    let end = Date()                                              │
  │    let start = now - 7 days                                      │
  │    recentLevels = estimatedLevels(from: start, to: end)          │
  │       → @Published [EstimatedPoint]                              │
  │  }                                                               │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 │ @Published notifications
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  SwiftUI View Tree Invalidation                                 │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  Affected views (re-compute body):                               │
  │                                                                   │
  │  HomeView                                                        │
  │  ├─ HeroView                                                     │
  │  │   ├─ currentHormoneLevel.value display                       │
  │  │   ├─ range badge (Optimal/High/etc)                          │
  │  │   └─ cycle day indicator                                     │
  │  ├─ FlatGraphView                                                │
  │  │   └─ recentLevels graph rendering                            │
  │  ├─ MainContentView                                              │
  │  │   ├─ missed dose prompt (hasMissedDose)                      │
  │  │   ├─ quick actions                                             │
  │  │   ├─ insight row (currentHormoneLevel.explanation)           │
  │  │   ├─ journal row                                               │
  │  │   └─ next dose row                                           │
  │  └─ UnifiedScheduleView                                          │
  │      └─ schedule summary cards                                   │
  │                                                                   │
  │  SettingsView                                                    │
  │  ├─ medication info cards                                        │
  │  ├─ current level display                                        │
  │  └─ next/last dose dates                                         │
  │                                                                   │
  │  BloomView ("Time" tab)                                          │
  │  ├─ hormone level display                                        │
  │  └─ body progress indicators                                    │
  │                                                                   │
  │  JournalView (indirect - via JournalManager)                    │
  │  └─ timeline refresh                                             │
  └─────────────────────────────────────────────────────────────────┘

### 7.2 State Object Graph (Environment Dependencies)

```
┌────────────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT OBJECT DEPENDENCY GRAPH               │
└────────────────────────────────────────────────────────────────────┘

  xTApp (Scene)
    │
    ├─► MedicationManager (shared singleton)
    │     │ @Published: doseHistory, lastDoseDate, nextDoseDate       │
    │     │ @Published: currentHormoneLevel, recentLevels            │
    │     │ Computed: hasMissedDose, isFullyConfigured, monthsOnHRT  │
    │     │ ◄── Depends on: DoseRecord (SwiftData)                   │
    │     │ ◄── Consumed by: HomeView, SettingsView, BloomView       │
    │
    ├─► JournalManager (shared singleton)
    │     │ var entries: [JournalEntry]                               │
    │     │ var currentMood: Mood                                    │
    │     │ var currentSymptoms: Set<Symptom>                        │
    │     │ ◄── Depends on: JournalEntry (SwiftData)                 │
    │     │ ◄── Consumed by: JournalView, JournalComposerView        │
    │
    ├─► ProfileManager (shared singleton)
    │     │ var profileName: String                                  │
    │     │ var profileImage: UIImage?                               │
    │     │ ◄── Depends on: UserDefaults (profile photo data)        │
    │     │ ◄── Consumed by: HeroView, SettingsView                  │
    │
    ├─► NotificationManager (shared singleton)
    │     │ Methods: configureDoseReminder(), scheduleAllReminders() │
    │     │ ◄── Depends on: UNUserNotificationCenter                 │
    │     │ ◄── Consumed by: SettingsView                           │
    │
    ├─► AuthenticationManager (shared singleton)
    │     │ @Published: isAuthenticated, showAuthentication          │
    │     │ ◄── Depends on: LAContext (Face ID / Touch ID)          │
    │     │ ◄── Consumed by: xTApp (scene phase handling)            │
    │
    └─► SecurityManager (shared singleton)
          │ Methods: encryptData(), decryptData()                    │
          │ ◄── Depends: Data Protection API                         │
          │ ◄── Consumed by: MedicationManager (encrypted storage)   │
```

---

## PHASE 8: DOSE SCHEDULING & REMINDERS

### 8.1 Next Dose Date Calculation Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              DOSE SCHEDULING PIPELINE                                   │
└────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │  calculateNextDoseDate(from lastDose: Date) → Date              │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  RESOLVE ADMINISTRATION METHOD                                  │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  guard let methodStr = selectedAdministrationMethod              │
  │        let method = AdministrationMethod(rawValue: methodStr)    │
  │                                                                   │
  │  ┌──────────────┐    ┌──────────────────┐                       │
  │  │ METHOD SET   │    │ NO METHOD         │                       │
  │  └──────┬───────┘    └────────┬─────────┘                       │
  │         │                     │                                  │
  │         ▼                     ▼                                  │
  │   Continue           return Date() (now)                        │
  └─────────┬───────────────────────────────────────────────────────┘
            │
            ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  LOOKUP FREQUENCY                                               │
  │  ────────────────                                               │
  │                                                                   │
  │  method.frequencyDays:                                           │
  │  ┌───────────────────┬────────────────┐                         │
  │  │ Method            │ Frequency      │                         │
  │  ├───────────────────┼────────────────┤                         │
  │  │ Injectable        │ 7 days         │                         │
  │  │ Cream             │ 1 day          │                         │
  │  │ Oral              │ 1 day          │                         │
  │  └───────────────────┴────────────────┘                         │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  COMPUTE NEXT DOSE DATE                                         │
  │  ───────────────────────                                        │
  │                                                                   │
  │  nextDoseDate = Calendar.current.date(                           │
  │    byAdding: .day,                                               │
  │    value: method.frequencyDays,   // 7 or 1                      │
  │    to: lastDoseDate                                               │
  │  ) ?? Date()                                                     │
  │                                                                   │
  │  Example:                                                        │
  │  lastDoseDate = Jun 28, 2026 10:00 AM                           │
  │  frequency = 7 days (injectable)                                 │
  │  nextDoseDate = Jul 5, 2026 10:00 AM                            │
  └──────────────┬──────────────────────────────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  UPDATE STATE & PERSIST                                         │
  │  ────────────────────                                           │
  │                                                                   │
  │  updateDoseDates(last: lastDoseDate, next: nextDoseDate)        │
  │    • lastDoseDate = last                                         │
  │    • nextDoseDate = next                                         │
  │    • persistDoseDates() → encrypted UserDefaults                 │
  │    • refreshState() → cascade to UI                              │
  └─────────────────────────────────────────────────────────────────┘
```

### 8.2 Missed Dose Detection Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              MISSED DOSE DETECTION & PROMPT FLOW                       │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  hasMissedDose: Bool (computed property)                         │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  guard let next = nextDoseDate                                   │
  │  return Date() > next  // is current time past next dose?        │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  DAILY STATE CHECK (on HomeViewAppear)                           │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  if MedicationManager.hasMissedDose == true:                     │
  │                                                                   │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ MISSED DOSE PROMPT (shown in MainContentView)            │   │
  │  │ ───────────────────────────────────────────────────────  │   │
  │  │                                                           │   │
  │  │  ⚠️ "You missed your dose yesterday."                   │   │
  │  │  "Record it now?"                                        │   │
  │  │                                                           │   │
  │  │  ┌──────────────────┐  ┌──────────────┐                  │   │
  │  │  │ Record Dose      │  │  Dismiss     │                  │   │
  │  │  └──────────────────┘  └──────────────┘                  │   │
  │  │                                                           │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  User taps "Record Dose":                                        │
  │  ├─→ MedicationManager.recordDose()                             │
  │  ├─→ lastDoseDate = now                                          │
  │  ├─→ nextDoseDate = now + frequency                             │
  │  ├─→ persistDoseDates()                                         │
  │  ├─→ refreshState() → UI updates                                │
  │  └─→ Prompt dismissed                                            │
  │                                                                   │
  │  User taps "Dismiss":                                            │
  │  └─→ Prompt dismissed (prompt shows again on next reload)       │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  DAYS SINCE MISSED DOSE (for display)                           │
  │  ──────────────────────────────────                              │
  │                                                                   │
  │  daysSinceMissedDose: Int? (computed)                            │
  │    guard hasMissedDose, let next = nextDoseDate                  │
  │    days = Calendar.current.dateComponents(                       │
  │      [.day], from: next, to: Date()                              │
  │    ).day ?? 0                                                    │
  │    return max(1, days)  // at least 1                            │
  │                                                                   │
  │  Display: "Missed X day(s) ago" in schedule summary              │
  └──────────────────────────────────────────────────────────────────┘
```

### 8.3 Notification Scheduling Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              NOTIFICATION SCHEDULING PIPELINE                          │
└────────────────────────────────────────────────────────────────────────┘

  App Launch: NotificationManager.init()
                │
                ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  setupNotificationCategories()                                  │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  UNUserNotificationCenter.current()                                │
  │    .setNotificationCategories:                                   │
  │    ┌────────────────────────────────────────────────────────┐   │
  │    │ DOSE_REMINDER Category:                                │   │
  │    │  Actions: ["Record Dose" (destructive)]               │   │
  │    │                                                        │   │
  │    │ JOURNAL_REMINDER Category:                             │   │
  │    │ Actions: ["Write Entry" (primary)]                    │   │
  │    └────────────────────────────────────────────────────────┘   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  requestAuthorization()                                          │
  │  ─────────────────────                                           │
  │                                                                   │
  │  notificationCenter.requestAuthorization(                        │
  │    options: [.alert, .badge, .sound]                             │
  │  ) { authorized, error in                                       │
  │    if authorized {                                               │
  │      scheduleAllReminders()  // based on user settings           │
  │    }                                                             │
  │  }                                                               │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  scheduleAllReminders()                                          │
  │  ───────────────────────                                         │
  │                                                                   │
  │  if UserDefaults.doseReminderEnabled:                            │
  │    configureDoseReminder(hour: doseReminderHour,                 │
  │                          minute: doseReminderMinute)              │
  │                                                                   │
  │  if UserDefaults.journalReminderEnabled:                        │
  │    configureJournalReminder(hour: journalReminderHour,           │
  │                            minute: journalReminderMinute)         │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  configureDoseReminder(hour: Int, minute: Int)                   │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  let content = UNMutableNotificationContent()                    │
  │  content.title = "Time for your dose"                            │
  │  content.body = "Don't forget to record your medication"         │
  │  content.sound = .default                                         │
  │  content.categoryIdentifier = "DOSE_REMINDER"                    │
  │                                                                   │
  │  var components = DateComponents()                               │
  │  components.hour = hour                                          │
  │  components.minute = minute                                      │
  │                                                                   │
  │  let trigger = UNCalendarNotificationTrigger(                   │
  │    dateMatching: components,                                     │
  │    repeats: true  // daily                                       │
  │  )                                                               │
  │                                                                   │
  │  let request = UNNotificationRequest(                           │
  │    identifier: "dose_reminder",                                  │
  │    content: content,                                             │
  │    trigger: trigger                                             │
  │  )                                                               │
  │                                                                   │
  │  notificationCenter.add(request)                                 │
  └──────────────────────────────────────────────────────────────────┘
```

---

## PHASE 9: DATA PERSISTENCE LAYER

### 9.1 Encrypted Storage Pipeline

```
┌────────────────────────────────────────────────────────────────────────┐
│              ENCRYPTED STORAGE PIPELINE (MedicationManager)            │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  SELECTION PERSISTENCE                                           │
  │  ─────────────────────                                           │
  │                                                                   │
  │  persistSelection():                                             │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Serialize:                                            │   │
  │  │    str = "\(medication)|\(method)"                        │   │
  │  │    e.g., "Estrogen|Injectable"                           │   │
  │  │                                                           │   │
  │  │ 2. Encode to Data:                                      │   │
  │  │    data = str.data(using: .utf8)                         │   │
  │  │                                                           │   │
  │  │ 3. Encrypt with SecurityManager:                        │   │
  │  │    encrypted = security.encryptData(data)               │   │
  │  │                                                           │   │
  │  │ 4. Store in UserDefaults:                               │   │
  │  │    defaults.set(encrypted, forKey:                      │   │
  │  │      "encryptedMedicationSelection")                     │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  loadSelection():                                                │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Read from UserDefaults:                               │   │
  │  │    data = defaults.data(forKey: "encrypted...")          │   │
  │  │                                                           │   │
  │  │ 2. Decrypt:                                              │   │
  │  │    decrypted = security.decryptData(data)                │   │
  │  │                                                           │   │
  │  │ 3. Parse:                                                │   │
  │  │    parts = decrypted.split(by: "|")                      │   │
  │  │    selectedMedication = parts[0]                          │   │
  │  │    selectedAdministrationMethod = parts[1]               │   │
  │  │                                                           │   │
  │  │ 4. Fallback: If no encrypted key,                        │   │
  │  │    read plain UserDefaults keys                          │   │
  │  └──────────────────────────────────────────────────────────┘   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  DOSE DATES PERSISTENCE                                          │
  │  ─────────────────────────                                       │
  │                                                                   │
  │  persistDoseDates():                                             │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Wrap in Codable container:                             │   │
  │  │    DoseDatesContainer(                                   │   │
  │  │      lastDoseDate, nextDoseDate, hrtStartDate            │   │
  │  │    )                                                      │   │
  │  │                                                           │   │
  │  │ 2. Encode to JSON:                                       │   │
  │  │    data = JSONEncoder().encode(container)                │   │
  │  │                                                           │   │
  │  │ 3. Encrypt:                                              │   │
  │  │    encrypted = security.encryptData(data)                │   │
  │  │                                                           │   │
  │  │ 4. Store:                                                │   │
  │  │    defaults.set(encrypted, forKey:                      │   │
  │  │      "encryptedDoseDates")                               │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  loadDoseDates():                                                │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Read + Decrypt                                        │   │
  │  │ 2. JSONDecode → DoseDatesContainer                       │   │
  │  │ 3. Restore:                                              │   │
  │  │    lastDoseDate = container.lastDoseDate                 │   │
  │  │    nextDoseDate = container.nextDoseDate                 │   │
  │  │    hrtStartDate = container.hrtStartDate                 │   │
  │  └──────────────────────────────────────────────────────────┘   │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  DOSE HISTORY PERSISTENCE (SwiftData)                            │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  addDose():                                                      │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Create DoseRecord(id, doseDate, type, ester,         │   │
  │  │                       method, doseAmount, notes)         │   │
  │  │                                                           │   │
  │  │ 2. Append to in-memory doseHistory                       │   │
  │  │                                                           │   │
  │  │ 3. Insert into SwiftData:                                │   │
  │  │    modelContext?.insert(record)                          │   │
  │  │                                                           │   │
  │  │ 4. Save context:                                         │   │
  │  │    try? modelContext?.save()                             │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  loadDoseHistory():                                              │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. FetchDescriptor<DoseRecord>(sortBy: [doseDate ASC])   │   │
  │  │                                                           │   │
  │  │ 2. Fetch from SwiftData:                                 │   │
  │  │    allRecords = try? context.fetch(fetchDescriptor)      │   │
  │  │                                                           │   │
  │  │ 3. Filter out soft-deleted:                              │   │
  │  │    doseHistory = allRecords.filter { !$0.isDeleted }     │   │
  │  └──────────────────────────────────────────────────────────┘   │
  │                                                                   │
  │  removeDose(withId id: String):                                  │
  │  ┌──────────────────────────────────────────────────────────┐   │
  │  │ 1. Find index by id                                      │   │
  │  │                                                           │   │
  │  │ 2. Soft delete (HIPAA-friendly audit):                   │   │
  │  │    doseHistory[index].isDeleted = true                   │   │
  │  │                                                           │   │
  │  │ 3. DO NOT remove from array or SwiftData                 │   │
  │  │    (keeps audit trail)                                   │   │
  │  │                                                           │   │
  │  │ 4. Save context                                          │   │
  │  └──────────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────────────┘
```

### 9.2 Data Model Relationship Map

```
┌────────────────────────────────────────────────────────────────────┐
│                  SWIFT DATA MODEL RELATIONSHIPS                      │
└────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │                     MODEL CONTAINER                          │
  │                                                              │
  │  ┌──────────────────┐    ┌──────────────────┐               │
  │  │  DoseRecord      │    │ JournalEntry     │               │
  │  │  ────────────    │    │ ────────────     │               │
  │  │ id: UUID/String  │    │ id: UUID         │               │
  │  │ doseDate: Date   │    │ date: Date       │               │
  │  │ medicationType:  │    │ mood: Mood       │               │
  │  │   String         │    │ text: String     │               │
  │  │ ester: String    │    │ symptoms:        │               │
  │  │ administration   │    │   Set<Symptom>   │               │
  │  │   method: String │    └──────────────────┘               │
  │  │ doseAmount:      │            (independent model)         │
  │  │   Double         │                                       │
  │  │ notes: String?   │                                       │
  │  │ isDeleted: Bool  │                                       │
  │  └──────────────────┘                                       │
  │                                                              │
  │  Both models persist in the same SwiftData ModelContainer.  │
  │  No explicit relationships/foreign keys between them.       │
  │  Cross-referenced via date (dose date ↔ journal date).      │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │              UserDefaults Keys (Plain/Encrypted)             │
  │                                                              │
  │  ┌────────────────────────────────────────────────────────┐ │
  │  │ MEDICATION SELECTION                                   │ │
  │  │ ──────────────────                                     │ │
  │  │ Plain:                                                  │ │
  │  │   selectedMedication (String)                           │ │
  │  │   selectedAdministrationMethod (String)                │ │
  │  │ Encrypted:                                              │ │
  │  │   encryptedMedicationSelection (Data)                  │ │
  │  └────────────────────────────────────────────────────────┘ │
  │                                                              │
  │  ┌────────────────────────────────────────────────────────┐ │
  │  │ DOSE DATES                                             │ │
  │  │ ──────────────                                         │ │
  │  │ Encrypted:                                              │ │
  │  │   encryptedDoseDates (Data) → DoseDatesContainer       │ │
  │  │   Contains: lastDoseDate, nextDoseDate, hrtStartDate   │ │
  │  └────────────────────────────────────────────────────────┘ │
  │                                                              │
  │  ┌────────────────────────────────────────────────────────┐ │
  │  │ NOTIFICATIONS                                          │ │
  │  │ ──────────────                                         │ │
  │  │   doseReminderEnabled (Bool)                           │ │
  │  │   doseReminderHour (Int)                               │ │
  │  │   doseReminderMinute (Int)                             │ │
  │  │   journalReminderEnabled (Bool)                        │ │
  │  │   journalReminderHour (Int)                            │ │
  │  │   journalReminderMinute (Int)                          │ │
  │  └────────────────────────────────────────────────────────┘ │
  │                                                              │
  │  ┌────────────────────────────────────────────────────────┐ │
  │  │ SECURITY                                               │ │
  │  │ ────────                                               │ │
  │  │   hasCompletedOnboarding (Bool)                        │ │
  │  │   requireAuthentication (Bool)                         │ │
  │  │   autoLockTimeout (Int - minutes)                      │ │
  │  │   allowPasscodeFallback (Bool)                         │ │
  │  └────────────────────────────────────────────────────────┘ │
  └──────────────────────────────────────────────────────────────┘
```

---

## PHASE 10: ANALYTICS & INSIGHTS GENERATION

### 10.1 Months on HRT & Streak Calculation

```
┌────────────────────────────────────────────────────────────────────────┐
│              ANALYTICS COMPUTATION PIPELINE                             │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  monthsOnHRT: Int (computed property)                            │
  │  ───────────────────────────────────                               │
  │                                                                   │
  │  1. Determine reference date:                                    │
  │     referenceDate = hrtStartDate ?? lastDoseDate                  │
  │                                                                   │
  │     Priority:                                                     │
  │     • hrtStartDate: User explicitly set their HRT start date     │
  │       (e.g., "I've been on it for 24 months")                    │
  │     • lastDoseDate: First dose logged in the app                 │
  │       (fallback for new users who selected "just starting"      │
  │       or didn't set history)                                     │
  │                                                                   │
  │  2. Calculate month difference:                                  │
  │     first = referenceDate                                         │
  │     months = Calendar.current.dateComponents(                    │
  │       [.month], from: first, to: Date()                          │
  │     ).month ?? 0                                                 │
  │                                                                   │
  │  3. Clamp to non-negative:                                       │
  │     return max(0, months)                                         │
  │                                                                   │
  │  Display contexts:                                               │
  │  • BloomView: "Month 3 · Week 2" header                          │
  │  • SettingsView: "3 mo on HRT" stat card                         │
  │  • Milestone tracking (3mo, 6mo, 1yr, 5yr)                      │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  currentStreakDays: Int? (computed property)                     │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  guard let last = lastDoseDate                                   │
  │                                                                   │
  │  days = Calendar.current.dateComponents(                         │
  │    [.day], from: last, to: Date()                                │
  │  ).day ?? 0                                                      │
  │                                                                   │
  │  return max(0, days)  // 0 = dose taken today                   │
  │                                                                   │
  │  Note: This is a simple "days since last dose" metric,          │
  │  not a true streak (doesn't handle missed doses).               │
  │  A real streak would require checking all intermediate dates.   │
  └──────────────────────────────────────────────────────────────────┘

### 10.2 Insight Generation (Home View)

```
┌────────────────────────────────────────────────────────────────────────┐
│              HOME VIEW INSIGHT ROW GENERATION                          │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  Insight row content determined by:                              │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  1. currentHormoneLevel.range                                    │
  │     ┌────────────┬──────────────────────────────────────────┐   │
  │     │ Range      │ Insight Text                             │   │
  │     ├────────────┼──────────────────────────────────────────┤   │
  │     │ Optimal    │ "Great! Your hormone levels are in       │   │
  │     │            │  optimal range."                         │   │
  │     ├────────────┼──────────────────────────────────────────┤   │
  │     │ High       │ "Your levels are elevated. Monitor for   │   │
  │     │            │  side effects."                          │   │
  │     ├────────────┼──────────────────────────────────────────┤   │
  │     │ Low/Very   │ "Your levels are below target.          │   │
  │     │ Low        │  Consider discussing dosage with        │   │
  │     │            │  your provider."                         │   │
  │     └────────────┴──────────────────────────────────────────┘   │
  │                                                                   │
  │  2. hasMissedDose                                                │
  │     If true: Insight row replaced by missed dose prompt         │
  │                                                                   │
  │  3. lastEntry (today's journal)                                  │
  │     If exists: Journal row shows entry preview + new button     │
  │     If nil: Journal row shows "new entry…" button               │
  └──────────────────────────────────────────────────────────────────┘
```

### 10.3 Milestone & Coming Up Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│              MILESTONE TRACKING (BloomView / "Time" Tab)               │
└────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │  BloomView Milestone Generation                                  │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  Input: monthsOnHRT                                              │
  │                                                                   │
  │  Milestone definitions:                                          │
  │  ┌────────────────┬──────────────────┬──────────────────────┐   │
  │  │ Milestone      │ Trigger          │ Content              │   │
  │  ├────────────────┼──────────────────┼──────────────────────┤   │
  │  │ 1 Month        │ monthsOnHRT >= 1 │ "First month       │   │
  │  │                │                  │  complete!"          │   │
  │  ├────────────────┼──────────────────┼──────────────────────┤   │
  │  │ 3 Month        │ monthsOnHRT >= 3 │ "Schedule blood    │   │
  │  │ Check-in       │                  │  work"              │   │
  │  ├────────────────┼──────────────────┼──────────────────────┤   │
  │  │ 6 Month        │ monthsOnHRT >= 6 │ "Expected changes: │   │
  │  │                │                  │  voice changes..."  │   │
  │  ├────────────────┼──────────────────┼──────────────────────┤   │
  │  │ 1 Year         │ monthsOnHRT >= 12│ "One year!        │   │
  │  │                │                  │  Full assessment"   │   │
  │  ├────────────────┼──────────────────┼──────────────────────┤   │
  │  │ 5 Years        │ monthsOnHRT >= 60│ "Long-term HRT     │   │
  │  │                │                  │  milestone"         │   │
  │  └────────────────┴──────────────────┴──────────────────────┘   │
  │                                                                   │
  │  Display Logic:                                                  │
  │  • Milestones < current shown as "completed" (checkmark)        │
  │  • Next milestone shown as "coming up" with countdown            │
  │  • Future milestones shown as locked/grayed                      │
  └──────────────┬───────────────────────────────────────────────────┘
                 │
                 ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  BODY SYSTEM PROGRESS TRACKING                                   │
  │  ──────────────────────────────────────────────────────────────  │
  │                                                                   │
  │  System progress is mapped to monthsOnHRT:                       │
  │  ┌────────────┬────────┬──────────────────────────────────┐     │
  │  │ System     │ Max    │ Progression (months 0→max)      │     │
  │  ├────────────┼────────┼──────────────────────────────────┤     │
  │  │ Brain &    │  5     │ Cognition, mood, clarity        │     │
  │  │ Cognition  │ months │                                  │     │
  │  ├────────────┼────────┼──────────────────────────────────┤     │
  │  │ Skin &     │  5     │ Softening, texture, hair        │     │
  │  │ Hair       │ months │                                  │     │
  │  ├────────────┼────────┼──────────────────────────────────┤     │
  │  │ Body       │  12    │ Fat redistribution, muscle      │     │
  │  │ Composition│ months │                                  │     │
  │  ├────────────┼────────┼──────────────────────────────────┤     │
  │  │ Facial     │  24    │ Soft tissue changes, bone (limited)│   │
  │  │ Changes    │ months │                                  │     │
  │  ├────────────┼────────┼──────────────────────────────────┤     │
  │  │ Voice      │  12    │ Changes (if no surgery)         │     │
  │  │ Changes    │ months │                                  │     │
  │  └────────────┴────────┴──────────────────────────────────┘     │
  │                                                                   │
  │  Progress calculation:                                           │
  │  progress = min(1.0, monthsOnHRT / maxMonths)                    │
  │  status: progress < 0.3 → "Early stages"                         │
  │         progress < 0.7 → "In progress"                           │
  │         progress ≥ 0.7 → "Noticeable changes"                    │
  └──────────────────────────────────────────────────────────────────┘
```

---

## COMPLETE SYSTEM ARCHITECTURE DIAGRAM

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        xT HORMONE SYSTEM - ARCHITECTURE OVERVIEW              │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │                        PRESENTATION LAYER (SwiftUI)                   │
  │                                                                      │
  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
  │  │ HomeView │  │Journal   │  │ BloomView│  │Settings  │            │
  │  │          │  │ View     │  │          │  │ View     │            │
  │  │• Hero    │  │• Timeline│  │• Progress│  │• Profile │            │
  │  │• Graph   │  │• Compose │  │• Milesto.│  │• Med info│            │
  │  │• Insights│  │• Details │  │• Changes │  │• Notifs  │            │
  │  │• Actions │  └──────────┘  └──────────┘  │• Security│            │
  │  └────┬─────┘                         └────┬───┘        │
  │       │                                     │            │
  └───────┼─────────────────────────────────────┼────────────┘
          │                                     │
          │     Environment Objects             │
          ▼                                     ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                      VIEW MODEL LAYER (@MainActor)                    │
  │                                                                      │
  │  ┌──────────────────┐  ┌──────────────────┐                         │
  │  │ MedicationManager│  │ JournalManager   │                         │
  │  │ ───────────      │  │ ──────────       │                         │
  │  │ @Published:      │  │ var entries:     │                         │
  │  │  doseHistory     │  │   [JournalEntry] │                         │
  │  │  lastDoseDate    │  │ currentMood:     │                         │
  │  │  nextDoseDate    │  │   Mood           │                         │
  │  │  currentLevel:   │  │ currentSymptoms: │                         │
  │  │   Tuple?         │  │   Set<Symptom>   │                         │
  │  │  recentLevels:   │  └──────────────────┘                         │
  │  │   [Point]        │                                              │
  │  └────────┬─────────┘                                              │
  │           │                                                        │
  │           │ Method Calls:                                          │
  │           │ • addDose()        • createNewEntry()                  │
  │           │ • recordDose()     • addEntry()                        │
  │           │ • updateSelection()                                   │
  │           └──────────────────────────────────────────────────────┘
  │                                    │
  │                                    ▼
  │  ┌────────────────────────────────────────────────────────────┐
  │  │                  RESEARCH ENGINE (PK Model)                 │
  │  │  ────────────────────────────────────────────────────────  │
  │  │                                                             │
  │  │  estimatedLevels():                                         │
  │  │  ├─ Resolve ester & half-life                              │
  │  │  ├─ Build dose events from history                         │
  │  │  ├─ Apply potency factors                                  │
  │  │  ├─ Compute λ = ln(2) / t½                                │
  │  │  ├─ Iterate time cursor                                    │
  │  │  └─ Return [EstimatedPoint]                                │
  │  │                                                             │
  │  │  getCurrentHormoneLevel():                                  │
  │  │  ├─ Sample recent levels                                   │
  │  │  ├─ Determine range (estrogen vs testosterone)             │
  │  │  └─ Generate explanation                                   │
  │  └────────────────────────────────────────────────────────────┘
  │                                    │
  └────────────────────────────────────┼─────────────────────────────┘
                                       │
                                       ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                       PERSISTENCE LAYER                               │
  │                                                                      │
  │  ┌────────────────────────┐  ┌────────────────────────┐             │
  │  │     SwiftData          │  │    UserDefaults        │             │
  │  │  ───────────           │  │    ──────────          │             │
  │  │  • DoseRecord         │  │  • Medication selection│             │
  │  │  • JournalEntry       │  │  • Dose dates (encrypted)│           │
  │  │  • UserPreferences    │  │  • Notification prefs  │             │
  │  │                        │  │  • Security settings   │             │
  │  │  Operations:           │  │  • Onboarding status   │             │
  │  │  • insert()            │  │                        │             │
  │  │  • fetch()             │  │  Operations:          │             │
  │  │  • delete()            │  │  • set() (encrypted)  │             │
  │  │                        │  │  • get() (decrypt)    │             │
  │  └────────────────────────┘  └────────────────────────┘             │
  │                                                                      │
  │  ┌────────────────────────┐                                         │
  │  │  SecurityManager       │                                         │
  │  │  ─────────────         │                                         │
  │  │  • encryptData()       │                                         │
  │  │  • decryptData()       │                                         │
  │  └────────────────────────┘                                         │
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │                       EXTERNAL SERVICES                               │
  │                                                                      │
  │  ┌────────────────────────┐  ┌────────────────────────┐             │
  │  │ UNUserNotificationCenter│  │ LAContext (Biometric) │             │
  │  │ (Notifications)        │  │ (Face ID / Touch ID)  │             │
  │  │ • Dose reminders       │  │                        │             │
  │  │ • Journal reminders    │  │ • Authentication       │             │
  │  └────────────────────────┘  └────────────────────────┘             │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## DATA FLOW SUMMARY: END-TO-END USER JOURNEY

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE END-TO-END DATA FLOW                              │
└──────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │  USER ACTIONS                    →  SYSTEM RESPONSES                  │
  └──────────────────────────────────────────────────────────────────────┘

  1. User installs & launches app
     → App initializes ModelContainer, Managers
     → OnboardingView displays (first launch)

  2. User completes onboarding:
     a) Welcome screen → tap Begin
     b) Features overview → tap Continue
     c) Optional profile → tap Continue
     d) Medication setup:
        → Select Estrogen
        → Select Injectable
        → Select Valerate (EV)
        → Enter 2.0 mg
        → Select "Just starting"
        → Tap "You're all set"

  3. System processes medication setup:
     → addDose(date, type, ester, method, amount)
     → DoseRecord created & saved to SwiftData
     → lastDoseDate = now, nextDoseDate = now+7d
     → persistSelection() → encrypted UserDefaults
     → refreshState() → compute hormone levels
     → currentHormoneLevel = (150.00, "pg/mL", "Optimal", "...")
     → recentLevels = [EstimatedPoint, ...] (7-day history)
     → hasCompletedOnboarding = true
     → Navigate to MainTabView (Home)

  4. HomeView renders:
     → HeroView displays: "Hello, Starla!", level 150 pg/mL [Optimal]
     → FlatGraphView renders: recentLevels line chart
     → MainContentView shows:
        • Insight: "Great! Your hormone levels are in optimal range."
        • Journal: "new entry…" button
        • Next dose: "Tomorrow · Mon, Jan 16"
        • Cycle progress: [●○○○○○○]

  5. User records dose (7 days later):
     → Notification triggers: "Time for your dose"
     → User taps notification → app opens
     → MedicationManager.recordDose() called
     → lastDoseDate = now, nextDoseDate = now+7d
     → refreshState() → cascade update
     → Graph shows new spike at current time
     → Level assessment recomputed
     → Next dose date updated

  6. User creates journal entry:
     → Tap "new entry…" → JournalComposerView opens
     → Select mood: 😊 Happy
     → Type: "Feeling great today!"
     → Select symptoms: [skin changes] [energy boost]
     → Tap Save
     → JournalEntry created & saved to SwiftData
     → entries array updated
     → JournalView timeline shows new entry

  7. UI reflects all changes:
     → @Published properties trigger SwiftUI reactivity
     → All views that depend on MedicationManager re-render
     → All views that depend on JournalManager re-render
     → User sees synchronized, real-time state
```

---

## APPENDIX: KEY MATHEMATICAL FORMULAS

```
┌────────────────────────────────────────────────────────────────────┐
│                    PHARMACOKINETIC FORMULAS                          │
└────────────────────────────────────────────────────────────────────┘

  1. EXPOENTIAL DECAY (Core PK Equation)
     ───────────────────────────────────
     C_spike(t) = D × potency × e^(-λ × t)

     Where:
       D    = dose amount (mg)
       potency = ester potency factor
       λ    = decay constant (ln(2) / halfLifeDays)
       t    = time elapsed since dose (days)

  2. DOSE STACKING (Multiple Doses)
     ───────────────────────
     C_total(t) = C_base + Σ C_spike_i(t)
                = C_base + Σ [D_i × p_i × e^(-λ × (t - t_i))]

     Summation over all previous active doses i where t_i ≤ t

  3. HALF-LIFE RELATIONSHIP
     ──────────────────────
     λ = ln(2) / t½
     t½ = ln(2) / λ ≈ 0.693 / λ

     t½ = time for concentration to halve

  4. BASELINE VALUES
     ────────────────
     Estrogen:  C_base = 100 pg/mL (endogenous baseline)
     Testosterone: C_base = 500 ng/dL (endogenous baseline)

  5. POTENCY ADJUSTMENT
     ─────────────────
     effectiveAmount = doseAmount × potencyFactor

     EC esters are ~25% less potent per mg than EV
     Oral esters have significant first-pass metabolism (50% loss)

  6. MONTHS ON HRT
     ──────────────
     months = Calendar.current.dateComponents(
       [.month], from: hrtStartDate, to: Date()
     ).month ?? 0

  7. NEXT DOSE DATE
     ──────────────
     nextDoseDate = Calendar.current.date(
       byAdding: .day,
       value: frequencyDays,
       to: lastDoseDate
     )

  8. MISSED DOSE DETECTION
     ─────────────────────
     hasMissed = Date() > nextDoseDate

  9. HORMONE RANGE CLASSIFICATION
     ────────────────────────────
     rangeInfo = ranges.first { value >= min && value < max }

     Ranges differ by medication type:
     • Estrogen: pg/mL (100-200 = Optimal)
     • Testosterone: ng/dL (<50 = Suppressed)
```

---

*Document generated for xT hormone tracking application*
*Version 1.0.0*
*Based on MedicationManager.swift, JournalManager.swift, DoseRecord.swift, JournalModels.swift*