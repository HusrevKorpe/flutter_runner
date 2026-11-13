// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FlutterRunner",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "FlutterRunner",
            path: "Sources/FlutterRunner",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
