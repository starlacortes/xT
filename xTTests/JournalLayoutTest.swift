//
//  JournalLayoutTest.swift
//  xT
//
//  Created by Cline on 5/26/2026.
//  Test file to verify journal layout fixes
//

import SwiftUI
@testable import xT

struct JournalLayoutTest: View {
    @State private var testEntry = "This is a test journal entry to verify that content no longer escapes the device borders. The text should be properly contained within safe area insets and not extend beyond the screen edges on any device."

    var body: some View {
        NavigationStack {
            JournalView()
                .environment(\.journalManager, JournalManager.shared)
                .environment(\.medicationManager, MedicationManager.shared)
                .navigationTitle("Layout Test")
        }
    }
}

#Preview {
    JournalLayoutTest()
}