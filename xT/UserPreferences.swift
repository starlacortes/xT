//
//  UserPreferences.swift
//  xT
//
//  Created by Starla Cortes on 2/17/26.
//


import Foundation
import SwiftData

@Model
final class UserPreferences {
    // Persisted indices for selection. Using Int keeps compatibility with enums.
    var medicationRow: Int
    var medicationColumn: Int

    // Optional persisted dose dates
    var lastDoseDate: Date?
    var nextDoseDate: Date?

    init(medicationRow: Int = -1, medicationColumn: Int = -1, lastDoseDate: Date? = nil, nextDoseDate: Date? = nil) {
        self.medicationRow = medicationRow
        self.medicationColumn = medicationColumn
        self.lastDoseDate = lastDoseDate
        self.nextDoseDate = nextDoseDate
    }
}

/*
 Future iCloud notes:
 - SwiftData can be configured to sync with iCloud by enabling CloudKit for the container in the app Target capabilities and using a shared model container with iCloud configuration.
 - At that point, this @Model will participate in syncing automatically.
 - Keep properties stable (avoid frequent schema changes) and prefer enums backed by Ints/Strings for forward compatibility.
*/
