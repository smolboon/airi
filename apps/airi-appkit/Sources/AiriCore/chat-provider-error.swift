import Foundation

public enum ChatProviderError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingAPIKey
    case invalidBaseURL(String)
    case httpStatus(Int, String)
    case providerMessage(String)
    case malformedResponse(String)

    public var description: String {
        switch self {
        case .missingAPIKey:
            return "No API key is set. Add one in Settings, or set AIRI_OPENAI_API_KEY."
        case .invalidBaseURL(let value):
            return "The base URL is not valid: \(value)"
        case .httpStatus(let status, let body):
            return "The provider returned HTTP \(status). \(body)"
        case .providerMessage(let message):
            return message
        case .malformedResponse(let detail):
            return "The provider response is not valid. \(detail)"
        }
    }
}

public enum SecretRedaction {
    public static func redact(_ text: String, secret: String) -> String {
        guard !secret.isEmpty else {
            return text
        }
        return text.replacingOccurrences(of: secret, with: "[redacted]")
    }

    public static func clip(_ text: String, limit: Int = 400) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return String(trimmed.prefix(limit))
    }
}
