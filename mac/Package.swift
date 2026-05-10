// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExeWatcherMenubar",
    platforms: [
        // macOS 26 (Tahoe) — required for native Liquid Glass APIs.
        .macOS(.v26)
    ],
    products: [
        .executable(name: "ExeWatcherMenubar", targets: ["ExeWatcherMenubar"])
    ],
    targets: [
        .executableTarget(
            name: "ExeWatcherMenubar",
            path: "Sources/ExeWatcherMenubar",
            resources: [
                .copy("Resources/owl.pdf"),
                .copy("Resources/owl-menubar.pdf"),
                .copy("Resources/Epilogue-Bold.ttf"),
                .copy("Resources/AppIcon.icns")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ExeWatcherMenubarTests",
            dependencies: ["ExeWatcherMenubar"],
            path: "Tests/ExeWatcherMenubarTests"
        ),
        .testTarget(
            name: "ExeWatcherUITests",
            path: "Tests/ExeWatcherUITests"
        )
    ]
)
