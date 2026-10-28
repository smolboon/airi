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

    func testLoopbackEmptyKeyOmitsTheAuthorizationHeader() async throws {
        let transport = ScriptedTransport(
            status: 200,
            chunks: [Data("data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: [DONE]\n\n".utf8)]
        )
        let client = OpenAICompatibleClient(transport: transport)
        let stream = try await client.streamChat(
            messages: [ChatMessage(role: .user, content: "Hi")],
            configuration: ProviderConfiguration(
                baseURL: URL(string: "http://127.0.0.1:11434/v1/")!,
                model: "test-model",
                apiKey: "",
                keySource: .missing
            )
        )
        var text = ""
        for try await event in stream {
            if case .delta(let piece) = event {
                text += piece
            }
        }
        XCTAssertEqual(text, "OK")
        let request = try XCTUnwrap(transport.requests().first)
        XCTAssertEqual(request.url.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")
        XCTAssertNil(request.headers["Authorization"])
        XCTAssertFalse(String(data: request.body, encoding: .utf8)?.contains("Bearer") ?? true)
    }

    func testVisionRequestUsesTheSameProviderAndKeepsTheKeyOutOfTheBody() async throws {
        let transport = ScriptedTransport(
            status: 200,
            chunks: [Data("data: {\"choices\":[{\"delta\":{\"content\":\"Mock vision from CI.\"}}]}\n\ndata: [DONE]\n\n".utf8)]
        )
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMAAf4C/gAAAABJRU5ErkJggg==")!
        let client = OpenAICompatibleClient(transport: transport)
        let stream = try await client.streamVision(
            png: png,
            configuration: configuration(apiKey: "test-key")
        )
        var text = ""
        for try await event in stream {
            if case .delta(let piece) = event {
                text += piece
            }
        }
        XCTAssertEqual(text, "Mock vision from CI.")
        let request = try XCTUnwrap(transport.requests().first)
        XCTAssertEqual(request.url.absoluteString, "https://example.test/v1/chat/completions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-key")
        let body = String(data: request.body, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("\"type\":\"image_url\""))
        XCTAssertTrue(body.contains("data:image/png;base64,") || body.contains("data:image\\/png;base64,"))
        XCTAssertTrue(body.contains("You are an on-device vision assistant."))
        XCTAssertFalse(body.contains("test-key"))
    }

    func testEmbeddingEndpointAndLocalFallback() async throws {
        let vector = LocalEmbedding.embed("I like tea").values
        let payload = try JSONSerialization.data(withJSONObject: [
            "data": [["embedding": vector.map { Double($0) }]],
        ])
        let transport = ScriptedTransport(status: 200, chunks: [payload])
        let client = OpenAICompatibleEmbeddingClient(transport: transport)
        let settings = configuration(apiKey: "test-key")
        let decoded = try await client.embed(text: "I like tea", configuration: settings)
        XCTAssertEqual(decoded.values, vector)
        let request = try XCTUnwrap(transport.requests().first)
        XCTAssertEqual(request.url.absoluteString, "https://example.test/v1/embeddings")
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-key")
        let body = String(data: request.body, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("I like tea"))
        XCTAssertFalse(body.contains("test-key"))

        let failing = ScriptedTransport(status: 500, chunks: [Data("down".utf8)])
        let fallback = EmbeddingFallback(transport: failing)
        let outcome = await fallback.embed("I like tea", configuration: settings)
        XCTAssertNotEqual(outcome.vector.values, vector)
        #if canImport(CoreML)
        XCTAssertEqual(outcome.source, .coreml)
        #else
        XCTAssertEqual(outcome.source, .unavailable)
        #endif

        let blank = configuration(apiKey: "")
        let local = await EmbeddingFallback().embed("I like tea", configuration: blank)
        XCTAssertEqual(local.source, outcome.source)

        let wide = [Double](repeating: 0.01, count: EmbeddingVector.sentenceDimensions)
        let widePayload = try JSONSerialization.data(withJSONObject: [
            "data": [["embedding": wide]],
        ])
        let wideVector = try OpenAICompatibleEmbeddingClient.vector(from: widePayload)
        XCTAssertEqual(wideVector.values.count, EmbeddingVector.sentenceDimensions)
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
