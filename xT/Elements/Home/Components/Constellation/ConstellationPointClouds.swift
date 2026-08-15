//
//  ConstellationPointClouds.swift
//  xT
//
//  Generates the brain and body point clouds consumed by ConstellationView.
//  Clouds are deterministic (seeded RNG) so they stay stable across renders,
//  and are regenerated only when `months` changes. The body cloud samples
//  points inside the existing DynamicBodySilhouette shape, so it widens at the
//  hips as months on HRT grow.
//

import SwiftUI
import simd

// MARK: - Seeded RNG (SplitMix64)

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Cloud Generation

enum ConstellationCloud {

    /// How actively a region is changing right now (0…1) — drives glow.
    /// `medication` selects which authored region set (timing differs by
    /// medication even where the region key is shared) the lookup reads from.
    static func activity(regionKey: String, months: Int, medication: String) -> Double {
        let all: [BodyRegion]
        if medication == "Estrogen" {
            all = TimeBodyRegions.mindRegions + TimeBodyRegions.bodyRegions
        } else {
            all = TimeBodyRegions.mindRegionsT + TimeBodyRegions.bodyRegionsT
        }
        guard let r = all.first(where: { $0.key == regionKey }) else { return 0.4 }
        let m = Double(months)
        if m < Double(r.startMonth) { return 0.06 }
        if m < Double(r.peakMonth) {
            let span = Double(max(1, r.peakMonth - r.startMonth))
            return 0.2 + 0.8 * ((m - Double(r.startMonth)) / span)
        }
        if m < Double(r.completeMonth) {
            let span = Double(max(1, r.completeMonth - r.peakMonth))
            return 1.0 - 0.6 * ((m - Double(r.peakMonth)) / span)
        }
        return 0.35
    }

    // MARK: Brain

    static func brain(months: Int) -> ConstellationField {
        var rng = SeededRNG(seed: 0xB0A17_C0DE)
        let density = min(1.0, Double(max(months, 0)) / 36.0)
        let count = 150 + Int(60 * density)

        // Ellipsoid radii (x: left-right, y: up, z: front-back).
        let rx: Float = 0.85, ry: Float = 0.62, rz: Float = 0.72

        var nodes: [ConstellationNode] = []
        nodes.reserveCapacity(count)

        var attempts = 0
        while nodes.count < count && attempts < count * 40 {
            attempts += 1
            let u = SIMD3<Float>(
                Float.random(in: -1...1, using: &rng),
                Float.random(in: -1...1, using: &rng),
                Float.random(in: -1...1, using: &rng))
            let len = simd_length(u)
            if len > 1 || len < 0.15 { continue }
            // Bias toward the shell for a wireframe-ish surface.
            let shell = powf(Float.random(in: 0...1, using: &rng), 0.5) * 0.5 + 0.5
            let dir = u / len
            let p = dir * shell * SIMD3<Float>(rx, ry, rz)

            // Central sulcus gap between hemispheres.
            if abs(p.x) < 0.05 && Float.random(in: 0...1, using: &rng) < 0.7 { continue }

            // Normalized position for region tagging.
            let n = SIMD3<Float>(p.x / rx, p.y / ry, p.z / rz)
            var region: String? = nil
            var secondary = false

            if n.z > 0.35 && n.y > 0.0 {
                region = "pfc"
            } else if n.y < -0.15 && abs(n.x) < 0.5 && abs(n.z) < 0.5 {
                region = "hippocampus"
                secondary = true
            } else if abs(n.x) > 0.45 && n.y < 0.2 && n.y > -0.55 {
                region = "amygdala"
            } else if Float.random(in: 0...1, using: &rng) < 0.35 {
                region = "synaptic"
            }

            let brightness: Float = region == nil
                ? Float.random(in: 0.3...0.55, using: &rng)
                : Float.random(in: 0.7...1.0, using: &rng)

            nodes.append(ConstellationNode(
                base: p,
                region: region,
                seed: Float.random(in: 0...6.28, using: &rng),
                brightness: brightness,
                useSecondary: secondary))
        }

        return ConstellationField(nodes: nodes,
                                  edges: buildEdges(nodes, threshold: 0.30, maxPerNode: 3))
    }

