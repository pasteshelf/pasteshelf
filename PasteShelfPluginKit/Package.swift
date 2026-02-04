// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PasteShelfPluginKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PasteShelfPluginKit",
            targets: ["PasteShelfPluginKit"]
        )
    ],
    targets: [
        .target(
            name: "PasteShelfPluginKit",
            dependencies: [],
            path: "Sources/PasteShelfPluginKit"
        )
    ]
)
