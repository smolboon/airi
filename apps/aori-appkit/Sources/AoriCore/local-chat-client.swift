import Foundation

/// A reply built on the device. This is a template. It is not a neural model.
public enum LocalReply {
    public static func text(for userText: String) -> String {
        let lower = userText.lowercased()
        if lower.contains("hello") {
            return "Hello. I am here."
        }
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "I am here."
        }
        return "I heard you say \(trimmed)."
    }
}

public struct LocalChatClient: ChatCompletionClient {
    public init() {}

    public func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let user = messages.last { $0.role == .user }?.content ?? ""
        let reply = LocalReply.text(for: user)
        return AsyncThrowingStream { continuation in
            continuation.yield(.delta(reply))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
