// swift-tools-version: 6.0
import PackageDescription

// The macOS app target is compiled only on macOS.
// Linux `swift test` builds AoriCore and AoriProviders.
var products: [Product] = [
    .library(name: "AoriCore", targets: ["AoriCore"]),
    .library(name: "AoriProviders", targets: ["AoriProviders"]),
]

var targets: [Target] = [
    .target(name: "AoriCore"),
    .target(name: "AoriProviders", dependencies: ["AoriCore"]),
    .testTarget(name: "AoriCoreTests", dependencies: ["AoriCore"]),
    .testTarget(name: "AoriProvidersTests", dependencies: ["AoriProviders"]),
]

#if os(macOS)
products.append(.executable(name: "AoriApp", targets: ["AoriApp"]))
targets.append(
    .executableTarget(
        name: "AoriApp",
        dependencies: ["AoriCore", "AoriProviders"],
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
    name: "AoriAppKit",
    platforms: [
        .macOS(.v14),
    ],
    products: products,
    targets: targets
)
