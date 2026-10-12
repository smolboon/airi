import XCTest
@testable import AoriCore

final class OnDeviceTests: XCTestCase {
    func testWhisperParserKeepsTheSpokenLine() {
        let stamped = WhisperTranscript.parse("[00:00:00.000 --> 00:00:01.280]   Hello papa.\nwhisper_print_timings: load=1\n")
        XCTAssertEqual(stamped, "Hello papa.")
        let plain = WhisperTranscript.parse("\n Hello Paca\n")
        XCTAssertEqual(plain, "Hello Paca")
        XCTAssertEqual(WhisperTranscript.parse("ggml_init: ok\n"), "")
    }

    func testWhisperCommandNamesTheModelAndTheWav() {
        let arguments = OnDeviceRecognizer.arguments(model: "ggml-tiny.en.bin", wavPath: "speech.wav")
        XCTAssertEqual(arguments, ["-m", "ggml-tiny.en.bin", "-f", "speech.wav", "-l", "en", "-nt", "-np"])
        XCTAssertNil(OnDeviceRecognizer.fromEnvironment([:]))
    }

    func testLocalReplyUsesTheHeardLine() async throws {
        XCTAssertEqual(LocalReply.text(for: "Hello papa"), "Hello. I am here.")
        XCTAssertEqual(LocalReply.text(for: "where is the tea"), "I heard you say where is the tea.")
        let client = LocalChatClient()
        let configuration = ProviderConfiguration(
            baseURL: URL(string: "https://example.test/v1")!,
            model: "local",
            apiKey: "",
            keySource: CredentialSource.missing
        )
        let stream = try await client.streamChat(
            messages: [ChatMessage(role: .user, content: "Hello papa")],
            configuration: configuration
        )
        var text = ""
        for try await event in stream {
            if case .delta(let piece) = event {
                text += piece
            }
        }
        XCTAssertEqual(text, "Hello. I am here.")
    }

    func testAccessibilityProofListsTheLiveLabels() {
        XCTAssertTrue(AccessibilityCopy.proof.contains("Chat transcript"))
        XCTAssertTrue(AccessibilityCopy.proof.contains("Search chat"))
        XCTAssertTrue(AccessibilityCopy.proof.contains("Companion character"))
        XCTAssertTrue(AccessibilityCopy.proof.contains("Companion window"))
        XCTAssertTrue(AccessibilityCopy.proof.contains("Chat window"))
    }
}
