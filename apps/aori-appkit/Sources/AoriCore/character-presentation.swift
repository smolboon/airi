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
    public var emotion: CompanionEmotion

    public init(
        title: String,
        subtitle: String,
        mouthOpen: Double,
        usesPlaceholderMesh: Bool,
        emotion: CompanionEmotion = .neutral
    ) {
        self.title = title
        self.subtitle = subtitle
        self.mouthOpen = mouthOpen
        self.usesPlaceholderMesh = usesPlaceholderMesh
        self.emotion = emotion
    }

    public static let placeholder = CharacterPresentation(
        title: "Aori",
        subtitle: "The VRM mesh is not loaded.",
        mouthOpen: 0,
        usesPlaceholderMesh: true,
        emotion: .neutral
    )

    public func applying(_ document: VRMDocument) -> CharacterPresentation {
        let title = document.title ?? "VRM"
        let version = document.vrmVersion ?? "unknown"
        return CharacterPresentation(
            title: title,
            subtitle: "VRM \(version). \(document.meshCount) meshes. This path does not read mesh bytes.",
            mouthOpen: mouthOpen,
            usesPlaceholderMesh: true,
            emotion: emotion
        )
    }

    public func applying(_ scene: VRMScene) -> CharacterPresentation {
        let title = scene.document.title ?? title
        let shapes = scene.blendShapes.count
        return CharacterPresentation(
            title: title,
            subtitle: "VRM mesh. \(scene.vertexCount) vertices. \(shapes) blend shapes.",
            mouthOpen: mouthOpen,
            usesPlaceholderMesh: scene.vertexCount == 0,
            emotion: emotion
        )
    }
}

public struct CharacterPose: Equatable, Sendable {
    public var mouthOpen: Double
    public var eyeOpen: Double
    public var sway: Double
    public var emotion: CompanionEmotion

    public init(mouthOpen: Double, eyeOpen: Double, sway: Double, emotion: CompanionEmotion) {
        self.mouthOpen = mouthOpen
        self.eyeOpen = eyeOpen
        self.sway = sway
        self.emotion = emotion
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

    /// Idle blink and sway, plus a speech-timed mouth. The mouth is not driven by audio samples.
    public static func pose(time: Double, speaking: Bool, emotion: CompanionEmotion) -> CharacterPose {
        let blink = !speaking && abs(time.truncatingRemainder(dividingBy: 3.2) - 0.1) < 0.08
        let eyeOpen: Double
        switch emotion {
        case .surprised:
            eyeOpen = blink ? 0.2 : 1.2
        case .sad:
            eyeOpen = blink ? 0.2 : 0.7
        case .neutral, .happy:
            eyeOpen = blink ? 0.15 : 1
        }
        let mouthOpen: Double
        if speaking {
            mouthOpen = Self.mouthOpen(time: time, speaking: true)
        } else if emotion == .happy {
            mouthOpen = 0.25
        } else {
            mouthOpen = 0
        }
        let sway = sin(time * 0.8) * (speaking ? 0.02 : 0.05)
        return CharacterPose(mouthOpen: mouthOpen, eyeOpen: eyeOpen, sway: sway, emotion: emotion)
    }
}
