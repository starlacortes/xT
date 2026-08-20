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

    var onboardingComplete: (() -> Void)? = nil

    // MARK: - Step State
    @State var currentStep: Int = 0
    @State var opacity: Double = 0

    // iCloud restore
    @State var isRestoringFromiCloud = false
    @State var showRestoreNotFoundAlert = false
    
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

    var isRouteShowsBodyPicker: Bool {
        RouteClass.from(method: selectedMethod) != .oral
    }

    var totalStepCount: Int {
        isRouteShowsBodyPicker ? 12 : 11
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Theme.Gradients.brand
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 32)
                    .padding(.horizontal, 40)

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
    }

    // MARK: - Progress Bar
    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.OnAccent.primary.opacity(0.3))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalStepCount), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
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
        var nextStep = currentStep + 1
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
        
        // Determine concentration to store (nil for non-injectable or if not set)
        let finalConcentration: Double? = (medMethod == .injectable && selectedConcentration > 0) ? selectedConcentration : nil

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
