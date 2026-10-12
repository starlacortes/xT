//
//  RangeBandTests.swift
//  xTTests
//
//  H-D4 — the user's therapeutic range as the curve draws it. Nil unless the user set
//  a range; bounds are troughMin…peakCeiling (X9); unit tracks the hormone.
//

import Testing
import Foundation
@testable import xT

@MainActor
@Suite("Range band (H-D4)")
struct RangeBandTests {

    @Test("Nil when the user has set no range")
    func nilWhenUnset() {
        let m = TestDefaults.manager()
        m.updateSelection(type: .estrogen, method: .injectable)
        #expect(m.userTherapeuticTarget == nil)
        #expect(m.rangeBand == nil)
    }

    @Test("Bounds span troughMin…peakCeiling for estrogen (pg/mL)")
    func estrogenBounds() throws {
        let m = TestDefaults.manager()
        m.selectedMedication = "Estrogen"
        m.userTherapeuticTarget = .init(troughMin: 100, troughMax: 200, peakCeiling: 600)

        let band = try #require(m.rangeBand)
        #expect(band.low == 100)
        #expect(band.high == 600)          // peakCeiling, not troughMax (X9)
        #expect(band.unit == .picogramsPerMilliliter)
    }

    @Test("Unit is ng/dL for testosterone")
    func testosteroneUnit() throws {
        let m = TestDefaults.manager()
        m.selectedMedication = "Testosterone"
        m.userTherapeuticTarget = .init(troughMin: 400, troughMax: 700, peakCeiling: 1200)

        let band = try #require(m.rangeBand)
        #expect(band.low == 400)
        #expect(band.high == 1200)
        #expect(band.unit == .nanogramsPerDeciliter)
    }
}
