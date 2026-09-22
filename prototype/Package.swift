// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadialPrototype",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RadialCore", targets: ["RadialCore"]),
        .executable(name: "RadialPrototype", targets: ["RadialPrototype"])
    ],
    targets: [
        .target(name: "RadialCore"),
        .target(name: "RadialRuntime", dependencies: ["RadialCore"]),
        .target(name: "RadialMac", dependencies: ["RadialCore", "RadialRuntime"]),
        .target(name: "RadialUI", dependencies: ["RadialCore"]),
        .executableTarget(name: "RadialPrototype", dependencies: ["RadialCore", "RadialRuntime", "RadialMac", "RadialUI"]),
        .testTarget(name: "RadialCoreTests", dependencies: ["RadialCore"]),
        .testTarget(name: "RadialRuntimeTests", dependencies: ["RadialCore", "RadialRuntime"]),
        .testTarget(name: "RadialMacTests", dependencies: ["RadialCore", "RadialMac"])
    ],
    swiftLanguageModes: [.v6]
)
