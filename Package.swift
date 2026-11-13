// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FlutterRunner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FlutterRunner",
            path: "Sources/FlutterRunner"
        )
    ]
)
