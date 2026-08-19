// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ModelOControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ModelOCore", targets: ["ModelOCore"]),
        .executable(name: "ModelOControl", targets: ["ModelOControl"]),
        .executable(name: "modelo-probe", targets: ["ModelOProbe"])
    ],
    targets: [
        .target(
            name: "ModelOCore",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "ModelOControl",
            dependencies: ["ModelOCore"],
            exclude: ["Resources"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "ModelOProbe",
            dependencies: ["ModelOCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ModelOCoreTests",
            dependencies: ["ModelOCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
