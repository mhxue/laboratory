// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EPUBKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EPUBKit",
            targets: ["EPUBKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            from: "0.9.19"
        )
    ],
    targets: [
        .target(
            name: "EPUBKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EPUBKitTests",
            dependencies: ["EPUBKit"],
            resources: [
                .copy("Fixtures/pride_and_prejudice.epub")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
