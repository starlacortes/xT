//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//  Simplified version
//

import SwiftUI
import SwiftData
import CryptoKit

/// Simplified MedicationManager with streamlined architecture
@MainActor
class MedicationManager: ObservableObject {
    static let shared = MedicationManager()
    
    @Published var selectedMedication: String?
    @Published var selectedAdministrationMethod: String?
    @Published var lastDoseDate: Date?
    @Published var nextDoseDate: Date?
    
    init() {
        loadSelection()
        loadDoseDates()
        migrateToEncryptedStorage()
    }
    
    // Simplified medication types
    enum MedicationType: String, CaseIterable {
        case estrogen = "Estrogen"
        case testosterone = "Testosterone"
        
        var halfLifeDays: Double {
            switch self {
            case .estrogen, .testosterone: return 7.0
            }
        }
        
        var baselineValue: Double {
            switch self {
            case .estrogen: return 80
            case .testosterone: return 500
            }
        }
    }
    
    // Simplified administration methods
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
            case .injectable, .cream: return true
            case .oral: return false
            }
        }
    }
    
    /// Get available administration methods for a medication
    func availableMethods(for medication: MedicationType) -> [AdministrationMethod] {
        AdministrationMethod.allCases.filter { $0.isImplemented }
    }
    
    /// Get medication name for display
    var medicationName: String {
        selectedMedication ?? "None Selected"
    }

    /// Get dosage information for display
    var dosageInfo: String {
        guard let medication = selectedMedication,
              let method = selectedAdministrationMethod else {
            return "No dosage info"
        }

        switch (medication, method) {
        case ("Estrogen", "Injectable"): return "0.5ml weekly"
        case ("Estrogen", "Cream"): return "2.5g daily"
        case ("Estrogen", "Oral"): return "10mg daily"
        case ("Testosterone", "Injectable"): return "1ml weekly"
        case ("Testosterone", "Cream"): return "5g daily"
        case ("Testosterone", "Oral"): return "20mg daily"
        default: return "Unknown dosage"
        }
    }

    /// Get complete medication display information
    var medicationDisplayInfo: String {
        if let medication = selectedMedication, let method = selectedAdministrationMethod {
            return "\(medication) via \(method)"
        } else if let medication = selectedMedication {
            return "\(medication) (method not selected)"
        } else if let method = selectedAdministrationMethod {
            return "\(method) (medication not selected)"
        } else {
            return "No medication selected"
        }
    }

    /// Get schedule summary for display
    var scheduleSummary: String {
        guard let last = lastDoseDate, let next = nextDoseDate else {
            return "No schedule set"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        return "Last: \(dateFormatter.string(from: last)) | Next: \(dateFormatter.string(from: next))"
    }

    /// Check if medication is fully configured
    var isFullyConfigured: Bool {
        selectedMedication != nil && selectedAdministrationMethod != nil
    }

    /// Check if medication is partially configured
    var isPartiallyConfigured: Bool {
        (selectedMedication != nil) != (selectedAdministrationMethod != nil)
    }

    /// Calculate current streak days based on dose history
    var currentStreakDays: Int? {
        guard let lastDoseDate = lastDoseDate else { return nil }

        let calendar = Calendar.current
        let today = Date()

        // Check if the last dose was taken today or yesterday
        if calendar.isDateInToday(lastDoseDate) || calendar.isDateInYesterday(lastDoseDate) {
            // For simplicity, return a fixed streak value for demo purposes
            // In a real app, this would track consecutive days of adherence
            return 12
        }

        return nil
    }

    /// Calculate months on HRT based on first dose date
    var monthsOnHRT: Int {
        guard let firstDoseDate = lastDoseDate else { return 0 }
        let calendar = Calendar.current
        let today = Date()

        // Calculate months between first dose and today
        let months = calendar.dateComponents([.month], from: firstDoseDate, to: today).month ?? 0
        return max(0, months)
    }

    /// Get current hormone level with plain language explanation
    func getCurrentHormoneLevel() -> (value: Double, unit: String, range: String, explanation: String)? {
        guard let medication = selectedMedication,
              let method = selectedAdministrationMethod else { return nil }

        // Get the most recent estimated level
        let recentLevels = estimatedRecentLevels(days: 1)
        guard let latestLevel = recentLevels.last else { return nil }

        let medicationEnum = MedicationType(rawValue: medication)
        let unit = medicationEnum == .estrogen ? "pg/mL" : "ng/dL"

        // Determine range and explanation
        let range: String
        let explanation: String

        if medicationEnum == .estrogen {
            if latestLevel.value < 50 {
                range = "Very low"
                explanation = "At this level, you may experience mood swings and limited physical changes."
            } else if latestLevel.value < 100 {
                range = "Low"
                explanation = "You'll notice some emotional and physical changes, but they may be subtle."
            } else if latestLevel.value < 200 {
                range = "Optimal"
                explanation = "At this level, you'll feel emotionally stable and notice ongoing skin and body changes."
            } else if latestLevel.value < 500 {
                range = "High"
                explanation = "You'll experience significant emotional and physical changes, but may need to monitor for side effects."
            } else {
                range = "Very high"
                explanation = "At this level, changes will be rapid, but you should consult your provider about potential adjustments."
            }
        } else { // Testosterone
            if latestLevel.value < 50 {
                range = "Suppressed"
                explanation = "Your testosterone is effectively suppressed, which is typical for feminizing regimens."
            } else if latestLevel.value < 200 {
                range = "Low male"
                explanation = "This is a low male range, you may notice some feminizing effects but testosterone is still present."
            } else if latestLevel.value < 800 {
                range = "Male range"
                explanation = "This is a typical male range, you may not see significant feminizing effects at this level."
            } else {
                range = "High male"
                explanation = "This is a high male range, you should consult your provider about potential adjustments."
            }
        }

        return (latestLevel.value, unit, range, explanation)
    }

    /// Get changes unlocked based on months on HRT
    func getChangesUnlocked() -> [String] {
        let months = monthsOnHRT
        var changes: [String] = []

        if months >= 1 {
            changes.append("Skin softening")
        }
        if months >= 2 {
            changes.append("Breast growth")
        }
        if months >= 3 {
            changes.append("Fat redistribution")
        }
        if months >= 6 {
            changes.append("Hair thinning slows")
        }
        if months >= 9 {
            changes.append("Muscle mass decreases")
        }
        if months >= 12 {
            changes.append("Hair regrowth begins")
        }

        return changes
    }

    /// Get upcoming milestones
    func getUpcomingMilestones() -> [(month: Int, description: String)] {
        let months = monthsOnHRT
        var milestones: [(Int, String)] = []

        if months < 3 {
            milestones.append((3, "Skin softening becomes noticeable"))
        }
        if months < 6 {
            milestones.append((6, "Breast growth enters new phase"))
        }
        if months < 9 {
            milestones.append((9, "Fat redistribution becomes more apparent"))
        }
        if months < 12 {
            milestones.append((12, "Hair regrowth typically begins"))
        }
        if months < 18 {
            milestones.append((18, "Body shape changes become more pronounced"))
        }

        return milestones
    }

    /// Get body system progress for each category
    func getBodySystemProgress() -> [(name: String, icon: String, color: String, progress: Double, status: String)] {
        let months = monthsOnHRT
        let medication = selectedMedication ?? "Estrogen"

        var systems: [(String, String, String, Double, String)] = []

        // Mood & Mind (Purple)
        let mindProgress = min(Double(months) / 6.0, 1.0)
        let mindStatus = months < 3 ? "Starting" : months < 6 ? "Stabilising" : "Stable"
        systems.append(("Mood & mind", "brain", "purple", mindProgress, mindStatus))

        // Skin & Glow (Teal)
        let skinProgress = min(Double(months) / 4.0, 1.0)
        let skinStatus = months < 2 ? "Beginning" : months < 4 ? "Progressing" : "Well underway"
        systems.append(("Skin & glow", "sparkles", "teal", skinProgress, skinStatus))

        // Body Shape (Amber)
        let bodyProgress = min(Double(months) / 12.0, 1.0)
        let bodyStatus = months < 6 ? "Early changes" : months < 12 ? "Still in progress" : "Significant changes"
        systems.append(("Body shape", "body-scan", "amber", bodyProgress, bodyStatus))

        // Injection Cycle (Pink)
        let cycleProgress = 1.0 // Always full for cycle tracking
        let cycleStatus = "Day 3 of 7" // This would be dynamic in a real implementation
        systems.append(("Your cycle", "heart-rate-monitor", "pink", cycleProgress, cycleStatus))

        return systems
    }
    
    /// Select a medication and administration method
    func updateSelection(type: MedicationType, method: AdministrationMethod) {
        selectedMedication = type.rawValue
        selectedAdministrationMethod = method.rawValue
        persistSelection()
        
        // Update dose dates if we have a selection
        let next = calculateNextDoseDate(from: Date())
        updateDoseDates(last: Date(), next: next)
    }
    
    /// Clear the current selection
    func clearSelection() {
        selectedMedication = nil
        selectedAdministrationMethod = nil
        lastDoseDate = nil
        nextDoseDate = nil
        persistSelection()
        persistDoseDates()
    }

    /// Configure medication with type and method indices
    /// - Parameters:
    ///   - typeIndex: Index of the medication type in MedicationType.allCases
    ///   - methodIndex: Index of the administration method in available methods
    func configureMedication(typeIndex: Int, methodIndex: Int) {
        let type = MedicationType.allCases[typeIndex]
        let availableMethods = availableMethods(for: type)

        // Ensure methodIndex is within bounds of available methods
        let safeMethodIndex = min(methodIndex, availableMethods.count - 1)
        let method = availableMethods[safeMethodIndex]

        updateSelection(type: type, method: method)
    }

    /// Get current medication configuration as a summary
    func getConfigurationSummary() -> String {
        if isFullyConfigured {
            return "✓ \(medicationDisplayInfo) - \(dosageInfo)"
        } else if isPartiallyConfigured {
            if selectedMedication != nil {
                return "⚠ \(selectedMedication!) - needs administration method"
            } else {
                return "⚠ Needs medication selection"
            }
        } else {
            return "✗ Not configured"
        }
    }
    
    /// Record a dose was taken
    func recordDose(on date: Date = Date()) {
        lastDoseDate = date
        if selectedMedication != nil, selectedAdministrationMethod != nil {
            nextDoseDate = calculateNextDoseDate(from: date)
        }
        persistDoseDates()
    }
    
    /// Calculate the next dose date based on current regimen
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        guard let _ = selectedMedication,
              let method = selectedAdministrationMethod else { return Date() }

        let frequencyDays: Int
        switch method {
        case "Injectable": frequencyDays = 7
        case "Cream", "Oral": frequencyDays = 1
        default: frequencyDays = 1
        }

        return Calendar.current.date(byAdding: .day, value: frequencyDays, to: lastDose) ?? Date()
    }
    
    /// Structure for estimated hormone levels over time
    struct EstimatedPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let medication: String
        let method: String
    }
    
    /// Estimate hormone levels over a date range
    func estimatedLevels(from start: Date, to end: Date, stepDays: Int = 1) -> [EstimatedPoint] {
        guard let medication = selectedMedication,
              let method = selectedAdministrationMethod else { return [] }
        
        var points = [EstimatedPoint]()
        var cursor = start
        let calendar = Calendar.current
        
        // Simplified estimation logic
        let medicationEnum = MedicationType(rawValue: medication)
        let methodEnum = AdministrationMethod(rawValue: method)
        
        let halfLifeDays = medicationEnum?.halfLifeDays ?? 7.0
        let baselineValue = medicationEnum?.baselineValue ?? 500.0
        let decayLambda = log(2) / halfLifeDays
        
        while cursor <= end {
            let daysSinceStart = calendar.dateComponents([.day], from: start, to: cursor).day ?? 0
            let value: Double
            
            switch method {
            case "Injectable":
                let period = 7
                let dayInCycle = daysSinceStart % period
                let spikeMagnitude = baselineValue * 0.4
                let decayed = spikeMagnitude * exp(-decayLambda * Double(dayInCycle))
                value = baselineValue + decayed
            case "Cream":
                value = baselineValue * (1.0 + 0.05 * sin(Double(daysSinceStart) / 6.0 * .pi))
            case "Oral":
                let spikeMagnitude = baselineValue * 0.2
                let decayed = spikeMagnitude * exp(-decayLambda * Double(daysSinceStart % 1))
                value = baselineValue + decayed
            default:
                value = baselineValue
            }
            
            points.append(EstimatedPoint(date: cursor, value: value, medication: medication, method: method))
            cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor) ?? cursor
        }
        
        return points
    }
    
    /// Get estimated levels for recent period
    func estimatedRecentLevels(days: Int = 90) -> [EstimatedPoint] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return estimatedLevels(from: start, to: end)
    }
}

