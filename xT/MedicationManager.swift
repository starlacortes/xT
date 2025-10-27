//
//  MedicationManager.swift
//  xT
//
//  Created by Starla Cortes on 5/16/25.
//

import SwiftUI
import Combine

/// MedicationManager handles all the matrix-based medication functionality
/// and serves as the data layer for medication selection and retrieval.
class MedicationManager: ObservableObject {
    // MARK: - Shared Instance (Singleton)
    static let shared = MedicationManager()

    // MARK: - Medication Matrix Definition

    /// Enumeration for medication types (rows in the matrix)
    enum MedicationType: Int, CaseIterable {
        case estrogen = 0
        case testosterone = 1

        var displayName: String {
            switch self {
            case .estrogen: return "Estrogen"
            case .testosterone: return "Testosterone"
            }
        }
    }

    /// Enumeration for administration methods (columns in the matrix)
    enum AdministrationMethod: Int, CaseIterable {
        case injectable = 0
        case cream = 1
        case oral = 2  // Future use

        var displayName: String {
            switch self {
            case .injectable: return "Injectable"
            case .cream: return "Cream"
            case .oral: return "Oral"
            }
        }

        var isImplemented: Bool {
            switch self {
            case .injectable, .cream: return true
            case .oral: return false  // Not yet implemented
            }
        }
    }

    // MARK: - Matrix Data

    /// Matrix to store medication names
    private let medicationMatrix: [[String]] = [
        // Column 0 (Injectable), Column 1 (Cream), Column 2 (Oral)
        ["Injectable Estrogen", "Estrogen Cream", "Oral Estrogen"],           // Row 0 (Estrogen)
        ["Injectable Testosterone", "Testosterone Cream", "Oral Testosterone"] // Row 1 (Testosterone)
    ]

    /// Matrix to store medication dosages (example for future use)
    private let dosageMatrix: [[String]] = [
        ["0.5ml weekly", "2.5g daily", "10mg daily"],  // Estrogen dosages
        ["1ml weekly", "5g daily", "20mg daily"]       // Testosterone dosages
    ]

    // MARK: - User Preferences

    // AppStorage wrappers for persisting user's medication choices
    @AppStorage("MedicationRow") private var medicationRow: Int = -1
    @AppStorage("MedicationColumn") private var medicationColumn: Int = -1

    // Published properties for SwiftUI binding
    @Published var selectedMedicationType: MedicationType?
    @Published var selectedAdministrationMethod: AdministrationMethod?

    // MARK: - Initialization

    private init() {
        // Initialize published properties from AppStorage if values exist
        if medicationRow >= 0 && medicationRow < MedicationType.allCases.count {
            selectedMedicationType = MedicationType(rawValue: medicationRow)
        }

        if medicationColumn >= 0 && medicationColumn < AdministrationMethod.allCases.count {
            selectedAdministrationMethod = AdministrationMethod(rawValue: medicationColumn)
        }
    }

    // MARK: - Matrix Accessors

    /// Returns the current matrix coordinates as a tuple
    var currentCoordinates: (row: Int, column: Int) {
        return (medicationRow, medicationColumn)
    }

    /// Returns the medication name based on the stored matrix coordinates
    var medicationName: String {
        guard medicationRow >= 0 && medicationRow < medicationMatrix.count,
              medicationColumn >= 0 && medicationColumn < medicationMatrix[medicationRow].count else {
            return "No medication selected"
        }

        return medicationMatrix[medicationRow][medicationColumn]
    }

    /// Returns the dosage information based on the stored matrix coordinates
    var dosageInfo: String {
        guard medicationRow >= 0 && medicationRow < dosageMatrix.count,
              medicationColumn >= 0 && medicationColumn < dosageMatrix[medicationRow].count else {
            return "No dosage information available"
        }

        return dosageMatrix[medicationRow][medicationColumn]
    }

    // MARK: - User Selection Methods

    /// Updates the medication selection and saves to AppStorage
    /// - Parameters:
    ///   - type: The selected medication type
    ///   - method: The selected administration method
    func updateSelection(type: MedicationType?, method: AdministrationMethod?) {
        // Update published properties
        self.selectedMedicationType = type
        self.selectedAdministrationMethod = method

        // Save to AppStorage
        if let type = type {
            medicationRow = type.rawValue
        }

        if let method = method {
            medicationColumn = method.rawValue
        }
    }

