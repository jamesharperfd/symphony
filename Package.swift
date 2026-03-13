// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Symphony",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "symphony", targets: ["Symphony"]),
        .library(name: "SymphonyCore", targets: ["SymphonyCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SymphonyCore",
            dependencies: ["Yams"],
            path: "Sources/SymphonyCore"
        ),
        .executableTarget(
            name: "Symphony",
            dependencies: ["SymphonyCore"],
            path: "Sources/Symphony"
        ),
        .testTarget(
            name: "SymphonyCoreTests",
            dependencies: ["SymphonyCore"],
            path: "Tests/SymphonyCoreTests"
        ),
    ]
)
