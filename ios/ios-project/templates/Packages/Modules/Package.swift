// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [.iOS(__PACKAGE_PLATFORM__)],
    products: [
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        ),
        // Add integration products here, e.g.:
        // .library(name: "AppleHealth", targets: ["AppleHealth"]),
    ],
    targets: [
        .target(
            name: "DesignSystem"
        ),
        // Integrations live under Sources/Integrations/<Name>:
        // .target(name: "AppleHealth", dependencies: [], path: "Sources/Integrations/AppleHealth"),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
            ]
        ),
    ]
)
