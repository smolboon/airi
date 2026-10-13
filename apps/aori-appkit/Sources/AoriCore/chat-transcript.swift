import Foundation

public struct FileChatTranscriptStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ChatMessage].self, from: data)
    }

    public func save(_ messages: [ChatMessage]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(messages)
        try data.write(to: fileURL, options: .atomic)
    }
}

public struct ProviderSettings: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var provider: String
    public var voice: String

    public init(baseURL: String, model: String, provider: String = "openai", voice: String = "") {
        self.baseURL = baseURL
        self.model = model
        self.provider = provider
        self.voice = voice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "openai"
        voice = try container.decodeIfPresent(String.self, forKey: .voice) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case model
        case provider
        case voice
    }
}

public struct FileProviderSettingsStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> ProviderSettings? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ProviderSettings.self, from: data)
    }

    public func save(_ settings: ProviderSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
