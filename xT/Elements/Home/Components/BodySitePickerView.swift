//
//  BodySitePickerView.swift
//  xT
//
//  Main orchestration view for injection/gel/patch site selection.
//  Two-level navigation (overview → detail sketch), multi-site support,
//  async heat map, dead-space snap, avoid zone marking, patch duration.
//

import SwiftUI
import UIKit

struct BodySitePickerView: View {
    // MARK: - Input
    let medicationType: String
    let administrationMethod: String
    let routeClass: RouteClass
    let doseHistory: [DoseRecord]
    let avoidZones: [String: AvoidZoneInfo]
    let preferredZones: Set<String>
    let recentlyUsedZones: Set<String>
    let onRecord: ([InjectionSite]) -> Void
    let onBack: () -> Void
    let onMarkAvoid: (String, String) -> Void
    var heatMapProvider: ((RouteClass) async -> [String: Int])? = nil

    // MARK: - State
    @State private var selectedFrontBack: String = "Front"
    @State private var selectedArmsMidsection: String = "Midsection"
    @State private var navigationStack: [String] = []  // overview → detail sketchId
    @State private var selectedSites: [(zone: String, coordinate: CGPoint)] = []
    @AppStorage("showHeatMap") private var showHeatMap: Bool = true
    @AppStorage("injectionSiteSnapToZone") private var snapToZone: Bool = false
    @State private var showRotationWarning: Bool = false
    @State private var warningZone: String = ""
    @State private var nearestPreviewZone: String? = nil
    @State private var showSnapRipple: Bool = false
    @State private var rippleCentroid: CGPoint = .zero
    @State private var isHeatMapLoading: Bool = false
    @State private var heatMapData: [String: Int] = [:]
    @State private var patchDurationDays: Int = 7
    @State private var showAvoidMarkSheet: Bool = false
    @State private var avoidMarkZone: String = ""
    @State private var avoidMarkReason: String = ""
    @State private var lastTapTime: Date = .distantPast
    @State private var pendingRotationCoordinate: CGPoint? = nil
    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var snapTask: Task<Void, Never>? = nil

    private var reduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Computed

    private var currentSketchId: String? {
        navigationStack.last
    }

    private var isShowingDetail: Bool {
        navigationStack.count > 0
    }

    private var sanitizedFrontBack: String {
        selectedFrontBack.lowercased() == "back" ? "Back" : "Front"
    }

    private var currentViewContext: String {
        sanitizedFrontBack.lowercased()
    }

    /// Convert selectedSites to the (zone, index) format expected by zone overlay views.
    private var selectedSiteIndices: [(zone: String, index: Int)] {
        selectedSites.enumerated().map { ($0.element.zone, $0.offset + 1) }
    }

    private var defaultSnapEnabled: Bool {
        !routeClass.requiresPreciseTap || UIAccessibility.isVoiceOverRunning
    }

    private var activePatchDays: [String: Int] {
        guard routeClass == .patch else { return [:] }
        let now = Date()
        var result: [String: Int] = [:]
        for dose in doseHistory where dose.isActive {
            for site in dose.injectionSites {
                let activeEnd = Calendar.current.date(byAdding: .day, value: site.durationDays, to: dose.doseDate) ?? dose.doseDate
                let remaining = Calendar.current.dateComponents([.day], from: now, to: activeEnd).day ?? 0
                if remaining > 0 {
                    result[site.zoneLabel] = max(result[site.zoneLabel] ?? 0, remaining)
                }
            }
        }
        return result
    }

    private var daysSinceUse: [String: Int] {
        let now = Date()
        var result: [String: Int] = [:]
        for dose in doseHistory where dose.isActive {
            for site in dose.injectionSites {
                let days = Calendar.current.dateComponents([.day], from: dose.doseDate, to: now).day ?? 0
                if let existing = result[site.zoneLabel] {
                    result[site.zoneLabel] = min(existing, days)
                } else {
                    result[site.zoneLabel] = days
                }
            }
        }
        return result
    }