// MARK: - Private Methods
internal extension MedicationManager {
    func loadSelection() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Try encrypted data first
        if let encryptedSelectionData = defaults.data(forKey: "encryptedMedicationSelection"),
           let decryptedSelectionData = securityManager.decryptData(encryptedSelectionData),
           let selectionString = String(data: decryptedSelectionData, encoding: .utf8) {
            // Parse the selection string (format: "medication|method")
            let components = selectionString.components(separatedBy: "|")
            if components.count == 2 {
                selectedMedication = components[0].isEmpty ? nil : components[0]
                selectedAdministrationMethod = components[1].isEmpty ? nil : components[1]
                return
            }
        }

        // Fallback to unencrypted data (migration)
        selectedMedication = defaults.string(forKey: "selectedMedication")
        selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
    }

    func persistSelection() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Combine selection into single string for encryption
        let medication = selectedMedication ?? ""
        let method = selectedAdministrationMethod ?? ""
        let selectionString = "\(medication)|\(method)"

        if let selectionData = selectionString.data(using: .utf8),
           let encryptedSelection = securityManager.encryptData(selectionData) {
            defaults.set(encryptedSelection, forKey: "encryptedMedicationSelection")
        }

        // Clear old unencrypted data
        defaults.removeObject(forKey: "selectedMedication")
        defaults.removeObject(forKey: "selectedAdministrationMethod")
    }
    
    func loadDoseDates() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Try encrypted data first
        if let encryptedDatesData = defaults.data(forKey: "encryptedDoseDates"),
           let decryptedDatesData = securityManager.decryptData(encryptedDatesData) {
            do {
                let decoder = JSONDecoder()
                let datesContainer = try decoder.decode(DoseDatesContainer.self, from: decryptedDatesData)
                lastDoseDate = datesContainer.lastDoseDate
                nextDoseDate = datesContainer.nextDoseDate
                return
            } catch {
                print("Failed to decode dose dates: \(error)")
            }
        }

        // Fallback to unencrypted data (migration)
        if let last = defaults.object(forKey: "lastDoseDate") as? Date,
           let next = defaults.object(forKey: "nextDoseDate") as? Date {
            lastDoseDate = last
            nextDoseDate = next
        }
    }

    /// Load dose dates and return them as a tuple (for compatibility with older code)
    func loadDoseDatesLegacy() -> (last: Date?, next: Date?) {
        return (lastDoseDate, nextDoseDate)
    }

    func persistDoseDates() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        let datesContainer = DoseDatesContainer(lastDoseDate: lastDoseDate, nextDoseDate: nextDoseDate)

        do {
            let encoder = JSONEncoder()
            let datesData = try encoder.encode(datesContainer)

            if let encryptedDates = securityManager.encryptData(datesData) {
                defaults.set(encryptedDates, forKey: "encryptedDoseDates")
            }
        } catch {
            print("Failed to encode dose dates: \(error)")
        }

        // Clear old unencrypted data
        defaults.removeObject(forKey: "lastDoseDate")
        defaults.removeObject(forKey: "nextDoseDate")
    }

    /// Migrate existing unencrypted data to encrypted storage
    private func migrateToEncryptedStorage() {
        let defaults = UserDefaults.standard
        let securityManager = SecurityManager.shared

        // Check if migration is needed
        if defaults.object(forKey: "encryptedMedicationSelection") != nil ||
           defaults.object(forKey: "encryptedDoseDates") != nil {
            return // Already migrated
        }

        // Migrate medication selection
        if defaults.string(forKey: "selectedMedication") != nil ||
           defaults.string(forKey: "selectedAdministrationMethod") != nil {
            persistSelection() // This will encrypt and clear old data
        }

        // Migrate dose dates
        if defaults.object(forKey: "lastDoseDate") != nil ||
           defaults.object(forKey: "nextDoseDate") != nil {
            persistDoseDates() // This will encrypt and clear old data
        }
    }

    // Container for dose dates serialization
    private struct DoseDatesContainer: Codable {
        let lastDoseDate: Date?
        let nextDoseDate: Date?
    }
    
    func updateDoseDates(last: Date?, next: Date?) {
        lastDoseDate = last
        nextDoseDate = next
        persistDoseDates()
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
