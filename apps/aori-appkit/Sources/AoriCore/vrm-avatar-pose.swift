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

    /// Head pitch in radians. Reduce motion holds the idle sway at rest.
    /// Happy, sad, and surprised still tilt the head.
    public var pitch: Double {
        let idle = reduceMotion ? 0.0 : sin(time * 0.35) * 0.08
        return idle + expressionPitch
    }

    /// A small tilt so the expression reads when the model has no emotion morph.
    public var expressionPitch: Double {
        switch emotion {
        case .happy:
            return -0.04
        case .sad:
            return 0.07
        case .surprised:
            return -0.02
        case .neutral:
            return 0
        }
    }

    /// Screenshot pose. The head faces the camera. Idle yaw stays off.
    public static func face(emotion: CompanionEmotion) -> VRMAvatarPose {
        VRMAvatarPose(
            time: MotionPolicy.screenshotTime,
            mouthOpen: 0.8,
            viseme: "a",
            reduceMotion: true,
            emotion: emotion
        )
    }

    public func weights(in scene: VRMScene) -> [MorphWeight] {
        var weights = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: emotion,
            mouthOpen: mouthOpen,
            blink: blink,
            viseme: viseme
        )
        weights.append(contentsOf: Self.standInWeights(scene: scene, emotion: emotion))
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

    /// Butter has vowel and blink shapes only. Those stand in for joy, sorrow, and surprise.
    private static func standInWeights(scene: VRMScene, emotion: CompanionEmotion) -> [MorphWeight] {
        guard !hasEmotionPreset(scene, emotion: emotion) else {
            return []
        }
        let preset: String
        let amount: Double
        switch emotion {
        case .happy:
            preset = "e"
            amount = 0.55
        case .sad:
            preset = "blink"
            amount = 0.45
        case .surprised:
            preset = "o"
            amount = 0.7
        case .neutral:
            return []
        }
        var weights: [MorphWeight] = []
        for shape in scene.blendShapes {
            let names = [shape.preset.lowercased(), shape.name.lowercased()]
            guard names.contains(preset) else {
                continue
            }
            for bind in shape.binds {
                let scaled = amount * min(1, max(0, bind.weight / 100))
                weights.append(MorphWeight(mesh: bind.mesh, morph: bind.morph, weight: scaled))
            }
        }
        return weights
    }

    private static func hasEmotionPreset(_ scene: VRMScene, emotion: CompanionEmotion) -> Bool {
        let wanted: [String]
        switch emotion {
        case .happy:
            wanted = ["joy", "happy", "fun"]
        case .sad:
            wanted = ["sorrow", "sad"]
        case .surprised:
            wanted = ["surprised", "surprise"]
        case .neutral:
            return true
        }
        return scene.blendShapes.contains { shape in
            let names = [shape.preset.lowercased(), shape.name.lowercased()]
            return names.contains { wanted.contains($0) }
        }
    }
}

public struct PortraitFrame: Equatable, Sendable {
    public var lookX: Float
    public var lookY: Float
    public var lookZ: Float
    public var cameraZ: Float
    public var viewHalf: Float
    public var fieldOfView: Float

    public init(
        lookX: Float,
        lookY: Float,
        lookZ: Float,
        cameraZ: Float,
        viewHalf: Float,
        fieldOfView: Float
    ) {
        self.lookX = lookX
        self.lookY = lookY
        self.lookZ = lookZ
        self.cameraZ = cameraZ
        self.viewHalf = viewHalf
        self.fieldOfView = fieldOfView
    }
}

public enum PortraitCamera {
    /// Frames a head-and-shoulders view. The camera sits on +Z.
    public static func frame(positions: [VRMVec3], fieldOfView: Float = 26) -> PortraitFrame {
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        for position in positions {
            minY = min(minY, position.y)
            maxY = max(maxY, position.y)
        }
        if minY > maxY {
            return PortraitFrame(lookX: 0, lookY: 0.2, lookZ: 0, cameraZ: 1.6, viewHalf: 0.3, fieldOfView: fieldOfView)
        }
        let height = max(0.2, maxY - minY)
        let headCut = maxY - height * 0.22
        var sumX: Float = 0
        var sumZ: Float = 0
        var count: Float = 0
        for position in positions where position.y >= headCut {
            sumX += position.x
            sumZ += position.z
            count += 1
        }
        let lookX = count > 0 ? sumX / count : 0
        let lookZ = count > 0 ? sumZ / count : 0
        // The head is wide. Fitting that width pulls the torso into the frame.
        // The portrait keeps the face large and lets the hair edges leave the frame.
        let top = maxY + height * 0.04
        let shoulderBottom = maxY - height * 0.28
        let half = max(0.05, (top - shoulderBottom) * 0.5)
        let lookY = (top + shoulderBottom) * 0.5
        let fov = Double(fieldOfView) * .pi / 180
        let distance = Double(half) / tan(fov * 0.5)
        return PortraitFrame(
            lookX: lookX,
            lookY: lookY,
            lookZ: lookZ,
            cameraZ: lookZ + Float(distance),
            viewHalf: half,
            fieldOfView: fieldOfView
        )
    }
}
