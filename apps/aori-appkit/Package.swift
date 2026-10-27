// swift-tools-version: 6.0
import PackageDescription

// The macOS app target is compiled only on macOS.
// Linux `swift test` builds AoriCore and AoriProviders.
var products: [Product] = [
    .library(name: "AoriCore", targets: ["AoriCore"]),
    .library(name: "AoriProviders", targets: ["AoriProviders"]),
]

var coreDependencies: [Target.Dependency] = []
var coreLinker: [LinkerSetting] = []
var providerLinker: [LinkerSetting] = []
#if os(Linux)
coreDependencies.append("CSQLite")
#endif
#if os(macOS)
coreLinker.append(.linkedFramework("JavaScriptCore"))
providerLinker.append(.linkedFramework("CoreML"))
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
            .copy("Resources/aori-minilm.mlmodel"),
            .copy("Resources/aori-minilm-vocab.txt"),
            .copy("Resources/aori-minilm-reference.json"),
            .copy("Resources/aori-minilm-license.txt"),
        ],
        linkerSettings: coreLinker
    ),
    .target(name: "AoriProviders", dependencies: ["AoriCore"], linkerSettings: providerLinker),
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
            .linkedFramework("JavaScriptCore"),
            .linkedFramework("CoreML"),
            // The static library is produced by `cargo build -p aori-face`.
            .unsafeFlags(["-L", "rust/target/debug", "-laori_face"]),
        ]
    )
)
products.append(.executable(name: "AoriSceneKit", targets: ["AoriSceneKit"]))
targets.append(
    .executableTarget(
        name: "AoriSceneKit",
        dependencies: ["AoriCore"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("SceneKit"),
            .linkedFramework("Metal"),
            .linkedFramework("ImageIO"),
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
