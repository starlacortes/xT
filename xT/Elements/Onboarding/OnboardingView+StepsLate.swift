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
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Text("Tap on the body model to mark your injection site.\nYou can rotate the model with the arrows below.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .padding(.top, Theme.Spacing.sm)

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
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .frame(height: 320)

            bodyPickerOrbitControls
                .padding(.top, Theme.Spacing.md)

            if let zone = selectedSiteLabels3D.first {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .font(Theme.Fonts.icon)
                        .foregroundStyle(Theme.Colors.accent)
                    Text(zone)
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Button {
                        selectedSiteLabels3D.removeAll()
                        tapPositions.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.row)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.accent.opacity(0.13))
                )
                .padding(.top, Theme.Spacing.md)
            } else {
                Text("Tap the model to mark your site")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, Theme.Spacing.md)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.lg) {
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
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)

            Spacer()
                .frame(height: 20)
        }
    }

    var bodyPickerOrbitControls: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + angles.count - 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(Theme.Fonts.icon)
                    .imageScale(.large)
                    .foregroundStyle(Theme.Colors.textSecondary)
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
                                             : Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xxl)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                    .fill(bodySnapAngle == angle
                                          ? Theme.Colors.accent.opacity(0.13)
                                          : Color.clear)
                            )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Colors.appBackground))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline))

            Spacer()

            Button {
                let angles = BodySnapAngle.allCases
                let cur = angles.firstIndex(of: bodySnapAngle) ?? 0
                bodySnapAngle = angles[(cur + 1) % angles.count]
                bodySnapNonce += 1
            } label: {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(Theme.Fonts.icon)
                    .imageScale(.large)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
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
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("Are you taking any other medications?")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            VStack(spacing: Theme.Spacing.md) {
                aaCard(title: "None", subtitle: "I only take my hormone", choice: "None")
                aaCard(title: "Spironolactone", subtitle: "Common anti‑androgen — can slightly increase estrogen clearance", choice: "Spiro")
                aaCard(title: "Cyproterone / GnRH agonist", subtitle: "Suppresses testosterone production", choice: "Other AA")
                aaCard(title: "Finasteride / Dutasteride", subtitle: "5α‑reductase inhibitor — blocks DHT conversion", choice: "5ARI")
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
    }

    // MARK: - Step 8: Body Silhouette
    var bodyTypeStep: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("Choose a body silhouette")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Text("This changes the 3D injection-site picker. You can update this anytime in Settings.")
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            VStack(spacing: Theme.Spacing.row) {
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
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
    }

    // MARK: - Step 9: Profile
    var profileStep: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("Personalize your space")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.Spacing.sm)

            // Photo
            Button { showImagePicker = true } label: {
                AvatarView(image: profileManager.profilePhoto, size: 100)
                    .id(profilePhotoNonce)
            }
            Text("Tap to add photo")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            // Name
            TextField("Your name", text: $profileName)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Colors.appBackground))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Colors.border, lineWidth: Theme.Line.hairline))
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            // Photo options
            HStack(spacing: Theme.Spacing.xxl) {
                photoBtn("photo", "Library") { showImagePicker = true }
                photoBtn("camera", "Camera") { showCamera = true }
            }
            .padding(.top, Theme.Spacing.sm)

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") {
                    if !profileName.isEmpty { profileManager.updateProfileName(profileName) }
                    advanceStep()
                }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
        .profilePhotoPickers(libraryPresented: $showImagePicker,
                             cameraPresented: $showCamera,
                             onImageChanged: { profilePhotoNonce += 1 })
    }

    // MARK: - Step 10: Choose your theme
    var themeStep: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()
            Text("Make it yours")
                .font(Theme.Fonts.serifTitle)
                .fontWeight(.regular)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.Spacing.xxs)
            Text("Drag to pick a color for the whole app. You can always change this later in Settings.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

            ThemePickerView()
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .padding(.top, Theme.Spacing.sm)

            Spacer()
            HStack(spacing: Theme.Spacing.lg) {
                secondaryButton("Back") { previousStep() }
                primaryButton("Continue") { advanceStep() }
            }
            .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
            .padding(.bottom, Theme.Spacing.Gutter.onboarding)
        }
    }

    // MARK: - Step 11: Review & Start
    var reviewStep: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                Text("Here's your setup")
                    .font(Theme.Fonts.serifTitle)
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, Theme.Spacing.xxxl)

                VStack(spacing: 0) {
                    reviewRow(label: "Hormone", value: selectedType)
                    reviewRow(label: "Method", value: selectedMethod)
                    if !selectedEster.isEmpty {
                        reviewRow(label: "Ester", value: selectedEster)
                    }
                    // Oral pills are dosed in whole mg — no vial volume to show.
                    if isOralRoute {
                        reviewRow(label: "Dose", value: "\(String(format: "%.1f", doseDecimal)) mg")
                    } else {
                        let vol = MedicationManager.computedVolume(doseMg: doseDecimal, concentrationMgPerMl: selectedConcentration)
                        reviewRow(label: "Dose", value: "\(String(format: "%.1f", doseDecimal)) mg (\(String(format: "%.3f", vol)) mL @ \(String(format: "%.0f", selectedConcentration)) mg/mL)")
                    }
                    reviewRow(label: "Frequency", value: "Every \(selectedFrequency) days")
                    reviewRow(label: "Last dose", value: lastDoseDate.formatted(date: .abbreviated, time: .shortened))
                    reviewRow(label: "Experience", value: hrtSummary)
                    if antiAndrogenChoice != "None" {
                        reviewRow(label: "Other meds", value: antiAndrogenChoice)
                    }
                    reviewRow(label: "Body silhouette", value: (BodyType(rawValue: medicationManager.bodyTypeRaw) ?? .neutral).displayName)
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(Theme.Colors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)

                VStack(spacing: Theme.Spacing.md) {
                    primaryButton("Begin Tracking") { commitOnboarding() }
                    secondaryButton("Back") { previousStep() }
                }
                .padding(.horizontal, Theme.Spacing.Gutter.onboarding)
                .padding(.bottom, Theme.Spacing.Gutter.onboarding)
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
