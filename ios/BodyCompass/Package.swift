// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BodyCompass",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BodyCompassCore", targets: ["BodyCompassCore"]),
        .executable(name: "BodyCompassCoreCheck", targets: ["BodyCompassCoreCheck"])
    ],
    targets: [
        .target(name: "BodyCompassCore"),
        .executableTarget(name: "BodyCompassCoreCheck", dependencies: ["BodyCompassCore"])
    ]
)