    /// Clears the current medication selection
    func clearSelection() {
        selectedMedicationType = nil
        selectedAdministrationMethod = nil
        medicationRow = -1
        medicationColumn = -1
    }

    // MARK: - Future Calculation Methods

    /// Example method for future functionality - Calculate next dose date
    func calculateNextDoseDate(from lastDose: Date) -> Date {
        guard let type = selectedMedicationType,
              let method = selectedAdministrationMethod else {
            return Date() // Return current date if no selection
        }

        // Different calculation logic based on medication and administration method
        switch (type, method) {
        case (.estrogen, .injectable), (.testosterone, .injectable):
            // Weekly injection
            return Calendar.current.date(byAdding: .day, value: 7, to: lastDose) ?? Date()

        case (.estrogen, .cream), (.testosterone, .cream):
            // Daily application
            return Calendar.current.date(byAdding: .day, value: 1, to: lastDose) ?? Date()

        case (_, .oral):
            // Daily pill
            return Calendar.current.date(byAdding: .day, value: 1, to: lastDose) ?? Date()
        }
    }

    // MARK: - Availability Helpers

    /// Returns the available administration methods for a given medication type.
    /// Currently filters out methods that are not yet implemented.
    /// - Parameter type: The selected medication type.
    /// - Returns: An array of implemented administration methods.
    func availableMethods(for type: MedicationType) -> [AdministrationMethod] {
        // In the future, availability could depend on the type; for now, filter by implementation status
        return AdministrationMethod.allCases.filter { $0.isImplemented }
    }

    // MARK: - Estimated Hormone Levels

    struct EstimatedPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Produces a naive estimated hormone level series for the current selection over a date range.
    /// - Parameters:
    ///   - start: Start date of the series.
    ///   - end: End date of the series.
    ///   - stepDays: Spacing in days between points.
    /// - Returns: An array of estimated points.
    func estimatedLevels(from start: Date, to end: Date, stepDays: Int = 1) -> [EstimatedPoint] {
        guard let type = selectedMedicationType, let method = selectedAdministrationMethod else { return [] }
        var points: [EstimatedPoint] = []
        var cursor = start
        let calendar = Calendar.current

        // Baseline assumptions per hormone (arbitrary demo values)
        let baseline: Double = {
            switch type {
            case .estrogen: return 80
            case .testosterone: return 500
            }
        }()

        // Method dynamics (very rough illustrative model)
        // - Injectable: peak at dose day, exponential decay with ~7-day half-life
        // - Cream: daily application creates a smoother, small oscillation around baseline
        let halfLifeDays = 7.0
        let decayLambda = log(2) / halfLifeDays

        while cursor <= end {
            let daysSinceStart = calendar.dateComponents([.day], from: start, to: cursor).day ?? 0
            let value: Double
            switch method {
            case .injectable:
                // Weekly pulses: every 7 days a dose spikes +40% then decays
                let period = 7
                let dayInCycle = daysSinceStart % period
                let spikeMagnitude = baseline * 0.4
                let decayed = spikeMagnitude * exp(-decayLambda * Double(dayInCycle))
                value = baseline + decayed
            case .cream:
                // Daily steady-state: baseline +/- small sinusoidal variation (~5%)
                value = baseline * (1.0 + 0.05 * sin(Double(daysSinceStart) / 6.0 * .pi))
            case .oral:
                // Not implemented in UI, but provide simple daily pulse
                let spikeMagnitude = baseline * 0.2
                let decayed = spikeMagnitude * exp(-decayLambda * Double(daysSinceStart % 1))
                value = baseline + decayed
            }

            points.append(EstimatedPoint(date: cursor, value: value))
            cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor) ?? cursor
            if cursor == points.last?.date { break }
        }

        return points
    }

    /// Convenience to produce a default recent window (e.g., last 90 days to today).
    func estimatedRecentLevels(days: Int = 90) -> [EstimatedPoint] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return estimatedLevels(from: start, to: end)
    }
}

// MARK: - SwiftUI Property Wrapper for easier access to MedicationManager
struct MedicationManagerKey: EnvironmentKey {
    static let defaultValue = MedicationManager.shared
}

extension EnvironmentValues {
    var medicationManager: MedicationManager {
        get { self[MedicationManagerKey.self] }
        set { self[MedicationManagerKey.self] = newValue }
    }
}

