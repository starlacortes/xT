//
//  ZoneMapTests.swift
//  xTTests
//
//  Validates the baked zone maps and the runtime lookup built on them.
//
//  Replaces CentroidValidationTests, which could not fail. That suite compared Y-up centroid
//  positions against raw *untransformed* Z-up mesh vertices, and `return`ed silently whenever a
//  resource was missing or SceneKit gave it no vertices — so it passed while 57% of the body
//  surface resolved to no zone, one zone was unreachable, and 27 of 49 centroid normals pointed
//  into the body.
//

import Testing
import SceneKit
import simd
import Foundation
@testable import xT

struct ZoneMapTests {

    static let bodyTypes: [BodyType] = [.neutral, .feminine, .masculine]

    // MARK: - Helpers

    private func loadFile(_ bodyType: BodyType) throws -> ZoneMapFile {
        let name = ZoneMapFile.resourceName(for: bodyType.rawValue)
        let url = try #require(
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Models")
                ?? Bundle.main.url(forResource: name, withExtension: "json"),
            "\(name).json is missing from the bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ZoneMapFile.self, from: data)
    }

    /// Loads the mesh the way the app does, so the vertices under test are the ones the app
    /// actually hit-tests against.
    private func loadMesh(_ bodyType: BodyType) throws -> (node: SCNNode, transform: BodyTransform, sourceToWorld: simd_float4x4) {
        let url = try #require(
            Bundle.main.url(forResource: bodyType.usdzName, withExtension: "usdz", subdirectory: "Models")
                ?? Bundle.main.url(forResource: bodyType.usdzName, withExtension: "usdz"),
            "\(bodyType.usdzName).usdz is missing from the bundle"
        )
        let scene = try SCNScene(url: url, options: [.checkConsistency: true, .flattenScene: false])
        let wrapper = SCNNode()
        for child in scene.rootNode.childNodes { wrapper.addChildNode(child) }

        var wrapperSpace: [SIMD3<Float>] = []
        var meshNode: SCNNode?
        var most = 0
        var sourceToWrapper = simd_float4x4(1)
        wrapper.enumerateChildNodes { node, _ in
            guard let src = node.geometry?.sources(for: .vertex).first else { return }
            let m = simd_float4x4(node.worldTransform)
            if src.vectorCount > most { most = src.vectorCount; meshNode = node; sourceToWrapper = m }
            for p in Self.readPositions(src) {
                let r = m * SIMD4<Float>(p, 1)
                wrapperSpace.append(SIMD3<Float>(r.x, r.y, r.z))
            }
        }
        guard let meshNode else { throw CocoaError(.fileNoSuchFile) }

