import Foundation

public enum AiriSecrets {
    public static let keychainService = "ai.moeru.airi.appkit"
    public static let openAIAPIKeyAccount = "openai-compatible-api-key"
}

public enum AiriPreferences {
    public static let baseURLKey = "ai.moeru.airi.appkit.baseURL"
    public static let modelKey = "ai.moeru.airi.appkit.model"
}

public protocol SecretStore: Sendable {
    func read(account: String) throws -> String?
    func write(account: String, secret: String) throws
    func delete(account: String) throws
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    public init() {}

    public func read(account: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[account]
    }

    public func write(account: String, secret: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[account] = secret
    }

    public func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[account] = nil
    }
}
