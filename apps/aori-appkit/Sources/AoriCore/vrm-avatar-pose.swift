import Foundation

/// Clock, mouth, and blink for one VRM portrait. SceneKit and tests share this value.
public struct VRMAvatarPose: Equatable, Sendable {
    public var time: Double
    public var mouthOpen: Double
    public var viseme: String
    public var reduceMotion: Bool
    public var emotion: CompanionEmotion

    public init(
        time: Double,
        mouthOpen: Double,
        viseme: String,
        reduceMotion: Bool,
        emotion: CompanionEmotion
    ) {
        self.time = time
        self.mouthOpen = mouthOpen
        self.viseme = viseme
        self.reduceMotion = reduceMotion
        self.emotion = emotion
    }

    /// Open A mouth at the screenshot clock. Blink is off at that time.
    public static let portrait = VRMAvatarPose(
        time: MotionPolicy.screenshotTime,
        mouthOpen: 0.8,
        viseme: "a",
        reduceMotion: false,
        emotion: .neutral
    )

    public var blink: Double {
        MotionPolicy.blink(time: time, reduceMotion: reduceMotion)
    }

    /// Head yaw in radians. Reduce motion holds the head at rest.
    public var yaw: Double {
        if reduceMotion {
            return 0
        }
        return sin(time * 0.7) * 0.25
    }

    /// Head pitch in radians. Reduce motion holds the head at rest.
    public var pitch: Double {
        if reduceMotion {
            return 0
        }
        return sin(time * 0.35) * 0.08
    }

    public func weights(in scene: VRMScene) -> [MorphWeight] {
        var weights = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: emotion,
            mouthOpen: mouthOpen,
            blink: blink,
            viseme: viseme
        )
        let shut = blink
        guard shut > 0 else {
            return weights
        }
        for (meshIndex, mesh) in scene.meshes.enumerated() {
            for (morphIndex, morph) in mesh.morphs.enumerated() where Self.isBlink(morph.name) {
                let already = weights.contains { $0.mesh == meshIndex && $0.morph == morphIndex }
                if !already {
                    weights.append(MorphWeight(mesh: meshIndex, morph: morphIndex, weight: shut))
                }
            }
        }
        return weights
    }

    private static func isBlink(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "blink" || lower == "blink_l" || lower == "blink_r"
    }
}
