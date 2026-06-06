// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoLoop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VideoLoop",
            path: "Sources/VideoLoop"
        )
    ]
)
