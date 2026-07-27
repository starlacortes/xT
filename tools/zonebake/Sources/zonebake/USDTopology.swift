import Foundation

/// Pulls mesh topology out of a USDZ by flattening it with `usdcat` and reading the three
/// arrays SceneKit will not give us: `faceVertexCounts`, `faceVertexIndices`, and the
/// per-material `GeomSubset` face lists.
///
/// `usdcat` ships with macOS at `/usr/bin/usdcat`. This is offline tooling, so shelling out
/// is acceptable; the alternative would be reverse-engineering SceneKit's `.polygon` element
/// encoding, which is undocumented and version-dependent.
struct USDTopology {

    let pointCount: Int
    /// Vertices per face. All quads in the shipped assets, but not assumed to be.
    let faceVertexCounts: [Int32]
    /// Flat corner → point index list, `sum(faceVertexCounts)` long.
    let faceVertexIndices: [Int32]
    /// Face indices per `GeomSubset`, keyed by subset name (e.g. `"Eye_brown"`).
    let subsetFaces: [String: [Int32]]
    /// Names of `primvars:` arrays present in the asset. Used to report the dead
    /// zone-weight payload that Phase 5 removes from the generator.
    let primvarNames: [String]

    static func extract(usdzURL: URL) throws -> USDTopology {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("zonebake-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flat = tmpDir.appendingPathComponent("flat.usda")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/usdcat")
        proc.arguments = ["--flatten", usdzURL.path, "-o", flat.path]
        let errPipe = Pipe()
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()
        let errText = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard proc.terminationStatus == 0, FileManager.default.fileExists(atPath: flat.path) else {
            throw BodyMesh.LoadError.usdcat("exit \(proc.terminationStatus): \(errText)")
        }

        guard let text = try? String(contentsOf: flat, encoding: .utf8) else {
            throw BodyMesh.LoadError.parse("could not read flattened usda")
        }

        guard let countsBody = bracketedValue(in: text, after: "int[] faceVertexCounts") else {
            throw BodyMesh.LoadError.parse("faceVertexCounts not found")
        }
        guard let indicesBody = bracketedValue(in: text, after: "int[] faceVertexIndices") else {
            throw BodyMesh.LoadError.parse("faceVertexIndices not found")
        }
        guard let pointsBody = bracketedValue(in: text, after: "point3f[] points") else {
            throw BodyMesh.LoadError.parse("points not found")
        }

        let counts = parseInts(countsBody)
        let indices = parseInts(indicesBody)
        // Counting '(' is enough to size the point array without parsing the floats — the
        // positions themselves come from SceneKit.
        let pointCount = pointsBody.reduce(into: 0) { acc, ch in if ch == "(" { acc += 1 } }

        guard counts.reduce(0, { $0 + Int($1) }) == indices.count else {
            throw BodyMesh.LoadError.parse("faceVertexCounts sum \(counts.reduce(0, { $0 + Int($1) })) != indices \(indices.count)")
        }

        return USDTopology(pointCount: pointCount,
                           faceVertexCounts: counts,
                           faceVertexIndices: indices,
                           subsetFaces: parseSubsets(text),
                           primvarNames: parsePrimvarNames(text))
    }

    // MARK: - Text parsing

    /// Returns the contents of the bracketed list that follows `marker`'s `=`.
    ///
    /// Searching from the `=` matters: the marker itself contains `[]` (as in `int[]`), so
    /// scanning for the first `[` after the marker start would match the type's own brackets
    /// and return an empty list.
    private static func bracketedValue(in text: String, after marker: String) -> Substring? {
        guard let markerRange = text.range(of: marker) else { return nil }
        guard let eq = text.range(of: "=", range: markerRange.upperBound..<text.endIndex) else { return nil }
        guard let open = text.range(of: "[", range: eq.upperBound..<text.endIndex) else { return nil }
        var depth = 0
        var i = open.lowerBound
        while i < text.endIndex {
            let ch = text[i]
            if ch == "[" { depth += 1 }
            else if ch == "]" {
                depth -= 1
                if depth == 0 { return text[text.index(after: open.lowerBound)..<i] }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func parseInts(_ s: Substring) -> [Int32] {
        var out: [Int32] = []
        out.reserveCapacity(64_000)
        var cur: Int32 = 0
        var have = false
        var negative = false
        for ch in s.utf8 {
            if ch >= 48 && ch <= 57 {
                cur = cur * 10 + Int32(ch - 48)
                have = true
            } else if ch == 45 {
                negative = true
            } else if have {
                out.append(negative ? -cur : cur)
                cur = 0; have = false; negative = false
            } else {
                negative = false
            }
        }
        if have { out.append(negative ? -cur : cur) }
        return out
    }

    /// Finds every `def GeomSubset "<name>"` block and reads its `int[] indices`.
    private static func parseSubsets(_ text: String) -> [String: [Int32]] {
        var result: [String: [Int32]] = [:]
        var searchStart = text.startIndex
        while let defRange = text.range(of: "def GeomSubset \"", range: searchStart..<text.endIndex) {
            guard let nameEnd = text.range(of: "\"", range: defRange.upperBound..<text.endIndex) else { break }
            let name = String(text[defRange.upperBound..<nameEnd.lowerBound])
            let tail = text[nameEnd.upperBound..<text.endIndex]
            if let body = bracketedValue(in: String(tail.prefix(4_000_000)), after: "int[] indices") {
                result[name] = parseInts(body)
            }
            searchStart = nameEnd.upperBound
        }
        return result
    }

    private static func parsePrimvarNames(_ text: String) -> [String] {
        var names = Set<String>()
        var searchStart = text.startIndex
        while let r = text.range(of: "primvars:", range: searchStart..<text.endIndex) {
            var i = r.upperBound
            var name = ""
            while i < text.endIndex {
                let ch = text[i]
                if ch.isLetter || ch.isNumber || ch == "_" || ch == ":" { name.append(ch) } else { break }
                i = text.index(after: i)
            }
            if !name.isEmpty { names.insert(name) }
            searchStart = r.upperBound
        }
        return names.sorted()
    }
}
