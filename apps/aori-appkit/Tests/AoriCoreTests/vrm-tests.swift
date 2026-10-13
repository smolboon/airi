import XCTest
@testable import AoriCore

final class VRMDocumentTests: XCTestCase {
    func testReadsVRM0AndVRM1Names() throws {
        let vrm0 = try VRMDocumentReader.read(glb(json: """
        {"asset":{"generator":"test"},"meshes":[{},{}],"extensions":{"VRM":{"meta":{"title":"Hiyori"}}}}
        """))
        XCTAssertEqual(vrm0.title, "Hiyori")
        XCTAssertEqual(vrm0.vrmVersion, "0.x")
        XCTAssertEqual(vrm0.generator, "test")
        XCTAssertEqual(vrm0.meshCount, 2)
        XCTAssertEqual(vrm0.glTFVersion, 2)

        let vrm1 = try VRMDocumentReader.read(glb(json: """
        {"asset":{"generator":"vrm1"},"meshes":[{}],"extensions":{"VRMC_vrm":{"meta":{"name":"Airi"}}}}
        """))
        XCTAssertEqual(vrm1.title, "Airi")
        XCTAssertEqual(vrm1.vrmVersion, "1.0")
        XCTAssertEqual(vrm1.meshCount, 1)
    }

    func testRejectsBadFiles() {
        XCTAssertThrowsError(try VRMDocumentReader.read(Data(count: 4))) { error in
            XCTAssertEqual(error as? VRMDocumentError, .tooSmall)
        }
        XCTAssertThrowsError(try VRMDocumentReader.read(Data(count: 32))) { error in
            XCTAssertEqual(error as? VRMDocumentError, .badMagic)
        }

        var truncated = Data()
        appendUInt32(0x4654_6C67, to: &truncated)
        appendUInt32(2, to: &truncated)
        appendUInt32(100, to: &truncated)
        truncated.append(Data(count: 8))
        XCTAssertThrowsError(try VRMDocumentReader.read(truncated)) { error in
            XCTAssertEqual(error as? VRMDocumentError, .truncated)
        }
    }

    func testRejectsInvalidJSONAndMissingJSONChunk() {
        XCTAssertThrowsError(try VRMDocumentReader.read(glb(json: "{"))) { error in
            XCTAssertEqual(error as? VRMDocumentError, .invalidJSON)
        }
        XCTAssertThrowsError(try VRMDocumentReader.read(glb(json: "{\"asset\":{}}", chunkType: 0x004E_4942))) { error in
            XCTAssertEqual(error as? VRMDocumentError, .missingJSONChunk)
        }
    }
}

final class CharacterAndWindowTests: XCTestCase {
    func testMouthOpenStaysInRange() {
        XCTAssertEqual(CharacterMotion.mouthOpen(time: 1.2, speaking: false), 0)
        let open = CharacterMotion.mouthOpen(time: 0.4, speaking: true)
        XCTAssertGreaterThanOrEqual(open, 0)
        XCTAssertLessThanOrEqual(open, 1)
        XCTAssertGreaterThan(open, 0)
    }

    func testPlaceholderStaysWhenVRMMetadataLoads() throws {
        let document = try VRMDocumentReader.read(glb(json: """
        {"meshes":[{},{},{}],"extensions":{"VRM":{"meta":{"title":"Nova"}}}}
        """))
        let presentation = CharacterPresentation.placeholder.applying(document)
        XCTAssertEqual(presentation.title, "Nova")
        XCTAssertTrue(presentation.usesPlaceholderMesh)
        XCTAssertTrue(presentation.subtitle.contains("3"))
    }

    func testIdleBlinkAndSpeechMouth() {
        let idle = CharacterMotion.pose(time: 0.1, speaking: false, emotion: .neutral)
        XCTAssertEqual(idle.mouthOpen, 0)
        XCTAssertLessThan(idle.eyeOpen, 0.5)

        let open = CharacterMotion.pose(time: 1, speaking: false, emotion: .neutral)
        XCTAssertGreaterThan(open.eyeOpen, 0.9)

        let speaking = CharacterMotion.pose(time: 0.4, speaking: true, emotion: .neutral)
        XCTAssertGreaterThan(speaking.mouthOpen, 0)
        XCTAssertLessThanOrEqual(speaking.mouthOpen, 1)

        let happy = CharacterMotion.pose(time: 1, speaking: false, emotion: .happy)
        XCTAssertEqual(happy.mouthOpen, 0.25)
        XCTAssertNotEqual(idle.sway, CharacterMotion.pose(time: 1, speaking: false, emotion: .neutral).sway)
    }