        let orientation = try #require(BodyOrientation(wrapperSpaceVertices: wrapperSpace),
                                       "could not detect orientation")
        let bb = wrapper.boundingBox
        let transform = try #require(BodyTransform(boundingBox: (min: bb.min, max: bb.max),
                                                    orientation: orientation))
        let sourceToWorld = transform.worldFromLocal * sourceToWrapper
        transform.apply(to: wrapper)

        return (meshNode, transform, sourceToWorld)
    }

    private static func readPositions(_ src: SCNGeometrySource) -> [SIMD3<Float>] {
        var out: [SIMD3<Float>] = []
        out.reserveCapacity(src.vectorCount)
        let stride = src.dataStride, offset = src.dataOffset, data = src.data
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            for i in 0..<src.vectorCount {
                let b = offset + i * stride
                guard b + 12 <= data.count else { continue }
                out.append(SIMD3<Float>(ptr.loadUnaligned(fromByteOffset: b, as: Float.self),
                                        ptr.loadUnaligned(fromByteOffset: b + 4, as: Float.self),
                                        ptr.loadUnaligned(fromByteOffset: b + 8, as: Float.self)))
            }
        }
        return out
    }

    // MARK: - Schema and label contract

    @Test(arguments: bodyTypes)
    func schemaAndLabels(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        #expect(file.schemaVersion == ZoneMapFile.currentSchemaVersion)
        #expect(file.bodyType == bodyType.rawValue)
        #expect(file.zones.count == ZoneID.allCases.count,
                "expected \(ZoneID.allCases.count) zones, got \(file.zones.count)")

        // The labels are a storage contract: InjectionSite.zoneLabel is the migration key for
        // existing dose history, so a renamed zone orphans a user's records.
        let baked = file.zones.map(\.label)
        let expected = ZoneID.allCases.map(\.rawValue)
        #expect(baked == expected, "baked labels differ from ZoneID, in order")

        // Zone IDs index into `zones`, so no duplicates are allowed.
        #expect(Set(baked).count == baked.count, "duplicate labels in baked map")
    }

    /// Every label referenced by the clinical tables must exist in the map, or a recommended
    /// site would be un-highlightable and un-tappable.
    @Test func clinicalTablesReferenceRealZones() {
        let known = Set(ZoneID.allCases.map(\.rawValue))
        for (key, zones) in ZoneCentroidStore.preferredZones {
            for zone in zones {
                #expect(known.contains(zone), "preferredZones[\"\(key)\"] references unknown zone \"\(zone)\"")
            }
        }
        for routeClass in RouteClass.allCases {
            for zone in ZoneCentroidStore.recommendedZones(for: routeClass) {
                #expect(known.contains(zone),
                        "recommendedZones(\(routeClass.rawValue)) references unknown zone \"\(zone)\"")
            }
        }
    }

    /// Every zone must map to a body region — `region(for:)` feeds the settings grouping and
    /// the recorded `bodyRegion` field.
    @Test func everyZoneHasARegion() {
        for zone in ZoneID.allCases {
            #expect(ZoneCentroidStore.shared.region(for: zone.rawValue) != nil,
                    "\"\(zone.rawValue)\" has no region")
        }
    }

    // MARK: - Map integrity

    @Test(arguments: bodyTypes)
    func vertexIDsAreWellFormed(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let ids = try #require(file.decodeZoneIDs(), "vertex ID blob is corrupt")
        #expect(ids.count == file.vertexCount)

        for id in ids where id != ZoneMapFile.noZoneID {
            #expect(Int(id) < file.zones.count, "zone ID \(id) is out of range")
        }
    }

    /// The map must be baked against the mesh the app loads. A mismatch would scramble every
    /// label, so `ZoneMap` refuses to load rather than degrade — this checks it agrees.
    @Test(arguments: bodyTypes)
    func mapMatchesShippedMesh(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let (meshNode, _, _) = try loadMesh(bodyType)
        let src = try #require(meshNode.geometry?.sources(for: .vertex).first)
        #expect(src.vectorCount == file.vertexCount,
                "map baked for \(file.vertexCount) vertices, mesh has \(src.vectorCount)")
    }

    /// No zone may be unreachable. Under the old scheme `Inner Right Thigh` claimed zero
    /// surface, so tapping it was impossible.
    @Test(arguments: bodyTypes)
    func everyZoneIsReachable(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let ids = try #require(file.decodeZoneIDs())
        var counts = [Int](repeating: 0, count: file.zones.count)
        for id in ids where id != ZoneMapFile.noZoneID { counts[Int(id)] += 1 }

        for (i, zone) in file.zones.enumerated() {
            #expect(counts[i] > 0, "\"\(zone.label)\" has no surface — it cannot be tapped")
            #expect(counts[i] == zone.vertexCount,
                    "\"\(zone.label)\" vertexCount says \(zone.vertexCount) but blob has \(counts[i])")
        }
    }

    @Test(arguments: bodyTypes)
    func radiiAndNormalsAreSane(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        for zone in file.zones {
            #expect(zone.radius > 0.005 && zone.radius < 0.20,
                    "\"\(zone.label)\" radius \(zone.radius) is implausible")
            let n = SIMD3<Float>(zone.normal[0], zone.normal[1], zone.normal[2])
            #expect(abs(simd_length(n) - 1) < 0.01, "\"\(zone.label)\" normal is not unit length")
            #expect(zone.centroid.count == 3 && zone.normal.count == 3)
        }
    }

    // MARK: - Anatomical correctness

    /// A zone named "Left …" must sit on the body's left, which is +X in the world frame
    /// `BodyTransform` establishes. This is the check that would have caught the mirrored
    /// transform and the inverted depth axis.
    @Test(arguments: bodyTypes)
    func sidedZonesAreOnTheCorrectSide(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        for zone in file.zones {
            let x = zone.centroid[0]
            let isLeft = zone.label.contains("Left")
            let isRight = zone.label.contains("Right")
            guard isLeft != isRight else { continue }   // skip midline and ambiguous names
            if isLeft {
                #expect(x > 0, "\"\(zone.label)\" is at x=\(x); the body's left is +x")
            } else {
                #expect(x < 0, "\"\(zone.label)\" is at x=\(x); the body's right is -x")
            }
        }
    }

    /// No zone may claim a substantial share of the opposite side of the body.
    ///
    /// Nine zones did under the old scheme. Left and right glutes genuinely meet at the cleft,
    /// so a small crossing is correct anatomy; the threshold targets real bleed.
    @Test(arguments: bodyTypes)
    func zonesDoNotBleedAcrossTheMidline(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let ids = try #require(file.decodeZoneIDs())
        let (meshNode, _, sourceToWorld) = try loadMesh(bodyType)
        let src = try #require(meshNode.geometry?.sources(for: .vertex).first)

        let midlineExempt: Set<String> = ["Upper Chest", "Periumbilical", "Neck"]
        var total = [Int](repeating: 0, count: file.zones.count)
        var wrongSide = [Int](repeating: 0, count: file.zones.count)

        for (i, p) in Self.readPositions(src).enumerated() {
            guard i < ids.count, ids[i] != ZoneMapFile.noZoneID else { continue }
            let z = Int(ids[i])
            let r = sourceToWorld * SIMD4<Float>(p, 1)
            let ownSide: Float = file.zones[z].centroid[0] >= 0 ? 1 : -1
            total[z] += 1
            if r.x * ownSide < 0 { wrongSide[z] += 1 }
        }

        for (i, zone) in file.zones.enumerated() where !midlineExempt.contains(zone.label) {
            guard total[i] > 0 else { continue }
            let fraction = Float(wrongSide[i]) / Float(total[i])
            #expect(fraction <= 0.20,
                    "\"\(zone.label)\" has \(Int(fraction * 100))% of its surface on the wrong side")
        }
    }

    /// Every vertex of a patch must lie reasonably close to that patch's centroid.
    ///
    /// This is the runtime stand-in for a contiguity check. *Topological* contiguity is gated in
    /// the bake (`zonebake`'s "patches are contiguous"), where the real edge graph is available;
    /// it cannot be checked faithfully here because the shipped geometry exposes no usable
    /// topology — SceneKit expands the USD quads into face-varying corners. An earlier version of
    /// this test approximated connectivity with a 3 cm radius graph and failed on correct data,
    /// because mean edge length in the thigh and forearm bands is ~2 cm and diagonal neighbours
    /// there exceed 3 cm.
    ///
    /// Compactness still catches the failure that actually happened: the wrist zones previously
    /// claimed thigh surface 40 cm away, because Euclidean nearest-centroid treats a hand hanging
    /// beside a thigh as adjacent to it.
    @Test(arguments: bodyTypes)
    func patchesAreCompact(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let ids = try #require(file.decodeZoneIDs())
        let (meshNode, _, sourceToWorld) = try loadMesh(bodyType)
        let positions = Self.readPositions(try #require(meshNode.geometry?.sources(for: .vertex).first))

        for (z, zone) in file.zones.enumerated() {
            let centroid = SIMD3<Float>(zone.centroid[0], zone.centroid[1], zone.centroid[2])
            // `radius` is the 90th percentile distance, so ~10% of a patch sits beyond it by
            // construction. The bound allows for that tail while still being far tighter than
            // the cross-body distances the old scheme produced.
            let bound = zone.radius * 3 + 0.02
            var worst: Float = 0
            for (i, p) in positions.enumerated() where i < ids.count && Int(ids[i]) == z {
                let r = sourceToWorld * SIMD4<Float>(p, 1)
                worst = max(worst, simd_distance(SIMD3<Float>(r.x, r.y, r.z), centroid))
            }
            let detail = "\"\(zone.label)\" has surface \(String(format: "%.3f", worst)) m from its "
                + "centroid (bound \(String(format: "%.3f", bound)) m)"
            #expect(worst <= bound, "\(detail)")
        }
    }

    // MARK: - Runtime lookup

    /// Resolving a vertex's own position must return that vertex's baked zone. This is the
    /// end-to-end check that the grid, the packed IDs and the label table all line up — if any
    /// of them were off, every tap would be mislabelled.
    @Test(arguments: bodyTypes)
    @MainActor
    func lookupAgreesWithBakedIDs(_ bodyType: BodyType) throws {
        let file = try loadFile(bodyType)
        let ids = try #require(file.decodeZoneIDs())
        let (meshNode, _, _) = try loadMesh(bodyType)
        let map = try ZoneMap(bodyType: bodyType, meshNode: meshNode)
        let positions = Self.readPositions(try #require(meshNode.geometry?.sources(for: .vertex).first))

        // Every 37th vertex — a spread across the whole mesh without a 14k-iteration test.
        var checked = 0
        for i in stride(from: 0, to: positions.count, by: 37) {
            let resolution = map.resolve(localPoint: positions[i])
            let expected = ids[i]
            switch resolution {
            case .zone(let label):
                #expect(expected != ZoneMapFile.noZoneID,
                        "vertex \(i) resolved to \"\(label)\" but is baked as noZone")
                if expected != ZoneMapFile.noZoneID {
                    #expect(label == file.zones[Int(expected)].label,
                            "vertex \(i) resolved to \"\(label)\", baked as \"\(file.zones[Int(expected)].label)\"")
                }
            case .noZone:
                #expect(expected == ZoneMapFile.noZoneID,
                        "vertex \(i) resolved to noZone but is baked as \"\(file.zones[Int(expected)].label)\"")
            }
            checked += 1
        }
        #expect(checked > 300, "sampled too few vertices to be meaningful")
    }

    /// A point far outside the body must not resolve to a zone.
    @Test @MainActor
    func pointsFarFromTheBodyDoNotResolve() throws {
        let (meshNode, _, _) = try loadMesh(.neutral)
        let map = try ZoneMap(bodyType: .neutral, meshNode: meshNode)
        #expect(map.resolve(localPoint: SIMD3<Float>(50, 50, 50)) == .noZone)
    }

    // MARK: - Transform

    /// The transform must be a proper rotation. The old `scale.y = -scale` had determinant
    /// −0.751: a mirror, which inverted winding and every exported normal.
    @Test(arguments: bodyTypes)
    func transformIsProperAndUpright(_ bodyType: BodyType) throws {
        let (meshNode, transform, sourceToWorld) = try loadMesh(bodyType)
        #expect(transform.isProper, "body transform mirrors the mesh")

        let positions = Self.readPositions(try #require(meshNode.geometry?.sources(for: .vertex).first))
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in positions {
            let r = sourceToWorld * SIMD4<Float>(p, 1)
            let w = SIMD3<Float>(r.x, r.y, r.z)
            lo = simd_min(lo, w); hi = simd_max(hi, w)
        }
        #expect(abs(lo.y) < 0.002, "feet are at y=\(lo.y), expected 0")
        #expect(abs(hi.y - BodyTransform.targetHeight) < 0.002,
                "crown is at y=\(hi.y), expected \(BodyTransform.targetHeight)")
    }

    /// Orientation detection must agree with what the shipped assets actually are. If a
    /// regenerated asset changes this, the test says so instead of the body silently flipping.
    @Test(arguments: bodyTypes)
    func orientationIsDetected(_ bodyType: BodyType) throws {
        let (_, transform, _) = try loadMesh(bodyType)
        #expect(transform.orientation.headAtMinY,
                "shipped assets are stored head-down; if this now fails the asset was regenerated")
        #expect(transform.orientation.frontZSign > 0)
    }

    // MARK: - View context

    /// `viewContext(from:)` was declared and never called; the hosts used the snap-angle label,
    /// so free-panning to the back and tapping recorded "front".
    @Test func viewContextFollowsYaw() {
        #expect(ZoneCentroidStore.viewContext(from: 0) == "front")
        #expect(ZoneCentroidStore.viewContext(from: .pi / 2) == "right")
        #expect(ZoneCentroidStore.viewContext(from: .pi) == "back")
        #expect(ZoneCentroidStore.viewContext(from: -.pi / 2) == "left")
        // Must normalize rather than fall through to "back".
        #expect(ZoneCentroidStore.viewContext(from: 2 * .pi) == "front")
    }
}
