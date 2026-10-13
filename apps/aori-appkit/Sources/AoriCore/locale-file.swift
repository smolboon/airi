import Foundation

public struct LocaleTable: Equatable, Sendable {
    public var values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    /// Reads nested `key:` maps and `key: value` lines. This is the English menu file, not a full YAML parser.
    public static func parse(_ text: String) -> LocaleTable {
        var values: [String: String] = [:]
        var stack: [(indent: Int, key: String)] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).replacingOccurrences(of: "\r", with: "")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            let indent = line.prefix(while: { $0 == " " }).count
            guard let colon = trimmed.firstIndex(of: ":") else {
                continue
            }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            while let last = stack.last, last.indent >= indent {
                stack.removeLast()
            }
            if rest.isEmpty {
                stack.append((indent, key))
                continue
            }
            let path = (stack.map(\.key) + [key]).joined(separator: ".")
            values[path] = unquote(rest)
        }
        return LocaleTable(values: values)
    }

    private static func unquote(_ text: String) -> String {
        guard text.count >= 2 else {
            return text
        }
        if text.hasPrefix("\""), text.hasSuffix("\"") {
            return String(text.dropFirst().dropLast())
        }
        if text.hasPrefix("'"), text.hasSuffix("'") {
            return String(text.dropFirst().dropLast())
        }
        return text
    }
}

public enum LocaleFile {
    /// Loads the English menu table. The app bundle copy comes from `packages/i18n`.
    public static func englishMenu() -> String? {
        var urls: [URL] = []
        if let url = BundledFile.url(name: "aori", extension: "yaml") {
            urls.append(url)
        }
        if let url = Bundle.main.url(forResource: "aori", withExtension: "yaml") {
            urls.append(url)
        }
        let bundle = Bundle.main.bundleURL
        urls.append(bundle.appendingPathComponent("Contents/Resources/aori.yaml"))
        urls.append(bundle.deletingLastPathComponent().appendingPathComponent("../Resources/aori.yaml"))
        for url in urls {
            if let text = try? String(contentsOf: url, encoding: .utf8), text.contains("showCompanion") {
                return text
            }
        }
        if let url = Bundle.module.url(forResource: "aori", withExtension: "yaml"),
           let text = try? String(contentsOf: url, encoding: .utf8),
           text.contains("showCompanion") {
            return text
        }
        return nil
    }
}
