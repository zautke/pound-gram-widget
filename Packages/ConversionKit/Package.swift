// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversionKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversionKit",
            targets: ["ConversionKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.19.2"
        )
    ],
    targets: [
        .target(
            name: "ConversionKit",
            path: "Sources/ConversionKit"
        ),
        .testTarget(
            name: "ConversionKitTests",
            dependencies: [
                "ConversionKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/ConversionKitTests"
        )
    ]
)
