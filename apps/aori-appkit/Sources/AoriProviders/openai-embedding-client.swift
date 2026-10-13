import AoriCore
import Foundation

public struct OpenAICompatibleEmbeddingClient: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func embed(text: String, configuration: ProviderConfiguration) async throws -> EmbeddingVector {
        guard !configuration.apiKey.isEmpty else {
            throw ChatProviderError.missingAPIKey
        }
        let body = try JSONSerialization.data(withJSONObject: [
            "model": configuration.model,
            "input": text,
        ])
        let request = HTTPRequest(
            url: configuration.embeddingsURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/json",
                "Authorization": "Bearer \(configuration.apiKey)",
            ],
            body: body
        )
        var status: Int?
        var payload = Data()
        for try await event in transport.open(request) {
            switch event {
            case .status(let code):
                status = code
            case .chunk(let chunk):
                payload.append(chunk)
            }
        }
        if let status, status >= 400 {
            throw ChatProviderError.httpStatus(status, "")
        }
        return try Self.vector(from: payload)
    }

    static func vector(from payload: Data) throws -> EmbeddingVector {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: payload)
        } catch {
            throw ChatProviderError.malformedResponse("The embeddings body is not JSON.")
        }
        guard let object = root as? [String: Any],
              let rows = object["data"] as? [Any],
              let first = rows.first as? [String: Any],
              let raw = first["embedding"] as? [Any]
        else {
            throw ChatProviderError.malformedResponse("The embeddings body has no vector.")
        }
        let values = raw.compactMap { item -> Float? in
            (item as? NSNumber)?.floatValue
        }
        guard values.count == EmbeddingVector.dimensions else {
            throw ChatProviderError.malformedResponse("The embeddings vector has the wrong length.")
        }
        return EmbeddingVector(values: values)
    }
}

public struct EmbeddingFallback: TextEmbedding {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func embed(_ text: String, configuration: ProviderConfiguration) async -> EmbeddingOutcome {
        if configuration.apiKey.isEmpty || configuration.model == "local" {
            return EmbeddingOutcome(vector: LocalEmbedding.embed(text), source: .local)
        }
        do {
            let vector = try await OpenAICompatibleEmbeddingClient(transport: transport).embed(
                text: text,
                configuration: configuration
            )
            return EmbeddingOutcome(vector: vector, source: .endpoint)
        } catch {
            return EmbeddingOutcome(vector: LocalEmbedding.embed(text), source: .local)
        }
    }
}
