import Foundation

public struct CompanionPersona: Codable, Equatable, Sendable {
    public var name: String
    public var personality: String
    public var scenario: String
    public var greeting: String

    public init(name: String, personality: String, scenario: String = "", greeting: String = "") {
        self.name = name
        self.personality = personality
        self.scenario = scenario
        self.greeting = greeting
    }

    // NOTICE:
    // Older companion.json files store only a name and a personality.
    // The JSON import in SQLiteCompanionStore reads those files.
    // Source: companion.json next to companion.sqlite.
    // Remove this decoder when that JSON import is removed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        personality = try container.decode(String.self, forKey: .personality)
        scenario = try container.decodeIfPresent(String.self, forKey: .scenario) ?? ""
        greeting = try container.decodeIfPresent(String.self, forKey: .greeting) ?? ""
    }

    public static let standard = CompanionPersona(
        name: "Aori",
        personality: "Stay warm, brief, and curious. You live on the desktop."
    )
}

public struct MemoryNote: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

public struct UserMemory: Codable, Equatable, Sendable {
    public var notes: [MemoryNote]

    public init(notes: [MemoryNote] = []) {
        self.notes = notes
    }

    public static let empty = UserMemory()

    /// Stores a new fact. Returns false when the text is blank or already stored.
    public mutating func remember(_ text: String, now: Date = Date(), limit: Int = 40) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        let key = trimmed.lowercased()
        if notes.contains(where: { $0.text.lowercased() == key }) {
            return false
        }
        notes.append(MemoryNote(text: trimmed, createdAt: now))
        if notes.count > limit {
            notes.removeFirst(notes.count - limit)
        }
        return true
    }
}

public struct CompanionProfile: Codable, Equatable, Sendable {
    public var persona: CompanionPersona
    public var memory: UserMemory

    public init(persona: CompanionPersona, memory: UserMemory) {
        self.persona = persona
        self.memory = memory
    }

    public static let standard = CompanionProfile(persona: .standard, memory: .empty)
}

public protocol CompanionProfileStore: Sendable {
    func load() throws -> CompanionProfile
    func save(_ profile: CompanionProfile) throws
}

public final class InMemoryCompanionProfileStore: CompanionProfileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var profile: CompanionProfile

    public init(profile: CompanionProfile = .standard) {
        self.profile = profile
    }

    public func load() throws -> CompanionProfile {
        lock.lock()
        defer { lock.unlock() }
        return profile
    }

    public func save(_ profile: CompanionProfile) throws {
        lock.lock()
        defer { lock.unlock() }
        self.profile = profile
    }
}

public struct FileCompanionProfileStore: CompanionProfileStore, Sendable {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> CompanionProfile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .standard
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CompanionProfile.self, from: data)
    }

    public func save(_ profile: CompanionProfile) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(profile)
        try data.write(to: fileURL, options: .atomic)
    }
}

public enum MemoryCapture {
    /// Reads a fact from "remember that ..." or "remember: ...".
    public static func note(from userText: String) -> String? {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let prefixes = ["remember that ", "remember: "]
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let note = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? nil : note
        }
        return nil
    }
}

public enum CompanionPrompt {
    public static func system(persona: CompanionPersona, memory: UserMemory) -> String {
        var lines = [
            "You are \(persona.name), a desktop companion on macOS.",
            persona.personality,
        ]
        let scenario = persona.scenario.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scenario.isEmpty {
            lines.append("The scene is \(scenario).")
        }
        lines.append("Reply in short spoken sentences. Do not use markdown.")
        lines.append("Name a feeling in the first sentence when you feel happy, sad, or surprised.")
        var text = lines.joined(separator: " ")
        if !memory.notes.isEmpty {
            let lines = memory.notes.map { "- \($0.text)" }.joined(separator: "\n")
            text += " You remember these facts about the user.\n\(lines)"
        }
        return text
    }
}

public enum CompanionGreeting {
    public static func opening(persona: CompanionPersona, memory: UserMemory) -> String {
        let greeting = persona.greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        if !greeting.isEmpty {
            return greeting
        }
        if let note = memory.notes.last?.text {
            return "Hello. I am \(persona.name). I still remember this. \(note)."
        }
        return "Hello. I am \(persona.name). I am here on your desktop."
    }
}

public enum CompanionEmotion: String, Codable, Equatable, Sendable {
    case neutral
    case happy
    case sad
    case surprised

    /// Maps a few words onto a face. This is not a model of feeling.
    public static func infer(from text: String) -> CompanionEmotion {
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        if words.contains("wow") || words.contains("whoa") || words.contains("surprised") {
            return .surprised
        }
        if words.contains("sad") || words.contains("sorry") || words.contains("lonely") {
            return .sad
        }
        if words.contains("happy") || words.contains("glad") || words.contains("love") {
            return .happy
        }
        return .neutral
    }
}
