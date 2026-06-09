//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//  Enhanced with Research-Grade Pharmacokinetic Modeling & Reactive Data Pipeline
//

import SwiftUI
import SwiftData
import CryptoKit

/// MedicationManager with a Reactive Data Pipeline to ensure UI synchronization.
/// This class acts as the Single Source of Truth for all hormone-related state.
@MainActor
class MedicationManager: ObservableObject {
    static let shared = MedicationManager()

    // MARK: - Core State
    @Published var selectedMedication: String?
    @Published var selectedAdministrationMethod: String?
    @Published var lastDoseDate: Date?
    @Published var nextDoseDate: Date?

    // MARK: - Reactive Research Properties (The "Signals" for SwiftUI)
    /// Provides the current level summary, including unit, range, and plain-language explanation.
    @Published var currentHormoneLevel: (value: Double, unit: String, range: String, explanation: String)?
    /// Provides the historical data points used to drive the 7-day and long-term charts.
    @Published var recentLevels: [EstimatedPoint] = []

    // MARK: - Research Models

    enum MedicationEster: String, CaseIterable {
        case valerate = "Valerate (EV)"
        case cypionate = "Cypionate (EC)"
        case oral = "Oral"
        case transdermal = "Transdermal"

        var halfLifeDays: Double {
            switch self {
            case .valerate: return 2.0
            case .cypionate: return 8.5
            case .oral: return 0.5
            case .transdermal: return 1.5
            }
        }
    }

    enum MedicationType: String, CaseIterable {
        case estrogen = "Estrogen"
        case testosterone = "Testosterone"

        var baselineValue: Double {
            switch self {
            case .estrogen: return 100.0
            case .testosterone: return 500.0
            }
        }

        var defaultEster: MedicationEster {
            switch self {
            case .estrogen: return .valerate
            case .testosterone: return .cypionate
            }
        }
    }

    enum AdministrationMethod: String, CaseIterable {
        case injectable = "Injectable"
        case cream = "Cream"
        case oral = "Oral"

        var frequencyDays: Int {
            switch self {
            case .injectable: return 7
            case .cream, .oral: return 1
            }
        }

        var isImplemented: Bool {
            switch self {
            case .injectable, .cream, .oral: return true
            }
        }
    }

    struct HormoneRange: Codable {
        let label: String
        let min: Double
        let max: Double
        let colorName: String
    }

