import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct CharacterPresentation: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var mouthOpen: Double
    public var usesPlaceholderMesh: Bool

    public init(title: String, subtitle: String, mouthOpen: Double, usesPlaceholderMesh: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.mouthOpen = mouthOpen
        self.usesPlaceholderMesh = usesPlaceholderMesh
    }

    public static let placeholder = CharacterPresentation(
        title: "AIRI",
        subtitle: "SceneKit placeholder. A VRM file shows its name here. The mesh is not imported yet.",
        mouthOpen: 0,
        usesPlaceholderMesh: true
    )

    public func applying(_ document: VRMDocument) -> CharacterPresentation {
        let title = document.title ?? "VRM"
        let version = document.vrmVersion ?? "unknown"
        return CharacterPresentation(
            title: title,
            subtitle: "VRM \(version). \(document.meshCount) meshes. SceneKit still draws the placeholder.",
            mouthOpen: mouthOpen,
            usesPlaceholderMesh: true
        )
    }
}

public enum CharacterMotion {
    /// Returns a mouth open amount from 0 to 1.
    public static func mouthOpen(time: Double, speaking: Bool) -> Double {
        guard speaking else {
            return 0
        }
        let wave = (sin(time * 14) + 1) / 2
        let amount = 0.15 + (0.85 * wave)
        return min(1, max(0, amount))
    }
}
