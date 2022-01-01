// swift-tools-version:5.3
 
import PackageDescription
 
let package = Package(
    name: "curl",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10)
    ],
    products: [
        .library(
            name: "curl",
            targets: ["curl"]),
    ],
    targets: [
        .binaryTarget(
            name: "curl",
            path: "Frameworks/curl.xcframework"
        )
    ]
)