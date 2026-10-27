import Foundation

enum ScopedBookmark {
    static func prove(directory: URL) -> String {
        let file = directory.appendingPathComponent("aori-js").appendingPathComponent("extension.airi.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            return "aori_bookmark=missing"
        }
        do {
            let data = try file.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var stale = false
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            let started = resolved.startAccessingSecurityScopedResource()
            defer {
                if started {
                    resolved.stopAccessingSecurityScopedResource()
                }
            }
            guard started else {
                return "aori_bookmark=denied"
            }
            let text = try String(contentsOf: resolved, encoding: .utf8)
            if text.contains("\"aori-js\"") {
                return "aori_bookmark=ok"
            }
            return "aori_bookmark=empty"
        } catch {
            return "aori_bookmark=failed"
        }
    }

    static func store(url: URL, name: String) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Aori", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent(name))
    }
}
