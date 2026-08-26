// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "anthropic-sdk-swift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Anthropic", targets: ["Anthropic"]),
        .library(name: "AnthropicBeta", targets: ["Anthropic", "AnthropicBeta"]),
    ],
    targets: [
        .target(name: "Anthropic"),
        .target(name: "AnthropicBeta", dependencies: ["Anthropic"]),
        .testTarget(name: "AnthropicTests", dependencies: ["Anthropic"]),
    ]
)
