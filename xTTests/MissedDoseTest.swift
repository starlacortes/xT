//
//  MissedDoseTest.swift
//  xTTests
//
//  Created by Cline on 5/28/2026.
//  Test for missed dose functionality
//

import XCTest
@testable import xT

class MissedDoseTest: XCTestCase {

    var medicationManager: MedicationManager!

    override func setUp() {
        super.setUp()
        medicationManager = MedicationManager.shared

        // Reset to clean state
        medicationManager.clearSelection()
    }

    override func tearDown() {
        medicationManager.clearSelection()
        super.tearDown()
    }

    func testMissedDoseDetection() {
        // Setup: Configure medication
        medicationManager.updateSelection(
            type: .estrogen,
            method: .injectable
        )

        // Set last dose to 8 days ago (missed the weekly dose)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        medicationManager.updateDoseDates(last: eightDaysAgo, next: nil)

        // Test: Should detect missed dose
        XCTAssertTrue(medicationManager.hasMissedDose, "Should detect missed dose when next dose date is in the past")

        // Test: Days since missed should be calculated
        if let daysMissed = medicationManager.daysSinceMissedDose {
            XCTAssertGreaterThan(daysMissed, 0, "Days since missed dose should be positive")
            print("✓ Missed dose detected: \(daysMissed) day(s) overdue")
        } else {
            XCTFail("Days since missed dose should not be nil when dose is missed")
        }
    }

    func testNoMissedDoseWhenOnTime() {
        // Setup: Configure medication
        medicationManager.updateSelection(
            type: .estrogen,
            method: .injectable
        )

        // Set last dose to today (on time)
        medicationManager.updateDoseDates(last: Date(), next: nil)

        // Test: Should not detect missed dose
        XCTAssertFalse(medicationManager.hasMissedDose, "Should not detect missed dose when next dose is in the future")

        // Test: Days since missed should be nil
        XCTAssertNil(medicationManager.daysSinceMissedDose, "Days since missed dose should be nil when no dose is missed")
    }

    func testMissedDoseRecovery() {
        // Setup: Create missed dose scenario
        medicationManager.updateSelection(
            type: .estrogen,
            method: .injectable
        )

        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        medicationManager.updateDoseDates(last: eightDaysAgo, next: nil)

        // Verify missed dose is detected
        XCTAssertTrue(medicationManager.hasMissedDose)

        // Test: Record dose to recover
        medicationManager.recordDose(on: Date())

        // Verify missed dose is resolved
        XCTAssertFalse(medicationManager.hasMissedDose, "Missed dose should be resolved after recording dose")
        XCTAssertNotNil(medicationManager.nextDoseDate, "Next dose date should be updated after recording dose")

        print("✓ Missed dose recovery successful")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
            for _ in 0..<100 {
                _ = medicationManager.hasMissedDose
                _ = medicationManager.daysSinceMissedDose
            }
        }
    }
}