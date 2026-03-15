// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyCue",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "EdgeControlShared", targets: ["EdgeControlShared"]),
        .library(name: "EdgeControlHost", targets: ["EdgeControlHost"]),
        .executable(name: "edge-control", targets: ["EdgeControlApp"])
    ],
    targets: [
        .target(
            name: "EdgeControlShared",
            path: "Sources/EdgeControlShared"
        ),
        .target(
            name: "EdgeControlHost",
            dependencies: ["EdgeControlShared"],
            path: "Sources/EdgeControlHost"
        ),
        .executableTarget(
            name: "EdgeControlApp",
            dependencies: ["EdgeControlHost"],
            path: "Sources/EdgeControlApp"
        ),
        .testTarget(
            name: "EdgeControlTests",
            dependencies: ["EdgeControlShared", "EdgeControlHost"],
            path: "Tests/EdgeControlTests"
        )
    ]
)
