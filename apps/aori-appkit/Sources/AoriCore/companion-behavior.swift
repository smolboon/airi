import Foundation

public struct LoreEntry: Codable, Equatable, Sendable {
    public var keywords: [String]
    public var content: String

    public init(keywords: [String], content: String) {
        self.keywords = keywords
        self.content = content
    }
}

public enum Lorebook {
    /// Reads `keyword, keyword | text` entries. Separate entries with `;;` or a new line.
    public static func parse(_ text: String) -> [LoreEntry] {
        let chunks = text
            .components(separatedBy: ";;")
            .flatMap { $0.split(whereSeparator: \.isNewline).map(String.init) }
        return normalized(chunks.compactMap(entry(from:)))
    }

    public static func text(for entries: [LoreEntry]) -> String {
        normalized(entries).map { entry in
            "\(entry.keywords.joined(separator: ", ")) | \(entry.content)"
        }.joined(separator: " ;; ")
    }

    public static func matches(_ entries: [LoreEntry], text: String) -> [LoreEntry] {
        let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return normalized(entries).filter { entry in
            entry.keywords.contains { words.contains($0.lowercased()) }
        }
    }

    public static func json(_ entries: [LoreEntry]) -> String {
        let payload: [[String: Any]] = normalized(entries).map { entry in
            ["keywords": entry.keywords, "content": entry.content]
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return text
    }

    public static func entries(fromJSON text: String) -> [LoreEntry] {
        guard let data = text.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        let entries = rows.compactMap { row -> LoreEntry? in
            let keywords = row["keywords"] as? [String] ?? []
            let content = row["content"] as? String ?? ""
            guard !keywords.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return LoreEntry(keywords: keywords, content: content)
        }
        return normalized(entries)
    }

    public static func normalized(_ entries: [LoreEntry]) -> [LoreEntry] {
        entries.compactMap { entry in
            var seen = Set<String>()
            var keywords: [String] = []
            for raw in entry.keywords {
                let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !keyword.isEmpty, seen.insert(keyword.lowercased()).inserted else {
                    continue
                }
                keywords.append(keyword)
            }
            let content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !keywords.isEmpty, !content.isEmpty else {
                return nil
            }
            return LoreEntry(keywords: keywords, content: content)
        }
    }

    private static func entry(from line: String) -> LoreEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bar = trimmed.firstIndex(of: "|") else {
            return nil
        }
        let keys = trimmed[..<bar].split(separator: ",").map(String.init)
        let content = trimmed[trimmed.index(after: bar)...]
        return LoreEntry(keywords: keys, content: String(content))
    }
}

public struct CompanionGame: Equatable, Sendable {
    public var id: String
    public var title: String

    public static let catalog = [
        CompanionGame(id: "factorio", title: "Factorio"),
        CompanionGame(id: "minecraft", title: "Minecraft"),
    ]
}

public enum GameScaffold {
    public static func report() -> String {
        "Games: Factorio and Minecraft. Factorio accepts a local hello. Minecraft accepts a local hello. A remote host is refused."
    }
}

public struct ChatProtocol: Equatable, Sendable {
    public var id: String
    public var title: String

    public static let catalog = [
        ChatProtocol(id: "discord", title: "Discord"),
        ChatProtocol(id: "telegram", title: "Telegram"),
        ChatProtocol(id: "satori", title: "Satori"),
        ChatProtocol(id: "x", title: "X"),
    ]
}

public enum ChatProtocolScaffold {
    public static let status = "not connected"
    public static let unavailableID = "x"

    /// Names the protocols. No token is included.
    public static func report() -> String {
        "Chat protocols: Discord is a message draft only. Telegram is a preview only. Satori is an event draft only. X is unavailable. Credential fields are dropped. No token is stored."
    }
}

public struct CompanionIntegration: Equatable, Sendable {
    public var id: String
    public var title: String

