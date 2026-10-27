import XCTest
@testable import AoriCore

final class VisionFrameTests: XCTestCase {
    func testPlanKeepsADeniedCaptureOffTheScreenPath() {
        let png = VisionFixture.png
        let denied = VisionCapturePlan.select(permission: .denied, screenPNG: png, fixturePNG: png)
        XCTAssertEqual(denied.source, .fixture)
        XCTAssertEqual(denied.png, png)

        let granted = VisionCapturePlan.select(permission: .granted, screenPNG: png, fixturePNG: Data("no".utf8))
        XCTAssertEqual(granted.source, .screen)
        XCTAssertEqual(granted.png, png)

        let unavailable = VisionCapturePlan.select(permission: .unavailable, screenPNG: png, fixturePNG: nil)
        XCTAssertEqual(unavailable.source, .none)
        XCTAssertNil(unavailable.png)

        let broken = VisionCapturePlan.select(permission: .granted, screenPNG: Data("no".utf8), fixturePNG: png)
        XCTAssertEqual(broken.source, .fixture)
    }

    func testRequestCarriesThePromptAndThePNG() throws {
        let data = try VisionRequest.encode(model: "mock", png: VisionFixture.png)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(root?["model"] as? String, "mock")
        XCTAssertEqual(root?["stream"] as? Bool, true)
        let messages = root?["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, VisionRequest.prompt)
        XCTAssertTrue(VisionRequest.prompt.contains("You are an on-device vision assistant."))
        let image = content?.last?["image_url"] as? [String: Any]
        let url = image?["url"] as? String ?? ""
        XCTAssertTrue(url.hasPrefix("data:image/png;base64,"))
        let encoded = String(url.dropFirst("data:image/png;base64,".count))
        XCTAssertEqual(Data(base64Encoded: encoded), VisionFixture.png)
        XCTAssertThrowsError(try VisionRequest.encode(model: "mock", png: Data("no".utf8))) { error in
            XCTAssertEqual(error as? ChatProviderError, .invalidVisionFrame)
        }
    }

    func testLocalVisionDoesNotInventADescription() async throws {
        let client = LocalVisionClient()
        let configuration = ProviderConfiguration(
            baseURL: URL(string: "https://example.test/v1")!,
            model: "local",
            apiKey: "",
            keySource: .missing
        )
        let stream = try await client.streamVision(png: VisionFixture.png, configuration: configuration)
        var text = ""
        for try await event in stream {
            if case .delta(let piece) = event {
                text += piece
            }
        }
        XCTAssertEqual(text, "I can see a frame. This reply is a template.")
        do {
            _ = try await client.streamVision(png: Data("no".utf8), configuration: configuration)
            XCTFail("A non-PNG frame must fail.")
        } catch {
            XCTAssertEqual(error as? ChatProviderError, .invalidVisionFrame)
        }
    }
}

enum VisionFixture {
    static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMAAf4C/gAAAABJRU5ErkJggg==")!
}