    struct EstimatedPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let medication: String
        let method: String
    }

    // MARK: - Configuration & UI Helpers

    private let estrogenRanges: [HormoneRange] = [
        HormoneRange(label: "Very Low", min: 0, max: 50, colorName: "bloomBodyColor"),
        HormoneRange(label: "Low", min: 50, max: 100, colorName: "bloomBodyColor"),
        HormoneRange(label: "Optimal", min: 100, max: 200, colorName: "successColor"),
        HormoneRange(label: "High", min: 200, max: 500, colorName: "bloomCycleColor"),
        HormoneRange(label: "Very High", min: 500, max: 1000, colorName: "bloomCycleColor")
    ]

    var medicationName: String { selectedMedication ?? "None Selected" }

    var medicationDisplayInfo: String {
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return "\(medication) via \(method)"
        } else if let medication = selectedMedication {
            return "\(medication) (method not selected)"
        } else {
            return "No medication selected"
        }
    }

    func getConfigurationSummary() -> String {
        if isFullyConfigured {
            return "Fully configured and ready"
        } else if isPartiallyConfigured {
            return "Partially configured - needs completion"
        } else {
            return "Not configured"
        }
    }

    var scheduleSummary: String {
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return "\(medication) via \(method) every \(AdministrationMethod(rawValue: method)?.frequencyDays ?? 7) days"
        } else {
            return "Not configured"
        }
    }

    var isFullyConfigured: Bool {
        selectedMedication != nil && selectedAdministrationMethod != nil
    }

    var isPartiallyConfigured: Bool {
        (selectedMedication != nil) != (selectedAdministrationMethod != nil)
    }

    var hasMissedDose: Bool {
        guard let next = nextDoseDate else { return false }
        return Date() > next
    }

    var daysSinceMissedDose: Int? {
        guard hasMissedDose, let next = nextDoseDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: next, to: Date()).day ?? 0
        return max(1, days) // At least 1 day if missed
    }

    var monthsOnHRT: Int {
        guard let first = lastDoseDate else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0
        return max(0, months)
    }

    var currentStreakDays: Int? {
        guard let last = lastDoseDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return max(0, days)
    }

    func availableMethods(for medicationType: MedicationType) -> [AdministrationMethod] {
        // For now, return all available methods
        // In a real app, this might be more sophisticated based on medication type
        return [.injectable, .cream, .oral]
    }

    func configureMedication(type: MedicationType, method: AdministrationMethod, firstDoseDate: Date) {
        updateSelection(type: type, method: method)
        recordDose(on: firstDoseDate)
    }

    // MARK: - Initialization

    init() {
        loadSelection()
        loadDoseDates()
        migrateToEncryptedStorage()
        refreshState() // Initialize reactive state
    }

    // MARK: - Public API (Management)

    func updateSelection(type: MedicationType, method: AdministrationMethod) {
        selectedMedication = type.rawValue
        selectedAdministrationMethod = method.rawValue
        persistSelection()

        let next = calculateNextDoseDate(from: Date())
        updateDoseDates(last: Date(), next: next)
        refreshState()
    }

    func clearSelection() {
        selectedMedication = nil
        selectedAdministrationMethod = nil
        lastDoseDate = nil
        nextDoseDate = nil
        persistSelection()
        persistDoseDates()
        refreshState()
    }

    func recordDose(on date: Date = Date()) {
        lastDoseDate = date
        if selectedMedication != nil, selectedAdministrationMethod != nil {
            nextDoseDate = calculateNextDoseDate(from: date)
        }
        persistDoseDates()
        refreshState()
    }

    func calculateNextDoseDate(from lastDose: Date) -> Date {
        guard let methodStr = selectedAdministrationMethod,
              let method = AdministrationMethod(rawValue: methodStr) else { return Date() }
        return Calendar.current.date(byAdding: .day, value: method.frequencyDays, to: lastDose) ?? Date()
    }

    // MARK: - Research Engine (Pharmacokinetics)

    /// The heart of the reactivity: Recalculates everything and broadcasts changes.
    func refreshState() {
        currentHormoneLevel = getCurrentHormoneLevel()
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        recentLevels = estimatedLevels(from: start, to: end)
    }

    func getCurrentHormoneLevel() -> (value: Double, unit: String, range: String, explanation: String)? {
        guard let medication = selectedMedication,
              let methodStr = selectedAdministrationMethod,
              let method = AdministrationMethod(rawValue: methodStr) else { return nil }

        let recent = estimatedLevels(from: Date().addingTimeInterval(-3600), to: Date())
        guard let latestLevel = recent.last else { return nil }

        let medicationEnum = MedicationType(rawValue: medication)
        let unit = medicationEnum == .estrogen ? "pg/mL" : "ng/dL"

        let rangeInfo = estrogenRanges.first { latestLevel.value >= $0.min && latestLevel.value < $0.max }
                        ?? HormoneRange(label: "Unknown", min: 0, max: 0, colorName: "primary")

        let explanation: String
        if medicationEnum == .estrogen {
            switch rangeInfo.label {
            case "Very Low": explanation = "At this level, you may experience mood swings and limited physical changes."
            case "Low": explanation = "You'll notice some emotional and physical changes, but they may be subtle."
            case "Optimal": explanation = "At this level, you'll feel emotionally stable and notice ongoing skin and body changes."
            case "High": explanation = "You'll experience significant emotional and physical changes; monitor for side effects."
            default: explanation = "Levels are outside typical monitoring ranges. Consult your provider."
            }
        } else {
            explanation = latestLevel.value < 50 ? "Your testosterone is effectively suppressed." : "This is a low male range."
        }

        return (latestLevel.value, unit, rangeInfo.label, explanation)
    }

    /// Dose Stacking Math: $C(t) = C_{base} + \sum D_i \cdot e^{-\lambda(t - t_i)}$
    func estimatedLevels(from start: Date, to end: Date, stepDays: Int = 1) -> [EstimatedPoint] {
        guard let medication = selectedMedication,
              let methodStr = selectedAdministrationMethod,
              let method = AdministrationMethod(rawValue: methodStr) else { return [] }

        var points = [EstimatedPoint]()
        var cursor = start
        let calendar = Calendar.current

        let medicationEnum = MedicationType(rawValue: medication)
        let ester = medicationEnum?.defaultEster ?? .valerate
        let halfLife = ester.halfLifeDays
        let lambda = log(2) / halfLife
        let baseLevel = medicationEnum?.baselineValue ?? 100.0
        let doseAmount = baseLevel * 0.5

        var doseDates: [Date] = []
        let lookbackStart = calendar.date(byAdding: .day, value: -30, to: start) ?? start
        if let last = lastDoseDate {
            var d = last
            while d >= lookbackStart {
                doseDates.append(d)
                d = calendar.date(byAdding: .day, value: -method.frequencyDays, to: d) ?? d
                if d == last { break }
            }
        }
        doseDates.sort()

        while cursor <= end {
            var cumulativeSpike = 0.0
            for doseDate in doseDates {
                let diff = cursor.timeIntervalSince(doseDate) / 86400.0
                if diff >= 0 {
                    cumulativeSpike += doseAmount * exp(-lambda * diff)
                }
            }
            points.append(EstimatedPoint(date: cursor, value: baseLevel + cumulativeSpike, medication: medication, method: methodStr))
            cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor) ?? cursor
        }
        return points
    }

    func estimatedRecentLevels(days: Int = 90) -> [EstimatedPoint] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return estimatedLevels(from: start, to: end)
    }

    // MARK: - Persistence (Private)

    func updateDoseDates(last: Date?, next: Date?) {
        lastDoseDate = last
        nextDoseDate = next
        persistDoseDates()
    }

    func loadSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedMedicationSelection"),
           let decrypted = security.decryptData(data),
           let str = String(data: decrypted, encoding: .utf8) {
            let parts = str.components(separatedBy: "|")
            if parts.count == 2 {
                selectedMedication = parts[0].isEmpty ? nil : parts[0]
                selectedAdministrationMethod = parts[1].isEmpty ? nil : parts[1]
            }
        } else {
            selectedMedication = defaults.string(forKey: "selectedMedication")
            selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
        }
    }

    func persistSelection() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let str = "\(selectedMedication ?? "")|\(selectedAdministrationMethod ?? "")"
        if let data = str.data(using: .utf8), let encrypted = security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedMedicationSelection")
        }
    }

    func loadDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        if let data = defaults.data(forKey: "encryptedDoseDates"),
           let decrypted = security.decryptData(data),
           let container = try? JSONDecoder().decode(DoseDatesContainer.self, from: decrypted) {
            lastDoseDate = container.lastDoseDate
            nextDoseDate = container.nextDoseDate
        }
    }

    func persistDoseDates() {
        let defaults = UserDefaults.standard
        let security = SecurityManager.shared
        let container = DoseDatesContainer(lastDoseDate: lastDoseDate, nextDoseDate: nextDoseDate)
        if let data = try? JSONEncoder().encode(container), let encrypted = security.encryptData(data) {
            defaults.set(encrypted, forKey: "encryptedDoseDates")
        }
    }

    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "encryptedMedicationSelection") == nil { persistSelection() }
        if defaults.object(forKey: "encryptedDoseDates") == nil { persistDoseDates() }
    }

    private struct DoseDatesContainer: Codable {
        let lastDoseDate: Date?
        let nextDoseDate: Date?
    }
}

// MARK: - Environment Key
@MainActor
struct MedicationManagerKey: @MainActor EnvironmentKey {
    static let defaultValue: MedicationManager = MedicationManager.shared
}

extension EnvironmentValues {
    @MainActor
    var medicationManager: MedicationManager {
        get { self[MedicationManagerKey.self] }
        set { self[MedicationManagerKey.self] = newValue }
    }
}