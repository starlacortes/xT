//
//  PKChartWindow.swift
//  xT
//
//  Chooses the date window and sample step the hormone chart is drawn from.
//
//  Pure math — no view and no manager dependencies, mirroring `CurveLayout.swift`.
//  `CurveLayout` maps values to pixels; this maps an ester's pharmacokinetics to a
//  time range and a sampling resolution. They are deliberately separate files.
//

import Foundation

/// Sizes the chart's visible time range from the ester actually being plotted.
///
/// **Why this exists.** The window and step used to be chosen inline from the manager's
/// *globally selected* administration method, in two places that had already drifted
/// apart (`halfLife / 30` in `refreshState`, `halfLife / 40` in `FlatGraphView`). Two
/// defects followed:
///
///   * **Oral was fully phase-aliased.** The non-injectable path took
///     `estimatedLevels`' default `stepDays = 1.0`, which is exactly the oral dosing
///     interval, so every sample landed at the same point in the dose cycle and the
///     drawn curve was a dead-flat line — against a modeled swing of 2.4× (oral E2)
///     and 18.5× (oral T) across that same window. What little movement a real user
///     saw came from dose-time jitter, not pharmacology.
///   * **Every injectable got the same hardcoded 3-day window.** That fits EV, but it
///     renders TU's 70-day cycle as five points.
///
/// **The rule.** EV's 1-day-back / 2-days-forward window is the one this replaces and
/// reproduces: EV's t_max is 2.10 d, so the forward extent is one time-to-peak and the
/// total is ~1.5 × t_max, split 1:2 past:future. Generalized:
///
///     W    = clamp(1.5 · t_max, lower: min(2 d, 2 · interval), upper: 1.5 · interval)
///     past = W/3,  forward = 2W/3
///     step = max(min(W/40, t_max/8), 15 min)
///
/// The `t_max/8` cap is the anti-aliasing guarantee — it is what stops the oral curve
/// from collapsing to a line. The `W/40` term keeps every ester at a comparable point
/// count (~41) so curves read with the same density regardless of timescale.
enum PKChartWindow {

    /// A resolved chart window: the range to sample and the resolution to sample it at.
    struct Window: Equatable {
        let start: Date
        let end: Date

        /// Step for the drawn curve (`MedicationManager.recentLevels`).
        let stepDays: Double

        /// Finer step for scrub interpolation and the "now" dot. Derived from
        /// `stepDays` rather than computed independently, so the two can't diverge
        /// the way the old inline formulas did.
        let denseStepDays: Double

        var totalDays: Double { end.timeIntervalSince(start) / 86400.0 }
    }

    /// - Parameters:
    ///   - tmaxDays: Exact Bateman time-to-peak for the *effective* ester, or `nil` when
    ///     it must not be trusted. **Callers must pass `nil`, not the raw value, when
    ///     `!ester.isTmaxCalibrated` or the value is non-finite.** This function does not
    ///     inspect those flags, so the gate lives at exactly one call site
    ///     (`MedicationManager.chartWindow(now:)`) and cannot be half-applied.
    ///
    ///     Passing a raw `timeToPeakDays` here would be a live NaN hazard rather than a
    ///     style problem: `TestosteroneEster.transdermal.timeToPeakDays` is NaN by design
    ///     (ke = 0, so the Bateman does not apply), and Swift's `min`/`max` are asymmetric
    ///     under NaN — `min(.nan, 5)` is NaN but `min(5, .nan)` is 5. Correctness would
    ///     then depend on operand order. `nil` is checked; NaN silently isn't.
    ///   - intervalDays: Effective dosing interval. Floored at a positive value, so a
    ///     future ester with a zero interval degrades instead of producing a zero-width
    ///     window.
    ///   - now: The instant the window is centred on. Injected for testability.
    static func compute(tmaxDays: Double?, intervalDays: Double, now: Date) -> Window {
        let interval = max(intervalDays, PKConstants.chartWindowMinIntervalDays)

        // The single gate. Past this line `peak` is either a usable positive number or
        // absent — no NaN can reach the arithmetic below.
        let peak: Double? = {
            guard let t = tmaxDays, t.isFinite, t > 0 else { return nil }
            return t
        }()

        let raw = peak.map { PKConstants.chartWindowTmaxMultiplier * $0 }
            ?? PKConstants.chartWindowFallbackRawDays

        let upper = PKConstants.chartWindowUpperIntervalMultiplier * interval

        // The lower bound is floored at `upper` so the two can never cross. For any
        // interval below 4/3 d — today that means the daily routes, oral and cream —
        // the raw lower bound (2 d) exceeds the ceiling (1.5 × 1 d), and the window must
        // collapse to the ceiling rather than invert. Without this floor the result
        // would depend on the argument order of `min`/`max`, which is exactly the kind
        // of accident this file exists to prevent.
        let lower = min(min(PKConstants.chartWindowLowerCapDays, 2.0 * interval), upper)

        let total = max(min(raw, upper), lower)

        // 1 part history to 2 parts projection, the split EV already shipped.
        let past = total / 3.0
        let forward = total - past

        var step = total / PKConstants.chartWindowStepDivisor
        if let peak {
            // The anti-aliasing guarantee: never sample coarser than t_max/8.
            step = min(step, peak / PKConstants.chartWindowTmaxStepDivisor)
        }
        step = max(step, PKConstants.chartWindowMinStepDays)

        let denseStep = max(step / PKConstants.chartWindowDenseStepDivisor,
                            PKConstants.chartWindowMinDenseStepDays)

        return Window(
            start: now.addingTimeInterval(-past * 86400.0),
            end: now.addingTimeInterval(forward * 86400.0),
            stepDays: step,
            denseStepDays: denseStep
        )
    }
}
