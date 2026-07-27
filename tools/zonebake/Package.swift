// swift-tools-version:5.9
import PackageDescription

// Offline tool. Bakes the per-vertex zone map that the app's tap resolution reads.
// `BodyTransform.swift` and `ZoneMapFile.swift` are symlinks into `xT/Shared/` so the
// tool and the app compile the *same* source — the whole point of this refactor is that
// there is exactly one definition of the body transform and one of the map schema.
let package = Package(
    name: "zonebake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "zonebake", path: "Sources/zonebake")
    ]
)
