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
    
    // MARK: - Matrix Utilities
    
    /// Checks if a given administration method is available for the specified medication type
    /// This can be expanded in the future to represent medication-specific availability
    func isMethodAvailable(type: MedicationType, method: AdministrationMethod) -> Bool {
        return method.isImplemented
    }
    
    /// Returns all available administration methods for a given medication type
    func availableMethods(for type: MedicationType) -> [AdministrationMethod] {
        return AdministrationMethod.allCases.filter { isMethodAvailable(type: type, method: $0) }
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

// Usage example: @Environment(\.medicationManager) private var medicationManager 
