import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequest: Equatable, Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data

    public init(url: URL, method: String, headers: [String: String], body: Data) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public enum HTTPEvent: Equatable, Sendable {
    case status(Int)
    case chunk(Data)
}

public protocol HTTPTransport: Sendable {
    func open(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPEvent, Error>
}

public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func open(_ request: HTTPRequest) -> AsyncThrowingStream<HTTPEvent, Error> {
        let session = self.session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = URLRequest(url: request.url)
                    urlRequest.httpMethod = request.method
                    urlRequest.httpBody = request.body
                    for (field, value) in request.headers {
                        urlRequest.setValue(value, forHTTPHeaderField: field)
                    }
                    #if os(macOS) || os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    continuation.yield(.status(status))
                    var buffer = Data()
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        buffer.append(byte)
                        if buffer.count >= 512 {
                            continuation.yield(.chunk(buffer))
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(.chunk(buffer))
                    }
                    continuation.finish()
                    #else
                    // NOTICE:
                    // Linux Swift 6.0 Foundation has no URLSession.bytes(for:).
                    // swift-corelibs-foundation returns the body only after it is complete.
                    // Source: swift-corelibs-foundation URLSession, Swift 6.0.3.
                    // Remove this branch when URLSession.bytes(for:) exists on Linux.
                    let (data, response) = try await session.data(for: urlRequest)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    continuation.yield(.status(status))
                    if !data.isEmpty {
                        continuation.yield(.chunk(data))
                    }
                    continuation.finish()
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
