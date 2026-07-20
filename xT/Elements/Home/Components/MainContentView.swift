//
//  MainContentView.swift
//  xT
//
//  Flat section stack below the graph. Hairline dividers separate sections
//  instead of glass cards. Inline types: FlatQuickActionsRow, FlatInsightRow,
//  FlatNextDoseRow, JournalHomeRow.
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool
    var isWide: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Missed dose prompt — urgent, always first when present
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .padding(.bottom, 20)
                    .transition(.opacity)
                    .entrance(index: 0)
            }

            // Quick actions — two-column flat row
            FlatQuickActionsRow()
                .entrance(index: 1)

            flatDivider()

            if isWide && medicationManager.isFullyConfigured {
                // Wide layouts: insight and journal sit side by side
                HStack(alignment: .top, spacing: 24) {
                    FlatInsightRow()
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    JournalHomeRow()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.vertical, 18)
                .entrance(index: 2)

                flatDivider()
            } else {
                // Contextual health insight
                if medicationManager.isFullyConfigured {
                    FlatInsightRow()
                        .padding(.vertical, 18)
                        .entrance(index: 2)

                    flatDivider()
                }

                // Journal row — always present (empty state or today's entry)
                JournalHomeRow()
                    .padding(.vertical, 18)
                    .entrance(index: 3)

                flatDivider()
            }

            // Next dose dot-tracker
            if medicationManager.isFullyConfigured {
                FlatNextDoseRow()
                    .padding(.vertical, 18)
                    .entrance(index: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: medicationManager.hasMissedDose)
    }

    private func flatDivider() -> some View {
        Divider()
            .opacity(0.5)
    }
}

// MARK: - Flat Quick Actions Row

struct FlatQuickActionsRow: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingDoseConfirmation = false
    @State private var showingQuickDoseSheet = false
    /// Tracks when a dose was just recorded so the alert fires on sheet dismiss
    @State private var doseJustRecorded = false

    private var doseMissed: Bool {
        medicationManager.isFullyConfigured && medicationManager.hasMissedDose
    }

    var body: some View {
        HStack(spacing: 0) {
            // Dose — left
            flatAction(
                icon: "checkmark.circle.fill",
                label: "Record dose",
                iconColor: doseMissed ? Theme.Colors.Time.cycle.base : Theme.Colors.Time.skin.base,
                iconBg: doseMissed ? Theme.Colors.Time.cycle.surface : Theme.Colors.Time.skin.surface
            ) {
                showingQuickDoseSheet = true
            }

            flatVerticalDivider()

            // Schedule — right
            NavigationLink(destination: UnifiedScheduleView()) {
                flatActionContent(
                    icon: "calendar",
                    label: "Schedule",
                    iconColor: Theme.Colors.Time.mind.base,
                    iconBg: Theme.Colors.Time.mind.surface
                )
            }
            .buttonStyle(.pressable)
        }
        .padding(.vertical, 18)
        .sheet(isPresented: $showingQuickDoseSheet) {
            QuickDoseSheet(isPresented: $showingQuickDoseSheet)
                .environment(\.medicationManager, medicationManager)
        }
        .alert("Dose recorded", isPresented: $showingDoseConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your dose has been logged for today.")
        }
    }

    private func flatAction(
        icon: String,
        label: String,
        iconColor: Color,
        iconBg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            flatActionContent(icon: icon, label: label, iconColor: iconColor, iconBg: iconBg)
        }
        .buttonStyle(.pressable)
    }

    private func flatActionContent(
        icon: String,
        label: String,
        iconColor: Color,
        iconBg: Color
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(iconColor)
            }

            Text(label)
                .font(Theme.Fonts.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func flatVerticalDivider() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 0.5, height: 52)
    }
}

// MARK: - Flat Insight Row

/// Status-tinted "dash of color" — a soft background wash and accent bar
/// whose color reflects how the current level reads (on target / low /
/// high / critical), so the color itself carries information rather than
/// being purely decorative.
struct FlatInsightRow: View {
    @Environment(\.medicationManager) private var medicationManager

