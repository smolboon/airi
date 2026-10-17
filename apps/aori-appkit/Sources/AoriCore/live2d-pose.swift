import Foundation

/// Selects the companion raster. `live2d` draws flat layers. Any other value keeps the VRM.
public enum AvatarKind: Equatable, Sendable {
    case vrm
    case layered

    public static func resolve(_ value: String?) -> AvatarKind {
        if value == "live2d" {
            return .layered
        }
        return .vrm
    }
}

/// Live2D parameter ids. The raster reads these names. It does not read a moc3 file.
public enum Live2DParameterId {
    public static let mouthOpenY = "ParamMouthOpenY"
    public static let eyeLOpen = "ParamEyeLOpen"
    public static let eyeROpen = "ParamEyeROpen"
    public static let angleX = "ParamAngleX"
    public static let angleY = "ParamAngleY"
}

public struct Live2DParameters: Equatable, Sendable {
    public var mouthOpenY: Double
    public var eyeLOpen: Double
    public var eyeROpen: Double
    public var angleX: Double
    public var angleY: Double

    public init(
        mouthOpenY: Double,
        eyeLOpen: Double,
        eyeROpen: Double,
        angleX: Double,
        angleY: Double
    ) {
        self.mouthOpenY = mouthOpenY
        self.eyeLOpen = eyeLOpen
        self.eyeROpen = eyeROpen
        self.angleX = angleX
        self.angleY = angleY
    }
}

public enum Live2DPose {
    /// Maps a viseme, a blink, and a look vector onto Live2D parameter values.
    public static func parameters(
        mouth: Double,
        blink: Double,
        viseme: Viseme,
        lookX: Double,
        lookY: Double,
        emotion: CompanionEmotion
    ) -> Live2DParameters {
        let amount = min(1, max(0, mouth))
        let scale: Double
        switch viseme {
        case .a:
            scale = 1
        case .e:
            scale = 0.7
        case .o:
            scale = 0.85
        case .u:
            scale = 0.45
        case .i:
            scale = 0.35
        case .pp, .sil:
            scale = 0
        }
        let shut = min(1, max(0, blink))
        var eye = 1 - shut
        if emotion == .sad {
            eye *= 0.7
        }
        return Live2DParameters(
            mouthOpenY: amount * scale,
            eyeLOpen: eye,
            eyeROpen: eye,
            angleX: lookX * 30,
            angleY: lookY * 30
        )
    }
}
