import Foundation

public struct LocalePreference: Codable, Equatable, Sendable {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}

public struct FileLocalePreferenceStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "en"
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(LocalePreference.self, from: data).id
    }

    public func save(id: String) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(LocalePreference(id: id))
        try data.write(to: fileURL, options: .atomic)
    }
}

public struct LocaleCatalog {
    public static let ids = ["en", "es", "fr", "ja", "ko", "ru", "vi", "zh-Hans", "zh-Hant"]

    public struct Loaded: Equatable, Sendable {
        public var id: String
        public var menuText: String?
        public var proof: String
        public var directoryExists: Bool

        public init(id: String, menuText: String?, proof: String, directoryExists: Bool) {
            self.id = id
            self.menuText = menuText
            self.proof = proof
            self.directoryExists = directoryExists
        }
    }

    public static func load(root: URL, id: String) -> Loaded {
        let directory = root.appendingPathComponent(id, isDirectory: true)
        let exists = FileManager.default.fileExists(atPath: directory.path)
        let menuURL = directory.appendingPathComponent("aori.yaml")
        let menuText = try? String(contentsOf: menuURL, encoding: .utf8)
        let tray = directory.appendingPathComponent("tamagotchi/electron/tray.yaml")
        let proof = (try? String(contentsOf: tray, encoding: .utf8))
            .map { LocaleTable.parse($0).values["menu.labels.label.settings"] ?? "" } ?? ""
        return Loaded(id: id, menuText: menuText, proof: proof, directoryExists: exists)
    }

    public static func loadAll(root: URL) -> [Loaded] {
        ids.map { load(root: root, id: $0) }
    }
}
