// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiquidAuthSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "LiquidAuthSDK",
            targets: ["LiquidAuthSDK"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/valpackett/SwiftCBOR.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/socketio/socket.io-client-swift.git",
            revision: "42da871d9369f290d6ec4930636c40672143905b"
        ),
        .package(url: "https://github.com/norio-nomura/Base32.git", from: "0.5.4"),
        .package(url: "https://github.com/stasel/WebRTC.git", from: "138.0.0"),
    ],
    targets: [
        .target(
            name: "LiquidAuthSDK",
            dependencies: [
                "SwiftCBOR",
                "Base32",
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "WebRTC", package: "WebRTC"),
            ],
            path: "Sources/LiquidAuthSDK",
            resources: [
                .process("auth.request.json")
            ]
        ),
        .testTarget(
            name: "LiquidAuthSDKTests",
            dependencies: ["LiquidAuthSDK"]
        ),
    ]
)