    public static let catalog = [
        CompanionIntegration(id: "vscode", title: "VS Code"),
        CompanionIntegration(id: "home-assistant", title: "Home Assistant"),
        CompanionIntegration(id: "web-search", title: "Web search"),
    ]
}

public enum IntegrationScaffold {
    /// Names the integrations. No token is included.
    public static func report() -> String {
        "Integrations: VS Code is a context draft only. Home Assistant is an entity draft only. Web search is unavailable. Credential fields are dropped. No token is stored."
    }
}

public enum CompanionModule: String, Codable, CaseIterable, Sendable {
    case chat
    case speech
    case vision
    case memory
    case plugins

    public static let defaultIDs = ["chat", "speech", "vision", "memory", "plugins"]

    /// Keeps known module ids. An empty list uses the default modules.
    public static func resolved(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in ids {
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let module = CompanionModule(rawValue: key), seen.insert(module.rawValue).inserted else {
                continue
            }
            result.append(module.rawValue)
        }
        return result.isEmpty ? defaultIDs : result
    }
}

public struct CompanionPersona: Codable, Equatable, Sendable {
    public var name: String
    public var nickname: String
    public var description: String
    public var personality: String
    public var scenario: String
    public var greeting: String
    public var alternateGreetings: [String]
    public var creatorNotes: String
    public var lore: String
    public var tags: [String]
    public var systemPrompt: String
    public var postHistoryInstructions: String
    public var cardVersion: String
    public var modules: [String]
    public var lorebook: [LoreEntry]

    public init(
        name: String,
        personality: String,
        scenario: String = "",
        greeting: String = "",
        creatorNotes: String = "",
        lore: String = "",
        tags: [String] = [],
        nickname: String = "",
        description: String = "",
        alternateGreetings: [String] = [],
        systemPrompt: String = "",
        postHistoryInstructions: String = "",
        cardVersion: String = "",
        modules: [String] = [],
        lorebook: [LoreEntry] = []
    ) {
        self.name = name
        self.nickname = nickname
        self.description = description
        self.personality = personality
        self.scenario = scenario
        self.greeting = greeting
        self.alternateGreetings = Self.normalizedGreetings(alternateGreetings)
        self.creatorNotes = creatorNotes
        self.lore = lore
        self.tags = Self.normalizedTags(tags)
        self.systemPrompt = systemPrompt
        self.postHistoryInstructions = postHistoryInstructions
        self.cardVersion = cardVersion
        self.modules = CompanionModule.resolved(modules)
        self.lorebook = Lorebook.normalized(lorebook)
    }

    /// Trims text fields. An empty name uses the fallback name.
    public func trimmed(fallbackName: String) -> CompanionPersona {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return CompanionPersona(
            name: trimmedName.isEmpty ? fallbackName : trimmedName,
            personality: personality.trimmingCharacters(in: .whitespacesAndNewlines),
            scenario: scenario.trimmingCharacters(in: .whitespacesAndNewlines),
            greeting: greeting.trimmingCharacters(in: .whitespacesAndNewlines),
            creatorNotes: creatorNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            lore: lore.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            alternateGreetings: alternateGreetings,
            systemPrompt: systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            postHistoryInstructions: postHistoryInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            cardVersion: cardVersion.trimmingCharacters(in: .whitespacesAndNewlines),
            modules: modules,
            lorebook: lorebook
        )
    }

    /// Splits a comma-separated tag field. Blank tags drop out. Repeated tags keep the first spelling.
    public static func tags(from text: String) -> [String] {
        normalizedTags(text.split(separator: ",").map(String.init))
    }

