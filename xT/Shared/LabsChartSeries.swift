//
//  LabsChartSeries.swift
//  xT
//
//  Pure-math chart model for the blood test history view. Deliberately imports
//  only Foundation: no SwiftUI, no MedicationManager, so the range math and the
//  series mapping are unit-testable without a simulator or a manager instance.
//

import Foundation

/// A single plotted point on the labs chart: the measured lab result at a draw
/// date, alongside the model's uncalibrated prediction at that same instant.
///
/// `predicted` is `nil` when the model could not produce a value for the draw
/// (no medication/method configured, or a predicted level ≤ 0.01). The chart
/// draws a gap in the modeled series at those points rather than interpolating
/// across them.
struct LabsSeriesPoint: Equatable, Identifiable {
    let id = UUID()
    let drawDate: Date
    let measured: Double
    let predicted: Double?
    let isCalibrated: Bool
}

/// Chart-series math for the labs view.
enum LabsChartSeries {

    /// The vertical extent the chart should plot, given the points to show.
    ///
    /// - Returns: A `(min, max)` pair that always spans at least `minimumSpan`
    ///   (default 1.0) so a single point or a flat series still renders a visible
    ///   band rather than a zero-height chart. When `points` is empty, returns
    ///   `(0, minimumSpan)`.
    static func range(for points: [LabsSeriesPoint], now: Date = Date(),
                      minimumSpan: Double = 1.0) -> (min: Double, max: Double) {
        var values: [Double] = points.map(\.measured)
        values.append(contentsOf: points.compactMap(\.predicted))

        guard let lo = values.min(), let hi = values.max() else {
            return (0, minimumSpan)
        }

        let span = max(hi - lo, minimumSpan)
        // Pad by 10% on each side so dots at the extremes don't sit on the edge.
        let padding = span * 0.10
        return (lo - padding, hi + padding)
    }
}