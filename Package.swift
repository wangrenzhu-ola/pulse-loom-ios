// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PulseLoomCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(name: "PulseLoomCore", targets: ["PulseLoomCore"])
    ],
    targets: [
        .target(
            name: "PulseLoomCore",
            path: "Sources/PulseLoomCore"
        ),
        .testTarget(
            name: "PulseLoomCoreTests",
            dependencies: ["PulseLoomCore"],
            path: "PulseLoomCoreTests"
        )
    ]
)

