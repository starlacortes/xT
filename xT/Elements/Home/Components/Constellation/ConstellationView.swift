//
//  ConstellationView.swift
//  xT
//
//  A reusable 3D point-field renderer. Individual points drift through x/y/z
//  like stars adrift in space, slowly rotating as a whole, with nearby points
//  linked into faint constellations. Points tagged to a body/mind region glow
//  brighter while that region is actively changing, and light up fully when
//  their region is selected.
//
//  Rendering uses SwiftUI Canvas + TimelineView (matching the existing
//  BrainWireframeView / ArchitectureBodyCanvas pattern) — no SceneKit / Metal.
//  Honors Reduce Motion by freezing to a static pose.
//

import SwiftUI
import simd

// MARK: - Data

/// A single point in the constellation, positioned in a normalized cube (−1…1).
struct ConstellationNode {
    var base: SIMD3<Float>      // resting position, normalized −1…1
    var region: String?         // region key (nil = ambient background star)
    var seed: Float             // per-node phase for drift / twinkle
    var brightness: Float       // 0…1 base brightness
    var useSecondary: Bool      // tint with the secondary color instead of the primary
}

/// A generated point cloud plus its precomputed connection edges (index pairs
/// into `nodes`). Edges are computed once from resting positions so the frame
/// loop only re-projects and never re-searches for neighbors.
struct ConstellationField {
    var nodes: [ConstellationNode]
    var edges: [(Int, Int)]

    static let empty = ConstellationField(nodes: [], edges: [])
}

// MARK: - View

struct ConstellationView: View {
    let field: ConstellationField
    let tint: Color
    var secondaryTint: Color? = nil
    var selectedRegion: String? = nil
    /// 0…1 "how actively is this region changing right now" — drives glow.
    var regionActivity: (String) -> Double = { _ in 0.4 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tuning
    private let focal: Float = 3.2
    private let autoYawRate: Float = 0.09

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            // Fixed pose when Reduce Motion is on.
            let t: Float = reduceMotion
                ? 12.0
                : Float(timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3600))

            Canvas { context, size in
                draw(&context, size: size, t: t)
            }
            .drawingGroup()
        }
    }

    // MARK: Projection

    private struct Projected {
        var pt: CGPoint
        var radius: CGFloat
        var glow: Double
        var region: String?
        var useSecondary: Bool
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Float) {
        guard !field.nodes.isEmpty else { return }

        let center = SIMD2<Float>(Float(size.width) / 2, Float(size.height) / 2)
        let unit = Float(min(size.width, size.height)) * 0.42

        let yaw = t * autoYawRate
        let cosY = cos(yaw), sinY = sin(yaw)
        let tilt = sin(t * 0.05) * 0.12
        let cosX = cos(tilt), sinX = sin(tilt)

        let anySelected = selectedRegion != nil

        // Cache region activity so we don't call the closure per-node repeatedly.
        var activityCache: [String: Double] = [:]
        func activity(_ key: String) -> Double {
            if let v = activityCache[key] { return v }
            let v = regionActivity(key)
            activityCache[key] = v
            return v
        }

        var projected = [Projected?](repeating: nil, count: field.nodes.count)
        var order: [(index: Int, depth: Float)] = []
        order.reserveCapacity(field.nodes.count)

        for i in field.nodes.indices {
            let node = field.nodes[i]

            // Per-node drift — low-frequency sines seeded per node.
            let s = node.seed
            let regionKey = node.region
            let act = regionKey.map { activity($0) } ?? 0
            let driftAmp: Float = 0.05 + 0.06 * Float(act)
            var p = node.base
            p.x += sin(t * 0.5 + s) * driftAmp
            p.y += cos(t * 0.42 + s * 1.3) * driftAmp
            p.z += sin(t * 0.33 + s * 2.1) * driftAmp

            // Rotate around Y, then a gentle X tilt.
            let x = p.x * cosY + p.z * sinY
            var z = -p.x * sinY + p.z * cosY
            let y0 = p.y
            let y = y0 * cosX - z * sinX
            z = y0 * sinX + z * cosX

            // Perspective divide.
            let denom = max(focal - z, 0.2)
            let persp = focal / denom
            let screen = center + SIMD2<Float>(x * persp * unit,
                                               -y * persp * unit)  // flip Y (screen down = +)

            // Closeness → size + opacity.
            let closeness = Double(max(0, min(1, (persp - 0.6) / 1.2)))
            let selected = regionKey != nil && regionKey == selectedRegion

            var glow = Double(node.brightness) * (0.45 + 0.55 * closeness)
            glow *= (1.0 + 0.9 * act)
            let twinkle = 0.5 + 0.5 * Double(sin(t * 1.4 + s * 6))
            glow *= (0.72 + 0.28 * twinkle)
            if selected {
                glow = min(1.0, glow * 1.9 + 0.15)
            } else if anySelected {
                glow *= 0.35
            }
            glow = min(1.0, glow)

            var r = CGFloat(1.0 + 2.2 * closeness)
            r += CGFloat(1.4 * act)
            if selected { r += 1.6 }

            projected[i] = Projected(
                pt: CGPoint(x: CGFloat(screen.x), y: CGFloat(screen.y)),
                radius: r,
                glow: glow,
                region: regionKey,
                useSecondary: node.useSecondary
            )
            order.append((i, z))
        }

        // Painter's algorithm — far (small z) first.
        order.sort { $0.depth < $1.depth }

        // Edges first, beneath the dots.
        for (a, b) in field.edges {
            guard let pa = projected[a], let pb = projected[b] else { continue }
            let g = min(pa.glow, pb.glow)
            let op = g * 0.28
            if op < 0.02 { continue }
            var line = Path()
            line.move(to: pa.pt)
            line.addLine(to: pb.pt)
            let edgeColor = (pa.useSecondary || pb.useSecondary)
                ? (secondaryTint ?? tint) : tint
            context.stroke(line, with: .color(edgeColor.opacity(op)),
                           lineWidth: 0.6)
        }

        // Dots + halos, sorted back to front.
        for entry in order {
            guard let pr = projected[entry.index] else { continue }
            let color = pr.useSecondary ? (secondaryTint ?? tint) : tint

            // Soft halo for bright / selected points.
            if pr.glow > 0.45 {
                let hr = pr.radius * 3.2
                let halo = Path(ellipseIn: CGRect(
                    x: pr.pt.x - hr, y: pr.pt.y - hr, width: hr * 2, height: hr * 2))
                context.fill(halo, with: .color(color.opacity(pr.glow * 0.10)))
            }

            let dot = Path(ellipseIn: CGRect(
                x: pr.pt.x - pr.radius, y: pr.pt.y - pr.radius,
                width: pr.radius * 2, height: pr.radius * 2))
            // Warm core: mix toward white for a "star" feel.
            context.fill(dot, with: .color(.white.opacity(pr.glow * 0.5)))
            context.fill(dot, with: .color(color.opacity(pr.glow)))
        }
    }
}

// MARK: - Region Label

/// A small floating pill that labels a region cluster in a constellation.
struct ConstellationRegionTag: View {
    let label: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                .shadow(color: color.opacity(0.6), radius: isSelected ? 5 : 2)
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(color.opacity(isSelected ? 0.6 : 0.2),
                             lineWidth: isSelected ? 1 : 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        .animation(Theme.Motion.snappy, value: isSelected)
        .contentShape(Capsule())
    }
}