    public static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tags {
            let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else {
                continue
            }
            result.append(tag)
        }
        return result
    }

    public static func tagsJSON(_ tags: [String]) -> String {
        let values = normalizedTags(tags)
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let text = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return text
    }

    public static func tags(fromJSON text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return []
        }
        return normalizedTags(values)
    }

    public var tagsText: String {
        tags.joined(separator: ", ")
    }

    /// Splits greetings on "|" or a new line. Blank greetings drop out.
    public static func greetings(from text: String) -> [String] {
        let parts = text.split(whereSeparator: { $0 == "|" || $0.isNewline }).map(String.init)
        return normalizedGreetings(parts)
    }

    public static func normalizedGreetings(_ greetings: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in greetings {
            let greeting = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !greeting.isEmpty, seen.insert(greeting).inserted else {
                continue
            }
            result.append(greeting)
        }
        return result
    }

    public static func stringListJSON(_ values: [String]) -> String {
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values),
              let text = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return text
    }

    public static func stringList(fromJSON text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return []
        }
        return values
    }

    public var alternateGreetingsText: String {
        alternateGreetings.joined(separator: " | ")
    }

    public var modulesText: String {
        modules.joined(separator: ", ")
    }

    public var lorebookText: String {
        Lorebook.text(for: lorebook)
    }

    /// Splits a comma-separated module field. Unknown ids drop out. An empty field uses the default modules.
    public static func modules(from text: String) -> [String] {
        CompanionModule.resolved(text.split(separator: ",").map(String.init))
    }

    // NOTICE:
    // Older companion.json files omit the card fields added after name and personality.
    // The JSON import in SQLiteCompanionStore reads those files.
    // Source: companion.json next to companion.sqlite.
    // Remove this decoder when that JSON import is removed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        personality = try container.decode(String.self, forKey: .personality)
        scenario = try container.decodeIfPresent(String.self, forKey: .scenario) ?? ""
        greeting = try container.decodeIfPresent(String.self, forKey: .greeting) ?? ""
        creatorNotes = try container.decodeIfPresent(String.self, forKey: .creatorNotes) ?? ""
        lore = try container.decodeIfPresent(String.self, forKey: .lore) ?? ""
        tags = Self.normalizedTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        alternateGreetings = Self.normalizedGreetings(
            try container.decodeIfPresent([String].self, forKey: .alternateGreetings) ?? []
        )
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
        postHistoryInstructions = try container.decodeIfPresent(String.self, forKey: .postHistoryInstructions) ?? ""
        cardVersion = try container.decodeIfPresent(String.self, forKey: .cardVersion) ?? ""
        modules = CompanionModule.resolved(try container.decodeIfPresent([String].self, forKey: .modules) ?? [])
        lorebook = Lorebook.normalized(try container.decodeIfPresent([LoreEntry].self, forKey: .lorebook) ?? [])
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
    public static func system(persona: CompanionPersona, memory: UserMemory, context: String = "") -> String {
        var lines = [
            "You are \(persona.name), a desktop companion on macOS.",
        ]
        let systemPrompt = persona.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !systemPrompt.isEmpty {
            lines.append(systemPrompt)
        }
        let description = persona.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            lines.append("The description is \(description).")
        }
        lines.append(persona.personality)
        let scenario = persona.scenario.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scenario.isEmpty {
            lines.append("The scene is \(scenario).")
        }
        let lore = persona.lore.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lore.isEmpty {
            lines.append("The lore is \(lore).")
        }
        for entry in Lorebook.matches(persona.lorebook, text: context) {
            lines.append("The lorebook says \(entry.content).")
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

    public static func postHistory(persona: CompanionPersona) -> String {
        persona.postHistoryInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds the provider messages. Post-history instructions follow the chat history.
    public static func messages(
        persona: CompanionPersona,
        memory: UserMemory,
        history: [ChatMessage],
        recalled: String = ""
    ) -> [ChatMessage] {
        let context = history.last(where: { $0.role == .user })?.content ?? ""
        var systemPrompt = system(persona: persona, memory: memory, context: context)
        if !recalled.isEmpty {
            systemPrompt += "\n\(recalled)"
        }
        var items = [ChatMessage(role: .system, content: systemPrompt)]
        items.append(contentsOf: history)
        let post = postHistory(persona: persona)
        if !post.isEmpty {
            items.append(ChatMessage(role: .system, content: post))
        }
        return items
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
