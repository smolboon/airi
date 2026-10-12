import XCTest
@testable import AoriCore

final class Live2DPoseTests: XCTestCase {
    func testAvatarKindReadsTheLive2DSelector() {
        XCTAssertEqual(AvatarKind.resolve("live2d"), .layered)
        XCTAssertEqual(AvatarKind.resolve("vrm"), .vrm)
        XCTAssertEqual(AvatarKind.resolve(nil), .vrm)
        XCTAssertEqual(AvatarKind.resolve("Live2D"), .vrm)
    }

    func testParameterIdsMatchThePublicNames() {
        XCTAssertEqual(Live2DParameterId.mouthOpenY, "ParamMouthOpenY")
        XCTAssertEqual(Live2DParameterId.eyeLOpen, "ParamEyeLOpen")
        XCTAssertEqual(Live2DParameterId.eyeROpen, "ParamEyeROpen")
        XCTAssertEqual(Live2DParameterId.angleX, "ParamAngleX")
        XCTAssertEqual(Live2DParameterId.angleY, "ParamAngleY")
    }

    func testVisemeScalesMouthAndBlinkClosesBothEyes() {
        let open = Live2DPose.parameters(
            mouth: 1,
            blink: 0,
            viseme: .a,
            lookX: 0.5,
            lookY: -0.25,
            emotion: .neutral
        )
        XCTAssertEqual(open.mouthOpenY, 1)
        XCTAssertEqual(open.eyeLOpen, 1)
        XCTAssertEqual(open.eyeROpen, 1)
        XCTAssertEqual(open.angleX, 15)
        XCTAssertEqual(open.angleY, -7.5)

        let narrow = Live2DPose.parameters(
            mouth: 1,
            blink: 0,
            viseme: .i,
            lookX: 0,
            lookY: 0,
            emotion: .neutral
        )
        XCTAssertEqual(narrow.mouthOpenY, 0.35, accuracy: 0.0001)

        let closed = Live2DPose.parameters(
            mouth: 1,
            blink: 0,
            viseme: .pp,
            lookX: 0,
            lookY: 0,
            emotion: .neutral
        )
        XCTAssertEqual(closed.mouthOpenY, 0)

        let shut = Live2DPose.parameters(
            mouth: 0,
            blink: 1,
            viseme: .a,
            lookX: 0,
            lookY: 0,
            emotion: .neutral
        )
        XCTAssertEqual(shut.eyeLOpen, 0)
        XCTAssertEqual(shut.eyeROpen, 0)

        let sad = Live2DPose.parameters(
            mouth: 0,
            blink: 0,
            viseme: .sil,
            lookX: 0,
            lookY: 0,
            emotion: .sad
        )
        XCTAssertEqual(sad.eyeLOpen, 0.7, accuracy: 0.0001)
    }
}
