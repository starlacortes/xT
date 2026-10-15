//
//  YourRangeView.swift
//  xT
//
//  Settings → Labs & Records → Your range (ST7). Moved out of the old
//  SettingsView inline "Use personal targets" block, in neutral language:
//  the range is a reference the user sets with their clinician, not a goal.
//
//  Fixes the old `loadSettings()` bug: `useCustomTargets` and the three values
//  are now initialized from `medicationManager.userTherapeuticTarget` on
//  appear, so the screen reflects what's stored instead of always reading off.
//  Storage (`TherapeuticTarget`, CloudKit-synced JSON) is unchanged.
//

import SwiftUI

struct YourRangeView: View {
    @Environment(\.medicationManager) var medicationManager

    @State var showOnCurve: Bool = false
    @State var lowerEdge: Double = 100
    @State var troughUpperEdge: Double = 200
    @State var upperEdge: Double = 600
    @FocusState var fieldFocused: Bool

    private var medicationUnit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                SettingsGroup {
                    HStack(spacing: Theme.Spacing.card) {
                        SettingsIconTile(icon: "target")

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Show my range on the curve")
                                .font(Theme.Fonts.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }

                        Spacer()

                        SettingsToggle(isOn: $showOnCurve)
                    }
                    .padding(.horizontal, Theme.Spacing.card)
                    .padding(.vertical, Theme.Spacing.md)
                    .contentShape(Rectangle())
                    .onChange(of: showOnCurve) { _, enabled in
                        if enabled { save() } else { clear() }
                    }
                }

                if showOnCurve {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SectionHeader(text: "Edges", emphasis: .accent)
                        SettingsGroup {
                            edgeRow(title: "Lower edge",
                                    value: $lowerEdge,
                                    description: "The bottom of your reference band")

                            SettingsGroupDivider()

                            edgeRow(title: "Trough upper edge",
                                    value: $troughUpperEdge,
                                    description: "Where you'd like troughs to sit below")

                            SettingsGroupDivider()

                            edgeRow(title: "Upper edge",
                                    value: $upperEdge,
                                    description: "The top of your reference band")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text("Your range is drawn as a band on your curve. It's a reference you set with your clinician, not a goal.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.Gutter.screen)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 48)
            .animation(Theme.Motion.snappy, value: showOnCurve)
        }
        .background(Theme.Colors.appBackground)
        .navigationTitle("Your range")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar { fieldFocused = false }
        .onAppear { loadFromTarget() }
        // The one commit point: validate and persist when the keyboard leaves
        // all three fields — never while a number is still being typed.
        .onChange(of: fieldFocused) { _, focused in
            if !focused { commitEdges() }
        }
    }

    // MARK: - Edge rows

    private func edgeRow(title: LocalizedStringResource, value: Binding<Double>,
                         description: LocalizedStringResource) -> some View {
        HStack(spacing: Theme.Spacing.card) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(description)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xxs) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                    .font(Theme.Fonts.numeric)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    // Commit-only: clamping or saving mid-keystroke snapped the
                    // field to the range floor while the number was still being
                    // edited. The commit runs in `commitEdges()`, on focus loss.
                    .onSubmit { fieldFocused = false }

                Text(verbatim: medicationUnit)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.card)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Persistence

    /// The ST7 bug fix: initialize from the stored target, not hard-coded
    /// defaults, so the screen reflects what was previously saved.
    private func loadFromTarget() {
        if let target = medicationManager.userTherapeuticTarget {
            showOnCurve = true
            lowerEdge = target.troughMin
            troughUpperEdge = target.troughMax
            upperEdge = target.peakCeiling
        } else {
            showOnCurve = false
        }
    }

    /// Clamps the three edges into their ordering (lower < trough upper ≤ upper)
    /// and persists — the single commit path, run on focus loss so a half-typed
    /// value never snaps the field out from under the cursor.
    private func commitEdges() {
        guard showOnCurve else { return }
        lowerEdge = min(max(lowerEdge, 0), 9999)
        troughUpperEdge = min(max(troughUpperEdge, lowerEdge + 1), 9999)
        upperEdge = min(max(upperEdge, troughUpperEdge), 9999)
        save()
    }

    private func save() {
        guard showOnCurve else { return }
        let target = MedicationManager.TherapeuticTarget(
            troughMin: lowerEdge,
            troughMax: troughUpperEdge,
            peakCeiling: upperEdge
        )
        medicationManager.userTherapeuticTarget = target
        medicationManager.refreshState()
    }

    private func clear() {
        medicationManager.userTherapeuticTarget = nil
        medicationManager.refreshState()
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            YourRangeView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
