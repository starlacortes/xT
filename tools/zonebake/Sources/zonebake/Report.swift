import Foundation
import simd

/// Prints the validation report and decides whether the bake passed.
///
/// The gates below are the audit's findings turned into assertions. Baseline for the neutral
/// mesh under the old nearest-centroid scheme, for comparison:
///
/// | metric                       | before | gate       |
/// |------------------------------|--------|------------|
/// | clinical surface unassigned  | 57.0%  | 0%         |
/// | unreachable zones            | 1      | 0          |
/// | zones bleeding across midline | 9     | 0 (of 46)  |
/// | centroid normals inverted    | 27/49  | 0          |
struct Report {

    struct Gate {
        let name: String
        let passed: Bool
        let detail: String
    }

    let bodyType: String
    let gates: [Gate]
    var passed: Bool { gates.allSatisfy(\.passed) }

    static func evaluate(mesh: BodyMesh,
                         seeds: [ZoneSeed],
                         result: Partition.Result,
                         stats: [Partition.ZoneStats]) -> Report {

        let n = mesh.vertexCount
        let assigned = result.zoneIDs.filter { $0 != ZoneMapFile.noZoneID }.count
        let noZone = n - assigned

        // Empty zones
        let empty = stats.filter { $0.vertices.isEmpty }.map(\.label)

        // Midline bleed, excluding the zones that legitimately straddle it
        let bleeding = stats.filter {
            $0.wrongSideFraction > 0.15 && !ZoneSeeds.midlineLabels.contains($0.label)
        }.map { String(format: "%@ (%.0f%% wrong side)", $0.label, $0.wrongSideFraction * 100) }

        // Are the mesh's normals outward at all?
        //
        // This is checked once, globally, via the divergence identity: for a closed surface
        // with outward normals, ∮ n·(p − c) dA = 3V > 0. It is the check that actually
        // catches a mirrored transform, and it replaces an earlier per-zone version that
        // compared each zone normal against the radial direction from the body's vertical
        // axis. That test was anatomically wrong: an inner thigh or inner wrist correctly
        // faces *toward* the midline, so it flagged 15 zones whose normals were fine.
        let areasPerVertex = mesh.vertexAreas
        var center = SIMD3<Float>(repeating: 0)
        for p in mesh.worldPositions { center += p }
        center /= Float(max(mesh.vertexCount, 1))
        var divergence: Float = 0
        for i in 0..<mesh.vertexCount {
            divergence += areasPerVertex[i] * simd_dot(mesh.worldNormals[i], mesh.worldPositions[i] - center)
        }

        // Area-weighted coverage. Vertex counts are meaningless here — the head alone holds
        // 36% of the vertices in 10% of the area.
        var assignedArea: Float = 0
        var totalArea: Float = 0
        for i in 0..<mesh.vertexCount {
            totalArea += areasPerVertex[i]
            if result.zoneIDs[i] != ZoneMapFile.noZoneID { assignedArea += areasPerVertex[i] }
        }
        let coverage = totalArea > 0 ? assignedArea / totalArea : 0

        // Patch size spread, by area. A large but finite ratio is expected — a shoulder is
        // genuinely bigger than a wrist — so this is reported, not gated.
        let sizes = stats.map(\.area).filter { $0 > 0 }.sorted()

        // Low normal agreement means a patch wrapped around a limb and now spans surfaces
        // facing opposite directions, so its glow cannot sit on all of it.
        let wrapped = stats.filter { !$0.vertices.isEmpty && $0.normalAgreement < 0.75 }
            .map { String(format: "%@ (%.0f%%)", $0.label, $0.normalAgreement * 100) }

        // True contiguity, using the real edge topology. Geodesic growth from a single seed
        // should make every patch one connected piece; asserting it costs nothing and catches a
        // future change to the partitioning algorithm.
        var fragmented: [String] = []
        for s in stats where s.vertices.count > 1 {
            let member = Set(s.vertices)
            var seen: Set<Int> = [s.vertices[0]]
            var stack = [s.vertices[0]]
            while let v = stack.popLast() {
                for n in mesh.neighbors[v] {
                    let u = Int(n)
                    if member.contains(u) && !seen.contains(u) { seen.insert(u); stack.append(u) }
                }
            }
            if seen.count != s.vertices.count {
                fragmented.append("\(s.label) (\(seen.count)/\(s.vertices.count) connected)")
            }
        }

        var gates: [Gate] = []
        gates.append(Gate(name: "all seeds snapped to surface",
                          passed: result.unsnappedSeeds.isEmpty,
                          detail: result.unsnappedSeeds.isEmpty ? "49/49"
                                : "unsnapped: \(result.unsnappedSeeds.joined(separator: ", "))"))
        gates.append(Gate(name: "no unreachable zones",
                          passed: empty.isEmpty,
                          detail: empty.isEmpty ? "all \(seeds.count) zones have surface"
                                : "empty: \(empty.joined(separator: ", "))"))
        gates.append(Gate(name: "no midline bleed",
                          passed: bleeding.isEmpty,
                          detail: bleeding.isEmpty ? "0 zones straddle the midline (excl. \(ZoneSeeds.midlineLabels.sorted().joined(separator: ", ")))"
                                : bleeding.joined(separator: ", ")))
        gates.append(Gate(name: "mesh normals point outward",
                          passed: divergence > 0,
                          detail: String(format: "∮n·(p−c)dA = %+.4f (= 3×volume; negative means a mirrored transform)", divergence)))
        // The clinical surface is head + hands + feet + below-knee subtracted from the whole
        // body, which measures out to roughly half the mesh. Coverage far outside this band
        // means extents are badly sized in one direction or the other.
        gates.append(Gate(name: "coverage in expected band",
                          passed: coverage >= 0.35 && coverage <= 0.80,
                          detail: String(format: "%.1f%% of surface area assigned (expect 35–80%%)", coverage * 100)))
        gates.append(Gate(name: "patches are contiguous",
                          passed: fragmented.isEmpty,
                          detail: fragmented.isEmpty ? "all patches are one connected piece"
                                : fragmented.joined(separator: ", ")))
        gates.append(Gate(name: "no wrapped patches",
                          passed: wrapped.isEmpty,
                          detail: wrapped.isEmpty ? "all patches ≥75% normal agreement"
                                : wrapped.joined(separator: ", ")))

        // Print
        print("")
        print("=========================================================")
        print(" zonebake report — \(mesh.bodyType)")
        print("=========================================================")
        print(String(format: " vertices           %d", n))
        print(String(format: " mean edge length   %.4f m  (boundary precision ≈ %.1f mm)",
                     mesh.meanEdgeLength, mesh.meanEdgeLength * 500))
        print(String(format: " assigned           %d verts / %.3f m² (%.1f%% of area)",
                     assigned, assignedArea, coverage * 100))
        print(String(format: " noZone             %d verts / %.3f m² (%.1f%% of area)  — head, hands, feet, below knee, eyes",
                     noZone, totalArea - assignedArea, (1 - coverage) * 100))
        if let lo = sizes.first, let hi = sizes.last {
            let median = sizes[sizes.count / 2]
            print(String(format: " patch area         min %.4f / median %.4f / max %.4f m²  (ratio %.1f×)",
                         lo, median, hi, hi / max(lo, 1e-6)))
        }
        print("")
        print(" per-zone:")
        print("   label                        verts    area   radius   drift  agree  midline")
        for s in stats.sorted(by: { $0.label < $1.label }) {
            let seed = seeds.first { $0.label == s.label }
            let seedVertexIndex = seeds.firstIndex { $0.label == s.label }.map { result.seedVertices[$0] } ?? -1
            let seedWorld = seedVertexIndex >= 0 ? mesh.worldPositions[seedVertexIndex] : SIMD3<Float>(repeating: 0)
            let drift = seedVertexIndex >= 0 ? simd_distance(seedWorld, s.centroid) * 100 : -1
            _ = seed
            print(String(format: "   %-28s %5d  %.4f  %.3f  %5.1f  %3.0f%%   %@",
                         (s.label as NSString).utf8String!, s.vertices.count, s.area, s.radius, drift,
                         s.normalAgreement * 100,
                         s.wrongSideFraction > 0.15
                            ? (ZoneSeeds.midlineLabels.contains(s.label) ? "ok(midline)" : "BLEED")
                            : ""))
        }
        print("")
        for g in gates {
            print(" [\(g.passed ? "PASS" : "FAIL")] \(g.name): \(g.detail)")
        }
        print("")
        print(" => \(gates.allSatisfy(\.passed) ? "BAKE PASSED" : "BAKE FAILED")")
        print("")

        return Report(bodyType: mesh.bodyType, gates: gates)
    }
}