    private var allPreferredAreAvoided: Bool {
        let pref = preferredZones
        guard !pref.isEmpty else { return false }
        return pref.allSatisfy { avoidZones[$0] != nil }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            segmentedPickers

            if allPreferredAreAvoided {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("All preferred zones are marked as avoid. Consider reviewing your avoid zones in Settings.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 8)
            }

            ZStack {
                if isShowingDetail {
                    detailSketchArea
                } else {
                    overviewSketchArea
                }

                // Snap ripple overlay
                if showSnapRipple {
                    snapRippleView
                }
            }
            .frame(maxHeight: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay {
                if isShowingDetail, let sketchId = currentSketchId {
                    GeometryReader { geo in
                        accessibilityZoneLayer(sketchId: sketchId, geo: geo)
                    }
                }
            }
            .overlay {
                if isHeatMapLoading && !reduceMotionEnabled {
                    Rectangle()
                        .fill(.gray.opacity(0.08))
                        .modifier(ShimmerEffect())
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 12)

            // Patch duration picker (show for patch route before and after site selection)
            if routeClass == .patch {
                patchDurationPicker
            }

            // Zone label
            zoneLabelView

            // Multi-site pill bar
            if routeClass.supportsMultiSite && !selectedSites.isEmpty {
                multiSitePillBar
            }

            // Record button
            recordButton
        }
        .navigationBarBackButtonHidden(true)
        .alert("Rotation Warning", isPresented: $showRotationWarning) {
            Button("Use Anyway", role: .destructive) {
                if let coord = pendingRotationCoordinate {
                    appendSite(label: warningZone, coordinate: coord)
                }
            }
            Button("Choose Different", role: .cancel) {
                pendingRotationCoordinate = nil
            }
        } message: {
            Text(rotationWarningMessage)
        }
        .sheet(isPresented: $showAvoidMarkSheet) {
            avoidMarkSheet
        }
        .task {
            await loadHeatMap()
        }
        .onDisappear { snapTask?.cancel() }
        .onChange(of: showHeatMap) { _, newValue in
            if newValue { Task { await loadHeatMap() } }
        }
        .onChange(of: doseHistory.count) { _, _ in
            if showHeatMap { Task { await loadHeatMap() } }
        }
        .onChange(of: navigationStack) { _ in
            currentZoom = 1.0
            lastZoom = 1.0
        }
        .onChange(of: selectedArmsMidsection) { val in
            if val == "Arms" && !isShowingDetail {
                navigateToDetail(sanitizedFrontBack == "Back" ? "armsBack" : "armsFront")
            }
        }
        .onChange(of: selectedFrontBack) { _ in
            currentZoom = 1.0
            lastZoom = 1.0
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
            }
            .accessibilityLabel("Close")

            if isShowingDetail {
                Button { popToOverview() } label: {
                    Text("← Back")
                        .font(.subheadline)
                }
                .accessibilityLabel("Back to body overview")
            }

            Spacer()

            Button {
                showHeatMap.toggle()
            } label: {
                Image(systemName: showHeatMap ? "flame.fill" : "flame")
                    .foregroundStyle(showHeatMap ? Theme.Colors.accent : .secondary)
            }
            .accessibilityLabel(showHeatMap ? "Heat map on" : "Heat map off")
            .accessibilityHint("Toggles zone usage history overlay")

            Button {
                snapToZone.toggle()
            } label: {
                Image(systemName: snapToZone ? "magnet.fill" : "magnet")
                    .foregroundStyle(snapToZone ? Theme.Colors.accentSecondary : .secondary)
            }
            .accessibilityLabel(snapToZone ? "Snap to zone on" : "Snap to zone off")
            .accessibilityHint("When on, taps snap to the nearest zone centroid")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Segmented Pickers

    private var segmentedPickers: some View {
        VStack(spacing: 6) {
            Picker("View", selection: $selectedFrontBack) {
                Text("Front").tag("Front")
                Text("Back").tag("Back")
            }
            .pickerStyle(.segmented)

            if !isShowingDetail {
                Picker("Region", selection: $selectedArmsMidsection) {
                    Text("Arms").tag("Arms")
                    Text("Midsection").tag("Midsection")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSketchArea: some View {
        GeometryReader { geo in
            ZStack {
                if sanitizedFrontBack == "Front" && selectedArmsMidsection == "Arms" {
                    Group {
                        OverviewFrontArmsSilhouette()
                            .fill(Color.gray.opacity(0.12))
                        OverviewFrontArmsOverlay(onNavigateToDetail: { navigateToDetail($0) })
                    }
                    .transition(.opacity)
                } else if sanitizedFrontBack == "Back" && selectedArmsMidsection == "Arms" {
                    Group {
                        OverviewBackArmsSilhouette()
                            .fill(Color.gray.opacity(0.12))
                        OverviewBackArmsOverlay(onNavigateToDetail: { navigateToDetail($0) })
                    }
                    .transition(.opacity)
                } else if sanitizedFrontBack == "Front" && selectedArmsMidsection == "Midsection" {
                    Group {
                        OverviewFrontMidsectionSilhouette()
                            .fill(Color.gray.opacity(0.12))
                        OverviewFrontMidsectionOverlay(onNavigateToDetail: { navigateToDetail($0) })
                    }
                    .transition(.opacity)
                } else {
                    Group {
                        OverviewBackMidsectionSilhouette()
                            .fill(Color.gray.opacity(0.12))
                        OverviewBackMidsectionOverlay(onNavigateToDetail: { navigateToDetail($0) })
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height * 0.85)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .animation(.easeInOut(duration: 0.2), value: sanitizedFrontBack)
            .animation(.easeInOut(duration: 0.2), value: selectedArmsMidsection)
        }
    }

    // MARK: - Detail Sketch

    @ViewBuilder
    private var detailSketchArea: some View {
        let sketchId = currentSketchId ?? "thighsFront"

        GeometryReader { geo in
            let sketchContent = ZStack {
                silhouetteView(for: sketchId)

                // Dead-space tap handler (on the background)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { point in
                        handleTap(at: point, sketchId: sketchId, geo: geo)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onEnded { value in
                                if case .second(true, let drag?) = value {
                                    handleLongPress(at: drag.startLocation, sketchId: sketchId, geo: geo)
                                }
                            }
                    )

                // Zone overlays
                zoneOverlayFor(sketchId: sketchId)
            }
            .scaleEffect(currentZoom)

            if routeClass.requiresPreciseTap {
                sketchContent
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let delta = value.magnification / lastZoom
                                lastZoom = value.magnification
                                let newZoom = currentZoom * delta
                                currentZoom = min(max(newZoom, 1.0), 3.0)
                            }
                            .onEnded { _ in
                                lastZoom = 1.0
                            }
                    )
            } else {
                sketchContent
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }

    @ViewBuilder
    private func silhouetteView(for sketchId: String) -> some View {
        switch sketchId {
        case "thighsFront":    ThighsFrontSilhouette().fill(Color.gray.opacity(0.12))
        case "thighsBack":     ThighsBackSilhouette().fill(Color.gray.opacity(0.12))
        case "glutesBack":     GlutesBackSilhouette().fill(Color.gray.opacity(0.12))
        case "armsFront":      ArmsFrontSilhouette().fill(Color.gray.opacity(0.12))
        case "armsBack":       ArmsBackSilhouette().fill(Color.gray.opacity(0.12))
        case "upperBodyFront": UpperBodyFrontSilhouette().fill(Color.gray.opacity(0.12))
        default:               ThighsFrontSilhouette().fill(Color.gray.opacity(0.12))
        }
    }

    @ViewBuilder
    private func zoneOverlayFor(sketchId: String) -> some View {
        switch sketchId {
        case "thighsFront":
            ThighsFrontZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        case "thighsBack":
            ThighsBackZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        case "glutesBack":
            GlutesBackZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        case "armsFront":
            ArmsFrontZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        case "armsBack":
            ArmsBackZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        case "upperBodyFront":
            UpperBodyFrontZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        default:
            ThighsFrontZoneOverlay(
                selectedSites: selectedSiteIndices,
                heatMap: heatMapData,
                recentlyUsedZones: recentlyUsedZones,
                preferredZones: preferredZones,
                avoidZones: avoidZones,
                routeClass: routeClass,
                isHeatMapLoading: isHeatMapLoading,
                reduceMotionEnabled: reduceMotionEnabled,
                activePatchDays: activePatchDays,
                daysSinceUse: daysSinceUse,
                nearestPreviewZone: nearestPreviewZone,
                onTap: { _ in },
                onLongPress: { markAvoidZone($0) }
            )
        }
    }

    // MARK: - Snap Ripple

    private var snapRippleView: some View {
        Circle()
            .fill(Theme.Colors.accent.opacity(0.2))
            .frame(width: 10, height: 10)
            .position(rippleCentroid)
            .scaleEffect(showSnapRipple ? 10 : 0.5)
            .opacity(showSnapRipple ? 0 : 1)
            .animation(reduceMotionEnabled ? nil : .easeOut(duration: 0.3), value: showSnapRipple)
    }

    // MARK: - Patch Duration

    private var patchDurationPicker: some View {
        HStack {
            Text("Wear duration:")
                .font(.subheadline)
            Picker("Days", selection: $patchDurationDays) {
                Text("3 days").tag(3)
                Text("5 days").tag(5)
                Text("7 days").tag(7)
                Text("10 days").tag(10)
            }
            .pickerStyle(.menu)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Zone Label

    private var zoneLabelView: some View {
        HStack(spacing: 6) {
            if isShowingDetail, !selectedSites.isEmpty {
                Text(currentSketchContextLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Group {
                if let preview = nearestPreviewZone {
                    Text("Nearest: \(preview)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.accentSecondary)
                } else if let lastSelected = selectedSites.last {
                    Text(selectedSites.count > 1
                         ? "\(selectedSites.count) sites selected"
                         : lastSelected.zone)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text("Tap a zone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 28)
    }

    private var currentSketchContextLabel: String {
        guard let sketchId = currentSketchId else { return "" }
        return BodySketchData.sketchViewContext[sketchId] == "back" ? "Back" : "Front"
    }

    // MARK: - Multi-Site Pill Bar

    private var multiSitePillBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedSites.indices, id: \.self) { i in
                    HStack(spacing: 4) {
                        Text("\(i + 1). \(selectedSites[i].zone)")
                            .font(.caption)
                        Button {
                            if i < selectedSites.count { selectedSites.remove(at: i) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Site \(i + 1): \(selectedSites[i].zone)")
                    .accessibilityHint("Activate to remove")
                    .accessibilityAddTraits(.isButton)
                }

            }
            .padding(.horizontal, 16)
        }
        .frame(height: 36)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            recordSites()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                Text("Record")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedSites.isEmpty
                        ? Theme.Colors.accent.opacity(0.4)
                        : Theme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .disabled(selectedSites.isEmpty)
        .accessibilityHint(selectedSites.isEmpty ? "Select at least one site first" : "Records dose with selected sites")
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Avoid Mark Sheet

    private var avoidMarkSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Mark as Avoid Zone")
                    .font(.headline)
                Text(avoidMarkZone)
                    .font(.title3)
                    .fontWeight(.medium)
                TextField("Reason (optional)", text: $avoidMarkReason)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                HStack(spacing: 20) {
                    Button("Cancel") {
                        showAvoidMarkSheet = false
                        avoidMarkReason = ""
                    }
                    Button("Mark as Avoid") {
                        onMarkAvoid(avoidMarkZone, avoidMarkReason)
                        showAvoidMarkSheet = false
                        avoidMarkReason = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.accent)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAvoidMarkSheet = false
                        avoidMarkReason = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func navigateToDetail(_ sketchId: String) {
        withAnimation(reduceMotionEnabled ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) {
            navigationStack.append(sketchId)
        }
    }

    private func popToOverview() {
        withAnimation(reduceMotionEnabled ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) {
            if !navigationStack.isEmpty {
                navigationStack.removeLast()
            }
        }
    }

    private func handleTap(at point: CGPoint, sketchId: String, geo: GeometryProxy) {
        // 300ms debounce
        guard Date().timeIntervalSince(lastTapTime) > 0.3 else { return }
        lastTapTime = Date()

        let normalized = CGPoint(
            x: (point.x / (geo.size.width * currentZoom)) + (currentZoom - 1) / (2 * currentZoom),
            y: (point.y / (geo.size.height * currentZoom)) + (currentZoom - 1) / (2 * currentZoom)
        )

        if let label = BodySketchData.zoneLabel(forTap: normalized, sketchId: sketchId, routeClass: routeClass) {
            // Check if avoid zone
            if avoidZones[label] != nil { return }

            // Check rotation warning — defer append to alert button action
            if recentlyUsedZones.contains(label) {
                warningZone = label
                pendingRotationCoordinate = normalized
                showRotationWarning = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }

            // Snap to zone centroid when snap is on or route doesn't require precise taps
            let snapCoord = (snapToZone || defaultSnapEnabled)
                ? (BodySketchData.zoneCentroid(for: label, sketchId: sketchId, routeClass: routeClass) ?? normalized)
                : normalized
            appendSite(label: label, coordinate: snapCoord)
        } else {
            // Dead-space snap — always active regardless of snapToZone toggle
            handleDeadSpaceSnap(at: normalized, sketchId: sketchId, geo: geo)
        }
    }

    private func appendSite(label: String, coordinate: CGPoint) {
        let selGen = UISelectionFeedbackGenerator()
        selGen.prepare()
        selGen.selectionChanged()
        if routeClass.supportsMultiSite == false && !selectedSites.isEmpty {
            selectedSites = [(zone: label, coordinate: coordinate)]
        } else {
            selectedSites.append((zone: label, coordinate: coordinate))
        }
        nearestPreviewZone = nil
    }

    private func handleDeadSpaceSnap(at point: CGPoint, sketchId: String, geo: GeometryProxy) {
        guard let nearest = BodySketchData.nearestZone(to: point, sketchId: sketchId, routeClass: routeClass)
        else { return }

        nearestPreviewZone = nearest.label

        // Reduce Motion: skip animation but still record the snap
        if reduceMotionEnabled {
            nearestPreviewZone = nil
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            appendSite(label: nearest.label, coordinate: nearest.centroid)
            return
        }

        // Animated path: show ripple then snap after 0.3s
        rippleCentroid = CGPoint(
            x: nearest.centroid.x * geo.size.width,
            y: nearest.centroid.y * geo.size.height
        )
        showSnapRipple = true

        snapTask?.cancel()
        snapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            showSnapRipple = false
            nearestPreviewZone = nil
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            appendSite(label: nearest.label, coordinate: nearest.centroid)
        }
    }

    private func handleLongPress(at point: CGPoint, sketchId: String, geo: GeometryProxy) {
        let normalized = CGPoint(
            x: (point.x / (geo.size.width * currentZoom)) + (currentZoom - 1) / (2 * currentZoom),
            y: (point.y / (geo.size.height * currentZoom)) + (currentZoom - 1) / (2 * currentZoom)
        )
        if let label = BodySketchData.zoneLabel(forTap: normalized, sketchId: sketchId, routeClass: routeClass) {
            markAvoidZone(label)
        }
    }

    private func zoneAccessibilityLabel(zone: String, sketchId: String) -> String {
        let viewContext = BodySketchData.sketchViewContext[sketchId] ?? "front"
        let viewLabel = viewContext == "back" ? "back view" : "front view"
        if let info = avoidZones[zone] {
            return info.reason.isEmpty
                ? "\(zone), \(viewLabel), marked as avoid"
                : "\(zone), \(viewLabel), marked as avoid: \(info.reason)"
        }
        if let patchDay = activePatchDays[zone] {
            return "\(zone), \(viewLabel), patch active, \(patchDay) day\(patchDay == 1 ? "" : "s") remaining"
        }
        return "\(zone), \(viewLabel)"
    }

    private func handleZoneTapForAccessibility(zone: String, sketchId: String) {
        guard avoidZones[zone] == nil else {
            UIAccessibility.post(notification: .announcement, argument: "\(zone) is marked as avoid")
            return
        }
        let coord = BodySketchData.zoneCentroid(for: zone, sketchId: sketchId, routeClass: routeClass) ?? CGPoint(x: 0.5, y: 0.5)
        if recentlyUsedZones.contains(zone) {
            warningZone = zone
            pendingRotationCoordinate = coord
            showRotationWarning = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            appendSite(label: zone, coordinate: coord)
        }
    }

    @ViewBuilder
    private func accessibilityZoneLayer(sketchId: String, geo: GeometryProxy) -> some View {
        let rects = BodySketchData.zoneBoundingRects[sketchId] ?? [:]
        ForEach(Array(rects.keys), id: \.self) { zone in
            let rect = rects[zone]!
            Color.clear
                .frame(width: rect.width * geo.size.width, height: rect.height * geo.size.height)
                .position(x: rect.midX * geo.size.width, y: rect.midY * geo.size.height)
                .contentShape(Rectangle())
                .allowsHitTesting(false)
                .accessibilityLabel(zoneAccessibilityLabel(zone: zone, sketchId: sketchId))
                .accessibilityHint(avoidZones[zone] != nil ? "Long press to unmark as avoid" : "Activate to select")
                .accessibilityValue(selectedSites.contains { $0.zone == zone } ? "Selected" : "")
                .accessibilityAddTraits(avoidZones[zone] != nil ? [] : .isButton)
                .accessibilityAction {
                    handleZoneTapForAccessibility(zone: zone, sketchId: sketchId)
                }
        }
    }

    private func markAvoidZone(_ zone: String) {
        avoidMarkZone = zone
        avoidMarkReason = ""
        showAvoidMarkSheet = true
    }

    private func recordSites() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        haptic.notificationOccurred(.success)

        let viewContext = BodySketchData.sketchViewContext[currentSketchId ?? "thighsFront"] ?? "front"
        let bodyRegion = BodySketchData.sketchToRegion[currentSketchId ?? "thighsFront"] ?? "unknown"

        let sites = selectedSites.map { entry in
            InjectionSite(
                sketchId: currentSketchId ?? "thighsFront",
                normalizedX: Double(entry.coordinate.x),
                normalizedY: Double(entry.coordinate.y),
                zoneLabel: entry.zone,
                viewContext: viewContext,
                bodyRegion: bodyRegion,
                routeClass: routeClass.rawValue,
                durationDays: routeClass == .patch ? patchDurationDays : routeClass.defaultDurationDays
            )
        }

        onRecord(sites)
    }

    private var rotationWarningMessage: String {
        let days = daysSinceLastDose(in: warningZone)
        if let d = days {
            return "You used \(warningZone) \(d) day\(d == 1 ? "" : "s") ago. Rotate to a different site?"
        }
        return "You used \(warningZone) recently. Rotate to a different site?"
    }

    private func daysSinceLastDose(in zone: String) -> Int? {
        let now = Date()
        let sortedDoses = doseHistory
            .filter { $0.isActive }
            .flatMap { dose in
                dose.injectionSites.filter { $0.zoneLabel == zone }.map { (dose.doseDate, $0.durationDays) }
            }
            .sorted { $0.0 > $1.0 }
        guard let first = sortedDoses.first else { return nil }
        return Calendar.current.dateComponents([.day], from: first.0, to: now).day
    }

    private func loadHeatMap() async {
        guard showHeatMap, routeClass.heatMapWindowDays > 0 else { return }

        isHeatMapLoading = true
        defer { isHeatMapLoading = false }

        if let provider = heatMapProvider {
            let counts = await provider(routeClass)
            await MainActor.run { withAnimation(.easeIn(duration: 0.25)) { heatMapData = counts } }
        } else {
            let cutoff = Calendar.current.date(
                byAdding: .day, value: -routeClass.heatMapWindowDays, to: Date()
            ) ?? Date()

            var counts: [String: Int] = [:]
            for dose in doseHistory where dose.isActive {
                for site in dose.injectionSites {
                    let activeEnd = Calendar.current.date(
                        byAdding: .day, value: site.durationDays, to: dose.doseDate
                    ) ?? dose.doseDate
                    if activeEnd >= cutoff {
                        counts[site.zoneLabel, default: 0] += 1
                    }
                }
            }

            await MainActor.run { withAnimation(.easeIn(duration: 0.25)) { heatMapData = counts } }
        }
    }
}

// MARK: - Preview

#Preview {
    BodySitePickerView(
        medicationType: "Estrogen",
        administrationMethod: "Injectable",
        routeClass: .injection,
        doseHistory: [],
        avoidZones: [:],
        preferredZones: ["Right Ventrogluteal", "Left Ventrogluteal"],
        recentlyUsedZones: [],
        onRecord: { _ in },
        onBack: { },
        onMarkAvoid: { _, _ in }
    )
}
