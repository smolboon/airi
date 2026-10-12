import AoriCore
import XCTest
@testable import AoriProviders

final class OpenAICompatibleClientTests: XCTestCase {
    func testStreamsDeltasFromSplitSSE() async throws {
        let sse = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}\n\n\
        data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n\
        data: {"choices":[{"delta":{"content":"lo"}}]}\n\n\
        data: [DONE]\n\n
        """
        let payload = Data(sse.utf8)
        var chunks: [Data] = []
        var index = payload.startIndex
        while index < payload.endIndex {
            let next = payload.index(index, offsetBy: 5, limitedBy: payload.endIndex) ?? payload.endIndex
            chunks.append(payload.subdata(in: index..<next))
            index = next
        }
        let transport = ScriptedTransport(status: 200, chunks: chunks)
        let client = OpenAICompatibleClient(transport: transport)
        let stream = try await client.streamChat(
            messages: [ChatMessage(role: .user, content: "Hi")],
            configuration: configuration(apiKey: "test-key")
        )
        var text = ""
        var finished = false
        for try await event in stream {
            switch event {
            case .delta(let piece):
                text += piece
            case .finished:
                finished = true
            }
        }
        XCTAssertEqual(text, "Hello")
        XCTAssertTrue(finished)

        let request = try XCTUnwrap(transport.requests().first)
        XCTAssertEqual(request.url.absoluteString, "https://example.test/v1/chat/completions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-key")
        XCTAssertEqual(request.method, "POST")
        let body = try JSONDecoder().decode(RequestBody.self, from: request.body)
        XCTAssertEqual(body.model, "test-model")
        XCTAssertTrue(body.stream)
        XCTAssertEqual(body.messages.map(\.content), ["Hi"])
    }

    func testHTTPErrorRedactsTheKey() async throws {
        let transport = ScriptedTransport(status: 401, chunks: [Data("bad test-key".utf8)])
        let client = OpenAICompatibleClient(transport: transport)
        let stream = try await client.streamChat(
            messages: [ChatMessage(role: .user, content: "Hi")],
            configuration: configuration(apiKey: "test-key")
        )
        do {
            for try await _ in stream {}
            XCTFail("The stream must fail.")
        } catch {
            let text = String(describing: error)
            XCTAssertTrue(text.contains("401"))
            XCTAssertTrue(text.contains("[redacted]"))
            XCTAssertFalse(text.contains("test-key"))
        }
    }

    func testProviderErrorAndMissingKey() async throws {
        let transport = ScriptedTransport(
            status: 200,
            chunks: [Data("data: {\"error\":{\"message\":\"model missing\"}}\n\n".utf8)]
        )
        let client = OpenAICompatibleClient(transport: transport)
        let stream = try await client.streamChat(
            messages: [ChatMessage(role: .user, content: "Hi")],
            configuration: configuration(apiKey: "test-key")
        )
        do {
            for try await _ in stream {}
            XCTFail("The stream must fail.")
        } catch {
            XCTAssertEqual(String(describing: error), "model missing")
        }

        let missing = OpenAICompatibleClient(transport: transport)
        do {
            _ = try await missing.streamChat(
                messages: [],
                configuration: configuration(apiKey: " ")
            )
            XCTFail("A blank key must fail before the network call.")
        } catch {
            XCTAssertEqual(error as? ChatProviderError, .missingAPIKey)
        }
        XCTAssertEqual(transport.requests().count, 1)
    }

    func testTransportCanBeConstructedWithoutARequest() {
        _ = URLSessionHTTPTransport()
    }
}

private struct RequestBody: Decodable {
    struct Message: Decodable {
        var role: String
        var content: String
    }

    var model: String
    var messages: [Message]
    var stream: Bool
}

private func configuration(apiKey: String) -> ProviderConfiguration {
    ProviderConfiguration(
        baseURL: URL(string: "https://example.test/v1")!,
        model: "test-model",
        apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
        keySource: .explicit
    )
}

private final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var captured: [HTTPRequest] = []
    private let status: Int
    private let chunks: [Data]

    init(status: Int, chunks: [Data]) {
        self.status = status
        self.chunks = chunks
    }

    func open(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPEvent, Error> {
        lock.lock()
        captured.append(request)
        lock.unlock()
        let status = status
        let chunks = chunks
        return AsyncThrowingStream { continuation in
            continuation.yield(.status(status))
            for chunk in chunks {
                continuation.yield(.chunk(chunk))
            }
            continuation.finish()
        }
    }

    func requests() -> [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }
}
