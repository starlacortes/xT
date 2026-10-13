//
//  CurveLayoutTimeMarkerTests.swift
//  xTTests
//
//  Covers `CurveLayout.timeMarkers` — the tiering that picks the stationary
//  day-of-the-week rules' granularity (day → week → month) for a chart window.
//

import Foundation
import Testing
@testable import xT

@Suite("CurveLayout.timeMarkers — stationary day-of-week rules")
struct CurveLayoutTimeMarkerTests {

    /// Fixed calendar so the tiering and the labels are deterministic: UTC,
    /// Gregorian, weeks starting Sunday.
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1
        return cal
    }

    private static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
    }

    @Test("A short window gets one weekday-labeled rule per midnight")
    func dailyRules() {
        // ~3-day window across ~390 pt: ~130 pt per day, comfortably daily.
        // Oct 10 2026 is a Saturday; the midnights inside the window are
        // Sun 11, Mon 12, Tue 13 — the window's own edges are excluded.
        // Labels are asserted against the app formatter itself, not hardcoded
        // English, so the suite holds under any test-host locale.
        let markers = CurveLayout.timeMarkers(first: Self.date(2026, 10, 10),
                                               last: Self.date(2026, 10, 13),
                                               width: 390,
                                               calendar: Self.calendar)
        #expect(markers.map { $0.date } == [Self.date(2026, 10, 11, 0),
                                            Self.date(2026, 10, 12, 0),
                                            Self.date(2026, 10, 13, 0)])
        #expect(markers.map { $0.label } == markers.map { AppDateFormatters.weekdayShort.string(from: $0.date) })
        #expect(markers.count == 3)
    }

    @Test("A 90-day window drops back to weekly rules on the calendar's first weekday")
    func weeklyRules() {
        // 90 d across 390 pt is ~4.3 pt per day — too dense; weeks are ~30 pt.
        let markers = CurveLayout.timeMarkers(first: Self.date(2026, 7, 14),
                                               last: Self.date(2026, 10, 12),
                                               width: 390,
                                               calendar: Self.calendar)
        for marker in markers {
            #expect(Self.calendar.component(.weekday, from: marker.date) == Self.calendar.firstWeekday,
                    "every weekly rule should sit on the first weekday: \(marker.date)")
            #expect(marker.date > Self.date(2026, 7, 14) && marker.date < Self.date(2026, 10, 12))
            #expect(!marker.label.isEmpty)
        }
        // ~13 weeks in the window; allow the calendar edges to trim a little.
        #expect(markers.count >= 11 && markers.count <= 13)
    }

    @Test("A multi-year window steps back to month starts with month labels")
    func monthlyRules() {
        // ~2.5 years across 390 pt: weeks land ~3 pt apart (too dense to keep),
        // months ~13 pt apart — so every other month survives the thinning.
        let markers = CurveLayout.timeMarkers(first: Self.date(2024, 4, 2),
                                               last: Self.date(2026, 10, 12),
                                               width: 390,
                                               calendar: Self.calendar)
        #expect(markers.first?.date == Self.date(2024, 5, 1, 0))
        #expect(markers.allSatisfy { Self.calendar.component(.day, from: $0.date) == 1 })
        #expect(markers.allSatisfy { $0.label == AppDateFormatters.monthShort.string(from: $0.date) })
        // Thinned by k = 2: consecutive rules sit two months or more apart.
        let gaps = zip(markers, markers.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
        #expect(gaps.allSatisfy { $0 >= 55 * 86400 })
        #expect(markers.count >= 12 && markers.count <= 16)
    }

    @Test("A decades-long window thins the month axis instead of losing it")
    func sparseDecadeAxis() {
        // 40 years across 390 pt: even months crowd, so every k-th month is
        // kept — a sparse axis, never a solid wall of ink.
        let markers = CurveLayout.timeMarkers(first: Self.date(1986, 1, 1),
                                               last: Self.date(2026, 10, 12),
                                               width: 390,
                                               calendar: Self.calendar)
        #expect(!markers.isEmpty)
        #expect(markers.allSatisfy { Self.calendar.component(.day, from: $0.date) == 1 })
        // 40 y ≈ 14,900 d across 390 pt is ~38 d/pt; 24 pt of spacing means
        // consecutive rules sit well over two years apart.
        let gaps = zip(markers, markers.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
        #expect(gaps.allSatisfy { $0 >= 900 * 86400 })
        #expect(markers.count <= 20)
    }

    @Test("Degenerate and inverted windows return no rules")
    func degenerateWindows() {
        let same = Self.date(2026, 10, 12)
        #expect(CurveLayout.timeMarkers(first: same, last: same, width: 390, calendar: Self.calendar).isEmpty)
        #expect(CurveLayout.timeMarkers(first: same, last: same.addingTimeInterval(-60), width: 390, calendar: Self.calendar).isEmpty)
        #expect(CurveLayout.timeMarkers(first: same, last: same.addingTimeInterval(3600), width: 0, calendar: Self.calendar).isEmpty)
    }

    @Test("Rules never sit on the window's own edges")
    func edgesExcluded() {
        // First instant is exactly a midnight; that midnight must not appear.
        let markers = CurveLayout.timeMarkers(first: Self.date(2026, 10, 11, 0),
                                               last: Self.date(2026, 10, 13, 0),
                                               width: 390,
                                               calendar: Self.calendar)
        #expect(markers.map { $0.date } == [Self.date(2026, 10, 12, 0)])
        #expect(markers.map { $0.label } == markers.map { AppDateFormatters.weekdayShort.string(from: $0.date) })
        #expect(markers.count == 1)
    }
}