    private var insightText: String {
        guard let level = medicationManager.currentHormoneLevel else {
            return "Log doses to see personalized insights."
        }
        
        let range = level.range
        let explanation = level.explanation
        
        // Use the classification label to drive concise insight text
        if range.contains("Critically Low") || range.contains("Sub-Therapeutic") {
            return "Your levels are critically low — a dose review or blood test is recommended."
        } else if range.contains("Very Low") || range.contains("Below Expected") {
            return "Your levels are running low. Consider checking in with your provider."
        } else if range.contains("Slightly Below") {
            return "You're slightly below your target range. A small adjustment may help."
        } else if range.contains("On Target") || range.contains("On Track") {
            return "Great! Your hormone levels are right on target. Keep up your current schedule."
        } else if range.contains("Slightly Above") {
            return "You're slightly above your target. Monitor for any side effects."
        } else if range.contains("Very High") || range.contains("Safety Check") || range.contains("Supraphysiological") {
            return "Levels are elevated — review with your provider and consider a dose adjustment."
        } else if range.contains("High") {
            return "Levels are running high. Monitor for symptoms and check in if needed."
        } else {
            // Fallback: give the first sentence of the explanation
            return explanation.components(separatedBy: ". ").first.map { $0.hasSuffix(".") ? $0 : "\($0)." } ?? explanation
        }
    }

    /// Color the wash and accent bar take on, based on the same
    /// classification used for `insightText` — critical reads as error red,
    /// low/high extremes as warning amber, on-target as success green, and
    /// everything else falls back to the brand accent.
    private var statusColor: Color {
        guard let level = medicationManager.currentHormoneLevel else {
            return Theme.Colors.accent
        }
        let range = level.range
        if range.contains("Critically") || range.contains("Safety Check") || range.contains("Sub-Therapeutic") {
            return Theme.Colors.error
        } else if range.contains("Very Low") || range.contains("Very High") || range.contains("Supraphysiological") {
            return Theme.Colors.warning
        } else if range.contains("On Target") || range.contains("On Track") {
            return Theme.Colors.success
        } else {
            return Theme.Colors.accent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor.opacity(0.6))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text("INSIGHT")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(statusColor)
                    .tracking(0.8)

                Text(insightText)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(statusColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .animation(.easeInOut(duration: 0.3), value: statusColor)
    }
}

// MARK: - Journal Home Row

struct JournalHomeRow: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingJournalComposer = false

    private var todayEntry: JournalEntry? {
        guard let last = journalManager.lastEntry,
              Calendar.current.isDateInToday(last.date) else { return nil }
        return last
    }