    // MARK: Body

    static func body(months: Int, medication: String) -> ConstellationField {
        var rng = SeededRNG(seed: 0xB0D1_5EED)
        let density = min(1.0, Double(max(months, 0)) / 36.0)
        let count = 150 + Int(70 * density)

        // Sample inside the animatable silhouette at the current month. Estrogen
        // grows a bust/hips and narrows the waist; testosterone broadens the
        // shoulders and chest instead — see DynamicBodySilhouette(T).
        let vRect = CGRect(x: 0, y: 0, width: 100, height: 120)
        let silhouette: Path = medication == "Estrogen"
            ? DynamicBodySilhouette(elapsedMonths: Double(months)).path(in: vRect)
            : DynamicBodySilhouetteT(elapsedMonths: Double(months)).path(in: vRect)

        var nodes: [ConstellationNode] = []
        nodes.reserveCapacity(count)

        var attempts = 0
        while nodes.count < count && attempts < count * 30 {
            attempts += 1
            let vx = CGFloat.random(in: 14...86, using: &rng)
            let vy = CGFloat.random(in: 8...116, using: &rng)
            guard silhouette.contains(CGPoint(x: vx, y: vy)) else { continue }

            // Region by vertical band; front/back decided by depth sign.
            let depthEnvelope: Float
            let y = Double(vy)
            let bandRegion: (Bool) -> String?
            switch y {
            case 40..<58:
                depthEnvelope = 0.30; bandRegion = { _ in "chest" }
            case 58..<72:
                depthEnvelope = 0.30; bandRegion = { _ in "abdomen" }
            case 72..<92:
                depthEnvelope = 0.32; bandRegion = { back in back ? "glutes" : "hips" }
            case 92...120:
                depthEnvelope = 0.20; bandRegion = { _ in "thighs" }
            default:
                depthEnvelope = 0.16; bandRegion = { _ in nil }   // head / shoulders / arms
            }

            // Shell-biased depth (front or back surface).
            let back = Float.random(in: 0...1, using: &rng) < 0.5
            let z = (back ? -1 : 1) * Float.random(in: 0.5...1.0, using: &rng) * depthEnvelope
            let region = bandRegion(back)

            let nx = Float((vx - 50) / 45)
            let ny = Float((60 - vy) / 58)

            let brightness: Float = region == nil
                ? Float.random(in: 0.3...0.5, using: &rng)
                : Float.random(in: 0.65...1.0, using: &rng)

            nodes.append(ConstellationNode(
                base: SIMD3<Float>(nx, ny, z),
                region: region,
                seed: Float.random(in: 0...6.28, using: &rng),
                brightness: brightness,
                useSecondary: false))
        }

        return ConstellationField(nodes: nodes,
                                  edges: buildEdges(nodes, threshold: 0.26, maxPerNode: 3))
    }

    // MARK: Edges

    /// Connects each node to its nearest neighbors within `threshold` (in
    /// normalized space), capped at `maxPerNode`. O(n²) — run once at generation.
    private static func buildEdges(_ nodes: [ConstellationNode],
                                   threshold: Float,
                                   maxPerNode: Int) -> [(Int, Int)] {
        var edges: [(Int, Int)] = []
        var degree = [Int](repeating: 0, count: nodes.count)
        let t2 = threshold * threshold

        for i in nodes.indices {
            if degree[i] >= maxPerNode { continue }
            // Gather candidates with squared distance.
            var candidates: [(j: Int, d2: Float)] = []
            for j in (i + 1)..<nodes.count {
                let d = nodes[i].base - nodes[j].base
                let d2 = simd_length_squared(d)
                if d2 <= t2 { candidates.append((j, d2)) }
            }
            candidates.sort { $0.d2 < $1.d2 }
            for c in candidates {
                if degree[i] >= maxPerNode { break }
                if degree[c.j] >= maxPerNode { continue }
                edges.append((i, c.j))
                degree[i] += 1
                degree[c.j] += 1
            }
        }
        return edges
    }
}
