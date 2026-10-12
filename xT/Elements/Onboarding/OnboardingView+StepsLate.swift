//
//  OnboardingView+StepsLate.swift
//  xT
//
//  Steps 7-11: injection site body picker, anti-androgens, body silhouette, profile, theme, and review.
//  (Split from OnboardingView.swift — same `OnboardingView`, different file.)
//

import SwiftUI

extension OnboardingView {

    // MARK: - Step 6: Injection / Application Site (Body Picker)

    var injectionSiteStep: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Where did you take it?")
                .font(Theme.Fonts.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Tap on the body model to mark your injection site.\nYou can rotate the model with the arrows below.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()

            BodyModel3DView(
                heatMapData: [:],
                avoidZones: [],
                preferredZones: bodyPickerPreferredZones,
                recommendedZones: bodyPickerRecommendedZones,
                selectedSites: $selectedSiteLabels3D,
                maxSelections: 1,
                bodyType: BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral,
                snapAngle: bodySnapAngle,
                snapNonce: bodySnapNonce,
                onTapZone: { _, _ in },
                tapPositions: $tapPositions,
                onPreTap: { _, _ in },
                onNoZoneTap: { point in
                    noZoneTaps.record(at: point)
                },
                onYawChange: { yaw in
                    cameraYaw = yaw
                }
            )
            .noZoneMarkers($noZoneTaps.taps)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .padding(.horizontal, 40)
            .frame(height: 320)

            bodyPickerOrbitControls
                .padding(.top, 12)

            if let zone = selectedSiteLabels3D.first {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.Colors.accentSecondary)
                    Text(zone)
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    Button {
                        selectedSiteLabels3D.removeAll()
                        tapPositions.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.accentSecondary.opacity(0.2))
                )
                .padding(.top, 12)
            } else {
                Text("Tap the model to mark your site")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.4))
                    .padding(.top, 12)
            }

            Spacer()

            HStack(spacing: 16) {
                secondaryButton("Skip for now") {
                    selectedSiteLabels3D.removeAll()
                    tapPositions.removeAll()
                    advanceStep()
                }
                primaryButton("Continue", disabled: selectedSiteLabels3D.isEmpty) {
                    commitInjectionSites()
                    advanceStep()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)

            Spacer()
                .frame(height: 20)
        }
    }

    var bodyPickerOrbitControls: some View {
        HStack(spacing: 16) {
            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + angles.count - 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }

            Spacer()

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
                                             : Theme.Colors.OnAccent.primary.opacity(0.6))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bodySnapAngle == angle
                                          ? Theme.Colors.accent.opacity(0.25)
                                          : Color.clear)
                            )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))

            Spacer()

            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.5))
            }
        }
        .padding(.horizontal, 40)
    }

    var bodyPickerPreferredZones: Set<String> {
        let routeClass = RouteClass.from(method: selectedMethod)
        return Set(ZoneCentroidStore.preferredZones(medication: selectedType, routeClass: routeClass))
    }

    var bodyPickerRecommendedZones: Set<String> {
        let routeClass = RouteClass.from(method: selectedMethod)
        return Set(ZoneCentroidStore.recommendedZones(for: routeClass))
    }

    func commitInjectionSites() {
        guard !selectedSiteLabels3D.isEmpty else { return }
        let now = lastDoseDate
        // Derived from the live camera yaw, not the snap-angle selection: a user can free-pan
        // to the back without changing the selected snap angle.
        let derivedViewContext = ZoneCentroidStore.viewContext(from: cameraYaw)
        let routeClass = RouteClass.from(method: selectedMethod)
        selectedInjectionSites = selectedSiteLabels3D.map { zoneLabel in
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
    }

    // MARK: - Step 7: Anti-Androgens
    var antiAndrogenStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Are you taking any other medications?")
                .font(Theme.Fonts.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                aaCard(title: "None", subtitle: "I only take my hormone", choice: "None")
                aaCard(title: "Spironolactone", subtitle: "Common anti‑androgen — can slightly increase estrogen clearance", choice: "Spiro")
                aaCard(title: "Cyproterone / GnRH agonist", subtitle: "Suppresses testosterone production", choice: "Other AA")
                aaCard(title: "Finasteride / Dutasteride", subtitle: "5α‑reductase inhibitor — blocks DHT conversion", choice: "5ARI")
            }
            .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 8: Body Silhouette
    var bodyTypeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Choose a body silhouette")
                .font(Theme.Fonts.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("This changes the 3D injection-site picker. You can update this anytime in Settings.")
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                ForEach(BodyType.allCases) { type in
                    pathCard(
                        title: type.displayName,
                        subtitle: type.subtitle,
                        isSelected: medicationManager.bodyTypeRaw == type.rawValue
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            medicationManager.bodyTypeRaw = type.rawValue
                        }
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 9: Profile
    var profileStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Personalize your space")
                .font(Theme.Fonts.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .padding(.bottom, 8)

            // Photo
            Button { showImagePicker = true } label: {
                AvatarView(image: profileManager.profilePhoto, size: 100)
                    .id(profilePhotoNonce)
            }
            Text("Tap to add photo")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.6))

            // Name
            TextField("Your name", text: $profileName)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.OnAccent.primary.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Colors.OnAccent.primary.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 40)

            // Photo options
            HStack(spacing: 24) {
                photoBtn("photo", "Library") { showImagePicker = true }
                photoBtn("camera", "Camera") { showCamera = true }
            }
            .padding(.top, 8)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") {
                    if !profileName.isEmpty { profileManager.updateProfileName(profileName) }
                    advanceStep()
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .profilePhotoPickers(libraryPresented: $showImagePicker,
                             cameraPresented: $showCamera,
                             onImageChanged: { profilePhotoNonce += 1 })
    }

    // MARK: - Step 10: Choose your theme
    var themeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Make it yours")
                .font(Theme.Fonts.title2)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.OnAccent.secondary)
                .padding(.bottom, 4)
            Text("Drag to pick a color for the whole app. You can always change this later in Settings.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.OnAccent.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ThemePickerView()
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()
            HStack(spacing: 16) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 11: Review & Start
    var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Here's your setup")
                    .font(Theme.Fonts.title2)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.OnAccent.primary.opacity(0.9))
                    .padding(.top, 32)

                VStack(spacing: 0) {
                    reviewRow(label: "Hormone", value: selectedType)
                    reviewRow(label: "Method", value: selectedMethod)
                    if !selectedEster.isEmpty {
                        reviewRow(label: "Ester", value: selectedEster)
                    }
                    let vol = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                    reviewRow(label: "Dose", value: "\(String(format: "%.1f", doseDecimal)) mg (\(String(format: "%.3f", vol)) mL @ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                    reviewRow(label: "Frequency", value: "Every \(selectedFrequency) days")
                    reviewRow(label: "Last dose", value: lastDoseDate.formatted(date: .abbreviated, time: .shortened))
                    reviewRow(label: "Experience", value: hrtSummary)
                    if antiAndrogenChoice != "None" {
                        reviewRow(label: "Other meds", value: antiAndrogenChoice)
                    }
                    reviewRow(label: "Body silhouette", value: (BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral).displayName)
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.OnAccent.primary.opacity(0.12))
                )
                .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    primaryButton("Begin Tracking") { commitOnboarding() }
                    secondaryButton("Back") { previousStep() }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    var hrtSummary: String {
        if !hasBeenOnHRT { return "Just starting" }
        var parts: [String] = []
        if hrtDurationYears > 0 { parts.append("\(hrtDurationYears) yr") }
        if hrtDurationMonths > 0 { parts.append("\(hrtDurationMonths) mo") }
        return parts.joined(separator: " ") + " on HRT"
    }
}
