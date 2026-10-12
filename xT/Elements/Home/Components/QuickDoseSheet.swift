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
    @State private var mgText: String = "2.0"
    @State private var mlText: String = "0.050"
    @FocusState private var mgFieldFocused: Bool
    @FocusState private var mlFieldFocused: Bool
    @State private var concentration: Double = 40.0
    @State private var showCustomConcentration: Bool = false
    @State private var customConcentrationText: String = ""
    @State private var doseDate: Date = Date()

    // MARK: - Multi-Step Flow State (v2.1)

    @State private var currentStep: Int = 1
    @State private var selectedSites: [InjectionSite] = []
    @State private var isCorrectionMode: Bool
    @State private var originalDose: DoseRecord?
    @State private var isCustomizing = false

    // MARK: - Body Picker Configuration

    private var bodyType: BodyType {
        BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral
    }

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

    /// Dynamic label for the site selection button based on regimen type.
    private var siteSelectionLabel: String {
        switch routeClass {
        case .injection: return "Injection sites"
        case .patch:     return "Patch site"
        case .topical:   return "Cream site"
        case .oral:      return "Choose a Location"
        }
    }

    private var isOral: Bool {
        routeClass == .oral
    }

    // MARK: - Cached dose/site lookups

    // Dose-history lookups that used to recompute on every body evaluation
    // (injectionHeatMap in particular filters all of doseHistory with Calendar
    // math, which ran once per keystroke in the dose fields). Hoisted into
    // state: computed once when the sheet appears and refreshed whenever a
    // dose is recorded or the regimen selection changes.
    @State private var recentlyUsedZones: Set<String> = []
    @State private var injectionHeatMap: [String: Int] = [:]

    /// Preferred zones for the current medication + route combination.
    private var preferredZones: Set<String> {
        let med = medicationManager.selectedMedication ?? ""
        return Set(ZoneCentroidStore.preferredZones(medication: med, routeClass: routeClass))
    }

    private var recommendedZones: Set<String> {
        Set(ZoneCentroidStore.recommendedZones(for: routeClass))
    }

    // Pre-fill concentration from last dose on appear
    private var defaultConcentration: Double {
        medicationManager.resolvedDoseDefaults(
            medication: medicationManager.selectedMedication,
            method: medicationManager.selectedAdministrationMethod
        ).concentrationMgPerMl
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
        .onAppear { refreshSiteCaches() }
        .onChange(of: medicationManager.doseRecordedCount) { _, _ in refreshSiteCaches() }
        .onChange(of: medicationManager.selectedAdministrationMethod) { _, _ in refreshSiteCaches() }
        .onChange(of: medicationManager.selectedMedication) { _, _ in refreshSiteCaches() }
    }

    // MARK: - Step 1: Dose Details

    private var step1DoseDetails: some View {
        Group {
            if isCorrectionMode || isCustomizing {
                doseEditView
            } else {
                doseSummaryView
            }
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
    }

    // MARK: Summary view (read-only prefill)

    private var doseSummaryView: some View {
        VStack(spacing: 16) {
            Text("Record Dose")
                .font(Theme.Fonts.headline)
                .padding(.top, 8)

            HStack {
                Image(systemName: "pills.fill")
                    .foregroundStyle(Theme.Colors.accent)
                Text(medicationManager.medicationDisplayInfo)
                    .font(Theme.Fonts.subheadline)
                Spacer()
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                summaryRow(label: "Dose",
                           value: "\(AppNumberFormatters.dose.string(mgAmount)) mg  (\(AppNumberFormatters.volume.string(mlAmount)) mL)")

                Divider()

                summaryRow(label: "Concentration",
                           value: "\(AppNumberFormatters.concentration.string(concentration)) mg/mL")

                Divider()

                summaryRow(label: "Date",
                           value: doseDate.formatted(date: .abbreviated, time: .shortened))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color(.secondarySystemBackground)))
            .padding(.horizontal, 20)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isCustomizing = true
                }
            } label: {
                Text("Customize Regimen")
                    .font(Theme.Fonts.subheadline.weight(.medium))
            }

            Spacer()

            if !isOral {
                Button {
                    advanceToStep2()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(siteSelectionLabel)
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(Theme.Colors.accent.opacity(0.5), lineWidth: 1.5))
                }
                .padding(.horizontal, 20)
            }

            AccentActionButton(title: "Record Dose") {
                recordDoseImmediately()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 4)

        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Fonts.subheadline.weight(.medium))
        }
    }

    // MARK: Edit view (customize regimen)

    private var doseEditView: some View {
        VStack(spacing: 16) {
            HStack {
                if isCustomizing {
                    Button {
                        commitActiveField()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isCustomizing = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }.font(Theme.Fonts.subheadline)
                    }
                    Spacer()
                }
                Text(isCorrectionMode ? "Correct Site" : "Customize Regimen")
                    .font(Theme.Fonts.headline)
                if isCustomizing {
                    Spacer().frame(width: 60)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)

            HStack {
                Image(systemName: "pills.fill")
                    .foregroundStyle(Theme.Colors.accent)
                Text(medicationManager.medicationDisplayInfo)
                    .font(Theme.Fonts.subheadline)
                Spacer()
            }
            .padding(.horizontal, 20)

            if isCorrectionMode, let original = originalDose, let primary = original.primarySite {
                correctionLockPanel(site: primary)
            }

            Picker("Dose Unit", selection: $doseUnit) {
                Text("mg").tag("mg")
                Text("mL").tag("mL")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .disabled(isCorrectionMode)

            if doseUnit == "mg" {
                HStack(spacing: 12) {
                    TextField("mg", text: $mgText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .focused($mgFieldFocused)
                        .onSubmit { commitMgText() }
                        .onChange(of: mgFieldFocused) { _, focused in
                            if !focused { commitMgText() }
                        }
                    Text("mg")
                        .font(Theme.Fonts.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .disabled(isCorrectionMode)

                let volume = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
                Text("= \(AppNumberFormatters.volume.string(volume)) mL (@ \(AppNumberFormatters.concentration.string(concentration)) mg/mL)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                if let warning = MedicationManager.volumeNote(for: volume, ester: medicationManager.lastLoggedDose?.ester) {
                    quickDoseWarning(warning)
                }
            } else {
                HStack(spacing: 12) {
                    TextField("mL", text: $mlText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .focused($mlFieldFocused)
                        .onSubmit { commitMlText() }
                        .onChange(of: mlFieldFocused) { _, focused in
                            if !focused { commitMlText() }
                        }
                    Text("mL")
                        .font(Theme.Fonts.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .disabled(isCorrectionMode)

                let computedMg = mlAmount * concentration
                Text("= \(AppNumberFormatters.dose.string(computedMg)) mg (@ \(AppNumberFormatters.concentration.string(concentration)) mg/mL)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                if let warning = MedicationManager.volumeNote(for: mlAmount, ester: medicationManager.lastLoggedDose?.ester) {
                    quickDoseWarning(warning)
                }
            }

            if !isCorrectionMode {
                VStack(spacing: 6) {
                    Text("Vial concentration")
                        .font(Theme.Fonts.caption)
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
                                    Text(verbatim: AppNumberFormatters.concentration.string(conc))
                                        .font(Theme.Fonts.caption)
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
                                    .font(Theme.Fonts.caption)
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

            if !isCorrectionMode {
                DisclosureGroup("Change date\u{2026}") {
                    DatePicker("", selection: $doseDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Text(doseDate.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.Fonts.subheadline)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            Spacer()

            if isCustomizing {
                AccentActionButton(title: "Done") {
                    commitActiveField()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCustomizing = false
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else if isCorrectionMode {
                AccentActionButton(title: "Choose New Site", systemImage: "arrow.triangle.swap") {
                    currentStep = 2
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    commitActiveField()
                    mgFieldFocused = false
                    mlFieldFocused = false
                } label: {
                    Text("Done")
                        .font(Theme.Fonts.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .paperCard(padding: 0, radius: Theme.Radius.md)
                }
            }
        }
    }

    // MARK: - Step 2: Body Site Picker

    @State private var selectedZoneLabels3D: [String] = []
    @State private var bodySnapAngle: BodySnapAngle = .front
    @State private var bodySnapNonce: Int = 0
    @State private var showOverlapDisclaimer = false
    @State private var tapPositions: [String: BodyModel3DView.HitPosition] = [:]
    /// Marks taps that land on the body but outside any clinical zone.
    @State private var noZoneTaps = NoZoneTapTracker()
    /// Live camera yaw in radians, used to record which side of the body was tapped.
    @State private var cameraYaw: Float = 0
    @State private var showInfoPanel = false
    @State private var multiSiteEnabled = false
    @State private var showRecommendedZonesInfo = false

    private typealias UndoState = (labels: [String], positions: [String: BodyModel3DView.HitPosition])
    @State private var undoStack: [UndoState] = []
    @State private var redoStack: [UndoState] = []

    private var step2BodySitePicker: some View {
        step23DBodyPicker
    }

    // MARK: - 3D Body Picker (experimental)

    private var step23DBodyPicker: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { withAnimation { currentStep = 1 } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }.font(Theme.Fonts.subheadline)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            // 3D body view
            ZStack(alignment: .center) {
                BodyModel3DView(
                    heatMapData: injectionHeatMap,
                    avoidZones: medicationManager.avoidZoneLabels,
                    preferredZones: preferredZones,
                    recommendedZones: recommendedZones,
                    selectedSites: $selectedZoneLabels3D,
                    maxSelections: multiSiteEnabled ? 2 : 1,
                    bodyType: bodyType,
                    snapAngle: bodySnapAngle,
                    snapNonce: bodySnapNonce,
                    onTapZone: { _, overlaps in
                        if overlaps {
                            showOverlapDisclaimer = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                showOverlapDisclaimer = false
                            }
                        }
                    },
                    tapPositions: $tapPositions,
                    onPreTap: { oldLabels, oldPositions in
                        undoStack.append((oldLabels, oldPositions))
                        redoStack.removeAll()
                    },
                    onNoZoneTap: { point in
                        noZoneTaps.record(at: point)
                    },
                    onYawChange: { yaw in
                        cameraYaw = yaw
                    }
                )
                .noZoneMarkers($noZoneTaps.taps)

                if showRecommendedZonesInfo {
                    recommendedZonesOverlay
                        .transition(.opacity.combined(with: .scale(0.95)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .padding(.horizontal, 12)
            .onAppear {
                showRecommendedZonesInfo = !UserDefaults.standard.bool(forKey: "hasSeenRecommendedZonesInfo")
            }

            // Guided orbit controls
            body3DOrbitControls
                .padding(.top, 10)

            VStack(spacing: 8) {
                if !selectedZoneLabels3D.isEmpty {
                    ForEach(selectedZoneLabels3D, id: \.self) { zone in
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.Colors.accent)
                            Text(zone).font(Theme.Fonts.subheadline)
                            Spacer()
                            Button {
                                selectedZoneLabels3D.removeAll { $0 == zone }
                                tapPositions.removeValue(forKey: zone)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(Theme.Colors.accent.opacity(0.12)))
                    }

                    if showOverlapDisclaimer {
                        Text("Site close to previous site.")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    Text("Tap the model to set site")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 64, alignment: .top)
            .padding(.horizontal, 20).padding(.top, 8)
            .animation(.easeInOut(duration: 0.25), value: showOverlapDisclaimer)

            Spacer()

            AccentActionButton(
                title: "Record Dose",
                systemImage: "checkmark.circle.fill",
                isDisabled: selectedZoneLabels3D.isEmpty
            ) {
                let now = Date()
                // Derived from the live camera yaw, not the snap-angle selection: a user can
                // free-pan to the back without changing the selected snap angle.
                let derivedViewContext = ZoneCentroidStore.viewContext(from: cameraYaw)
                selectedSites = selectedZoneLabels3D.map { zoneLabel in
                    let pos = tapPositions[zoneLabel]
                    return InjectionSite(
                        zoneLabel: zoneLabel,
                        bodyRegion: ZoneCentroidStore.shared.region(for: zoneLabel) ?? InjectionSite.unknownFallback,
                        viewContext: derivedViewContext,
                        worldPosition: pos.map { (x: $0.worldX, y: $0.worldY, z: $0.worldZ) },
                        viewNormal: pos.map { (x: $0.normalX, y: $0.normalY, z: $0.normalZ) },
                        lastUsedDate: now,
                        durationDays: routeClass.defaultDurationDays,
                        routeClass: routeClass.rawValue
                    )
                }
                finalizeRecording()
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private var recommendedZonesOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            VStack(spacing: 20) {
                Image(systemName: "lightspectral.horizontal")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Shaded areas are the sites commonly used for this route.")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showRecommendedZonesInfo = false
                    }
                    UserDefaults.standard.set(true, forKey: "hasSeenRecommendedZonesInfo")
                } label: {
                    Text("OK")
                        .font(Theme.Fonts.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxWidth: 260, maxHeight: 282)
    }

    /// Front / Back toggle + step-left / step-right orbit arrows.
    private var body3DOrbitControls: some View {
        HStack(spacing: 16) {
            // Step orbit -90°
            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + angles.count - 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer()

            // Front / Back primary toggle
            HStack(spacing: 0) {
                ForEach([BodySnapAngle.front, .back], id: \.rawValue) { angle in
                    Button {
                        bodySnapAngle = angle
                        bodySnapNonce += 1
                    } label: {
                        Text(angle.label)
                            .font(Theme.Fonts.subheadline.weight(bodySnapAngle == angle ? .semibold : .regular))
                            .foregroundStyle(bodySnapAngle == angle
                                             ? Theme.Colors.accent
                                             : Color(.secondaryLabel))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bodySnapAngle == angle
                                          ? Theme.Colors.accent.opacity(0.12)
                                          : Color.clear)
                            )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemFill)))

            Spacer()

            // Info button
            Button {
                showInfoPanel.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .popover(isPresented: $showInfoPanel, arrowEdge: .bottom) {
                infoPanel
            }

            // Step orbit +90°
            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 28)
    }

    private var infoPanel: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $multiSiteEnabled) {
                Text("Multi-Site")
                    .font(Theme.Fonts.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider()

            HStack(spacing: 0) {
                Button {
                    undoLastTap()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(undoStack.isEmpty)
                .foregroundStyle(undoStack.isEmpty ? Color(.tertiaryLabel) : Theme.Colors.accent)

                Divider().frame(height: 28)

                Button {
                    redoLastTap()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(redoStack.isEmpty)
                .foregroundStyle(redoStack.isEmpty ? Color(.tertiaryLabel) : Theme.Colors.accent)
            }

            Divider()

            Button {
                showInfoPanel = false
            } label: {
                Text("Done")
                    .font(Theme.Fonts.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(Theme.Colors.accent)
        }
        .frame(width: 180)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func undoLastTap() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append((selectedZoneLabels3D, tapPositions))
        selectedZoneLabels3D = previous.labels
        tapPositions = previous.positions
    }

    private func redoLastTap() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append((selectedZoneLabels3D, tapPositions))
        selectedZoneLabels3D = next.labels
        tapPositions = next.positions
    }

    /// Recomputes the hoisted dose-history lookups. Runs on appear and whenever
    /// the dose history changes (`doseRecordedCount` bumps on every recorded
    /// dose) or the regimen selection changes — so the heat map no longer
    /// re-filters `doseHistory` on every body evaluation.
    private func refreshSiteCaches() {
        recentlyUsedZones = medicationManager.recentlyUsedZones(withinDays: routeClass.defaultRotationWindowDays)

        var heat: [String: Int] = [:]
        let doses = medicationManager.doseHistory.filter { dose in
            guard RouteClass.from(method: dose.administrationMethod) == routeClass else { return false }
            guard let days = Calendar.current.dateComponents([.day], from: dose.doseDate, to: Date()).day else { return false }
            return days <= routeClass.heatMapWindowDays
        }
        for dose in doses {
            for site in dose.injectionSites {
                guard site.routeClass == routeClass.rawValue || site.routeClass == "injection" else { continue }
                heat[site.zoneLabel, default: 0] += 1
            }
        }
        injectionHeatMap = heat
    }

    // MARK: - Correction Lock Panel

    private func correctionLockPanel(site: InjectionSite) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(Theme.Fonts.caption)
            Text("Previously: \(site.zoneLabel) (\(site.viewContext))")
                .font(Theme.Fonts.subheadline)
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
        if !mlFieldFocused {
            mlText = String(format: "%.3f", mlAmount)
        }
    }

    private func commitMgText() {
        if let val = Double(mgText), val > 0 {
            mgAmount = val
            updateMlFromMg()
        } else {
            mgText = String(format: "%.1f", mgAmount)
        }
    }

    private func commitMlText() {
        if let val = Double(mlText), val > 0 {
            mlAmount = val
            mgAmount = val * concentration
            mgText = String(format: "%.1f", mgAmount)
        } else {
            mlText = String(format: "%.3f", mlAmount)
        }
    }

    /// Parses the text field backing the currently selected dose unit.
    /// The decimal-pad TextFields only commit on submit (never fires — the pad
    /// has no return key) or focus loss (unreliable when the field is torn down
    /// by in-sheet navigation, e.g. the customize "Done" button), so any action
    /// that reads the dose must commit explicitly first.
    private func commitActiveField() {
        if doseUnit == "mg" {
            commitMgText()
        } else {
            commitMlText()
        }
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
            mgText = String(format: "%.1f", mgAmount)
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
        mgText = String(format: "%.1f", mgAmount)
    }

    private func advanceToStep2() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentStep = 2
        }
    }

    /// For oral routes: record immediately without site selection.
    private func recordDoseImmediately() {
        commitActiveField()
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
        commitActiveField()
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

    private func resolveEster(medType: String) -> String {
        medicationManager.resolvedDoseDefaults(
            medication: medType,
            method: medicationManager.selectedAdministrationMethod
        ).esterName
    }

    // MARK: - Volume Warning

    private func quickDoseWarning(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.yellow)
            Text(message)
                .font(Theme.Fonts.caption2)
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

#if DEBUG
#Preview {
    QuickDoseSheet(isPresented: .constant(true))
        .environment(\.medicationManager, MedicationManager.shared)
}
#endif
