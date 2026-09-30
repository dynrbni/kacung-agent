// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lafly",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Lafly", targets: ["LaflyApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LaflyApp",
            dependencies: [],
            path: "Sources/LaflyApp"
        )
    ]
)
