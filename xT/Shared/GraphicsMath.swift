//
//  GraphicsMath.swift
//  xT
//
//  Deterministic math primitives shared by the SceneKit/SwiftUI graphics
//  code: a canonical ease-in-out-quad curve, seeded RNG streams (stable
//  across runs, unlike Swift's randomized hashing), and the night-sky star
//  palette. Previously each renderer kept its own hand-rolled copy.
//

import Foundation
import simd

enum Ease {
    /// Canonical ease-in-out-quad. Input is clamped to 0...1.
    static func inOutQuad(_ t: Double) -> Double {
        let c = min(max(t, 0), 1)
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }
}

/// SplitMix64 — stable across runs, unlike Swift's randomized hashing.
struct SplitMix64 {
    var state: UInt64

    init(state: UInt64) {
        self.state = state
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform float in [0, 1).
    mutating func nextUnit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}

/// SplitMix32-style avalanche plus per-lane uniform streams — stable across
/// runs, unlike `Int.hashValue`.
enum SplitMix32 {
    static func hash(_ x: UInt32) -> UInt32 {
        var z = x &+ 0x9E3779B9
        z = (z ^ (z >> 16)) &* 0x21F0AAAD
        z = (z ^ (z >> 15)) &* 0x735A2D97
        return z ^ (z >> 15)
    }

    /// Uniform [0, 1) stream `lane` derived from a seed hash.
    static func rand(_ h: UInt32, _ lane: UInt32) -> Float {
        Float(hash(h &+ lane &* 0x85EBCA6B)) / Float(UInt32.max)
    }
}

/// Night-sky palette — deliberately *not* theme-tinted, so stars read
/// against the starfield body. Shared by `StarFieldGeometry`.
enum StarPalette {
    static let warmWhite = SIMD3<Float>(1.00, 0.95, 0.86)
    static let coolBlue  = SIMD3<Float>(0.72, 0.82, 1.00)
    static let gold      = SIMD3<Float>(1.00, 0.78, 0.45)

    /// Starfield color: mostly warm white, a fifth cool blue, a few gold
    /// accents, scaled by a brightness variation so the field doesn't read
    /// as a uniform grid of identical LEDs.
    static func fieldColor(pick: Float, brightness: Float) -> SIMD3<Float> {
        let base: SIMD3<Float>
        if pick < 0.72 {
            base = warmWhite
        } else if pick < 0.92 {
            base = coolBlue
        } else {
            base = gold
        }
        return base * brightness
    }
}
