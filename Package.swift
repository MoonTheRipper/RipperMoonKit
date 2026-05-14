// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RipperMoonKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RipperMoonKitLauncher",
            targets: ["RipperMoonKitLauncher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RipperMoonKitLauncher",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
