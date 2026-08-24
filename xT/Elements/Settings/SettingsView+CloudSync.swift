//
//  SettingsView+CloudSync.swift
//  xT
//
//  "Restore from iCloud" and "Sync Now" row handlers.
//  (Split from SettingsView.swift — same `SettingsView`, different file.)
//

import SwiftUI

extension SettingsView {

    // MARK: - iCloud restore / sync

    func restoreFromiCloud() async {
        cloudActivity = .restoring
        let restored = await CloudSyncService.restoreFromiCloud()
        cloudActivity = nil
        if restored {
            showRestoreCompleteAlert = true
        } else {
            showRestoreNotFoundAlert = true
        }
        // No onboardingComplete here: the managers are ObservableObjects, so
        // Settings rows and the rest of the app refresh live on success.
    }

    func syncNow() async {
        cloudActivity = .syncing
        let requested = await CloudSyncService.syncNow()
        cloudActivity = nil
        if requested {
            showSyncCompleteAlert = true
        } else {
            showSyncFailedAlert = true
        }
    }
}
