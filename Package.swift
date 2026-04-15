// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TextEngineTool",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "TextEngineTool",
            targets: ["TextEngineTool"]
        ),
        .library(
            name: "TextEngineToolCore",
            targets: ["TextEngineToolCore"]
        ),
    ],
    targets: [
        .target(
            name: "TextEngineToolCore"
        ),
        .executableTarget(
            name: "TextEngineTool",
            dependencies: ["TextEngineToolCore"]
        ),
    ]
)
