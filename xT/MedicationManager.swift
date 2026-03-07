//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//  Simplified version
//

import SwiftUI
import SwiftData

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
    
    /// Record a dose was taken
    func recordDose(on date: Date = Date()) {
        lastDoseDate = date
        if let medication = selectedMedication,
           let method = selectedAdministrationMethod {
            nextDoseDate = calculateNextDoseDate(from: date)
        }
        persistDoseDates()
    }
    
    /// Calculate the next dose date based on current regimen
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        guard let medication = selectedMedication,
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
        // Load from UserDefaults or other storage
        let defaults = UserDefaults.standard
        selectedMedication = defaults.string(forKey: "selectedMedication")
        selectedAdministrationMethod = defaults.string(forKey: "selectedAdministrationMethod")
    }
    
    func persistSelection() {
        let defaults = UserDefaults.standard
        defaults.set(selectedMedication, forKey: "selectedMedication")
        defaults.set(selectedAdministrationMethod, forKey: "selectedAdministrationMethod")
    }
    
    func loadDoseDates() {
        let defaults = UserDefaults.standard
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
        defaults.set(lastDoseDate, forKey: "lastDoseDate")
        defaults.set(nextDoseDate, forKey: "nextDoseDate")
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
