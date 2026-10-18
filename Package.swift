// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dropwheel",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Dropwheel", path: "Sources/Dropwheel")
    ]
)
