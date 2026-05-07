// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyboardSwitch",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "KeyboardSwitchCore",
            targets: ["KeyboardSwitchCore"]
        ),
        .executable(
            name: "KeyboardMonitor",
            targets: ["KeyboardMonitor"]
        )
    ],
    targets: [
        .target(
            name: "KeyboardSwitchCore"
        ),
        .executableTarget(
            name: "KeyboardMonitor",
            dependencies: ["KeyboardSwitchCore"]
        ),
        .testTarget(
            name: "KeyboardSwitchCoreTests",
            dependencies: ["KeyboardSwitchCore"]
        )
    ]
)
