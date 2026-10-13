// swift-tools-version: 6.0
import PackageDescription

// The macOS app target is compiled only on macOS.
// Linux `swift test` builds AoriCore and AoriProviders.
var products: [Product] = [
    .library(name: "AoriCore", targets: ["AoriCore"]),
    .library(name: "AoriProviders", targets: ["AoriProviders"]),
]

var coreDependencies: [Target.Dependency] = []
#if os(Linux)
coreDependencies.append("CSQLite")
#endif

var targets: [Target] = []
#if os(Linux)
targets.append(.systemLibrary(name: "CSQLite"))
#endif
targets.append(contentsOf: [
    .target(
        name: "AoriCore",
        dependencies: coreDependencies,
        resources: [
            .copy("Resources/aori.yaml"),
        ]
    ),
    .target(name: "AoriProviders", dependencies: ["AoriCore"]),
    .testTarget(name: "AoriCoreTests", dependencies: ["AoriCore"]),
    .testTarget(name: "AoriProvidersTests", dependencies: ["AoriProviders"]),
])

#if os(macOS)
products.append(.executable(name: "AoriApp", targets: ["AoriApp"]))
targets.append(
    .executableTarget(
        name: "AoriApp",
        dependencies: ["AoriCore", "AoriProviders"],
        resources: [
            .copy("Resources/aori-sample.vrm"),
        ],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("AVFoundation"),
            .linkedFramework("Speech"),
            .linkedFramework("Security"),
            .linkedFramework("ScreenCaptureKit"),
            .linkedFramework("CoreGraphics"),
            .linkedFramework("ImageIO"),
            // The static library is produced by `cargo build -p aori-face`.
            .unsafeFlags(["-L", "rust/target/debug", "-laori_face"]),
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
