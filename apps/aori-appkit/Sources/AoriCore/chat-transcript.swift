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

    public init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
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
