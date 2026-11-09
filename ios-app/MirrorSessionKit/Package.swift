// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MirrorSessionKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MirrorSessionKit", targets: ["MirrorSessionKit"]),
    ],
    targets: [
        .target(
            name: "ExceptionCatcher",
            path: "Sources/ExceptionCatcher",
            publicHeadersPath: "include"
        ),
        .target(
            name: "MirrorSessionKit",
            path: "Sources/MirrorSessionKit"
        ),
        .testTarget(
            name: "MirrorSessionKitTests",
            dependencies: ["MirrorSessionKit", "ExceptionCatcher"],
            path: "Tests/MirrorSessionKitTests"
        ),
    ]
)
