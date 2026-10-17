import Foundation

public struct PluginRunReport: Equatable, Sendable {
    public var lines: [String]
}

/// Reads Manifest v2 and runs a command list or a JavaScript file inside the host grant.
/// JavaScript runs only through JavaScriptCore. The script can call `aori.call`.
public enum PluginHost {
    public static let airiVersion = "0.1.0"
    static let greetingKey = "aori.companion.greeting"
    static let greetingText = "Plugin greeting."

    public static func run(directory: URL, airiVersion: String = PluginHost.airiVersion) -> PluginRunReport {
        run(directory: directory, airiVersion: airiVersion, scriptRuntime: defaultScriptRuntime())
    }

    static func run(
        directory: URL,
        airiVersion: String = PluginHost.airiVersion,
        scriptRuntime: (any PluginScriptRuntime)?
    ) -> PluginRunReport {
        let roots = packageRoots(in: directory)
        if roots.isEmpty {
            return PluginRunReport(lines: ["aori_plugin=none"])
        }
        var lines: [String] = []
        for root in roots {
            lines.append(contentsOf: runPackage(root, airiVersion: airiVersion, scriptRuntime: scriptRuntime))
        }
        return PluginRunReport(lines: lines)
    }

    static func defaultScriptRuntime() -> (any PluginScriptRuntime)? {
        #if canImport(JavaScriptCore)
        return JavaScriptCorePluginRuntime()
        #else
        return nil
        #endif
    }

    /// Host ceiling. A plugin receives the overlap of this grant and its request.
    static func ceiling() -> PluginPermissions {
        PluginPermissions(
            apis: [],
            resources: [],
            capabilities: [PluginPermission(key: "aori.companion.*", actions: ["snapshot"])],
            processors: [],
            pipelines: []
        )
    }

    private static func runPackage(
        _ root: URL,
        airiVersion: String,
        scriptRuntime: (any PluginScriptRuntime)?
    ) -> [String] {
        let manifestURL = root.appendingPathComponent("extension.airi.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            return ["aori_plugin=error"]
        }
        guard case .manifest(let manifest) = PluginManifestReader.parse(data) else {
            return ["aori_plugin=error"]
        }
        guard let range = PluginVersionRange.parse(manifest.airiRange),
              let host = PluginVersion.parseExact(airiVersion),
              range.matches(host)
        else {
            return ["aori_plugin=error"]
        }
        guard let relative = entrypoint(in: manifest) else {
            return ["aori_plugin=error"]
        }
        guard let file = resolve(relative, under: root) else {
            return ["aori_plugin=error"]
        }
        let grant = PluginPermissions.intersect(manifest.permissions, ceiling())
        if isJavaScript(relative) {
            return runJavaScript(file: file, manifest: manifest, grant: grant, runtime: scriptRuntime)
        }
        if isRejectedScript(relative) {
            return ["aori_plugin=error"]
        }
        guard let commands = try? Data(contentsOf: file), let calls = parseCalls(commands) else {
            return ["aori_plugin=error"]
        }
        var lines = ["aori_plugin=loaded id=\(manifest.id)"]
        for call in calls.prefix(32) {
            let allowed = PluginPermissions.allows(grant, area: call.area, action: call.action, key: call.key)
            let value = allowed ? capabilityValue(key: call.key, action: call.action) : nil
            if let value {
                lines.append("aori_plugin_call=\(token(call.key))")
                lines.append("aori_plugin_result=\(value)")
            } else {
                lines.append("aori_plugin_denied=\(token(call.key))")
            }
        }
        return lines
    }

    private static func runJavaScript(
        file: URL,
        manifest: PluginManifest,
        grant: PluginPermissions,
        runtime: (any PluginScriptRuntime)?
    ) -> [String] {
        guard let source = try? String(contentsOf: file, encoding: .utf8), source.utf8.count <= 64_000 else {
            return ["aori_plugin=error"]
        }
        let loaded = "aori_plugin=loaded id=\(manifest.id)"
        guard let runtime else {
            return [loaded, "aori_plugin_js=unavailable"]
        }
        let value = token(runtime.evaluate(source: source, grant: grant))
        if value.isEmpty || value == "error" {
            return [loaded, "aori_plugin_js=error"]
        }
        return [loaded, "aori_plugin_js=\(value)"]
    }

    private static func capabilityValue(key: String, action: String) -> String? {
        if key == greetingKey && action == "snapshot" {
            return greetingText
        }
        return nil
    }

    private static func packageRoots(in directory: URL) -> [URL] {
        let manifest = directory.appendingPathComponent("extension.airi.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            return [directory]
        }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return children
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("extension.airi.json").path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func entrypoint(in manifest: PluginManifest) -> String? {
        for runtime in manifest.runtimes {
            if let path = manifest.entrypoints[runtime] {
                return path
            }
        }
        return manifest.entrypoints["default"]
    }

    private static func isJavaScript(_ relative: String) -> Bool {
        relative.lowercased().hasSuffix(".js")
    }

    private static func isRejectedScript(_ relative: String) -> Bool {
        let lower = relative.lowercased()
        return lower.hasSuffix(".mjs") || lower.hasSuffix(".cjs")
    }

    private static func resolve(_ relative: String, under root: URL) -> URL? {
        if relative.hasPrefix("/") || relative.contains("\\") {
            return nil
        }
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.contains("..") || parts.contains("~") {
            return nil
        }
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let target = base.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard target.path.hasPrefix(prefix), FileManager.default.fileExists(atPath: target.path) else {
            return nil
        }
        return target
    }

    private static func parseCalls(_ data: Data) -> [PluginCall]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard Set(root.keys) == ["calls"], let items = root["calls"] as? [Any] else {
            return nil
        }
        var calls: [PluginCall] = []
        for item in items {
            guard let object = item as? [String: Any], Set(object.keys) == ["area", "action", "key"] else {
                return nil
            }
            guard let area = object["area"] as? String,
                  let action = object["action"] as? String,
                  let key = object["key"] as? String,
                  !area.isEmpty, !action.isEmpty, !key.isEmpty
            else {
                return nil
            }
            calls.append(PluginCall(area: area, action: action, key: key))
        }
        return calls
    }

    private static func token(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > 80 {
            return String(cleaned.prefix(80))
        }
        return cleaned
    }
}

private struct PluginCall {
    var area: String
    var action: String
    var key: String
}
