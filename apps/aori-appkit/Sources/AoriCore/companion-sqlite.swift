import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

public enum CompanionStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    case openFailed(String)
    case queryFailed(String)
    case closed

    public var description: String {
        switch self {
        case .openFailed(let message):
            return "The companion database did not open. \(message)"
        case .queryFailed(let message):
            return "The companion database query failed. \(message)"
        case .closed:
            return "The companion database is closed."
        }
    }
}

/// Chat, provider settings, the persona, and the locale id in one SQLite file.
public final class SQLiteCompanionStore: CompanionProfileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var database: OpaquePointer?
    public private(set) var migrated: [String] = []

    public init(fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try open(path: fileURL.path)
        migrated = importJSON(in: directory)
    }

    public static func open(fileURL: URL) -> SQLiteCompanionStore {
        if let store = try? SQLiteCompanionStore(fileURL: fileURL) {
            return store
        }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-companion-\(UUID().uuidString).sqlite")
        if let store = try? SQLiteCompanionStore(fileURL: fallback) {
            return store
        }
        return SQLiteCompanionStore(closed: true)
    }

    private init(closed: Bool) {
        _ = closed
        database = nil
    }

    deinit {
        sqlite3_close(database)
    }

    public func load() throws -> CompanionProfile {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        let persona = try readPersona()
        let notes = try readNotes()
        return CompanionProfile(persona: persona ?? .standard, memory: UserMemory(notes: notes))
    }

    public func save(_ profile: CompanionProfile) throws {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        try write(profile)
    }

    public func loadMessages() throws -> [ChatMessage] {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        return try readMessages()
    }

    public func saveMessages(_ messages: [ChatMessage]) throws {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        try write(messages)
    }

    public func loadSettings() throws -> ProviderSettings? {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        return try readSettings()
    }

    public func saveSettings(_ settings: ProviderSettings) throws {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        try write(settings)
    }

    public func loadLocale() throws -> String {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        return try readLocale() ?? "en"
    }

    public func saveLocale(id: String) throws {
        try requireOpen()
        lock.lock()
        defer { lock.unlock() }
        try writeLocale(id)
    }

    private func open(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let opened = sqlite3_open_v2(path, &handle, flags, nil)
        guard opened == SQLITE_OK, let handle else {
            let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(handle)
            throw CompanionStoreError.openFailed(message)
        }
        database = handle
        try execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                base_url TEXT NOT NULL,
                model TEXT NOT NULL,
                provider TEXT NOT NULL DEFAULT 'openai',
                voice TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS persona (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                name TEXT NOT NULL,
                personality TEXT NOT NULL,
                scenario TEXT NOT NULL DEFAULT '',
                greeting TEXT NOT NULL DEFAULT '',
                creator_notes TEXT NOT NULL DEFAULT '',
                lore TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '[]'
            );
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY NOT NULL,
                text TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS locale (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                locale TEXT NOT NULL
            );
            """
        )
        try? execute("ALTER TABLE settings ADD COLUMN provider TEXT NOT NULL DEFAULT 'openai'")
        try? execute("ALTER TABLE settings ADD COLUMN voice TEXT NOT NULL DEFAULT ''")
        try? execute("ALTER TABLE persona ADD COLUMN scenario TEXT NOT NULL DEFAULT ''")
        try? execute("ALTER TABLE persona ADD COLUMN greeting TEXT NOT NULL DEFAULT ''")
        try? execute("ALTER TABLE persona ADD COLUMN creator_notes TEXT NOT NULL DEFAULT ''")
        try? execute("ALTER TABLE persona ADD COLUMN lore TEXT NOT NULL DEFAULT ''")
        try? execute("ALTER TABLE persona ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'")
    }

    // NOTICE:
    // The first open copies JSON into SQLite when the tables are empty.
    // Older builds wrote companion.json, chat.json, settings.json, and locale.json.
    // Those files live next to companion.sqlite.
    // Remove this import when those files are gone from Application Support.
    private func importJSON(in directory: URL) -> [String] {
        var names: [String] = []
        let profileURL = directory.appendingPathComponent("companion.json")
        if FileManager.default.fileExists(atPath: profileURL.path), (try? readPersona()) == nil {
            if let profile = try? FileCompanionProfileStore(fileURL: profileURL).load() {
                try? write(profile)
                try? FileManager.default.removeItem(at: profileURL)
                names.append("persona")
            }
        }
        let chatURL = directory.appendingPathComponent("chat.json")
        if FileManager.default.fileExists(atPath: chatURL.path), (try? readMessages().isEmpty) == true {
            if let messages = try? FileChatTranscriptStore(fileURL: chatURL).load() {
                if !messages.isEmpty {
                    try? write(messages)
                }
                try? FileManager.default.removeItem(at: chatURL)
                names.append("chat")
            }
        }
        let settingsURL = directory.appendingPathComponent("settings.json")
        if FileManager.default.fileExists(atPath: settingsURL.path), (try? readSettings()) == nil {
            if let settings = try? FileProviderSettingsStore(fileURL: settingsURL).load() {
                try? write(settings)
                try? FileManager.default.removeItem(at: settingsURL)
                names.append("settings")
            }
        }
        let localeURL = directory.appendingPathComponent("locale.json")
        if FileManager.default.fileExists(atPath: localeURL.path), (try? readLocale()) == nil {
            if let id = try? FileLocalePreferenceStore(fileURL: localeURL).load() {
                try? writeLocale(id)
                try? FileManager.default.removeItem(at: localeURL)
                names.append("locale")
            }
        }
        return names
    }

    private func requireOpen() throws {
        if database == nil {
            throw CompanionStoreError.closed
        }
    }

    private func readPersona() throws -> CompanionPersona? {
        let sql = "SELECT name, personality, scenario, greeting, creator_notes, lore, tags FROM persona WHERE id = 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return CompanionPersona(
            name: columnText(statement, 0),
            personality: columnText(statement, 1),
            scenario: columnText(statement, 2),
            greeting: columnText(statement, 3),
            creatorNotes: columnText(statement, 4),
            lore: columnText(statement, 5),
            tags: CompanionPersona.tags(fromJSON: columnText(statement, 6))
        )
    }

    private func readNotes() throws -> [MemoryNote] {
        let sql = "SELECT id, text, created_at FROM notes ORDER BY created_at ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        var notes: [MemoryNote] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: columnText(statement, 0)) else {
                continue
            }
            notes.append(
                MemoryNote(
                    id: id,
                    text: columnText(statement, 1),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                )
            )
        }
        return notes
    }

    private func readMessages() throws -> [ChatMessage] {
        let sql = "SELECT id, role, content, created_at FROM messages ORDER BY created_at ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        var messages: [ChatMessage] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: columnText(statement, 0)),
                  let role = ChatRole(rawValue: columnText(statement, 1))
            else {
                continue
            }
            messages.append(
                ChatMessage(
                    id: id,
                    role: role,
                    content: columnText(statement, 2),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                )
            )
        }
        return messages
    }

    private func readSettings() throws -> ProviderSettings? {
        let sql = "SELECT base_url, model, provider, voice FROM settings WHERE id = 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return ProviderSettings(
            baseURL: columnText(statement, 0),
            model: columnText(statement, 1),
            provider: columnText(statement, 2),
            voice: columnText(statement, 3)
        )
    }

    private func write(_ profile: CompanionProfile) throws {
        try execute("BEGIN")
        do {
            try execute("DELETE FROM persona")
            try execute("DELETE FROM notes")
            try insertPersona(profile.persona)
            for note in profile.memory.notes {
                try insert(note)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func write(_ messages: [ChatMessage]) throws {
        try execute("BEGIN")
        do {
            try execute("DELETE FROM messages")
            for message in messages {
                try insert(message)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func readLocale() throws -> String? {
        let sql = "SELECT locale FROM locale WHERE id = 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        let id = columnText(statement, 0)
        return id.isEmpty ? nil : id
    }

    private func writeLocale(_ id: String) throws {
        let sql = "INSERT INTO locale (id, locale) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET locale = excluded.locale"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(id, at: 1, statement: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
    }

    private func write(_ settings: ProviderSettings) throws {
        let sql = "INSERT INTO settings (id, base_url, model, provider, voice) VALUES (1, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET base_url = excluded.base_url, model = excluded.model, provider = excluded.provider, voice = excluded.voice"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(settings.baseURL, at: 1, statement: statement)
        bind(settings.model, at: 2, statement: statement)
        bind(settings.provider, at: 3, statement: statement)
        bind(settings.voice, at: 4, statement: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
    }

    private func insertPersona(_ persona: CompanionPersona) throws {
        let sql = "INSERT INTO persona (id, name, personality, scenario, greeting, creator_notes, lore, tags) VALUES (1, ?, ?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(persona.name, at: 1, statement: statement)
        bind(persona.personality, at: 2, statement: statement)
        bind(persona.scenario, at: 3, statement: statement)
        bind(persona.greeting, at: 4, statement: statement)
        bind(persona.creatorNotes, at: 5, statement: statement)
        bind(persona.lore, at: 6, statement: statement)
        bind(CompanionPersona.tagsJSON(persona.tags), at: 7, statement: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
    }

    private func insert(_ note: MemoryNote) throws {
        let sql = "INSERT INTO notes (id, text, created_at) VALUES (?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(note.id.uuidString, at: 1, statement: statement)
        bind(note.text, at: 2, statement: statement)
        sqlite3_bind_double(statement, 3, note.createdAt.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
    }

    private func insert(_ message: ChatMessage) throws {
        let sql = "INSERT INTO messages (id, role, content, created_at) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(statement) }
        bind(message.id.uuidString, at: 1, statement: statement)
        bind(message.role.rawValue, at: 2, statement: statement)
        bind(message.content, at: 3, statement: statement)
        sqlite3_bind_double(statement, 4, message.createdAt.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CompanionStoreError.queryFailed(errorMessage())
        }
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(database, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "query failed"
            sqlite3_free(error)
            throw CompanionStoreError.queryFailed(message)
        }
    }

    private func bind(_ text: String, at index: Int32, statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, text, -1, Self.transient)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    private func errorMessage() -> String {
        guard let database else {
            return "closed"
        }
        return String(cString: sqlite3_errmsg(database))
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
