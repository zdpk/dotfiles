// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InputSourceSwitcher",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "InputSourcePolicy", targets: ["InputSourcePolicy"]),
        .executable(name: "input-source-switcher", targets: ["InputSourceSwitcher"]),
    ],
    targets: [
        .target(name: "InputSourcePolicy"),
        .executableTarget(
            name: "InputSourceSwitcher",
            dependencies: ["InputSourcePolicy"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "InputSourcePolicyTests",
            dependencies: ["InputSourcePolicy"]
        ),
    ]
)
