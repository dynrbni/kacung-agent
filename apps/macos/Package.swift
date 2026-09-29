// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kacung",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Kacung", targets: ["KacungApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KacungApp",
            dependencies: [],
            path: "Sources/KacungApp"
        )
    ]
)
