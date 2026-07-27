import Foundation
import SceneKit
import simd
import AppKit

/// Renders the baked partition to PNGs so it can actually be looked at.
///
/// This is the authoring loop. Numbers in the report catch structural failures — an empty
/// zone, a patch straddling the midline — but they cannot tell you that "Left Deltoid" landed
/// on the neck. Four renders at the app's own snap angles can.
///
/// Each zone gets a distinct flat colour; `noZone` surface renders dark grey.
enum Preview {

    /// Colours chosen to be distinguishable between *neighbouring* zones. A cycling palette
    /// is fine because adjacent zones are rarely adjacent in the seed list.
    private static let palette: [SIMD3<Float>] = [
        SIMD3(0.90, 0.24, 0.24), SIMD3(0.24, 0.55, 0.90), SIMD3(0.30, 0.78, 0.35),
        SIMD3(0.96, 0.70, 0.16), SIMD3(0.65, 0.35, 0.85), SIMD3(0.20, 0.80, 0.78),
        SIMD3(0.95, 0.45, 0.70), SIMD3(0.55, 0.75, 0.20), SIMD3(0.85, 0.50, 0.20),
        SIMD3(0.40, 0.40, 0.85), SIMD3(0.75, 0.20, 0.50), SIMD3(0.20, 0.65, 0.55),
    ]

    static func render(mesh: BodyMesh,
                       seeds: [ZoneSeed],
                       result: Partition.Result,
                       stats: [Partition.ZoneStats],
                       to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Build a vertex-coloured copy of the mesh. Colours go in a per-vertex source and are
        // read with a constant lighting model so the partition is visible without shading.
        var colors = [SIMD4<Float>](repeating: SIMD4<Float>(0.22, 0.22, 0.24, 1), count: mesh.vertexCount)
        for (v, id) in result.zoneIDs.enumerated() where id != ZoneMapFile.noZoneID {
            let c = palette[Int(id) % palette.count]
            // Alternate brightness by zone index so same-palette-slot neighbours still differ.
            let shade: Float = (Int(id) / palette.count) % 2 == 0 ? 1.0 : 0.62
            colors[v] = SIMD4<Float>(c.x * shade, c.y * shade, c.z * shade, 1)
        }

        let scene = SCNScene()
        let geometry = buildGeometry(mesh: mesh, colors: colors)
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)

        // Small spheres mark each snapped seed, so a seed that landed on the wrong body part
        // is obvious even when its patch is small.
        for (i, sv) in result.seedVertices.enumerated() where sv >= 0 {
            let marker = SCNSphere(radius: 0.008)
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = NSColor.white
            marker.materials = [m]
            let mn = SCNNode(geometry: marker)
            mn.position = SCNVector3(mesh.worldPositions[sv])
            scene.rootNode.addChildNode(mn)
            _ = i
        }

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 1000
        scene.rootNode.addChildNode(ambient)

        // Same orbit the app uses, at the four snap angles.
        let angles: [(String, Float)] = [("front", 0), ("right", .pi / 2), ("back", .pi), ("left", 3 * .pi / 2)]
        for (name, yaw) in angles {
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 42
            camera.camera?.zNear = 0.01
            camera.camera?.zFar = 100
            camera.position = SCNVector3(2.5 * sin(yaw), 0.75, 2.5 * cos(yaw))
            camera.look(at: SCNVector3(0, 0.75, 0))
            scene.rootNode.addChildNode(camera)

            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = scene
            renderer.pointOfView = camera

            let size = CGSize(width: 500, height: 1000)
            let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                camera.removeFromParentNode()
                continue
            }
            let url = directory.appendingPathComponent("\(mesh.bodyType)_\(name).png")
            try png.write(to: url)
            camera.removeFromParentNode()
        }

        // A legend mapping colour → label, so the renders are readable.
        var legend = "zone colours for \(mesh.bodyType)\n"
        for (i, s) in stats.enumerated() {
            let c = palette[i % palette.count]
            let shade: Float = (i / palette.count) % 2 == 0 ? 1.0 : 0.62
            legend += String(format: "  #%02X%02X%02X  %-28@ %d verts\n",
                             Int(c.x * shade * 255), Int(c.y * shade * 255), Int(c.z * shade * 255),
                             s.label as NSString, s.vertices.count)
        }
        try legend.write(to: directory.appendingPathComponent("\(mesh.bodyType)_legend.txt"),
                         atomically: true, encoding: .utf8)
    }

    /// Rebuilds the mesh as triangles with per-vertex colour. The shipped geometry cannot be
    /// reused directly because its elements are face-varying `.polygon` primitives.
    private static func buildGeometry(mesh: BodyMesh, colors: [SIMD4<Float>]) -> SCNGeometry {
        let positions = mesh.worldPositions
        let normals = mesh.worldNormals

        // Triangulate the quad adjacency we already have by walking faces again would need
        // the face list; instead draw the surface as its edge wireframe filled by triangles
        // built from each face. Faces are recovered from the neighbour graph via the stored
        // triangle fan of each quad — see `triangles`.
        var indices: [Int32] = []
        indices.reserveCapacity(mesh.faceTriangles.count)
        indices.append(contentsOf: mesh.faceTriangles)

        // Flatten to plain `[Float]` before handing bytes to SceneKit. `SIMD3<Float>` is
        // padded to a 16-byte stride, so copying `count * 12` bytes out of a `[SIMD3<Float>]`
        // reads a progressively misaligned stream and renders as smeared garbage.
        var posFloats = [Float](); posFloats.reserveCapacity(positions.count * 3)
        for p in positions { posFloats.append(p.x); posFloats.append(p.y); posFloats.append(p.z) }
        var normFloats = [Float](); normFloats.reserveCapacity(normals.count * 3)
        for nrm in normals { normFloats.append(nrm.x); normFloats.append(nrm.y); normFloats.append(nrm.z) }
        var colorFloats = [Float](); colorFloats.reserveCapacity(colors.count * 4)
        for c in colors { colorFloats.append(c.x); colorFloats.append(c.y); colorFloats.append(c.z); colorFloats.append(c.w) }

        let posSource = SCNGeometrySource(data: Data(bytes: posFloats, count: posFloats.count * 4),
                                         semantic: .vertex,
                                         vectorCount: positions.count,
                                         usesFloatComponents: true,
                                         componentsPerVector: 3,
                                         bytesPerComponent: 4,
                                         dataOffset: 0,
                                         dataStride: 12)
        let normSource = SCNGeometrySource(data: Data(bytes: normFloats, count: normFloats.count * 4),
                                           semantic: .normal,
                                           vectorCount: normals.count,
                                           usesFloatComponents: true,
                                           componentsPerVector: 3,
                                           bytesPerComponent: 4,
                                           dataOffset: 0,
                                           dataStride: 12)
        let colorSource = SCNGeometrySource(data: Data(bytes: colorFloats, count: colorFloats.count * 4),
                                            semantic: .color,
                                            vectorCount: colors.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 4,
                                            bytesPerComponent: 4,
                                            dataOffset: 0,
                                            dataStride: 16)
        let element = SCNGeometryElement(data: Data(bytes: indices, count: indices.count * 4),
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: 4)

        let geo = SCNGeometry(sources: [posSource, normSource, colorSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = false
        geo.materials = [mat]
        return geo
    }
}
