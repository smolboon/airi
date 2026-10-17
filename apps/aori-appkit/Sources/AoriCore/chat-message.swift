import Foundation

public enum ChatRole: String, Codable, Sendable, Equatable {
    case system
    case user
    case assistant
}

public struct ChatMessage: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var role: ChatRole
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public enum ChatPrompt {
    /// Short spoken replies. The AppKit chat view speaks this text aloud.
    public static var companion: String {
        CompanionPrompt.system(persona: .standard, memory: .empty)
    }
}
