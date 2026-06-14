// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeadroomCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "HeadroomCore", targets: ["HeadroomCore"]),
        .executable(name: "headroom", targets: ["headroom"]),
    ],
    targets: [
        .target(name: "HeadroomCore"),
        .executableTarget(name: "headroom", dependencies: ["HeadroomCore"]),
        .testTarget(name: "HeadroomCoreTests", dependencies: ["HeadroomCore"]),
    ]
)
