// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacIsland",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacIsland",
            path: "Sources/MacIsland"
        )
    ]
)
