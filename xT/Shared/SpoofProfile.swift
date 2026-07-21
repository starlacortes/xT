//
//  SpoofProfile.swift
//  xT
//
//  DEBUG-only comprehensive spoof profile named "Jan".
//  Applied only when the Developer Area's Sample toggle is enabled
//  (Settings → Developer). Populates all singleton managers with realistic
//  data so every preview and view in the app renders content. The user's
//  real data is snapshotted/restored around it by ProfileSnapshot.
//

#if DEBUG

import SwiftUI
import SwiftData

/// Centralized spoof-data generator for the "Jan" persona.
/// Populates ProfileManager, MedicationManager, JournalManager, and NotificationManager
/// with a rich, internally consistent dataset.
enum SpoofProfile {

    // MARK: - Entry Point

    /// Call once at app launch (or from a #Preview .task) to seed all managers.
    /// Idempotent — checks a UserDefaults flag to avoid repeated population.
    @MainActor
    static func applyIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: spfKey) else { return }

        resetAllManagers()
        populateProfile()
        populateMedication()
        populateJournal()
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

    private static let spfKey = "com.xt.spoofProfile_jan_v1"

    /// "Jan" started HRT ~18 months ago from the reference date.
    private static let hrtStartDate: Date = {
        var dc = DateComponents()
        dc.year = 2024
        dc.month = 12
        dc.day = 15
        return Calendar.current.date(from: dc)!
    }()

    /// Reference "now" for deterministic dose generation.
    private static var today: Date { Calendar.current.startOfDay(for: Date()) }

    // MARK: - Reset

    @MainActor
    private static func resetAllManagers() {
        let mm = MedicationManager.shared

        // --- Profile ---
        let pm = ProfileManager.shared
        pm.profileName = ""
        pm.profileImage = nil
        pm.profileImageData = nil
        pm.dateOfBirth = nil

        // --- Medication: manually clear all @Published state ---
        mm.selectedMedication = nil
        mm.selectedAdministrationMethod = nil
        mm.lastDoseDate = nil
        mm.nextDoseDate = nil
        mm.hrtStartDate = nil
        mm.currentHormoneLevel = nil
        mm.recentLevels = []
        mm.doseHistory = []
        mm.bloodTestHistory = []
        mm.antiAndrogenInUse = false
        mm.spironolactoneInUse = false
        mm.spironolactoneClearanceEnabled = false
        mm.suppressionSpeed = .fast
        mm.customFrequencyDays = nil
        mm.showDoseIntensityInsights = false
        mm.missedDoseGracePeriodHours = 12.0
        mm.predictedTroughDrop = nil
        mm.userTherapeuticTarget = nil

        // Clear persisted dose dates
        UserDefaults.standard.removeObject(forKey: "lastDoseDate")
        UserDefaults.standard.removeObject(forKey: "nextDoseDate")
        UserDefaults.standard.removeObject(forKey: "selectedMedication")
        UserDefaults.standard.removeObject(forKey: "selectedAdministrationMethod")

        // Remove all DoseRecords + BloodTestRecords from SwiftData
        if let ctx = mm.modelContext {
            do {
                let doses = try ctx.fetch(FetchDescriptor<DoseRecord>())
                for d in doses { ctx.delete(d) }
                let tests = try ctx.fetch(FetchDescriptor<BloodTestRecord>())
                for t in tests { ctx.delete(t) }
                let screenings = try ctx.fetch(FetchDescriptor<ScreeningRecord>())
                for s in screenings { ctx.delete(s) }
                try ctx.save()
            } catch {
                print("[SpoofProfile] reset SwiftData error: \(error)")
            }
        }

        // --- Journal ---
        if let ctx = JournalManager.shared.modelContext {
            do {
                let entries = try ctx.fetch(FetchDescriptor<JournalEntry>())
                for e in entries { ctx.delete(e) }
                try ctx.save()
            } catch {
                print("[SpoofProfile] reset journal error: \(error)")
            }
        }
        JournalManager.shared.entries = []

        // --- Notifications: clear UserDefaults keys (singular naming convention) ---
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "doseReminderEnabled")
        defaults.removeObject(forKey: "journalReminderEnabled")
        defaults.removeObject(forKey: "doseReminderHour")
        defaults.removeObject(forKey: "doseReminderMinute")
        defaults.removeObject(forKey: "journalReminderHour")
        defaults.removeObject(forKey: "journalReminderMinute")
    }

    // MARK: - Profile Population

    @MainActor
    private static func populateProfile() {
        let pm = ProfileManager.shared
        pm.profileName = "Jan"

        // Generate a teal-gradient avatar with "J" initial
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.20, green: 0.78, blue: 0.78, alpha: 1.0).cgColor,
                UIColor(red: 0.60, green: 0.40, blue: 0.90, alpha: 1.0).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 90, weight: .medium),
                .foregroundColor: UIColor.white,
            ]
            let text = "J"
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            pm.profileImageData = jpegData
            pm.profileImage = image
        }
    }

    // MARK: - Medication Population

    @MainActor
    private static func populateMedication() {
        let mm = MedicationManager.shared
        let calendar = Calendar.current

        // Configure for "Jan": Estradiol Valerate, Injectable, 5mg every 5 days
        mm.selectedMedication = "Estrogen"
        mm.selectedAdministrationMethod = "Injectable"
        mm.hrtStartDate = hrtStartDate
        mm.antiAndrogenInUse = true
        mm.spironolactoneInUse = true
        mm.spironolactoneClearanceEnabled = true
        mm.suppressionSpeed = .fast
        mm.customFrequencyDays = 5
        mm.missedDoseGracePeriodHours = 12.0

        // Generate ~18 months of dose history at 5-day intervals
        // addDose signature: addDose(date:type:ester:method:doseAmount:concentrationMgPerMl:notes:)
        var doseDate = hrtStartDate
        let endDate = today
        var doseCount = 0

        while doseDate <= endDate {
            let doseAmount = Double.random(in: 4.5...5.5)

            if doseCount > 10 && Double.random(in: 0...1) < 0.05 {
                // Log a dose then mark it as skipped
                mm.addDose(
                    date: doseDate,
                    type: "Estrogen",
                    ester: "Valerate (EV)",
                    method: "Injectable",
                    doseAmount: doseAmount,
                    concentrationMgPerMl: 20.0,
                    notes: nil
                )
                // skipDose creates a separate skipped record; it uses selectedMedication/selectedAdministrationMethod
                mm.skipDose(on: doseDate, reason: "Forgot — took next day")
            } else {
                mm.addDose(
                    date: doseDate,
                    type: "Estrogen",
                    ester: "Valerate (EV)",
                    method: "Injectable",
                    doseAmount: doseAmount,
                    concentrationMgPerMl: 20.0,
                    notes: doseCount == 0 ? "First injection — starting HRT! 🎉" : nil
                )
            }

            doseDate = calendar.date(byAdding: .day, value: 5, to: doseDate)!
            doseCount += 1
        }

        // Set last/next from the most recent taken dose
        let activeDoses = mm.doseHistory.filter {
            $0.doseStatus == DoseStatus.taken.rawValue && !$0.isDeleted
        }
        if let lastDose = activeDoses.sorted(by: { $0.doseDate > $1.doseDate }).first {
            mm.lastDoseDate = lastDose.doseDate
            mm.nextDoseDate = calendar.date(byAdding: .day, value: 5, to: lastDose.doseDate)
        }

        // Persist dose dates to UserDefaults
        mm.persistDoseDates()

        // Add 4 blood test records at various points in the HRT journey
        // addBloodTest signature: addBloodTest(drawDate:measuredLevel:hormoneType:notes:)
        let bloodTests: [(monthsAfter: Int, e2: Double, notes: String)] = [
            (3,  180, "3-month baseline — good initial response"),
            (6,  230, "6-month check — levels in target range"),
            (12, 195, "12-month annual labs — consistent"),
            (16, 210, "16-month follow-up — maintaining well"),
        ]

        for test in bloodTests {
            guard let drawDate = calendar.date(
                byAdding: .month, value: test.monthsAfter, to: hrtStartDate
            ) else { continue }

            mm.addBloodTest(
                drawDate: drawDate,
                measuredLevel: Double(test.e2),
                hormoneType: "Estrogen",
                notes: test.notes
            )
        }

        // Set therapeutic targets
        mm.userTherapeuticTarget = MedicationManager.TherapeuticTarget(
            troughMin: 100,
            troughMax: 200,
            peakCeiling: 600
        )

        // Recompute derived state (estimated levels, adherence, etc.)
        mm.refreshState()
    }

    // MARK: - Journal Population

    @MainActor
    private static func populateJournal() {
        let jm = JournalManager.shared
        guard let ctx = jm.modelContext else { return }

        let calendar = Calendar.current
        let today = self.today

        // Symptom presets from Symptom.commonSymptoms
        let allSymptoms = Symptom.commonSymptoms
        let symptomMap = Dictionary(uniqueKeysWithValues: allSymptoms.map { ($0.name, $0) })

        // Templates: (daysAgo, mood, symptomNames, text)
        typealias T = (Int, Mood, [String], String)
        let templates: [T] = [
            // Week 1-2 (60-55 days ago): Early HRT excitement
            (60, .happy,     ["Energy boost"],                     "Started HRT! Feeling so hopeful about the journey ahead. The first injection went smoothly — barely felt it."),
            (58, .energetic, ["Energy boost"],                     "Woke up with so much energy today. Is this the estrogen already? Probably placebo but I'll take it!"),
            (56, .anxious,   ["Mood swings", "Fatigue"],           "Feeling a bit anxious today. Worried I'm not doing enough. Trying to be patient with the process."),
            (54, .calm,      [],                                   "Nice quiet day. Did some meditation and felt really centered. My skin is starting to feel a little softer already."),
            (52, .tired,     ["Fatigue"],                          "Exhausted today. Could barely get out of bed. Remembering this is a marathon, not a sprint."),
            // Week 3-4 (50-45 days ago): Skin changes
            (50, .happy,     ["Skin changes"],                     "OMG my skin is getting SO soft! I keep touching my face and arms. This is really happening!"),
            (48, .neutral,   ["Skin changes"],                     "Skin continuing to change. Noticing less oil production. My skincare routine is finally working."),
            (46, .energetic, ["Energy boost", "Skin changes"],     "Great day at the gym! Strength is still good but noticing subtle changes in muscle definition."),
            (44, .sad,       ["Mood swings"],                      "Feeling down today. Dysphoria hit hard. Trying to remind myself that changes take time."),
            (42, .calm,      [],                                   "Had a lovely conversation with a friend who said she can already see changes in my face. That meant so much."),
            // Week 5-6 (40-35 days ago): Hot flashes
            (40, .neutral,   ["Hot flashes", "Skin changes"],      "Experiencing what I think are hot flashes? Is that normal for trans femmes on E? Note to self: research this."),
            (38, .tired,     ["Hot flashes", "Fatigue"],           "Hot flashes kept waking me up last night. Only got 4 hours of sleep. Dragging through the day."),
            (36, .happy,     ["Skin changes"],                     "Hot flashes seem to have settled. Feeling more stable emotionally. My cheeks look fuller in photos!"),
            (34, .energetic, ["Energy boost"],                     "Feeling AMAZING today. Crushed my workout, took a cute selfie, and actually liked what I saw for once."),
            (32, .calm,      [],                                   "Peaceful Sunday. Journaled for an hour about my transition goals. Feeling grateful for this journey."),
            // Week 7-8 (30-25 days ago): Breast tenderness
            (30, .anxious,   ["Breast tenderness", "Mood swings"], "Breast tenderness started today — ow! But also... yay? Growth is happening!! Mixed feelings but mostly excited."),
            (28, .happy,     ["Breast tenderness"],                "The tenderness is real but I'm not complaining. This is the first tangible sign of physical change and I'm thrilled."),
            (26, .neutral,   ["Breast tenderness", "Fatigue"],     "Tenderness continues. Had to adjust how I sleep. Fatigue is also picking up — body is working hard!"),
            (24, .energetic, ["Energy boost"],                     "Energy is back! Went for a long walk and felt so connected to my body. Loving this new relationship with myself."),
            (22, .calm,      ["Breast tenderness"],                "Tenderness lessening a bit. Measured myself and there's definitely growth happening. Slow and steady."),
            // Week 9-10 (20-15 days ago): Mood stabilizing
            (20, .happy,     ["Skin changes", "Energy boost"],     "Had my 3-month blood test today! Excited to see the numbers. Feeling really good about my progress."),
            (18, .neutral,   [],                                   "Got my labs back — E2 is at 180 pg/mL! Doctor is pleased. Adjusting dose slightly but staying on EV 5-day schedule."),
            (16, .energetic, ["Energy boost"],                     "Best day in weeks! My mood has been so stable lately. The emotional rollercoaster is leveling out."),
            (14, .calm,      ["Skin changes"],                     "Someone at work told me I'm 'glowing.' Didn't mention why but I know it's the E. My skin is so clear now."),
            (12, .happy,     ["Skin changes", "Breast tenderness"],"Breast tenderness is back but milder. Continuing to see changes. Feeling more and more like myself every day."),
            // Week 11-12 (10-3 days ago): Settling in
            (10, .neutral,   [],                                   "Nothing major to report but that's okay. Consistency is key. My routine feels natural now."),
            (8,  .happy,     ["Energy boost", "Skin changes"],     "Looking at old photos and wow — the difference is subtle but real. My jawline looks softer, eyes seem bigger."),
            (6,  .calm,      [],                                   "Had therapy today and reflected on how far I've come. Six months ago I couldn't have imagined feeling this grounded."),
            (5,  .energetic, ["Energy boost"],                     "Morning run felt amazing. My endurance is actually improving? Maybe it's the happiness boosting everything."),
            (3,  .tired,     ["Fatigue"],                          "Tired today but it's the good kind of tired. The kind where you know you're growing into yourself."),
            (1,  .happy,     ["Skin changes", "Energy boost"],     "One of those days where I look in the mirror and actually SEE myself. Not who I was, but who I'm becoming. Grateful."),
            (0,  .calm,      [],                                   "Today was peaceful. Took my dose on time, did my skincare routine, and felt present in my body. This is what authentic feels like."),
        ]

        for template in templates {
            let (daysAgo, mood, symptomNames, text) = template
            guard let entryDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            let symptomList = symptomNames.compactMap { symptomMap[$0] }

            let entry = JournalEntry(
                id: UUID(),
                date: entryDate,
                mood: mood,
                text: text,
                symptoms: symptomList
            )
            ctx.insert(entry)
        }

        do {
            try ctx.save()
            jm.loadEntries()
        } catch {
            print("[SpoofProfile] populateJournal save failed: \(error)")
        }
    }

    // MARK: - Notifications Population

    @MainActor
    private static func populateNotifications() {
        let nm = NotificationManager.shared
        let defaults = UserDefaults.standard

        // Dose reminders ON at 8 AM (keys use singular "Reminder" convention)
        defaults.set(true, forKey: "doseReminderEnabled")
        defaults.set(8, forKey: "doseReminderHour")
        defaults.set(0, forKey: "doseReminderMinute")

        // Journal reminders ON at 9 PM
        defaults.set(true, forKey: "journalReminderEnabled")
        defaults.set(21, forKey: "journalReminderHour")
        defaults.set(0, forKey: "journalReminderMinute")

        // Mirror to NotificationManager's @Published properties (singular naming)
        nm.doseReminderEnabled = true
        nm.doseReminderHour = 8
        nm.doseReminderMinute = 0
        nm.journalReminderEnabled = true
        nm.journalReminderHour = 21
        nm.journalReminderMinute = 0
    }
}

#endif