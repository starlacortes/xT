//
//  CurveLayout.swift
//  xT
//
//  Shared math for positioning data points on hormone graphs.
//  Provides cubic-bezier curve construction and X/Y coordinate mapping
//  used by FlatGraphView, MiniTrendGraph, and any future chart components.
//

import SwiftUI

/// Pure math — no view dependencies.  All functions take a view-port width/height
/// so they work across `Path`, `Canvas`, and `GeometryReader` contexts.
enum CurveLayout {

    // MARK: - X-axis

    /// Horizontal position for the data point at `index` (0…count-1).
    static func xPos(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    /// Like `xPos` but clamped 8pt from edges so markers don't clip off-screen.
    static func markerX(index: Int, count: Int, width: CGFloat) -> CGFloat {
        min(max(xPos(index: index, count: count, width: width), 8), width - 8)
    }

    // MARK: - Y-axis

    /// Vertical position for a data value within the given value range and pixel height.
    ///
    /// `dataFraction` controls how much of `height` the data occupies (1.0 = full height).
    /// `bottomMargin` is the bottom-padding fraction within the data region.
    static func yPos(value: Double,
                     min: Double,
                     range: Double,
                     height: CGFloat,
                     dataFraction: CGFloat = 1.0,
                     bottomMargin: CGFloat = 0.07) -> CGFloat {
        guard range > 0 else { return height / 2 }
        let norm = (value - min) / range
        let dataHeight = height * dataFraction
        return height - CGFloat(norm) * dataHeight * 0.85 - dataHeight * bottomMargin - height * (1 - dataFraction)
    }

    /// Band variant of `yPos`: the curve occupies the vertical band `[plotTop, plotBottom]`
    /// directly, rather than a fraction of the full height. Used by the Home curve (H1),
    /// whose top and bottom insets track the readout and overlay-card heights (`plotInsets`).
    static func yPos(value: Double,
                     min: Double,
                     range: Double,
                     plotTop: CGFloat,
                     plotBottom: CGFloat) -> CGFloat {
        let band = Swift.max(plotBottom - plotTop, 1)
        guard range > 0 else { return plotTop + band / 2 }
        let norm = (value - min) / range
        return plotBottom - CGFloat(norm) * band
    }

    // MARK: - Computed bounds

    /// The inflated value range (85% of min, 110% of max) used by all graphs.
    static func valueBounds(_ values: [Double]) -> (min: Double, max: Double, range: Double) {
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let minV = rawMin * 0.85
        let maxV = rawMax * 1.1
        return (minV, maxV, maxV - minV)
    }

    // MARK: - Path construction (cubic bezier)

    static func curvePath(values: [Double],
                          min: Double,
                          range: Double,
                          width: CGFloat,
                          height: CGFloat,
                          dataFraction: CGFloat = 1.0) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            for (i, v) in values.enumerated() {
                let x = xPos(index: i, count: values.count, width: width)
                let y = yPos(value: v, min: min, range: range, height: height, dataFraction: dataFraction)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let prev = CGPoint(
                        x: xPos(index: i - 1, count: values.count, width: width),
                        y: yPos(value: values[i - 1], min: min, range: range, height: height, dataFraction: dataFraction)
                    )
                    let ctrl1 = CGPoint(x: prev.x + (x - prev.x) * 0.5, y: prev.y)
                    let ctrl2 = CGPoint(x: prev.x + (x - prev.x) * 0.5, y: y)
                    path.addCurve(to: CGPoint(x: x, y: y), control1: ctrl1, control2: ctrl2)
                }
            }
        }
    }

    static func curveFillPath(values: [Double],
                              min: Double,
                              range: Double,
                              width: CGFloat,
                              height: CGFloat,
                              dataFraction: CGFloat = 1.0) -> Path {
        var base = curvePath(values: values, min: min, range: range, width: width, height: height, dataFraction: dataFraction)
        let bottomY = dataFraction < 1.0
            ? height * (1 - dataFraction) + height * dataFraction * 0.93
            : height
        base.addLine(to: CGPoint(x: width, y: bottomY))
        base.addLine(to: CGPoint(x: 0, y: bottomY))
        base.closeSubpath()
        return base
    }

    // MARK: - Path construction (band variant)

    /// Band-mapped cubic-bezier stroke path: the curve is drawn into the vertical band
    /// `[plotTop, plotBottom]` (H1). Shares the smoothing of the `dataFraction` variant.
    static func curvePath(values: [Double],
                          min: Double,
                          range: Double,
                          width: CGFloat,
                          plotTop: CGFloat,
                          plotBottom: CGFloat) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            func y(_ i: Int) -> CGFloat {
                yPos(value: values[i], min: min, range: range, plotTop: plotTop, plotBottom: plotBottom)
            }
            for i in values.indices {
                let x = xPos(index: i, count: values.count, width: width)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y(i)))
                } else {
                    let prevX = xPos(index: i - 1, count: values.count, width: width)
                    let ctrl1 = CGPoint(x: prevX + (x - prevX) * 0.5, y: y(i - 1))
                    let ctrl2 = CGPoint(x: prevX + (x - prevX) * 0.5, y: y(i))
                    path.addCurve(to: CGPoint(x: x, y: y(i)), control1: ctrl1, control2: ctrl2)
                }
            }
        }
    }

    /// Band-mapped fill path. The curve closes down to `fillBottom` (the screen bottom on
    /// Home, so the fill reads behind the overlay card), not to the band's own floor.
    static func curveFillPath(values: [Double],
                              min: Double,
                              range: Double,
                              width: CGFloat,
                              plotTop: CGFloat,
                              plotBottom: CGFloat,
                              fillBottom: CGFloat) -> Path {
        var base = curvePath(values: values, min: min, range: range,
                             width: width, plotTop: plotTop, plotBottom: plotBottom)
        base.addLine(to: CGPoint(x: width, y: fillBottom))
        base.addLine(to: CGPoint(x: 0, y: fillBottom))
        base.closeSubpath()
        return base
    }

    // MARK: - Nice axis ticks

    /// Returns evenly-spaced label values for the Y-axis given a data range.
    static func niceTicks(min: Double, max: Double, count: Int = 4) -> [Double] {
        guard count > 0, max > min else { return [] }
        let roughStep = (max - min) / Double(count)
        let exponent = floor(log10(roughStep))
        let fraction = roughStep / pow(10, exponent)

        let niceStep: Double = switch fraction {
        case ..<1.5:  1
        case ..<3:    2
        case ..<7:    5
        default:      10
        }

        let step = niceStep * pow(10, exponent)
        let niceMin = floor(min / step) * step

        var ticks: [Double] = []
        var tick = niceMin
        while tick <= max + step * 0.5 {
            if tick >= min { ticks.append(tick) }
            tick += step
        }
        return ticks
    }
}

