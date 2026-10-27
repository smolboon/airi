import Foundation

public enum ChatChannelKind: String, Equatable, Sendable {
    case openai
    case telegram
}

public enum ChatChannelFlag {
    /// `telegram` selects the extra channel. Every other value stays on the provider.
    public static func kind(raw: String?) -> ChatChannelKind {
        if raw == "telegram" {
            return .telegram
        }
        return .openai
    }
}

public struct TelegramSend: Equatable, Sendable {
    public var path: String
    public var body: Data

    public init(path: String, body: Data) {
        self.path = path
        self.body = body
    }

    /// Builds a Telegram `sendMessage` body. Empty fields produce no request.
    public static func make(token: String, chatID: String, text: String) -> TelegramSend? {
        guard !token.isEmpty, !chatID.isEmpty, !text.isEmpty else {
            return nil
        }
        let object = ["chat_id": chatID, "text": text]
        guard let body = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }
        return TelegramSend(path: "bot\(token)/sendMessage", body: body)
    }
}
