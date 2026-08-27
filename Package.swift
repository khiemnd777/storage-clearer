// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StorageClearer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StorageClearerApp", targets: ["StorageClearerApp"])
    ],
    targets: [
        .executableTarget(
            name: "StorageClearerApp",
            path: "App/Sources"
        )
    ]
)