// MARK: - Animatable Vector for curve morphing

/// Used by `AnimatableCurveShape` to smoothly interpolate between two sets of
/// hormone-level values when new dose data arrives.
struct AnimatableVector: VectorArithmetic {
    var values: [Double]

    static var zero = AnimatableVector(values: [])

    static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        let count = max(lhs.values.count, rhs.values.count)
        let lPad = lhs.values.last ?? 0
        let rPad = rhs.values.last ?? 0
        var result: [Double] = []
        for i in 0..<count {
            let l = i < lhs.values.count ? lhs.values[i] : lPad
            let r = i < rhs.values.count ? rhs.values[i] : rPad
            result.append(l + r)
        }
        return AnimatableVector(values: result)
    }

    static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        let count = max(lhs.values.count, rhs.values.count)
        let lPad = lhs.values.last ?? 0
        let rPad = rhs.values.last ?? 0
        var result: [Double] = []
        for i in 0..<count {
            let l = i < lhs.values.count ? lhs.values[i] : lPad
            let r = i < rhs.values.count ? rhs.values[i] : rPad
            result.append(l - r)
        }
        return AnimatableVector(values: result)
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }
}

// MARK: - Animatable Shape

/// A `Shape` whose `animatableData` is the data vector itself, allowing
/// SwiftUI to interpolate the hormone curve smoothly between data sets.
struct AnimatableCurveShape: Shape {
    var values: AnimatableVector
    var minV: Double
    var range: Double
    var dataFraction: CGFloat = 1.0
    /// When set (with `plotBottom`), the curve is drawn into the band `[plotTop, plotBottom]`
    /// instead of `dataFraction` of the full height (the Home `plotInsets` path, H1).
    var plotTop: CGFloat? = nil
    var plotBottom: CGFloat? = nil

    var animatableData: AnimatableVector {
        get { values }
        set { values = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if let plotTop, let plotBottom {
            return CurveLayout.curvePath(
                values: values.values, min: minV, range: range,
                width: rect.width, plotTop: plotTop, plotBottom: plotBottom
            )
        }
        return CurveLayout.curvePath(
            values: values.values,
            min: minV,
            range: range,
            width: rect.width,
            height: rect.height,
            dataFraction: dataFraction
        )
    }
}

struct AnimatableFillShape: Shape {
    var values: AnimatableVector
    var minV: Double
    var range: Double
    var dataFraction: CGFloat = 1.0
    /// Band mapping, as in `AnimatableCurveShape`. `fillBottom` is where the fill closes
    /// (the screen bottom on Home, so it reads behind the overlay card).
    var plotTop: CGFloat? = nil
    var plotBottom: CGFloat? = nil
    var fillBottom: CGFloat? = nil

    var animatableData: AnimatableVector {
        get { values }
        set { values = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if let plotTop, let plotBottom {
            return CurveLayout.curveFillPath(
                values: values.values, min: minV, range: range,
                width: rect.width, plotTop: plotTop, plotBottom: plotBottom,
                fillBottom: fillBottom ?? rect.height
            )
        }
        return CurveLayout.curveFillPath(
            values: values.values,
            min: minV,
            range: range,
            width: rect.width,
            height: rect.height,
            dataFraction: dataFraction
        )
    }
}
