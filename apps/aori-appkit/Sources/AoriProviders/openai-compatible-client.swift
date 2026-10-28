import AoriCore
import Foundation

public struct OpenAICompatibleClient: ChatCompletionClient, VisionCompletionClient {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        if configuration.apiKey.isEmpty, !LocalLoopback.allows(configuration.baseURL) {
            throw ChatProviderError.missingAPIKey
        }
        let request = try makeRequest(messages: messages, configuration: configuration)
        return stream(request, apiKey: configuration.apiKey)
    }

    public func streamVision(
        png: Data,
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        guard !configuration.apiKey.isEmpty else {
            throw ChatProviderError.missingAPIKey
        }
        let data = try VisionRequest.encode(model: configuration.model, png: png)
        let request = HTTPRequest(
            url: configuration.chatCompletionsURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
                "Authorization": "Bearer \(configuration.apiKey)",
            ],
            body: data
        )
        return stream(request, apiKey: configuration.apiKey)
    }

    private func stream(
        _ request: HTTPRequest,
        apiKey: String
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let events = transport.open(request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var decoder = SSEDecoder()
                var utf8 = UTF8StreamDecoder()
                var status: Int?
                var errorBody = Data()
                var prelude = Data()
                var finished = false
                do {
                    for try await event in events {
                        try Task.checkCancellation()
                        switch event {
                        case .status(let code):
                            status = code
                            if code < 400, !prelude.isEmpty {
                                finished = try Self.consume(
                                    utf8.feed(prelude),
                                    decoder: &decoder,
                                    continuation: continuation
                                )
                                prelude.removeAll(keepingCapacity: false)
                            }
                        case .chunk(let data):
                            guard let status else {
                                prelude.append(data)
                                continue
                            }
                            if status >= 400 {
                                errorBody.append(data)
                                continue
                            }
                            if finished {
                                continue
                            }
                            finished = try Self.consume(
                                utf8.feed(data),
                                decoder: &decoder,
                                continuation: continuation
                            )
                        }
                        if finished {
                            break
                        }
                    }
                    if let status, status >= 400 {
                        let raw = String(data: errorBody, encoding: .utf8) ?? ""
                        let body = SecretRedaction.clip(SecretRedaction.redact(raw, secret: apiKey))
                        throw ChatProviderError.httpStatus(status, body)
                    }
                    if !finished {
                        finished = try Self.consume(
                            utf8.finish(),
                            decoder: &decoder,
                            continuation: continuation
                        )
                        if !finished {
                            for event in decoder.finish() {
                                if try Self.consumeEvent(event, continuation: continuation) {
                                    finished = true
                                    break
                                }
                            }
                        }
                    }
                    if !finished {
                        continuation.yield(.finished)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func makeRequest(messages: [ChatMessage], configuration: ProviderConfiguration) throws -> HTTPRequest {
        let body = ChatCompletionBody(
            model: configuration.model,
            messages: messages.map { message in
                ChatCompletionBody.Message(role: message.role.rawValue, content: message.content)
            },
            stream: true
        )
        let data = try JSONEncoder().encode(body)
        var headers = [
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        ]
        if !configuration.apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(configuration.apiKey)"
        }
        return HTTPRequest(
            url: configuration.chatCompletionsURL,
            method: "POST",
            headers: headers,
            body: data
        )
    }

    private static func consume(
        _ text: String,
        decoder: inout SSEDecoder,
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) throws -> Bool {
        guard !text.isEmpty else {
            return false
        }
        for event in decoder.feed(text) {
            if try consumeEvent(event, continuation: continuation) {
                return true
            }
        }
        return false
    }

    private static func consumeEvent(
        _ event: SSEEvent,
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) throws -> Bool {
        if event.data == "[DONE]" {
            continuation.yield(.finished)
            return true
        }
        switch try parseChunk(event.data) {
        case .delta(let text):
            continuation.yield(.delta(text))
            return false
        case .empty:
            return false
        }
    }

    private enum ParsedChunk {
        case delta(String)
        case empty
    }

    private static func parseChunk(_ data: String) throws -> ParsedChunk {
        guard let raw = data.data(using: .utf8) else {
            throw ChatProviderError.malformedResponse("The event is not UTF-8.")
        }
        let chunk: CompletionChunk
        do {
            chunk = try JSONDecoder().decode(CompletionChunk.self, from: raw)
        } catch {
            throw ChatProviderError.malformedResponse("The event is not JSON.")
        }
        if let message = chunk.error?.message, !message.isEmpty {
            throw ChatProviderError.providerMessage(message)
        }
        let content = chunk.choices?.compactMap { $0.delta?.content }.joined() ?? ""
        if content.isEmpty {
            return .empty
        }
        return .delta(content)
    }
}

private struct ChatCompletionBody: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    var model: String
    var messages: [Message]
    var stream: Bool
}

private struct CompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            var content: String?
        }

        var delta: Delta?
    }

    struct APIErrorBody: Decodable {
        var message: String?
    }

    var choices: [Choice]?
    var error: APIErrorBody?
}
