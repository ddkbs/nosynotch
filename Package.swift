// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NosyNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NosyNotch",
            path: "Sources/NosyNotch"
        )
    ]
)
