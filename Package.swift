// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlinFoundation",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "AlinFoundation",
            targets: ["AlinFoundation"]),
    ],
    targets: [
        .target(
            name: "AlinFoundation",
            dependencies: []),
    ]
)
