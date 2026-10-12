//
//  SpoofProfile.swift
//  xT
//
//  DEBUG-only comprehensive spoof profiles.
//  Applied only when the Developer Area's Sample toggle is enabled
//  (Settings → Developer). Populates all singleton managers with realistic
//  data so every preview and view in the app renders content. The user's
//  real data is snapshotted/restored around it by ProfileSnapshot.
//
//  Multi-persona system (2026-08-04): supports 8 personas selectable via
//  DeveloperSettings.activePersonaIndex. Jan is the original sample profile;
//  the other 7 correspond to the UX paper's persona journeys (Section 5).
//

#if DEBUG

import SwiftUI
import SwiftData

// MARK: - Persona Enum

/// Each case maps to a specific persona with a complete regimen configuration.
/// The rawValue is the index in `DeveloperSettings.personaNames`.
enum SpoofPersona: Int, CaseIterable {
    case jan    = 0
    case maya   = 1
    case devon  = 2
    case priya  = 3
    case sam    = 4
    case rowan  = 5
    case jules  = 6
    case nadia  = 7

}

// MARK: - Entry Point

/// Centralized spoof-data generator. Dispatches to the persona selected in
/// DeveloperSettings.
enum SpoofProfile {

    // MARK: - Entry Point

    /// Call once at app launch (or from a #Preview .task) to seed all managers.
    /// Idempotent — checks a UserDefaults flag to avoid repeated population.
    @MainActor
    static func applyIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: spfKey) else { return }

        let persona = SpoofPersona(rawValue: DeveloperSettings.shared.activePersonaIndex) ?? .jan
        resetAllManagers()
        populateProfile(for: persona)
        populateMedication(for: persona)
        populateJournal(for: persona)
        populateNotifications()

        UserDefaults.standard.set(true, forKey: spfKey)
    }

    /// Force re-apply even if already applied (useful during development).
    @MainActor
    static func forceApply() {
        UserDefaults.standard.removeObject(forKey: spfKey)
        applyIfNeeded()
    }

    // MARK: - Private Constants

    /// Internal (not private) so `ProfileSnapshot` and the Settings reset can
    /// reference the marker instead of re-hardcoding the string.
    static let spfKey = "com.xt.spoofProfile_jan_v1"

    /// Reference "now" for deterministic dose generation.
    private static var today: Date { Calendar.current.startOfDay(for: Date()) }

    private static func hrtStartDate(monthsAgo: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -monthsAgo, to: today) ?? today
    }

    // MARK: - Reset

    @MainActor
    private static func resetAllManagers() {
        DatasetReset.resetManagerState()

        // Clear persisted dose dates
        UserDefaults.standard.removeObject(forKey: "lastDoseDate")
        UserDefaults.standard.removeObject(forKey: "nextDoseDate")
        UserDefaults.standard.removeObject(forKey: "selectedMedication")
        UserDefaults.standard.removeObject(forKey: "selectedAdministrationMethod")
        UserDefaults.standard.removeObject(forKey: "hasSeenRecommendedZonesInfo")

        // Remove all SwiftData records
        if let ctx = MedicationManager.shared.modelContext {
            do {
                try DatasetReset.wipeSwiftData(in: ctx)
            } catch {
                print("[SpoofProfile] reset SwiftData error: \(error)")
            }
        }

        // --- Notifications: clear UserDefaults keys ---
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: NotificationManager.Keys.doseReminderEnabled)
        defaults.removeObject(forKey: NotificationManager.Keys.journalReminderEnabled)
        defaults.removeObject(forKey: NotificationManager.Keys.doseReminderHour)
        defaults.removeObject(forKey: NotificationManager.Keys.doseReminderMinute)
        defaults.removeObject(forKey: NotificationManager.Keys.journalReminderHour)
        defaults.removeObject(forKey: NotificationManager.Keys.journalReminderMinute)
    }

    // MARK: - Profile Population (per persona)

    @MainActor
    private static func populateProfile(for persona: SpoofPersona) {
        let pm = ProfileManager.shared
        let (name, _) = personaNameAndColor(for: persona)
        pm.profileName = name

        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let (_, colors) = personaNameAndColor(for: persona)
            let cgColors = colors.map { $0.cgColor }
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: cgColors as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            let initial = String(name.prefix(1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 90, weight: .medium),
                .foregroundColor: UIColor.white,
            ]
            let textSize = initial.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            initial.draw(in: textRect, withAttributes: attrs)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            pm.profileImageData = jpegData
            pm.profileImage = image
        }
        pm.persistProfile()
    }

    /// Returns (name, gradientColors) for each persona's avatar.
    private static func personaNameAndColor(for persona: SpoofPersona) -> (String, [UIColor]) {
        switch persona {
        case .jan:   return ("Jan",   [UIColor(red: 0.20, green: 0.78, blue: 0.78, alpha: 1.0),
                                        UIColor(red: 0.60, green: 0.40, blue: 0.90, alpha: 1.0)])
        case .maya:  return ("Maya",  [UIColor(red: 0.83, green: 0.33, blue: 0.49, alpha: 1.0),
                                        UIColor(red: 0.53, green: 0.29, blue: 0.72, alpha: 1.0)])
        case .devon: return ("Devon", [UIColor(red: 0.13, green: 0.55, blue: 0.75, alpha: 1.0),
                                        UIColor(red: 0.25, green: 0.40, blue: 0.65, alpha: 1.0)])
        case .priya: return ("Priya", [UIColor(red: 0.90, green: 0.45, blue: 0.20, alpha: 1.0),
                                        UIColor(red: 0.75, green: 0.25, blue: 0.40, alpha: 1.0)])
        case .sam:   return ("Sam",   [UIColor(red: 0.23, green: 0.68, blue: 0.43, alpha: 1.0),
                                        UIColor(red: 0.15, green: 0.50, blue: 0.55, alpha: 1.0)])
        case .rowan: return ("Rowan", [UIColor(red: 0.55, green: 0.35, blue: 0.70, alpha: 1.0),
                                        UIColor(red: 0.40, green: 0.25, blue: 0.55, alpha: 1.0)])
        case .jules: return ("Jules", [UIColor(red: 0.85, green: 0.60, blue: 0.15, alpha: 1.0),
                                        UIColor(red: 0.70, green: 0.35, blue: 0.20, alpha: 1.0)])
        case .nadia: return ("Nadia", [UIColor(red: 0.30, green: 0.55, blue: 0.65, alpha: 1.0),
                                        UIColor(red: 0.20, green: 0.40, blue: 0.50, alpha: 1.0)])
        }
    }

    // MARK: - Medication Population (per persona)

    @MainActor
    private static func populateMedication(for persona: SpoofPersona) {
        switch persona {
        case .jan:   populateJanMedication()
        case .maya:  populateMayaMedication()
        case .devon: populateDevonMedication()
        case .priya: populatePriyaMedication()
        case .sam:   populateSamMedication()
        case .rowan: populateRowanMedication()
        case .jules: populateJulesMedication()
        case .nadia: populateNadiaMedication()
        }
    }

    // MARK: Jan (original sample)

    @MainActor
    private static func populateJanMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 18)

        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Injectable"
        mm.hrtStartDate = startDate
        mm.antiAndrogenInUse = true
        mm.spironolactoneInUse = true
        mm.spironolactoneClearanceEnabled = true
        mm.suppressionSpeed = .fast
        mm.customFrequencyDays = 5
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        mm.performBatch {
            var doseDate = startDate
            var doseCount = 0
            while doseDate <= today {
                let doseAmount = Double.random(in: 4.5...5.5)
                if doseCount > 10 && Double.random(in: 0...1) < 0.05 {
                    mm.addDose(date: doseDate, type: "Estrogen", ester: "Valerate (EV)",
                               method: "Injectable", doseAmount: doseAmount,
                               concentrationMgPerMl: 20.0, notes: nil)
                    mm.skipDose(on: doseDate, reason: "Forgot — took next day")
                } else {
                    mm.addDose(date: doseDate, type: "Estrogen", ester: "Valerate (EV)",
                               method: "Injectable", doseAmount: doseAmount,
                               concentrationMgPerMl: 20.0,
                               notes: doseCount == 0 ? "First injection — starting HRT! 🎉" : nil)
                }
                doseDate = calendar.date(byAdding: .day, value: 5, to: doseDate)!
                doseCount += 1
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 5, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            let bloodTests: [(monthsAfter: Int, e2: Double, notes: String)] = [
                (3,  180, "3-month baseline — good initial response"),
                (6,  230, "6-month check — levels in target range"),
                (12, 195, "12-month annual labs — consistent"),
                (16, 210, "16-month follow-up — maintaining well"),
            ]
            for test in bloodTests {
                guard let drawDate = calendar.date(byAdding: .month, value: test.monthsAfter, to: startDate)
                else { continue }
                mm.addBloodTest(drawDate: drawDate, measuredLevel: Double(test.e2),
                               hormoneType: "Estrogen", notes: test.notes)
            }
            mm.userTherapeuticTarget = .default
        }
    }

    // MARK: Maya — 4mg EV IM q7d, first-time user

    @MainActor
    private static func populateMayaMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        // Maya just started: hrtStartDate is yesterday so she has exactly 1 dose
        let startDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Injectable"
        mm.selectedEster = "Valerate (EV)"
        mm.hrtStartDate = startDate
        mm.customFrequencyDays = 7
        mm.suppressionSpeed = .fast
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        mm.performBatch {
            mm.addDose(date: startDate, type: "Estrogen", ester: "Valerate (EV)",
                       method: "Injectable", doseAmount: 4.0,
                       concentrationMgPerMl: 40.0,
                       notes: "First injection — excited to start! 🎉")

            mm.lastDoseDate = startDate
            mm.nextDoseDate = calendar.date(byAdding: .day, value: 7, to: startDate)
            mm.persistUserPreferences()

            // Maya hasn't had blood tests yet — she just started
            // She set therapeutic targets based on her doctor's guidance
            mm.userTherapeuticTarget = .default
        }
    }

    // MARK: Devon — 100mg TC q7d → 200mg TC q14d at month 6

    @MainActor
    private static func populateDevonMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 8)
        guard let switchDate = calendar.date(byAdding: .month, value: 6, to: startDate)
        else { return }

        mm.selectedMedication = "Testosterone"
        mm.selectedAdministrationMethod = "Injectable"
        mm.selectedEster = "Cypionate (TC)"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        mm.performBatch {
            // Phase 1: 100mg TC q7d (months 0–6)
            mm.customFrequencyDays = 7
            var doseDate = startDate
            var doseCount = 0
            while doseDate < switchDate {
                mm.addDose(date: doseDate, type: "Testosterone", ester: "Cypionate (TC)",
                           method: "Injectable", doseAmount: 100.0,
                           concentrationMgPerMl: 200.0,
                           notes: doseCount == 0 ? "First T injection! 💉" : nil)
                doseDate = calendar.date(byAdding: .day, value: 7, to: doseDate)!
                doseCount += 1
            }

            // Phase 2: 200mg TC q14d (months 6–8)
            mm.customFrequencyDays = 14
            doseDate = switchDate
            var phase2First = true
            while doseDate <= today {
                mm.addDose(date: doseDate, type: "Testosterone", ester: "Cypionate (TC)",
                           method: "Injectable", doseAmount: 200.0,
                           concentrationMgPerMl: 200.0,
                           notes: phase2First ? "Switched to q14d schedule — doubling interval" : nil)
                doseDate = calendar.date(byAdding: .day, value: 14, to: doseDate)!
                phase2First = false
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 14, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // Blood tests before and after switch
            if let bt1 = calendar.date(byAdding: .month, value: 3, to: startDate) {
                mm.addBloodTest(drawDate: bt1, measuredLevel: 580.0,
                               hormoneType: "Testosterone",
                               notes: "3-month check on 100mg q7d — trough 580 ng/dL")
            }
            if let bt2 = calendar.date(byAdding: .month, value: 7, to: startDate) {
                mm.addBloodTest(drawDate: bt2, measuredLevel: 520.0,
                               hormoneType: "Testosterone",
                               notes: "1mo after switching to 200mg q14d — trough 520 ng/dL")
            }

            mm.userTherapeuticTarget = MedicationManager.TherapeuticTarget(troughMin: 300, troughMax: 1000, peakCeiling: 1500)
        }
    }

    // MARK: Priya — 2mg oral E2 BID × 4mo → 4mg EV IM q7d

    @MainActor
    private static func populatePriyaMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 8)
        guard let switchDate = calendar.date(byAdding: .month, value: 4, to: startDate)
        else { return }

        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Oral"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium

        mm.performBatch {
            // Phase 1: 2mg oral E2 BID (months 0–4)
            mm.customFrequencyDays = 1
            var doseDate = startDate
            var doseCount = 0
            while doseDate < switchDate {
                // Morning dose
                let morningDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: doseDate) ?? doseDate
                mm.addDose(date: morningDate, type: "Estrogen", ester: "Oral",
                           method: "Oral", doseAmount: 2.0,
                           concentrationMgPerMl: nil,
                           notes: doseCount == 0 ? "Starting oral E2 — BID schedule" : nil)
                // Evening dose
                let eveningDate = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: doseDate) ?? doseDate
                mm.addDose(date: eveningDate, type: "Estrogen", ester: "Oral",
                           method: "Oral", doseAmount: 2.0,
                           concentrationMgPerMl: nil, notes: nil)

                doseDate = calendar.date(byAdding: .day, value: 1, to: doseDate)!
                doseCount += 1
            }

            // Phase 2: 4mg EV IM q7d (months 4–8)
            mm.selectedAdministrationMethod = "Injectable"
            mm.selectedEster = "Valerate (EV)"
            mm.customFrequencyDays = 7
            doseDate = switchDate
            var phase2First = true
            while doseDate <= today {
                mm.addDose(date: doseDate, type: "Estrogen", ester: "Valerate (EV)",
                           method: "Injectable", doseAmount: 4.0,
                           concentrationMgPerMl: 40.0,
                           notes: phase2First ? "Switched from oral to injectable EV" : nil)
                doseDate = calendar.date(byAdding: .day, value: 7, to: doseDate)!
                phase2First = false
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 7, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // Blood tests
            if let bt1 = calendar.date(byAdding: .month, value: 3, to: startDate) {
                mm.addBloodTest(drawDate: bt1, measuredLevel: 95.0,
                               hormoneType: "Estrogen",
                               notes: "3-month on oral E2 — 95 pg/mL at trough")
            }
            if let bt2 = calendar.date(byAdding: .month, value: 6, to: startDate) {
                mm.addBloodTest(drawDate: bt2, measuredLevel: 210.0,
                               hormoneType: "Estrogen",
                               notes: "2mo after switching to EV IM — levels much more stable")
            }

            mm.userTherapeuticTarget = .default
        }
    }

    // MARK: Sam — 50mg/day T gel, misses ~2 days/week

    @MainActor
    private static func populateSamMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 4)

        mm.selectedMedication = "Testosterone"
        mm.selectedAdministrationMethod = "Cream"
        mm.selectedEster = "Transdermal"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium
        mm.customFrequencyDays = 1
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        // Sam's whole point is to demonstrate the missed-dose UI, so the seed
        // must stop short of today — logging all the way through today (as this
        // used to) leaves `lastDoseDate` as today and `nextDoseDate` as tomorrow,
        // so `hasMissedDose` is false and the persona never shows what it's named for.
        let missedDoseCutoff = calendar.date(byAdding: .day, value: -5, to: today)!

        mm.performBatch {
            var doseDate = startDate
            var doseCount = 0
            // Seed for deterministic "random" missed days based on day-of-year
            while doseDate <= missedDoseCutoff {
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: doseDate) ?? 0
                // Miss ~2 days per week: skip days where dayOfYear % 7 ∈ {2, 5}
                let shouldMiss = (dayOfYear % 7 == 2 || dayOfYear % 7 == 5) && doseCount > 7

                if shouldMiss {
                    mm.addDose(date: doseDate, type: "Testosterone", ester: "Transdermal",
                               method: "Cream", doseAmount: 50.0,
                               concentrationMgPerMl: nil, notes: nil)
                    mm.skipDose(on: doseDate, reason: "Forgot — busy morning")
                } else {
                    mm.addDose(date: doseDate, type: "Testosterone", ester: "Transdermal",
                               method: "Cream", doseAmount: 50.0,
                               concentrationMgPerMl: nil,
                               notes: doseCount == 0 ? "First day on T gel! 🎉" : nil)
                }
                doseDate = calendar.date(byAdding: .day, value: 1, to: doseDate)!
                doseCount += 1
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 1, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // Sam hasn't set therapeutic targets — tests the "no user-set bounds" path
            mm.userTherapeuticTarget = nil
        }
    }

    // MARK: Rowan — 4mg/day compounded E2 cream, custom 2.5mg/mL

    @MainActor
    private static func populateRowanMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 6)

        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Cream"
        mm.selectedEster = "Transdermal"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium
        mm.customFrequencyDays = 1

        mm.performBatch {
            var doseDate = startDate
            var doseCount = 0
            while doseDate <= today {
                mm.addDose(date: doseDate, type: "Estrogen", ester: "Transdermal",
                           method: "Cream", doseAmount: 4.0,
                           concentrationMgPerMl: 2.5,  // custom compounded concentration
                           notes: doseCount == 0 ? "Starting compounded cream — custom 2.5mg/mL" : nil)
                doseDate = calendar.date(byAdding: .day, value: 1, to: doseDate)!
                doseCount += 1
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 1, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // No blood tests yet — Rowan's doctor schedules at 6-month mark
            // No therapeutic targets set — tests the "model-derived only" path
            mm.userTherapeuticTarget = nil
        }
    }

    // MARK: Jules — 100mg TE IM q7d, blood test at month 3

    @MainActor
    private static func populateJulesMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 4)

        mm.selectedMedication = "Testosterone"
        mm.selectedAdministrationMethod = "Injectable"
        mm.selectedEster = "Enanthate (TE)"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium
        mm.customFrequencyDays = 7
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        mm.performBatch {
            var doseDate = startDate
            var doseCount = 0
            while doseDate <= today {
                mm.addDose(date: doseDate, type: "Testosterone", ester: "Enanthate (TE)",
                           method: "Injectable", doseAmount: 100.0,
                           concentrationMgPerMl: 200.0,
                           notes: doseCount == 0 ? "First TE injection" : nil)
                doseDate = calendar.date(byAdding: .day, value: 7, to: doseDate)!
                doseCount += 1
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 7, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // Blood test at month 3 — the calibration anchor
            if let drawDate = calendar.date(byAdding: .month, value: 3, to: startDate) {
                // Draw taken at trough (day 6-7 of cycle), measured 680 ng/dL
                let troughDraw = calendar.date(byAdding: .day, value: 6, to: drawDate) ?? drawDate
                mm.addBloodTest(drawDate: troughDraw, measuredLevel: 680.0,
                               hormoneType: "Testosterone",
                               notes: "3-month trough draw — 680 ng/dL. Above population prediction.")
            }

            mm.userTherapeuticTarget = MedicationManager.TherapeuticTarget(troughMin: 300, troughMax: 1000, peakCeiling: 1500)
        }
    }

    // MARK: Nadia — 5mg EC IM q10d, unconventional interval

    @MainActor
    private static func populateNadiaMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current
        let startDate = hrtStartDate(monthsAgo: 12)

        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Injectable"
        mm.selectedEster = "Cypionate (EC)"
        mm.hrtStartDate = startDate
        mm.suppressionSpeed = .medium
        mm.customFrequencyDays = 10  // unconventional — EC is typically q7d
        mm.missedDoseGracePeriodHours = PKConstants.missedDoseGraceHours

        mm.performBatch {
            var doseDate = startDate
            var doseCount = 0
            while doseDate <= today {
                mm.addDose(date: doseDate, type: "Estrogen", ester: "Cypionate (EC)",
                           method: "Injectable", doseAmount: 5.0,
                           concentrationMgPerMl: 5.0,
                           notes: doseCount == 0 ? "Starting EC q10d — experimenting with longer interval" : nil)
                doseDate = calendar.date(byAdding: .day, value: 10, to: doseDate)!
                doseCount += 1
            }

            let lastTaken = mm.doseHistory.last { $0.doseStatus == DoseStatus.taken.rawValue }
            if let lastTaken {
                mm.lastDoseDate = lastTaken.doseDate
                mm.nextDoseDate = calendar.date(byAdding: .day, value: 10, to: lastTaken.doseDate)
            }
            mm.persistUserPreferences()

            // Blood tests at months 3, 6, and 12
            let bloodTests: [(monthsAfter: Int, e2: Double, notes: String)] = [
                (3,  175, "3-month on EC q10d — trough ~175 pg/mL"),
                (6,  155, "6-month — trough 155 pg/mL, lower than expected on q7d"),
                (12, 140, "12-month annual — 140 pg/mL. Interval may be too long; discussing with doctor"),
            ]
            for test in bloodTests {
                guard let drawDate = calendar.date(byAdding: .month, value: test.monthsAfter, to: startDate)
                else { continue }
                mm.addBloodTest(drawDate: drawDate, measuredLevel: Double(test.e2),
                               hormoneType: "Estrogen", notes: test.notes)
            }

            mm.userTherapeuticTarget = .default
        }
    }

    // MARK: - Journal Population (per persona)

    @MainActor
    private static func populateJournal(for persona: SpoofPersona) {
        let jm = JournalManager.shared
        guard let ctx = jm.modelContext else { return }

        let calendar = Calendar.current

        // Spread entry times across the four day periods so morning/afternoon/evening/night
        // are all represented, instead of every entry landing at midnight (J12).
        let periodHours = [8, 13, 18, 22]

        let templates = journalTemplates(for: persona)
        for (index, template) in templates.enumerated() {
            let (daysAgo, mood, symptomNames, text) = template
            guard let dayStart = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let hour = periodHours[(index + daysAgo) % periodHours.count]
            let minute = (text.count * 7) % 60
            let entryDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
            // Match seed symptom names case-insensitively — template names are Title-case,
            // the common palette is lowercase, so a literal lookup dropped them all (J12).
            let symptomList = symptomNames.compactMap { Symptom.matching(name: $0) }
            let entry = JournalEntry(
                id: UUID(), date: entryDate, mood: mood, text: text, symptoms: symptomList)
            ctx.insert(entry)
        }

        do {
            try ctx.save()
            jm.loadEntries()
        } catch {
            print("[SpoofProfile] populateJournal save failed: \(error)")
        }
    }

    /// Returns (daysAgo, mood, [symptomNames], text) for a persona's journal entries.
    private static func journalTemplates(for persona: SpoofPersona) -> [(Int, Mood, [String], String)] {
        typealias T = (Int, Mood, [String], String)
        switch persona {
        case .jan:
            return janJournalTemplates()
        case .maya:
            return [
                (1, .happy,     ["Energy boost"],
                 "Started HRT yesterday! The injection went way smoother than I expected. Barely felt it. I know it's too early for any real changes but I'm feeling so hopeful."),
                (0, .calm,      [],
                 "Just tracking today. Reading about other people's experiences with EV. The graph on the home screen is already showing my first dose curve — it's wild to see it visualized."),
            ]
        case .devon:
            return [
                (240, .energetic, ["Energy boost"],
                 "First T injection! I was nervous about doing it myself but it was actually fine. Can't wait to see changes start."),
                (200, .happy,     ["Energy boost"],
                 "Voice is starting to feel a little scratchy? Could be in my head but I'll take it. Energy is definitely up."),
                (160, .neutral,   ["Skin changes"],
                 "Skin is getting oilier for sure. Had to switch my face wash. Small price to pay."),
                (120, .calm,      [],
                 "Things feel stable. Weekly injections are just part of the routine now."),
                (90,  .anxious,   ["Mood swings"],
                 "Doctor wants to switch me to every 2 weeks at double the dose. I'm worried the trough will be rough. Going to try it."),
                (60,  .neutral,   [],
                 "First 200mg q14d injection today. Feels weird not injecting next week. Trusting the process."),
                (40,  .tired,     ["Fatigue"],
                 "Day 12 of the 14-day cycle and I can feel it. Energy dipped yesterday. The graph shows my trough is lower but still in range."),
                (20,  .happy,     ["Energy boost"],
                 "Got my 7-month labs back — trough at 520. Right where the model predicted after the switch. Feeling validated."),
                (7,   .energetic, [],
                 "Hit the gym hard today. The longer interval took adjusting but my levels are stable and I feel good."),
                (1,   .calm,      [],
                 "Did my injection today. The 14-day schedule is working out — fewer injections, same results. Glad I switched."),
            ]
        case .priya:
            return [
                (240, .happy,     [],
                 "Started oral E2 today! BID schedule is a bit annoying but I'm just happy to finally be starting."),
                (200, .neutral,   ["Nausea"],
                 "Mild nausea after the morning dose. Taking it with food helps. Doctor says it should pass."),
                (160, .tired,     ["Fatigue", "Mood swings"],
                 "Energy dips between doses are real. I can feel when it's wearing off. Counting down to my evening pill."),
                (130, .anxious,   ["Mood swings"],
                 "Had a rough day. The BID rollercoaster is getting to me. Doctor suggested switching to injections."),
                (120, .happy,     [],
                 "First EV injection today! Nervous about needles but the nurse showed me how. 7 days between doses sounds like freedom."),
                (95,  .energetic, ["Energy boost"],
                 "Week 3 on injections and WOW what a difference. No more twice-daily pill anxiety. Levels feel so much smoother."),
                (70,  .happy,     ["Skin changes"],
                 "Got my labs back after the switch — E2 at 210! Way more stable than the oral numbers. My skin is glowing."),
                (40,  .calm,      [],
                 "Can't believe I waited 4 months to switch. Injections are easier than I thought and the stability is night and day."),
                (14,  .happy,     ["Energy boost", "Skin changes"],
                 "Someone told me I'm glowing today. The switch to injections was the best decision."),
                (1,   .calm,      [],
                 "7 months on HRT total, 3 on injections. Everything is stable. Grateful for this journey."),
            ]
        case .sam:
            return [
                (120, .happy,     ["Energy boost"],
                 "First day on T gel! Applied it this morning. The ritual feels grounding — a daily reminder I'm taking care of myself."),
                (100, .energetic, [],
                 "Energy is noticeably higher. Is this the T already or just excitement? Either way, I'll take it."),
                (85,  .anxious,   [],
                 "Missed my gel this morning — slept through my alarm and had to rush to class. Hate when this happens."),
                (70,  .neutral,   ["Skin changes"],
                 "Skin is getting oilier. Acne starting on my shoulders. Normal but annoying."),
                (55,  .tired,     ["Fatigue"],
                 "Missed two days this week. Can feel the difference — lower energy, kinda foggy. Need to be better about consistency."),
                (40,  .happy,     ["Energy boost"],
                 "Didn't miss a single day this week! Energy is great, voice is starting to crack. Progress feels real."),
                (25,  .sad,       [],
                 "Missed again. College schedule makes it so hard to be consistent. Wish there was a longer-acting option."),
                (10,  .calm,      [],
                 "Accepting that perfect adherence isn't realistic for me right now. Doing my best. The app shows my levels dip on missed days but recover fast."),
                (3,   .energetic, ["Energy boost"],
                 "Good week! Only missed one day. Voice is definitely deeper. Little changes adding up."),
                (0,   .happy,     [],
                 "4 months on T. Even with the missed doses, changes are happening. Grateful for the app helping me see the big picture."),
            ]
        case .rowan:
            return [
                (180, .happy,     [],
                 "Starting compounded E2 cream today. My doctor prescribed a custom 2.5mg/mL concentration since the standard wasn't absorbing well for me."),
                (150, .calm,      [],
                 "Daily cream routine is settling in. It's actually kind of nice — a moment of self-care every morning."),
                (120, .neutral,   ["Skin changes"],
                 "Skin feels softer! Not sure if it's the cream base or the E2, but I'll take it."),
                (90,  .anxious,   [],
                 "Worried the custom concentration might not be accurate. No way to verify without labs. Trusting my compounding pharmacy."),
                (60,  .happy,     ["Skin changes"],
                 "Definite changes now — skin texture, fat redistribution starting. The cream is working despite my worries."),
                (30,  .calm,      [],
                 "6 months coming up. Doctor wants labs at the 6-month mark. Curious to see my numbers on this custom concentration."),
                (7,   .energetic, [],
                 "Feeling really good. The daily application is second nature now. Custom concentration was the right call."),
                (0,   .calm,      [],
                 "Applied my cream this morning and feeling grateful. Transition isn't a race, it's a journey."),
            ]
        case .jules:
            return [
                (120, .happy,     [],
                 "First TE injection! Chose enanthate because I heard the peaks are smoother than cypionate. Let's find out."),
                (100, .energetic, ["Energy boost"],
                 "Energy is GREAT. TE feels different than what friends described on TC. More even, less peak-y."),
                (85,  .calm,      [],
                 "Steady. No rollercoaster. Weekly injections are just part of my Sunday routine now."),
                (60,  .anxious,   [],
                 "Getting blood drawn next week. Nervous about my levels. What if they're way off?"),
                (50,  .happy,     [],
                 "Labs came back! 680 ng/dL at trough — above the population prediction. My body metabolizes T slower than average. The calibration is cool to see."),
                (35,  .calm,      [],
                 "The calibrated curve on the labs chart is satisfying. Seeing my measured point right above the prediction line."),
                (15,  .energetic, [],
                 "4 months in, calibrated, stable. Voice dropped, muscle definition improving. TE was the right choice."),
                (1,   .happy,     [],
                 "Another Sunday, another injection. The routine is grounding. My levels are dialed in thanks to that blood test."),
            ]
        case .nadia:
            return [
                (365, .happy,     [],
                 "Starting EC today but on a 10-day schedule instead of the standard 7. My doctor agreed to let me try it — fewer injections, same total dose."),
                (330, .calm,      [],
                 "So far so good. The longer interval means the trough is lower but I'm not feeling it yet."),
                (300, .neutral,   [],
                 "Day 9 of the cycle and I can feel the dip. Not terrible, but noticeable. The graph shows my trough is ~40% below the q7d equivalent."),
                (270, .happy,     [],
                 "3-month labs: 175 pg/mL at trough. A little lower than the typical q7d range but my doctor says it's fine. I feel good."),
                (210, .anxious,   [],
                 "6-month labs show 155. That's lower. Wondering if the 10-day interval is too long. But I really don't want to go back to weekly injections."),
                (150, .neutral,   ["Fatigue"],
                 "Day 9-10 fatigue is becoming a pattern. My body is telling me something. The app's curve makes it so obvious."),
                (90,  .calm,      [],
                 "Had a good conversation with my doctor. We're watching the trend. Might shorten to q9d as a compromise."),
                (30,  .tired,     ["Fatigue"],
                 "Annual labs soon. The trough is 140 now — definitely trending down. The 10-day experiment might be reaching its limit."),
                (10,  .neutral,   [],
                 "The app's curve tells the story clearly: EC q10d works, but the trough is ~40% below standard. I can see it in the graph every cycle."),
                (0,   .calm,      [],
                 "12 months of data, 3 blood tests, a clear pattern. Even if I adjust the interval, this experiment taught me so much about my body."),
            ]
        }
    }

    /// Jan's original journal templates (unchanged from prior implementation).
    private static func janJournalTemplates() -> [(Int, Mood, [String], String)] {
        typealias T = (Int, Mood, [String], String)
        return [
            (60, .happy,     ["Energy boost"],
             "Started HRT! Feeling so hopeful about the journey ahead. The first injection went smoothly — barely felt it."),
            (58, .energetic, ["Energy boost"],
             "Woke up with so much energy today. Is this the estrogen already? Probably placebo but I'll take it!"),
            (56, .anxious,   ["Mood swings", "Fatigue"],
             "Feeling a bit anxious today. Worried I'm not doing enough. Trying to be patient with the process."),
            (54, .calm,      [],
             "Nice quiet day. Did some meditation and felt really centered. My skin is starting to feel a little softer already."),
            (52, .tired,     ["Fatigue"],
             "Exhausted today. Could barely get out of bed. Remembering this is a marathon, not a sprint."),
            (50, .happy,     ["Skin changes"],
             "OMG my skin is getting SO soft! I keep touching my face and arms. This is really happening!"),
            (48, .neutral,   ["Skin changes"],
             "Skin continuing to change. Noticing less oil production. My skincare routine is finally working."),
            (46, .energetic, ["Energy boost", "Skin changes"],
             "Great day at the gym! Strength is still good but noticing subtle changes in muscle definition."),
            (44, .sad,       ["Mood swings"],
             "Feeling down today. Dysphoria hit hard. Trying to remind myself that changes take time."),
            (42, .calm,      [],
             "Had a lovely conversation with a friend who said she can already see changes in my face. That meant so much."),
            (40, .neutral,   ["Hot flashes", "Skin changes"],
             "Experiencing what I think are hot flashes? Is that normal for trans femmes on E? Note to self: research this."),
            (38, .tired,     ["Hot flashes", "Fatigue"],
             "Hot flashes kept waking me up last night. Only got 4 hours of sleep. Dragging through the day."),
            (36, .happy,     ["Skin changes"],
             "Hot flashes seem to have settled. Feeling more stable emotionally. My cheeks look fuller in photos!"),
            (34, .energetic, ["Energy boost"],
             "Feeling AMAZING today. Crushed my workout, took a cute selfie, and actually liked what I saw for once."),
            (32, .calm,      [],
             "Peaceful Sunday. Journaled for an hour about my transition goals. Feeling grateful for this journey."),
            (30, .anxious,   ["Breast tenderness", "Mood swings"],
             "Breast tenderness started today — ow! But also... yay? Growth is happening!! Mixed feelings but mostly excited."),
            (28, .happy,     ["Breast tenderness"],
             "The tenderness is real but I'm not complaining. This is the first tangible sign of physical change and I'm thrilled."),
            (26, .neutral,   ["Breast tenderness", "Fatigue"],
             "Tenderness continues. Had to adjust how I sleep. Fatigue is also picking up — body is working hard!"),
            (24, .energetic, ["Energy boost"],
             "Energy is back! Went for a long walk and felt so connected to my body. Loving this new relationship with myself."),
            (22, .calm,      ["Breast tenderness"],
             "Tenderness lessening a bit. Measured myself and there's definitely growth happening. Slow and steady."),
            (20, .happy,     ["Skin changes", "Energy boost"],
             "Had my 3-month blood test today! Excited to see the numbers. Feeling really good about my progress."),
            (18, .neutral,   [],
             "Got my labs back — E2 is at 180 pg/mL! Doctor is pleased. Adjusting dose slightly but staying on EV 5-day schedule."),
            (16, .energetic, ["Energy boost"],
             "Best day in weeks! My mood has been so stable lately. The emotional rollercoaster is leveling out."),
            (14, .calm,      ["Skin changes"],
             "Someone at work told me I'm 'glowing.' Didn't mention why but I know it's the E. My skin is so clear now."),
            (12, .happy,     ["Skin changes", "Breast tenderness"],
             "Breast tenderness is back but milder. Continuing to see changes. Feeling more and more like myself every day."),
            (10, .neutral,   [],
             "Nothing major to report but that's okay. Consistency is key. My routine feels natural now."),
            (8,  .happy,     ["Energy boost", "Skin changes"],
             "Looking at old photos and wow — the difference is subtle but real. My jawline looks softer, eyes seem bigger."),
            (6,  .calm,      [],
             "Had therapy today and reflected on how far I've come. Six months ago I couldn't have imagined feeling this grounded."),
            (5,  .energetic, ["Energy boost"],
             "Morning run felt amazing. My endurance is actually improving? Maybe it's the happiness boosting everything."),
            (3,  .tired,     ["Fatigue"],
             "Tired today but it's the good kind of tired. The kind where you know you're growing into yourself."),
            (1,  .happy,     ["Skin changes", "Energy boost"],
             "One of those days where I look in the mirror and actually SEE myself. Not who I was, but who I'm becoming. Grateful."),
            (0,  .calm,      [],
             "Today was peaceful. Took my dose on time, did my skincare routine, and felt present in my body. This is what authentic feels like."),
        ]
    }

    // MARK: - Notifications Population

    @MainActor
    private static func populateNotifications() {
        let nm = NotificationManager.shared
        let defaults = UserDefaults.standard

        // Dose reminders ON at 8 AM
        defaults.set(true, forKey: "doseReminderEnabled")
        defaults.set(8, forKey: "doseReminderHour")
        defaults.set(0, forKey: "doseReminderMinute")

        // Journal reminders ON at 9 PM
        defaults.set(true, forKey: "journalReminderEnabled")
        defaults.set(21, forKey: "journalReminderHour")
        defaults.set(0, forKey: "journalReminderMinute")

        nm.doseReminderEnabled = true
        nm.doseReminderHour = 8
        nm.doseReminderMinute = 0
        nm.journalReminderEnabled = true
        nm.journalReminderHour = 21
        nm.journalReminderMinute = 0

        // Suppress one-time overlays for a clean preview appearance
        defaults.set(true, forKey: "hasSeenRecommendedZonesInfo")
    }
}


// MARK: - Preview wrapper
// (Moved from SpoofPreview.swift — a 38-line file whose only content was this
// DEBUG-only wrapper around the same spoof system.)

/// Wraps preview content and seeds all managers with SpoofProfile (Jan) data.
///
/// Usage:
/// ```swift
/// #Preview {
///     SpoofPreview {
///         HomeView()
///     }
/// }
/// ```
struct SpoofPreview<Content: View>: View {
    @State private var seeded = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .task {
                guard !seeded else { return }
                seeded = true
                SpoofProfile.forceApply()
            }
    }
}

#endif
