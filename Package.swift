// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SparkClean",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Swift Testing is bundled with Xcode 16+; pinned here so the package
        // also tests under standalone CommandLineTools toolchains.
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
        // Sparkle: app update framework (binary target, distributed as xcframework).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "SparkClean",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/SparkCleanApp",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                // SwiftPM links the Sparkle binary target as @rpath but injects
                // no search path of its own. Two rpaths cover both layouts:
                // @loader_path resolves `swift run` (framework staged next to
                // the binary in .build/<config>/), @executable_path/../Frameworks
                // resolves the packaged bundle (Contents/Frameworks).
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .testTarget(
            name: "SparkCleanTests",
            dependencies: [
                "SparkClean",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/SparkCleanTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
