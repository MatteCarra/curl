// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "curl-test",
    platforms: [
        .macOS(.v10_12)
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .target(
            name: "curl-test",
            dependencies: ["curl"])
    ]
)
