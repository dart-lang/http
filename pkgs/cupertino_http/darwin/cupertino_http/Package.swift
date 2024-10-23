// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cupertino_http",
    platforms: [
        .iOS("12.0"),
        .macOS("10.4"),
    ],
    products: [
        .library(name: "cupertino-http", targets: ["cupertino_http"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "cupertino_http",
            dependencies: [],
            resources: [
            ],
            cSettings: [
                .headerSearchPath("include/cupertino_http"),
                .unsafeFlags(["-fno-objc-arc"]),
            ]
        )
    ]
)
