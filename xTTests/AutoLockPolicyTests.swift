//
//  AutoLockPolicyTests.swift
//  xTTests
//
//  Auto-lock policy.
//
//  Locking used to be driven by a 1 Hz timer measuring "idleness" against a
//  `recordActivity()` call that only one view ever made — so ordinary use counted as
//  idle, and the timer kept ticking even with app lock switched off. The policy is now
//  a pure function of how long the app spent in the *background*, which is both cheaper
//  and testable without a UI. These tests cover its boundaries.
//

import Testing
import Foundation
@testable import xT

@Suite("Auto-Lock Policy")
@MainActor
struct AutoLockPolicyTests {

    private func decide(
        requireAuthentication: Bool = true,
        isAuthenticated: Bool = true,
        awayDuration: TimeInterval?,
        timeout: TimeInterval = AutoLockTimeout.fiveMinutes.rawValue
    ) -> AuthenticationManager.ForegroundLockDecision {
        AuthenticationManager.foregroundLockDecision(
            requireAuthentication: requireAuthentication,
            isAuthenticated: isAuthenticated,
            awayDuration: awayDuration,
            timeout: timeout
        )
    }

    @Test("App lock off never locks, however long the app was away")
    func lockDisabledStaysUnlocked() {
        #expect(decide(requireAuthentication: false, awayDuration: 86_400) == .stayUnlocked)
        #expect(decide(requireAuthentication: false,
                       isAuthenticated: false,
                       awayDuration: nil) == .stayUnlocked)
    }

    @Test("An already-locked app re-presents its cover on return")
    func alreadyLockedPresentsCover() {
        #expect(decide(isAuthenticated: false, awayDuration: nil) == .presentExistingLock)
        #expect(decide(isAuthenticated: false, awayDuration: 1) == .presentExistingLock)
    }

    @Test("Never backgrounded means nothing to measure, so nothing locks")
    func noBackgroundStampStaysUnlocked() {
        #expect(decide(awayDuration: nil) == .stayUnlocked)
    }

    @Test("A brief hop to another app does not force re-authentication") //NEEDS FIX: App SHOULD re-authenticate even for brief app change.
    func shortAbsenceStaysUnlocked() {
        #expect(decide(awayDuration: 1) == .stayUnlocked)
        #expect(decide(awayDuration: 299) == .stayUnlocked)
    }

    @Test("Reaching the timeout locks")
    func timeoutBoundaryLocks() {
        // The boundary itself locks: `awayDuration >= timeout`.
        #expect(decide(awayDuration: 300) == .lock)
        #expect(decide(awayDuration: 301) == .lock)
    }

    @Test("Immediately locks on any absence at all")
    func immediateTimeoutLocks() {
        let immediate = AutoLockTimeout.immediately.rawValue
        #expect(decide(awayDuration: 0, timeout: immediate) == .lock)
        #expect(decide(awayDuration: 0.5, timeout: immediate) == .lock)
        // Still nothing to measure without a background stamp.
        #expect(decide(awayDuration: nil, timeout: immediate) == .stayUnlocked)
    }

    @Test("Every offered timeout locks past its own threshold and not before")
    func allTimeoutsHonourTheirThreshold() {
        for option in AutoLockTimeout.allCases {
            let timeout = option.rawValue
            #expect(decide(awayDuration: timeout, timeout: timeout) == .lock,
                    "\(option.label) should lock once the app has been away that long")
            if timeout > 0 {
                #expect(decide(awayDuration: timeout - 0.001, timeout: timeout) == .stayUnlocked,
                        "\(option.label) should not lock before its threshold")
            }
        }
    }

    @Test("An unrecognised stored timeout falls back rather than disabling lock")
    func unknownStoredTimeoutFallsBack() {
        // A value written by an older build must not silently become "never lock".
        #expect(AutoLockTimeout(storedValue: 42) == AutoLockTimeout.fallback)
        #expect(AutoLockTimeout(storedValue: AutoLockTimeout.oneHour.rawValue) == .oneHour)
    }
}
