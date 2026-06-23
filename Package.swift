// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KlineTimer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KlineCore"),
        .executableTarget(
            name: "KlineTimer",
            dependencies: ["KlineCore"]
        ),
        .testTarget(
            name: "KlineCoreTests",
            dependencies: ["KlineCore"]
        ),
    ]
)
