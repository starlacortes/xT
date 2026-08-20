//
//  AppConstants.swift
//  xT
//
//  App-wide numeric constants that were previously copy-pasted as bare
//  literals across models, managers, and views. Domain-specific constants
//  live in their own homes (PKConstants for pharmacokinetics, Notification
//  defaults in NotificationManager.Keys) — this file is for the generic
//  values that cross those domains.
//

import Foundation

enum AppConstants {
    /// Seconds in one calendar day — used by day→seconds conversions in the
    /// PK model, chart windows, dose records, and overlay positioning.
    static let secondsPerDay: TimeInterval = 86_400
}
