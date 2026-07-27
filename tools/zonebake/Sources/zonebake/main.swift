import Foundation
import simd

// Bakes the per-vertex zone map for each body type.
//
//   swift run zonebake [--no-preview] [bodyType ...]
//
// Writes xT/Resources/Models/zone_map_<type>.json plus preview renders under
// tools/zonebake/previews/. Exits non-zero if any gate in the report fails, so it can
// be wired into CI.

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // zonebake
    .deletingLastPathComponent()   // Sources
    .deletingLastPathComponent()   // tools/zonebake
    .deletingLastPathComponent()   // tools
    .deletingLastPathComponent()   // repo root

let modelsDir = repoRoot.appendingPathComponent("xT/Resources/Models")
let previewDir = repoRoot.appendingPathComponent("tools/zonebake/previews")

var args = Array(CommandLine.arguments.dropFirst())
let wantPreview = !args.contains("--no-preview")
let wantAnatomy = args.contains("--anatomy")
args.removeAll { $0.hasPrefix("--") }
let bodyTypes = args.isEmpty ? ["neutral", "feminine", "masculine"] : args

print("zonebake — repo root \(repoRoot.path)")
print("  models  \(modelsDir.path)")
print("  seeds   \(ZoneSeeds.all.count)")

var anyFailed = false

for bodyType in bodyTypes {
    let usdz = modelsDir.appendingPathComponent("body_\(bodyType).usdz")
    guard FileManager.default.fileExists(atPath: usdz.path) else {
        print("!! missing \(usdz.lastPathComponent)")
        anyFailed = true
        continue
    }

    print("\n--- \(bodyType) ---")
    let mesh: BodyMesh
    do {
        mesh = try BodyMesh.load(usdzURL: usdz, bodyType: bodyType)
    } catch {
        print("!! load failed: \(error)")
        anyFailed = true
        continue
    }

    guard mesh.transform.isProper else {
        print("!! body transform is improper (mirrored) — refusing to bake against it")
        anyFailed = true
        continue
    }

    print("  loaded \(mesh.vertexCount) verts, \(mesh.eyeVertices.count) eye verts, "
          + String(format: "scale %.4f", mesh.transform.scale))
    let o = mesh.transform.orientation
    print("  orientation: head at \(o.headAtMinY ? "MIN" : "MAX") Y, front \(o.frontZSign >= 0 ? "+" : "-")Z"
          + "  → correcting euler \(o.correctingEulerAngles)")

    // Adjacency health. A partition built on a broken neighbour graph fails in ways that
    // look like bad seed placement, so it is checked explicitly before anything else.
    let degrees = mesh.neighbors.map(\.count)
    let isolated = degrees.enumerated().filter { $0.element == 0 }.count
    let components = mesh.connectedComponentCount()
    print(String(format: "  adjacency: mean degree %.2f, min %d, max %d, isolated %d, components %d",
                 Double(degrees.reduce(0, +)) / Double(max(degrees.count, 1)),
                 degrees.min() ?? 0, degrees.max() ?? 0, isolated, components))
    print(String(format: "  surface area ≈ %.3f m², triangles %d",
                 mesh.surfaceArea, mesh.faceTriangles.count / 3))

    // Edge length and vertex density per height band. MakeHuman topology is heavily
    // non-uniform, so extents must be sized against the band they actually sit in.
    let areas = mesh.vertexAreas
    print("  density by height band:")
    for (lo, hi, name) in [(Float(1.30), Float(1.50), "head"),
                           (Float(1.10), Float(1.30), "neck/shoulder"),
                           (Float(0.85), Float(1.10), "chest/upper arm"),
                           (Float(0.60), Float(0.85), "abdomen/glute"),
                           (Float(0.40), Float(0.60), "thigh/wrist"),
                           (Float(0.00), Float(0.40), "below knee")] {
        let (mean, edges) = mesh.meanEdgeLength(yRange: lo...hi)
        let idx = (0..<mesh.vertexCount).filter { mesh.worldPositions[$0].y >= lo && mesh.worldPositions[$0].y < hi }
        let bandArea = idx.reduce(Float(0)) { $0 + areas[$1] }
        print(String(format: "    %-16s y[%.2f,%.2f)  verts %5d  area %.3f m²  meanEdge %.4f m  edges %d",
                     (name as NSString).utf8String!, lo, hi, idx.count, bandArea, mean, edges))
    }

    if wantAnatomy { Anatomy.report(mesh: mesh) }

    let result = Partition.run(mesh: mesh, seeds: ZoneSeeds.all)
    let stats = Partition.stats(mesh: mesh, seeds: ZoneSeeds.all, result: result)
    let report = Report.evaluate(mesh: mesh, seeds: ZoneSeeds.all, result: result, stats: stats)
    if !report.passed { anyFailed = true }

    // Write the map even when gates fail — inspecting a failed bake is how it gets fixed.
    let file = ZoneMapFile(
        schemaVersion: ZoneMapFile.currentSchemaVersion,
        bodyType: bodyType,
        vertexCount: mesh.vertexCount,
        zones: stats.map { s in
            ZoneMapFile.Zone(label: s.label,
                             centroid: [s.centroid.x, s.centroid.y, s.centroid.z],
                             normal: [s.normal.x, s.normal.y, s.normal.z],
                             radius: s.radius,
                             vertexCount: s.vertices.count)
        },
        vertexZoneIDs: ZoneMapFile.encodeZoneIDs(result.zoneIDs)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let data = try encoder.encode(file)
        let out = modelsDir.appendingPathComponent("\(ZoneMapFile.resourceName(for: bodyType)).json")
        try data.write(to: out)
        print(String(format: "  wrote %@ (%.1f KB)", out.lastPathComponent, Double(data.count) / 1024))
    } catch {
        print("!! write failed: \(error)")
        anyFailed = true
    }

    if wantPreview {
        do {
            try Preview.render(mesh: mesh, seeds: ZoneSeeds.all, result: result, stats: stats, to: previewDir)
            print("  previews → tools/zonebake/previews/\(bodyType)_{front,right,back,left}.png")
        } catch {
            print("  !! preview render failed: \(error)")
        }
    }
}

// Regenerate the label enum from the same seed table the bake used, so the app cannot drift
// out of sync with the map.
do {
    let out = repoRoot.appendingPathComponent("xT/Shared/ZoneID.swift")
    try ZoneIDGenerator.write(seeds: ZoneSeeds.all, to: out)
    print("\nwrote xT/Shared/ZoneID.swift (\(ZoneSeeds.all.count) cases)")
} catch {
    print("\n!! could not write ZoneID.swift: \(error)")
    anyFailed = true
}

print(anyFailed ? "\nzonebake finished WITH FAILURES" : "\nzonebake finished clean")
exit(anyFailed ? 1 : 0)
