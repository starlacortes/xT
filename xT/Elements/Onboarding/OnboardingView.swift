//
//  OnboardingView.swift
//  xT
//
//  Redesigned by Cline on 6/30/2026.
//  9-step progressive onboarding with concentration-aware dose logging.
//

import SwiftUI
import SwiftData
import PhotosUI

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct OnboardingView: View {
    @Environment(\.medicationManager) var medicationManager
    @Environment(\.profileManager) var profileManager
    @Environment(\.themeManager) var themeManager
    @Environment(\.rebuildCloudContainer) var rebuildCloudContainer

    var onboardingComplete: (() -> Void)? = nil

    // MARK: - Step State
    @State var currentStep: Int = 0
    @State var opacity: Double = 0

    // iCloud restore
    @State var isRestoringFromiCloud = false
    @State var showRestoreNotFoundAlert = false
    @State var showTurnOnSyncAlert = false
    // iCloud consent sheet (shown once, after the profile step)
    @State var showCloudSyncChoice = false
    
    // Step 2 — medication type
    @State var selectedType: String = ""
    
    // Step 3 — HRT experience
    @State var hasBeenOnHRT: Bool = false
    @State var hrtDurationMonths: Int = 1
    @State var hrtDurationYears: Int = 0
    
    // Step 4 — method + ester + frequency
    @State var selectedMethod: String = ""
    @State var selectedEster: String = ""
    @State var selectedFrequency: Int = 7

    // Step 5 — vial concentration (NEW)
    @State var selectedConcentration: Double = 40.0
    @State var customConcentrationText: String = ""
    @State var showCustomConcentration: Bool = false
    
    // Step 6 — dose + timing (enhanced with mg/mL toggle)
    @State var doseUnit: String = "mg"
    @State var doseDecimal: Double = 2.0
    @State var doseText: String = "2.0"
    @State var mlAmount: Double = 0.05
    @State var mlText: String = "0.05"
    @State var lastDoseDate: Date = Date()
    @FocusState var doseFieldFocused: Bool
    
    // Step 7 — anti-androgens
    @State var antiAndrogenChoice: String = "None"
    
    // Step 8 — body type (backed by medicationManager for CloudKit sync)

    // Step 9 — profile
    @State var profileName: String = ""
    @State var showImagePicker: Bool = false
    @State var showCamera: Bool = false
    /// Bumped when a photo lands so the profile avatar repaints immediately
    /// (the photo is applied on a background transfer, outside the normal
    /// observation path of this step's `Image`).
    @State var profilePhotoNonce: Int = 0

    // Step 6b — injection/application site (body picker)
    @State var selectedSiteLabels3D: [String] = []
    @State var tapPositions: [String: BodyModel3DView.HitPosition] = [:]
    /// Marks taps that land on the body but outside any clinical zone.
    @State var noZoneTaps = NoZoneTapTracker()
    /// Live camera yaw in radians, used to record which side of the body was tapped.
    @State var cameraYaw: Float = 0
    @State var bodySnapAngle: BodySnapAngle = .front
    @State var bodySnapNonce: Int = 0
    @State var selectedInjectionSites: [InjectionSite] = []

    var isOralRoute: Bool {
        RouteClass.from(method: selectedMethod) == .oral
    }

    var isTopicalRoute: Bool {
        RouteClass.from(method: selectedMethod) == .topical
    }

    var isRouteShowsBodyPicker: Bool {
        !isOralRoute
    }

    /// The concentration step asks an mg/mL strength question. Oral pills carry
    /// none — they're dosed in whole mg — and `commitOnboarding` stores no
    /// concentration for them, so the step is skipped for the oral route, the
    /// same way the injection-site step is.
    var showsConcentrationStep: Bool {
        !isOralRoute
    }

    /// Step indices actually visited for the chosen route, in order. Skipped
    /// steps drop out here so the progress bar's fraction, which walks this
    /// array, never overflows on the routes that skip (a raw
    /// `(currentStep + 1) / totalStepCount` ran past 1.0 at the review step).
    var visitedSteps: [Int] {
        var steps = Array(0...11)
        if !showsConcentrationStep { steps.removeAll { $0 == 4 } }
        if !isRouteShowsBodyPicker { steps.removeAll { $0 == 6 } }
        return steps
    }

    var totalStepCount: Int {
        visitedSteps.count
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Paper ground (O1 step 1) — the brand gradient ground retired with
            // the Isocline transition; onboarding reads like the app it opens.
            Theme.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, Theme.Spacing.xxxl)
                    .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                ZStack {
                    Group {
                        switch currentStep {
                        case 0: welcomeStep
                        case 1: pathStep
                        case 2: experienceStep
                        case 3: medicationStep
                        case 4: concentrationStep
                        case 5: doseStep
                        case 6: injectionSiteStep
                        case 7: antiAndrogenStep
                        case 8: bodyTypeStep
                        case 9: profileStep
                        case 10: themeStep
                        case 11: reviewStep
                        default: EmptyView()
                        }
                    }
                    .opacity(opacity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1.0 }
        }
        .onChange(of: selectedEster) { _, newEster in
            // Auto-select default concentration when ester changes
            autoSelectConcentration(for: newEster)
        }
        .onChange(of: selectedConcentration) { _, _ in
            updateMlFromMg()
        }
        .onChange(of: doseDecimal) { _, _ in
            updateMlFromMg()
        }
        .sheet(isPresented: $showCloudSyncChoice) {
            CloudSyncChoiceView { useCloudKit in
                UserDefaults.standard.set(useCloudKit, forKey: "icloudSyncEnabled")
                if !useCloudKit {
                    // Declined: swap the container to local-only in place. No
                    // restart needed — nothing sync-relevant has been written
                    // at this point in onboarding.
                    rebuildCloudContainer(.cloudKit(false))
                }
                showCloudSyncChoice = false
                advanceStep()
            }
        }
    }

    // MARK: - Progress Bar
    var progressBar: some View {
        GeometryReader { geo in
            // Fraction from the visited-step sequence, not the raw index —
            // skipped steps would otherwise leave the bar short (or, at the
            // review step, wider than its track).
            let visitedIndex = (visitedSteps.firstIndex(of: currentStep) ?? 0) + 1
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.Radius.hairline)
                    .fill(Theme.Colors.border)
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: Theme.Radius.hairline)
                    .fill(Theme.Colors.accent)
                    .frame(width: geo.size.width * CGFloat(visitedIndex) / CGFloat(totalStepCount), height: 3)
                    .animation(Theme.Motion.quick, value: currentStep)
            }
        }
        .frame(height: 3)
    }

    func selectType(_ type: String, defaultDose: Double) {
        selectedType = type
        doseDecimal = defaultDose
        doseText = String(format: "%.1f", defaultDose)
        selectedEster = ""
        selectedMethod = ""
        showCustomConcentration = false
    }

    func autoSelectConcentration(for ester: String) {
        let defaults = MedicationManager.commonConcentrations(forEster: ester)
        if let defaultConc = defaults.first(where: { $0 > 0 }) {
            selectedConcentration = defaultConc
        }
        showCustomConcentration = false
        customConcentrationText = ""
        updateMlFromMg()
    }

    func updateMlFromMg() {
        guard selectedConcentration > 0 else { return }
        let vol = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
        mlAmount = vol
        mlText = String(format: "%.2f", vol)
    }

    func advanceStep() {
        if currentStep == 9, UserDefaults.standard.object(forKey: "icloudSyncEnabled") == nil {
            // First-run iCloud consent: asked right after the profile step,
            // never as a separate screen before onboarding.
            showCloudSyncChoice = true
            return
        }
        var nextStep = currentStep + 1
        if currentStep == 3 && !showsConcentrationStep {
            // Oral: no vial-strength question — jump the concentration step.
            nextStep = 5
        }
        if currentStep == 5 && !isRouteShowsBodyPicker {
            nextStep = 7
        }
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep = nextStep
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        }
    }

    func previousStep() {
        var prevStep = currentStep - 1
        if currentStep == 5 && !showsConcentrationStep {
            prevStep = 3
        }
        if currentStep == 7 && !isRouteShowsBodyPicker {
            prevStep = 5
        }
        withAnimation(.easeInOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep = prevStep
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        }
    }

    func commitOnboarding() {
        let medType = MedicationManager.MedicationType(rawValue: selectedType) ?? .estrogen
        let medMethod = MedicationManager.AdministrationMethod(rawValue: selectedMethod) ?? .injectable

        // Set HRT start date
        if hasBeenOnHRT {
            let cal = Calendar.current
            let months = hrtDurationYears * 12 + hrtDurationMonths
            medicationManager.hrtStartDate = cal.date(byAdding: .month, value: -months, to: Date())
        }

        // Set AA flags
        medicationManager.antiAndrogenInUse = antiAndrogenChoice == "Spiro" || antiAndrogenChoice == "Other AA"
        medicationManager.spironolactoneInUse = antiAndrogenChoice == "Spiro"

        // Determine ester label.
        //
        // Fixed 2026‑07‑31: non-injectable routes stored the raw method name, so a cream
        // dose was saved with ester "Cream" — which matches no case in either ester enum.
        // The PK engine's transdermal branch then failed its `MedicationEster(rawValue:)`
        // lookup and fell through to a hardcoded scaling constant of 8000, roughly 52×
        // the calibrated transdermal value, for every user who onboarded onto a cream.
        // Users who set the same route from Settings stored "Transdermal" and were fine.
        // Store the pseudo-ester the engine actually resolves to, so record and model agree.
        let esterLabel: String = {
            if medMethod == .injectable {
                return selectedEster.isEmpty ? medMethod.rawValue : selectedEster
            }
            return MedicationManager.effectiveEsterName(ester: selectedEster, route: medMethod.rawValue)
        }()

        // Configure medication
        medicationManager.updateSelection(type: medType, method: medMethod)

        // Determine final dose in mg (already computed correctly from whichever mode)
        let finalMg = doseDecimal
        
        // Determine concentration to store. Oral has no mg/mL strength to ask
        // about (its concentration step is skipped), so it is always nil;
        // injectables and creams carry a real label strength, which the dose
        // sheet later prefills from.
        let finalConcentration: Double? = (medMethod != .oral && selectedConcentration > 0) ? selectedConcentration : nil

        // Log first dose with concentration + injection sites (from body picker step)
        medicationManager.addDose(
            date: lastDoseDate,
            type: medType.rawValue,
            ester: esterLabel,
            method: medMethod.rawValue,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration,
            injectionSites: selectedInjectionSites
        )

        // Save custom frequency from onboarding stepper
        medicationManager.customFrequencyDays = selectedFrequency

        // Save the onboarding-chosen default concentration through the manager
        // API, which also refreshes the in-memory cache — writing the prefs
        // record directly (the old code) left `resolvedDoseDefaults` serving the
        // pre-onboarding fallback until the next launch.
        if let finalConcentration {
            medicationManager.updateOnboardingDefaultConcentration(finalConcentration, for: selectedType)
        }
        medicationManager.persistUserPreferences()

        // Configure dose reminders with the selected frequency and default time
        let reminderHour = NotificationManager.Defaults.doseHour
        let reminderMinute = NotificationManager.Defaults.doseMinute
        NotificationManager.shared.configureDoseReminder(
            enabled: true,
            hour: reminderHour,
            minute: reminderMinute
        )

        withAnimation(.easeInOut(duration: 0.4)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onboardingComplete?()
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.themeManager, ThemeManager.shared)
}
#endif
