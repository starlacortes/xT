//
//  QuickDoseSheet.swift
//  xT
//
//  Quick dose recording sheet with mg/mL toggle, concentration picker,
//  date selection, volume warnings, and (v2.1) multi-step injection site tracking.
//

import SwiftUI

struct QuickDoseSheet: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var isPresented: Bool

    // MARK: - Dose Input State (Step 1)

    @State private var doseUnit: String = "mg"
    @State private var mgAmount: Double = 2.0
    @State private var mlAmount: Double = 0.05
    @State private var concentration: Double = 40.0
    @State private var showCustomConcentration: Bool = false
    @State private var customConcentrationText: String = ""
    @State private var doseDate: Date = Date()

    // MARK: - Multi-Step Flow State (v2.1)

    @State private var currentStep: Int = 1
    @State private var selectedSites: [InjectionSite] = []
    @State private var showLastSitePreview: Bool = false
    @State private var isCorrectionMode: Bool
    @State private var originalDose: DoseRecord?
    @State private var patchDurationDays: Int = 7

    // MARK: - Init

    init(
        isPresented: Binding<Bool>,
        correctionMode: Bool = false,
        originalDose: DoseRecord? = nil
    ) {
        self._isPresented = isPresented
        self._isCorrectionMode = State(initialValue: correctionMode)
        self._originalDose = State(initialValue: originalDose)
    }

    // MARK: - Computed

    private var routeClass: RouteClass {
        RouteClass.from(method: medicationManager.selectedAdministrationMethod ?? "")
    }

    private var isOral: Bool {
        routeClass == .oral
    }

    private var lastInjectionSites: [InjectionSite]? {
        medicationManager.lastInjectionSites(for: routeClass)
    }

    /// True if any of the last dose's sites are marked as avoid.
    private var lastSitesContainAvoidZone: Bool {
        guard let sites = lastInjectionSites else { return false }
        return sites.contains { medicationManager.avoidZones[$0.zoneLabel] != nil }
    }

    /// Days since the most recent injection dose was recorded (for safety indicator).
    /// Uses doseDate from the DoseRecord, not InjectionSite.lastUsedDate which reflects struct creation time.
    private var lastSiteDaysAgo: Int? {
        guard lastInjectionSites != nil,
              let lastDate = medicationManager.lastInjectionSiteDoseDate(for: routeClass) else {
            return nil
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }

    /// True if the last site is safely outside the rotation window.
    private var lastSiteIsSafe: Bool {
        guard let days = lastSiteDaysAgo else { return false }
        return days >= routeClass.defaultRotationWindowDays
    }

    /// Preferred zones for the current medication + route combination.
    private var preferredZones: Set<String> {
        let med = medicationManager.selectedMedication ?? ""
        return Set(BodySketchData.preferredZones(medication: med, routeClass: routeClass))
    }

    /// Recently used zones within the rotation safety window.
    private var recentlyUsedZones: Set<String> {
        medicationManager.recentlyUsedZones(withinDays: routeClass.defaultRotationWindowDays)
    }

    // Pre-fill concentration from last dose on appear
    private var defaultConcentration: Double {
        if let conc = medicationManager.defaultConcentrationMgPerMl {
            return conc
        }
        if medicationManager.selectedMedication == "Estrogen" { return 40.0 }
        if medicationManager.selectedMedication == "Testosterone" { return 200.0 }
        return 40.0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if currentStep == 1 {
                step1DoseDetails
            } else {
                step2BodySitePicker
            }
        }
    }

    // MARK: - Step 1: Dose Details

    private var step1DoseDetails: some View {
        VStack(spacing: 16) {
            // Header
            Text(isCorrectionMode ? "Correct Site" : "Record Dose")
                .font(.headline)
                .padding(.top, 8)

            // Medication info
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundStyle(Theme.Colors.accent)
                Text(medicationManager.medicationDisplayInfo)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 20)

            // ── Last Location Panel (v2.1) ──
            if !isCorrectionMode && !isOral && lastInjectionSites != nil {
                lastLocationPanel
            } else if isCorrectionMode, let original = originalDose, let primary = original.primarySite {
                correctionLockPanel(site: primary)
            }

            // ── Dose Unit Picker ──
            Picker("Dose Unit", selection: $doseUnit) {
                Text("mg").tag("mg")
                Text("mL").tag("mL")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .disabled(isCorrectionMode)

            // ── Dose Amount ──
            if doseUnit == "mg" {
                HStack(spacing: 12) {
                    TextField("mg", value: $mgAmount, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.secondarySystemBackground))
                        )
                    Text("mg")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .disabled(isCorrectionMode)

                let volume = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
                Text("= \(String(format: "%.3f", volume)) mL (@ \(String(format: "%.0f", concentration)) mg/mL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let warning = MedicationManager.volumeWarning(for: volume, ester: medicationManager.lastLoggedDose?.ester) {
                    quickDoseWarning(warning)
                }
            } else {
                HStack(spacing: 12) {
                    TextField("mL", value: $mlAmount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.secondarySystemBackground))
                        )
                    Text("mL")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .disabled(isCorrectionMode)

                let computedMg = mlAmount * concentration
                Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", concentration)) mg/mL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let warning = MedicationManager.volumeWarning(for: mlAmount, ester: medicationManager.lastLoggedDose?.ester) {
                    quickDoseWarning(warning)
                }
            }

            // ── Concentration Picker ──
            if !isCorrectionMode {
                VStack(spacing: 6) {
                    Text("Vial concentration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    let ester = medicationManager.lastLoggedDose?.ester ?? ""
                    let concentrations = MedicationManager.commonConcentrations(forEster: ester)
                        .filter { $0 > 0 }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(concentrations, id: \.self) { conc in
                                Button {
                                    withAnimation { concentration = conc; showCustomConcentration = false }
                                } label: {
                                    Text("\(String(format: "%.0f", conc))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(concentration == conc && !showCustomConcentration
                                                      ? Theme.Colors.accent.opacity(0.5)
                                                      : Color(.tertiarySystemFill))
                                        )
                                }
                            }
                            Button {
                                withAnimation { showCustomConcentration = true }
                            } label: {
                                Text("Custom")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(showCustomConcentration
                                                  ? Theme.Colors.accent.opacity(0.5)
                                                  : Color(.tertiarySystemFill))
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // ── Date Picker ──
            if !isCorrectionMode {
                DisclosureGroup("Change date\u{2026}") {
                    DatePicker("", selection: $doseDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
            } else {
                // Correction mode: lock icon + immutable date
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(doseDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            Spacer()

            // ── Action Button ──
            Button {
                if isOral {
                    recordDoseImmediately()
                } else if isCorrectionMode {
                    currentStep = 2
                } else {
                    advanceToStep2()
                }
            } label: {
                HStack(spacing: 6) {
                    if isCorrectionMode {
                        Image(systemName: "arrow.triangle.swap")
                        Text("Choose New Site")
                    } else if isOral {
                        Text("Record Dose")
                    } else {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.accent.opacity(0.8))
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isPresented = false }
            }
        }
        .onAppear {
            prefillFromRecentDose()
        }
        .onChange(of: concentration) { _, _ in updateMlFromMg() }
        .onChange(of: mgAmount) { _, _ in updateMlFromMg() }
        .sheet(isPresented: $showLastSitePreview) {
            if let sites = lastInjectionSites {
                LastSitePreview(injectionSites: sites, routeClass: routeClass)
            }
        }
    }

    // MARK: - Step 2: Body Site Picker

    private var step2BodySitePicker: some View {
        BodySitePickerView(
            medicationType: medicationManager.selectedMedication ?? "",
            administrationMethod: medicationManager.selectedAdministrationMethod ?? "",
            routeClass: routeClass,
            doseHistory: medicationManager.doseHistory,
            avoidZones: medicationManager.avoidZones,
            preferredZones: preferredZones,
            recentlyUsedZones: recentlyUsedZones,
            onRecord: { sites in
                selectedSites = sites
                finalizeRecording()
            },
            onBack: { currentStep = 1 },
            onMarkAvoid: markZoneAsAvoid,
            heatMapProvider: { routeClass in
                await medicationManager.injectionSiteHeatMap(for: routeClass)
            }
        )
    }

    // MARK: - Last Location Panel

    private var lastLocationPanel: some View {
        Button {
            showLastSitePreview = true
        } label: {
            HStack(spacing: 10) {
                // Left: pin icon + last zone label
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.Colors.accentSecondary)
                    if let sites = lastInjectionSites, let first = sites.first {
                        Text(sites.count > 1
                             ? "Last dose: \(first.zoneLabel) +\(sites.count - 1)"
                             : "Last dose: \(first.zoneLabel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Center-right: safety indicator
                if let days = lastSiteDaysAgo {
                    HStack(spacing: 4) {
                        if lastSiteIsSafe {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.Colors.warning)
                                .font(.caption)
                        }
                        Text("\(days)d ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.accentSecondary.opacity(0.13))
            )
            .padding(.horizontal, 20)
            .overlay(alignment: .trailing) {
                Button {
                    quickSelectLastSites()
                } label: {
                    Text("Use Same Site →")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(lastSitesContainAvoidZone ? .secondary : Theme.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(lastSitesContainAvoidZone
                                      ? Color(.tertiarySystemFill)
                                      : Theme.Colors.accent.opacity(0.12))
                        )
                }
                .disabled(lastSitesContainAvoidZone)
                .overlay(alignment: .top) {
                    if lastSitesContainAvoidZone {
                        Text("Last site is marked as avoid. Choose a different site.")
                            .font(.caption2)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .offset(y: -28)
                    }
                }
                .padding(.trailing, 28)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Correction Lock Panel

    private func correctionLockPanel(site: InjectionSite) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Previously: \(site.zoneLabel) (\(site.viewContext))")
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Color(.tertiarySystemFill))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func updateMlFromMg() {
        guard concentration > 0 else { return }
        mlAmount = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
    }

    private func prefillFromRecentDose() {
        if isCorrectionMode, let original = originalDose {
            mgAmount = original.doseAmount
            if let conc = original.concentrationMgPerMl {
                concentration = conc
            } else {
                concentration = defaultConcentration
            }
            doseDate = original.doseDate
            updateMlFromMg()
            return
        }

        if let lastDose = medicationManager.lastLoggedDose {
            mgAmount = lastDose.doseAmount
            if let conc = lastDose.concentrationMgPerMl {
                concentration = conc
            } else {
                concentration = defaultConcentration
            }
            updateMlFromMg()
        } else {
            concentration = defaultConcentration
            updateMlFromMg()
        }
    }

    private func advanceToStep2() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentStep = 2
        }
    }

    /// For oral routes: record immediately without site selection.
    private func recordDoseImmediately() {
        let finalMg = doseUnit == "mg" ? mgAmount : mlAmount * concentration
        let finalConcentration = concentration > 0 ? concentration : nil

        guard let medType = medicationManager.selectedMedication,
              let medMethod = medicationManager.selectedAdministrationMethod else { return }

        let ester = resolveEster(medType: medType)

        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        haptic.notificationOccurred(.success)

        medicationManager.addDose(
            date: doseDate,
            type: medType,
            ester: ester,
            method: medMethod,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration,
            injectionSites: []  // oral: no site tracking
        )

        isPresented = false
    }

    private func finalizeRecording() {
        let finalMg = doseUnit == "mg" ? mgAmount : mlAmount * concentration
        let finalConcentration = concentration > 0 ? concentration : nil

        guard let medType = medicationManager.selectedMedication,
              let medMethod = medicationManager.selectedAdministrationMethod else { return }

        let ester = resolveEster(medType: medType)

        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        haptic.notificationOccurred(.success)

        if isCorrectionMode, let original = originalDose {
            medicationManager.replaceDoseWithCorrectedSite(
                originalDose: original,
                newSites: selectedSites
            )
        } else {
            medicationManager.addDose(
                date: doseDate,
                type: medType,
                ester: ester,
                method: medMethod,
                doseAmount: finalMg,
                concentrationMgPerMl: finalConcentration,
                injectionSites: selectedSites,
                isUserCorrected: false,
                originalDoseId: nil,
                originalSites: []
            )
        }

        isPresented = false
    }

    private func quickSelectLastSites() {
        guard let sites = lastInjectionSites, !sites.isEmpty else { return }
        guard !lastSitesContainAvoidZone else { return }
        selectedSites = sites
        finalizeRecording()
    }

    private func markZoneAsAvoid(_ zone: String, reason: String) {
        medicationManager.markZoneAsAvoid(zone, reason: reason)
    }

    private func resolveEster(medType: String) -> String {
        if let recentEster = medicationManager.lastLoggedDose?.ester {
            return recentEster
        }
        if medType == "Estrogen" {
            return "Valerate (EV)"
        }
        return "Cypionate (TC)"
    }

    // MARK: - Volume Warning

    private func quickDoseWarning(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.yellow.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    QuickDoseSheet(isPresented: .constant(true))
        .environment(\.medicationManager, MedicationManager.shared)
}
