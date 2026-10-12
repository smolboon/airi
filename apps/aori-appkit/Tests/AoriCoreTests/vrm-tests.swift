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
        XCTAssertEqual(scene.document.title, "Aori Sample")
        XCTAssertGreaterThan(scene.vertexCount, 20)
        XCTAssertFalse(scene.meshes[0].morphs.isEmpty)
        let happy = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: .happy,
            mouthOpen: 0.5,
            blink: 0
        )
        XCTAssertTrue(happy.contains(where: { $0.morph == 1 && $0.weight == 1 }))
        XCTAssertTrue(happy.contains(where: { $0.morph == 0 && abs($0.weight - 0.5) < 0.001 }))
        let vowelI = FaceDriver.morphWeights(
            blendShapes: scene.blendShapes,
            emotion: .neutral,
            mouthOpen: 0.5,
            blink: 0,
            viseme: "i"
        )
        XCTAssertFalse(vowelI.contains(where: { $0.morph == 0 }))
        XCTAssertTrue(vowelI.contains(where: { $0.morph == 5 && abs($0.weight - 0.5) < 0.001 }))
        let presentation = CharacterPresentation.placeholder.applying(scene)
        XCTAssertFalse(presentation.usesPlaceholderMesh)
        XCTAssertEqual(SpeechLevel.mouthOpen(samples: [Float](repeating: 0, count: 8)), 0)
        XCTAssertGreaterThan(SpeechLevel.mouthOpen(samples: [Float](repeating: 0.25, count: 8)), 0.5)
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.contains("inverseBindMatrices"))
        XCTAssertTrue(text.contains("baseColorTexture"))
        XCTAssertTrue(text.contains("JOINTS_0"))
        XCTAssertTrue(text.contains("\"name\":\"idle\""))
        XCTAssertTrue(text.contains("\"name\":\"blink\""))
        XCTAssertTrue(text.contains("\"bone\":\"hips\""))
        XCTAssertTrue(text.contains("\"bone\":\"head\""))
        XCTAssertTrue(text.contains("\"bone\":\"leftEye\""))
        XCTAssertTrue(text.contains("\"bone\":\"rightEye\""))
        XCTAssertTrue(text.contains("5121"))
        let bones = try VRMHumanoidReader.bones(in: bytes)
        XCTAssertEqual(
            bones.map(\.name),
            ["hips", "spine", "neck", "head", "leftEye", "rightEye", "leftShoulder", "leftUpperArm", "leftLowerArm", "rightShoulder", "rightUpperArm", "rightLowerArm"]
        )
        XCTAssertEqual(
            PhonemeTimeline.symbols(in: "Hello papa"),
            ["HH", "EH", "L", "OW", "P", "AA", "P", "AH"]
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

    func testStandardCompanionStyle() {
        let style = CompanionWindowPolicy.standard.style()
        XCTAssertTrue(style.floating)
        XCTAssertTrue(style.transparent)
        XCTAssertTrue(style.borderless)
        XCTAssertTrue(style.joinsAllSpaces)
        XCTAssertTrue(style.movableByBackground)
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