    var body: some View {
        Group {
            if let entry = todayEntry {
                // 80:20 split — preview left, new entry icon right
                HStack(spacing: 0) {
                    JournalCardView(entry: entry, showBackground: false)
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 0.5, height: 44)

                    Button {
                        showingJournalComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.6))
                            .frame(width: 56, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .background(Theme.Colors.Time.skin.surface.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            } else {
                // Full-width new entry button
                Button {
                    showingJournalComposer = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.55))

                        Text("new entry…")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.Colors.accent.opacity(0.55))

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.Colors.Time.skin.surface.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Flat Next Dose Row

struct FlatNextDoseRow: View {
    @Environment(\.medicationManager) private var medicationManager

    private var cycleDays: Int {
        guard let method = medicationManager.selectedAdministrationMethod,
              let adm = MedicationManager.AdministrationMethod(rawValue: method) else { return 7 }
        return adm.frequencyDays
    }

    private var completedDays: Int {
        guard let last = medicationManager.lastDoseDate else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return min(elapsed + 1, cycleDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEXT DOSE")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Color.secondary)
                    .tracking(0.5)

                Spacer()

                if let next = medicationManager.nextDoseDate {
                    Text(nextLabel(next))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            HStack(spacing: 5) {
                ForEach(0..<cycleDays, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < completedDays ? Theme.Colors.accent : Color.primary.opacity(0.12))
                        .frame(height: 4)
                        .frame(maxWidth: 22)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func nextLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let fmt = date.formatted(date: .abbreviated, time: .omitted)
        if days == 0 { return "Today · \(fmt)" }
        if days == 1 { return "Tomorrow · \(fmt)" }
        return "In \(days) days · \(fmt)"
    }
}

// MARK: - Quick Dose Sheet (Concentration-Aware)

struct QuickDoseSheet: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var isPresented: Bool

    @State private var doseUnit: String = "mg"
    @State private var mgAmount: Double = 2.0
    @State private var mlAmount: Double = 0.05
    @State private var concentration: Double = 40.0
    @State private var doseDate: Date = Date()
    @State private var showCustomConcentration: Bool = false
    @State private var customConcentrationText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                Text("Record Dose")
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

                // mg / mL segmented control
                Picker("Dose Unit", selection: $doseUnit) {
                    Text("mg").tag("mg")
                    Text("mL").tag("mL")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                // Dose entry
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

                    let computedMg = mlAmount * concentration
                    Text("= \(String(format: "%.1f", computedMg)) mg (@ \(String(format: "%.0f", concentration)) mg/mL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let warning = MedicationManager.volumeWarning(for: mlAmount, ester: medicationManager.lastLoggedDose?.ester) {
                        quickDoseWarning(warning)
                    }
                }

                // Concentration picker
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
                                                .fill(concentration == conc && !showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Color(.tertiarySystemFill))
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
                                            .fill(showCustomConcentration ? Theme.Colors.accent.opacity(0.5) : Color(.tertiarySystemFill))
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Date picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose date & time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    DatePicker("", selection: $doseDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.horizontal, 20)
                }

                Spacer()

                // Record button
                Button {
                    recordDose()
                } label: {
                    Text("Record Dose")
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
                // Pre-fill from saved defaults
                if let lastDose = medicationManager.lastLoggedDose {
                    mgAmount = lastDose.doseAmount
                    if let conc = lastDose.concentrationMgPerMl {
                        concentration = conc
                    } else if let defaultConc = medicationManager.defaultConcentrationMgPerMl {
                        concentration = defaultConc
                    }
                    updateMlFromMg()
                } else if let defaultConc = medicationManager.defaultConcentrationMgPerMl {
                    concentration = defaultConc
                    updateMlFromMg()
                }
            }
            .onChange(of: concentration) { _, _ in updateMlFromMg() }
            .onChange(of: mgAmount) { _, _ in updateMlFromMg() }
        }
    }

    private func updateMlFromMg() {
        guard concentration > 0 else { return }
        mlAmount = MedicationManager.computedVolume(doseMg: mgAmount, concentrationMgPerMl: concentration)
    }

    private func recordDose() {
        let finalMg = doseUnit == "mg" ? mgAmount : mlAmount * concentration
        let finalConcentration = concentration > 0 ? concentration : nil

        guard let medType = medicationManager.selectedMedication,
              let medMethod = medicationManager.selectedAdministrationMethod else { return }

        // Determine ester
        let ester: String
        if let recentEster = medicationManager.lastLoggedDose?.ester {
            ester = recentEster
        } else if medType == "Estrogen" {
            ester = "Valerate (EV)"
        } else {
            ester = "Cypionate (TC)"
        }

        // Haptic: soft impact to acknowledge the action
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()

        medicationManager.addDose(
            date: doseDate,
            type: medType,
            ester: ester,
            method: medMethod,
            doseAmount: finalMg,
            concentrationMgPerMl: finalConcentration
        )

        // Secondary haptic after the model commits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        isPresented = false
    }

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
    MainContentView(showingGraphDetail: .constant(false))
        .padding(.horizontal, 22)
        .padding(.vertical)
        .background(Color(.systemBackground))
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
