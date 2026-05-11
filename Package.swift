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
            name: "PromptWhisper",
            targets: ["PromptWhisper"]
        ),
        .executable(
            name: "KeyboardSwitch",
            targets: ["KeyboardSwitch"]
        )
    ],
    targets: [
        .target(
            name: "KeyboardSwitchCore"
        ),
        .executableTarget(
            name: "PromptWhisper",
            dependencies: ["KeyboardSwitchCore"]
        ),
        .executableTarget(
            name: "KeyboardSwitch",
            dependencies: ["KeyboardSwitchCore"],
            path: "Sources/KeyboardMonitor"
        ),
        .testTarget(
            name: "KeyboardSwitchCoreTests",
            dependencies: ["KeyboardSwitchCore"]
        )
    ]
)
