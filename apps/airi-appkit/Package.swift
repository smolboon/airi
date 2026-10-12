// swift-tools-version: 6.0
import PackageDescription

// The macOS app target is compiled only on macOS.
// Linux `swift test` builds AiriCore and AiriProviders.
var products: [Product] = [
    .library(name: "AiriCore", targets: ["AiriCore"]),
    .library(name: "AiriProviders", targets: ["AiriProviders"]),
]

var targets: [Target] = [
    .target(name: "AiriCore"),
    .target(name: "AiriProviders", dependencies: ["AiriCore"]),
    .testTarget(name: "AiriCoreTests", dependencies: ["AiriCore"]),
    .testTarget(name: "AiriProvidersTests", dependencies: ["AiriProviders"]),
]

#if os(macOS)
products.append(.executable(name: "AiriApp", targets: ["AiriApp"]))
targets.append(
    .executableTarget(
        name: "AiriApp",
        dependencies: ["AiriCore", "AiriProviders"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("AVFoundation"),
            .linkedFramework("Speech"),
            .linkedFramework("SceneKit"),
            .linkedFramework("Security"),
        ]
    )
)
#endif

let package = Package(
    name: "AiriAppKit",
    platforms: [
        .macOS(.v14),
    ],
    products: products,
    targets: targets
)
