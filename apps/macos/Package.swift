// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lofly",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Lofly", targets: ["LoflyApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LoflyApp",
            dependencies: [],
            path: "Sources/LoflyApp"
        )
    ]
)
