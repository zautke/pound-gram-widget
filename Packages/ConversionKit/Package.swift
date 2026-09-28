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
    targets: [
        .target(
            name: "ConversionKit",
            path: "Sources/ConversionKit"
        ),
        .testTarget(
            name: "ConversionKitTests",
            dependencies: ["ConversionKit"],
            path: "Tests/ConversionKitTests"
        )
    ]
)
