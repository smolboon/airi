import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

public struct EmbeddingMemoryRecord: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var vector: [Float]

    public init(id: UUID, text: String, createdAt: Date, vector: [Float]) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.vector = vector
    }
}

public struct ScoredMemory: Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var score: Float

    public init(id: UUID, text: String, score: Float) {
        self.id = id
        self.text = text
        self.score = score
    }
}

public enum EmbeddingMemoryError: Error, Equatable, Sendable, CustomStringConvertible {
    case openFailed(String)
    case queryFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let message):
            return "The memory database did not open. \(message)"
        case .queryFailed(let message):
            return "The memory database query failed. \(message)"
        }
    }
}

public final class EmbeddingMemoryStore: @unchecked Sendable {
    private let lock = NSLock()
    private var database: OpaquePointer?

    public init(fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let opened = sqlite3_open_v2(fileURL.path, &handle, flags, nil)
        guard opened == SQLITE_OK, let handle else {
            let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(handle)
            throw EmbeddingMemoryError.openFailed(message)
        }
        database = handle
        try execute("CREATE TABLE IF NOT EXISTS memories (id TEXT PRIMARY KEY NOT NULL, text TEXT NOT NULL, created_at REAL NOT NULL, vector BLOB NOT NULL)")
    }

    deinit {
        sqlite3_close(database)
    }

    @discardableResult
    public func insert(text: String, vector: [Float], now: Date, id: UUID = UUID()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, EmbeddingVector.isStoredLength(vector.count) else {
            return false
        }
        let key = trimmed.lowercased()
        if list().contains(where: { $0.text.lowercased() == key }) {
            return false
        }
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT INTO memories (id, text, created_at, vector) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, Self.transient)
        bind(trimmed, at: 2, statement: statement)
        sqlite3_bind_double(statement, 3, now.timeIntervalSince1970)
        let bytes = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        bytes.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(statement, 4, raw.baseAddress, Int32(raw.count), Self.transient)
        }
        return sqlite3_step(statement) == SQLITE_DONE
    }

    public func list() -> [EmbeddingMemoryRecord] {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT id, text, created_at, vector FROM memories ORDER BY created_at ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var rows: [EmbeddingMemoryRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0),
                  let note = sqlite3_column_text(statement, 1),
                  let id = UUID(uuidString: String(cString: idText))
            else {
                continue
            }
            let created = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            let vector = Self.vector(statement: statement, column: 3)
            rows.append(EmbeddingMemoryRecord(id: id, text: String(cString: note), createdAt: created, vector: vector))
        }
        return rows
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let sql = "DELETE FROM memories WHERE id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, Self.transient)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            return false
        }
        return sqlite3_changes(database) == 1
    }

    public func recall(query: [Float], limit: Int) -> [ScoredMemory] {
        let scored = list().map { row in
            ScoredMemory(id: row.id, text: row.text, score: CosineSimilarity.score(query, row.vector))
        }
        return scored
            .filter { $0.score >= MemoryRecall.minimumScore }
            .sorted { left, right in
                if left.score == right.score {
                    return left.text < right.text
                }
                return left.score > right.score
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(database, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "query failed"
            sqlite3_free(error)
            throw EmbeddingMemoryError.queryFailed(message)
        }
    }

    private func bind(_ text: String, at index: Int32, statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, text, -1, Self.transient)
    }

    private static func vector(statement: OpaquePointer?, column: Int32) -> [Float] {
        let count = Int(sqlite3_column_bytes(statement, column))
        guard count > 0, count.isMultiple(of: MemoryLayout<Float>.size), let pointer = sqlite3_column_blob(statement, column) else {
            return []
        }
        let data = Data(bytes: pointer, count: count)
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
