// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Repaste",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (history, filtering, persistence) kept separate so it can be unit tested.
        .target(name: "RepasteCore", path: "Sources/RepasteCore"),
        .executableTarget(
            name: "Repaste",
            dependencies: ["RepasteCore"],
            path: "Sources/Repaste"
        ),
        .testTarget(
            name: "RepasteCoreTests",
            dependencies: ["RepasteCore"],
            path: "Tests/RepasteCoreTests"
        )
    ]
)