    func testSampleVRMHasAMeshAndBlendShapes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AoriApp/Resources/aori-sample.vrm")
        let scene = try VRMSceneReader.read(Data(contentsOf: url))
        XCTAssertEqual(scene.document.title, "Butter")
        XCTAssertGreaterThan(scene.vertexCount, 20)
        XCTAssertFalse(scene.meshes[0].morphs.isEmpty)
        XCTAssertFalse(scene.meshes[0].uvs.isEmpty)
        XCTAssertGreaterThan(scene.meshes[0].texturePNG.count, 1000)
        XCTAssertEqual(scene.meshes[0].texturePNG.prefix(8), Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        let vowelA = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: .neutral,
            mouthOpen: 0.5,
            blink: 0,
            viseme: "a"
        )
        XCTAssertTrue(vowelA.contains(where: { abs($0.weight - 0.5) < 0.001 }))
        let vowelI = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: .neutral,
            mouthOpen: 0.5,
            blink: 0,
            viseme: "i"
        )
        let aKeys = Set(vowelA.map { "\($0.mesh):\($0.morph)" })
        let iKeys = Set(vowelI.map { "\($0.mesh):\($0.morph)" })
        XCTAssertFalse(aKeys.isEmpty)
        XCTAssertFalse(iKeys.isEmpty)
        XCTAssertTrue(aKeys.isDisjoint(with: iKeys))
        let presentation = CharacterPresentation.placeholder.applying(scene)
        XCTAssertFalse(presentation.usesPlaceholderMesh)
        XCTAssertEqual(SpeechLevel.mouthOpen(samples: [Float](repeating: 0, count: 8)), 0)
        XCTAssertGreaterThan(SpeechLevel.mouthOpen(samples: [Float](repeating: 0.25, count: 8)), 0.5)
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.contains("inverseBindMatrices"))
        XCTAssertTrue(text.contains("baseColorTexture"))
        XCTAssertTrue(text.contains("JOINTS_0"))
        XCTAssertTrue(text.lowercased().contains("blink"))
        XCTAssertTrue(text.contains("\"bone\": \"hips\""))
        XCTAssertTrue(text.contains("\"bone\": \"head\""))
        XCTAssertTrue(text.contains("CC0"))
        let bones = try VRMHumanoidReader.bones(in: bytes)
        let names = bones.map(\.name)
        XCTAssertTrue(names.contains("hips"))
        XCTAssertTrue(names.contains("head"))
        XCTAssertTrue(names.contains("leftLowerArm"))
        XCTAssertEqual(
            PhonemeTimeline.symbols(in: "Hello papa"),
            ["h", "e", "l", "l", "o", "p", "a", "p", "a"]
        )
        XCTAssertTrue(PhonemeTimeline.visemes(in: "Hi").contains(.i))
        let phrase = VisemeTimeline.presets(in: "Hello papa")
        XCTAssertTrue(phrase.contains(.e))
        XCTAssertTrue(phrase.contains(.o))
        XCTAssertTrue(phrase.contains(.a))
        XCTAssertTrue(phrase.contains(.pp))
        XCTAssertEqual(VisemeTimeline.preset(in: "Hello papa", at: 0).rawValue, "sil")
        let played = VisemeTimeline.presets(in: "Hello papa", from: 0, to: 0.85).map(\.rawValue)
        XCTAssertTrue(played.contains("e"))
        XCTAssertTrue(played.contains("o"))
        XCTAssertTrue(played.contains("a"))
        XCTAssertTrue(played.contains("pp"))
        let wav = WavFile.encode(samples: [Float](repeating: 0.25, count: 16), sampleRate: 16_000)
        XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wav.dropFirst(8).prefix(4), as: UTF8.self), "WAVE")
        XCTAssertGreaterThan(WavFile.rms(samples: [Float](repeating: 0.25, count: 16)), 0.2)
        let decoded = WavFile.decode(wav)
        XCTAssertEqual(decoded?.sampleRate, 16_000)
        XCTAssertEqual(decoded?.samples.count, 16)
        XCTAssertEqual(ScreenshotPose.mouthOpen, 1)
        XCTAssertEqual(MotionPolicy.blink(time: 0.1, reduceMotion: false), 1)
        XCTAssertEqual(MotionPolicy.blink(time: 0.1, reduceMotion: true), 0)
        XCTAssertEqual(MotionPolicy.idleTime(time: ScreenshotPose.time, reduceMotion: true), 0)
        XCTAssertEqual(MotionPolicy.idleTime(time: ScreenshotPose.time, reduceMotion: false), ScreenshotPose.time)
        XCTAssertEqual(AoriCopy.showCompanion, "Show Companion")
        XCTAssertFalse(AoriCopy.statusItem.isEmpty)
    }

    func testAvatarPoseOpensTheMouthAndBlinksTheEyes() throws {
        let portrait = VRMAvatarPose.portrait
        XCTAssertEqual(portrait.blink, 0)
        XCTAssertEqual(portrait.mouthOpen, 0.8)
        XCTAssertGreaterThan(abs(portrait.yaw), 0.05)
        XCTAssertGreaterThan(abs(portrait.pitch), 0.01)
        let still = VRMAvatarPose(
            time: MotionPolicy.screenshotTime,
            mouthOpen: 0.8,
            viseme: "a",
            reduceMotion: true,
            emotion: .neutral
        )
        XCTAssertEqual(still.yaw, 0)
        XCTAssertEqual(still.pitch, 0)
        XCTAssertEqual(still.blink, 0)
        let blink = VRMAvatarPose(
            time: 0.1,
            mouthOpen: 0,
            viseme: "sil",
            reduceMotion: false,
            emotion: .neutral
        )
        XCTAssertEqual(blink.blink, 1)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AoriApp/Resources/aori-sample.vrm")
        let scene = try VRMSceneReader.read(Data(contentsOf: url))
        let open = portrait.weights(in: scene)
        XCTAssertTrue(open.contains(where: { $0.weight > 0.5 }))
        let shut = blink.weights(in: scene)
        XCTAssertTrue(shut.contains(where: { $0.weight == 1 }))
    }

    func testReplySentimentChangesTheFace() throws {
        let scene = try VRMSceneReader.read(Data(contentsOf: sampleVRM()))
        let neutral = VRMAvatarPose.face(emotion: .neutral)
        let happy = VRMAvatarPose.face(emotion: .happy)
        let sad = VRMAvatarPose.face(emotion: .sad)
        let surprised = VRMAvatarPose.face(emotion: .surprised)
        XCTAssertEqual(neutral.yaw, 0)
        XCTAssertEqual(neutral.pitch, 0)
        XCTAssertLessThan(happy.pitch, 0)
        XCTAssertGreaterThan(sad.pitch, 0)
        let neutralKeys = morphKeys(neutral.weights(in: scene))
        XCTAssertFalse(morphKeys(happy.weights(in: scene)).subtracting(neutralKeys).isEmpty)
        XCTAssertFalse(morphKeys(sad.weights(in: scene)).subtracting(neutralKeys).isEmpty)
        XCTAssertFalse(morphKeys(surprised.weights(in: scene)).subtracting(neutralKeys).isEmpty)
        let joy = VRMBlendShape(
            name: "Joy",
            preset: "joy",
            binds: [VRMBlendBind(mesh: 0, morph: 3, weight: 100)]
        )
        let withJoy = VRMScene(document: scene.document, meshes: scene.meshes, blendShapes: scene.blendShapes + [joy])
        let glad = VRMAvatarPose.face(emotion: .happy).weights(in: withJoy)
        XCTAssertTrue(glad.contains(where: { $0.morph == 3 && $0.weight == 1 }))
        XCTAssertEqual(CompanionEmotion.infer(from: "I am glad."), .happy)
        XCTAssertEqual(CompanionEmotion.infer(from: "I am sorry."), .sad)
        XCTAssertEqual(CompanionEmotion.infer(from: "Wow, that is new."), .surprised)
    }

    func testPortraitCameraFramesTheHead() throws {
        let scene = try VRMSceneReader.read(Data(contentsOf: sampleVRM()))
        let positions = scene.meshes.flatMap(\.positions)
        let frame = PortraitCamera.frame(positions: positions)
        let maxY = positions.map(\.y).max() ?? 0
        let minY = positions.map(\.y).min() ?? 0
        let height = maxY - minY
        let top = frame.lookY + frame.viewHalf
        let bottom = frame.lookY - frame.viewHalf
        XCTAssertGreaterThan(top, maxY)
        XCTAssertLessThan(bottom, maxY - height * 0.2)
        XCTAssertGreaterThan(bottom, minY + height * 0.4)
        let maxZ = positions.map(\.z).max() ?? 0
        XCTAssertGreaterThan(frame.cameraZ, maxZ + 0.2)
        XCTAssertGreaterThan(frame.lookY, maxY - height * 0.45)
    }

    private func sampleVRM() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AoriApp/Resources/aori-sample.vrm")
    }

    private func morphKeys(_ weights: [MorphWeight]) -> Set<String> {
        Set(weights.map { "\($0.mesh):\($0.morph)" })
    }

    func testStandardCompanionStyle() {
        let style = CompanionWindowPolicy.standard.style()
        XCTAssertTrue(style.floating)
        XCTAssertTrue(style.transparent)
        XCTAssertTrue(style.borderless)
        XCTAssertTrue(style.joinsAllSpaces)
        XCTAssertTrue(style.movableByBackground)
        XCTAssertTrue(CompanionWindowPolicy.standard.clickThrough)
        XCTAssertTrue(ClickThrough.ignores(alpha: 0, enabled: true))
        XCTAssertFalse(ClickThrough.ignores(alpha: 255, enabled: true))
        XCTAssertFalse(ClickThrough.ignores(alpha: 1, enabled: true))
        XCTAssertFalse(ClickThrough.ignores(alpha: 0, enabled: false))
        XCTAssertEqual(ClickThrough.rasterY(viewY: 0, height: 380), 379)
        XCTAssertEqual(ClickThrough.rasterY(viewY: 379, height: 380), 0)
        XCTAssertEqual(ClickThrough.decision(pass: true), "pass")
        XCTAssertEqual(ClickThrough.decision(pass: false), "keep")
        XCTAssertEqual(AoriCopy.clickThrough, "Click Through")
    }

    func testCoreGraphicsClickPoint() {
        XCTAssertEqual(ClickThrough.coreGraphicsY(appKitY: 100, screenHeight: 900), 800)
        XCTAssertEqual(ClickThrough.coreGraphicsY(appKitY: 0, screenHeight: 900), 900)
        XCTAssertEqual(ClickThrough.coreGraphicsY(appKitY: 900, screenHeight: 900), 0)
    }

    func testLiveUtteranceMark() {
        XCTAssertEqual(LiveUtterance.mark(hasDevice: false, sampleCount: 0, speech: false), "no-device")
        XCTAssertEqual(LiveUtterance.mark(hasDevice: false, sampleCount: 10, speech: true), "no-device")
        XCTAssertEqual(LiveUtterance.mark(hasDevice: true, sampleCount: 0, speech: false), "silence")
        XCTAssertEqual(LiveUtterance.mark(hasDevice: true, sampleCount: 8, speech: false), "silence")
        XCTAssertEqual(LiveUtterance.mark(hasDevice: true, sampleCount: 8, speech: true), "speech")
    }
}

private func glb(json: String, chunkType: UInt32 = 0x4E4F_534A) -> Data {
    var jsonData = Data(json.utf8)
    while jsonData.count % 4 != 0 {
        jsonData.append(0x20)
    }
    var data = Data()
    appendUInt32(0x4654_6C67, to: &data)
    appendUInt32(2, to: &data)
    appendUInt32(UInt32(12 + 8 + jsonData.count), to: &data)
    appendUInt32(UInt32(jsonData.count), to: &data)
    appendUInt32(chunkType, to: &data)
    data.append(jsonData)
    return data
}

private func appendUInt32(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { bytes in
        data.append(contentsOf: bytes)
    }
}
