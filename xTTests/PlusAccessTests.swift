//
//  PlusAccessTests.swift
//  xTTests
//
//  Isocline Plus entitlement resolution (calibration-and-subscriptions plan
//  §3.2, §13): an active entitlement wins, a past transaction without one is
//  lapsed (refunds included), and nothing at all is the free tier.
//

import Testing
@testable import xT

@Suite("Plus access")
struct PlusAccessTests {

    @Test func activeWinsOverHistory() {
        #expect(PlusAccess.resolve(hasActive: true, hasPastTransaction: true) == .active)
        #expect(PlusAccess.resolve(hasActive: true, hasPastTransaction: false) == .active)
    }

    @Test func pastTransactionWithoutActiveIsLapsed() {
        #expect(PlusAccess.resolve(hasActive: false, hasPastTransaction: true) == .lapsed)
    }

    @Test func noTransactionsIsFree() {
        #expect(PlusAccess.resolve(hasActive: false, hasPastTransaction: false) == .free)
    }

    @Test func productIDsShareTheAppPrefix() {
        for id in PlusProduct.all {
            #expect(id.hasPrefix("com.starlacortes.isocline.plus."))
        }
        #expect(Set(PlusProduct.all).count == PlusProduct.all.count)
    }
}
