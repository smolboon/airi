import Foundation
import XCTest
@testable import AoriCore

private struct GrantScriptRuntime: PluginScriptRuntime {
    func evaluate(source _: String, grant: PluginPermissions) -> String {
        let greeting = PluginScriptBridge.call(
            grant: grant,
            area: "capabilities",
            action: "snapshot",
            key: "aori.companion.greeting"
        )
        let files = PluginScriptBridge.call(
            grant: grant,
            area: "capabilities",
            action: "snapshot",
            key: "aori.files.read"
        )
        return "greeting=\(greeting) files=\(files)"
    }
}

final class PluginHostTests: XCTestCase {
    func testGreetingSucceedsWhenFileReadAndSpeechAreDenied() throws {
        let directory = appKitRoot().appendingPathComponent("plugins/aori-greeting")
        let report = PluginHost.run(directory: directory)
        XCTAssertEqual(report.lines, [
            "aori_plugin=loaded id=aori-greeting",
            "aori_plugin_call=aori.companion.greeting",
            "aori_plugin_result=Plugin greeting.",
            "aori_plugin_denied=aori.files.read",
            "aori_plugin_denied=aori.speech.speak",
        ])
        XCTAssertFalse(report.lines.joined(separator: "\n").contains("/"))
        XCTAssertEqual(report.lines.filter { $0.hasPrefix("aori_plugin_result=") }, ["aori_plugin_result=Plugin greeting."])
    }

    func testEmptyAndMissingDirectoriesLogNone() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-plugin-missing-\(UUID().uuidString)", isDirectory: true)
        XCTAssertEqual(PluginHost.run(directory: missing).lines, ["aori_plugin=none"])

        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-plugin-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertEqual(PluginHost.run(directory: empty).lines, ["aori_plugin=none"])
        try? FileManager.default.removeItem(at: empty)
    }

    func testManifestRejections() {
        XCTAssertTrue(rejects(manifest(manifestVersion: "1")))
        XCTAssertTrue(rejects(manifest(extraRoot: ", \"note\": \"no\"")))
        XCTAssertTrue(rejects(manifest(id: "con")))
        XCTAssertTrue(rejects(manifest(id: "Hello")))
        XCTAssertTrue(rejects(manifest(entrypoints: "{}")))
        XCTAssertTrue(rejects(manifest(runtimes: "[\"node\", \"node\"]")))
        XCTAssertTrue(rejects(manifest(actions: "[\"delete\"]")))
        XCTAssertTrue(rejects(manifest(version: "01.0.0")))
        XCTAssertTrue(rejects(manifest(airi: "1.0.0 || 2.0.0")))
        XCTAssertFalse(rejects(manifest()))
    }

    func testPermissionIntersectionStaysInsideBothSides() {
        let wideRequest = permissions(key: "aori.companion.*", actions: ["snapshot", "wait"])
        let narrowGrant = permissions(key: "aori.companion.greeting", actions: ["snapshot"])
        let narrowed = PluginPermissions.intersect(wideRequest, narrowGrant)
        XCTAssertEqual(narrowed.capabilities, [
            PluginPermission(key: "aori.companion.greeting", actions: ["snapshot"]),
        ])

        let fileRequest = permissions(key: "aori.files.read", actions: ["snapshot"])
        XCTAssertTrue(PluginPermissions.intersect(fileRequest, PluginHost.ceiling()).capabilities.isEmpty)

        let noSharedAction = PluginPermissions.intersect(
            permissions(key: "aori.companion.greeting", actions: ["snapshot"]),
            permissions(key: "aori.companion.greeting", actions: ["wait"])
        )
        XCTAssertTrue(noSharedAction.capabilities.isEmpty)
    }

    func testVersionRanges() {
        let host = PluginVersion.parseExact("0.1.0")
        XCTAssertNotNil(host)
        XCTAssertEqual(PluginVersionRange.parse("^0.1.0")?.matches(host!), true)
        XCTAssertEqual(PluginVersionRange.parse("^0.1.0")?.matches(PluginVersion.parseExact("0.2.0")!), false)
        XCTAssertEqual(PluginVersionRange.parse("^0.0.1")?.matches(PluginVersion.parseExact("0.0.1")!), true)
        XCTAssertEqual(PluginVersionRange.parse("^0.0.1")?.matches(PluginVersion.parseExact("0.0.2")!), false)
        XCTAssertEqual(PluginVersionRange.parse("*")?.matches(host!), true)
        XCTAssertNil(PluginVersionRange.parse("1.0.0 || 2.0.0"))
        XCTAssertNil(PluginVersion.parseExact("1.0.0-beta.1"))
        XCTAssertEqual(PluginVersionRange.parse("^2.0.0")?.matches(host!), false)
    }

    func testParentPathAndScriptEntrypointsFailClosed() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-plugin-escape-\(UUID().uuidString)", isDirectory: true)
        let package = parent.appendingPathComponent("package", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let secret = Data("secret-marker".utf8)
        try secret.write(to: parent.appendingPathComponent("outside.json"))
        try manifest(entrypoints: "{ \"node\": \"../outside.json\" }").write(to: package.appendingPathComponent("extension.airi.json"))
        let escaped = PluginHost.run(directory: package)
        XCTAssertEqual(escaped.lines, ["aori_plugin=error"])
        XCTAssertFalse(escaped.lines.joined(separator: "\n").contains("secret-marker"))

        try manifest(entrypoints: "{ \"node\": \"./plugin.mjs\" }").write(to: package.appendingPathComponent("extension.airi.json"))
        try secret.write(to: package.appendingPathComponent("plugin.mjs"))
        let script = PluginHost.run(directory: package)
        XCTAssertEqual(script.lines, ["aori_plugin=error"])
        XCTAssertFalse(script.lines.joined(separator: "\n").contains("secret-marker"))

        let link = package.appendingPathComponent("linked.json")
        try? FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: parent.appendingPathComponent("outside.json"))
        try manifest(entrypoints: "{ \"node\": \"./linked.json\" }").write(to: package.appendingPathComponent("extension.airi.json"))
        let linked = PluginHost.run(directory: package)
        XCTAssertEqual(linked.lines, ["aori_plugin=error"])
        XCTAssertFalse(linked.lines.joined(separator: "\n").contains("secret-marker"))

        try FileManager.default.removeItem(at: parent)
    }

    func testJavaScriptUsesTheGrantAndHidesTheSource() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-plugin-js-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let source = """
        var greeting = aori.call("capabilities", "snapshot", "aori.companion.greeting");
        var files = aori.call("capabilities", "snapshot", "aori.files.read");
        "greeting=" + greeting + " files=" + files;
        """
        try Data(source.utf8).write(to: parent.appendingPathComponent("main.js"))
        try manifest(entrypoints: "{ \"node\": \"./main.js\" }").write(to: parent.appendingPathComponent("extension.airi.json"))

        let unavailable = PluginHost.run(directory: parent, scriptRuntime: nil)
        XCTAssertEqual(unavailable.lines, [
            "aori_plugin=loaded id=aori-greeting",
            "aori_plugin_js=unavailable",
        ])

        let report = PluginHost.run(directory: parent, scriptRuntime: GrantScriptRuntime())
        XCTAssertEqual(report.lines, [
            "aori_plugin=loaded id=aori-greeting",
            "aori_plugin_js=greeting=Plugin greeting. files=denied",
        ])
        XCTAssertFalse(report.lines.joined(separator: "\n").contains("aori.call"))
        try FileManager.default.removeItem(at: parent)
    }

    func testSampleJavaScriptPluginMatchesTheGrant() {
        let directory = appKitRoot().appendingPathComponent("plugins/aori-js")
        let report = PluginHost.run(directory: directory, scriptRuntime: GrantScriptRuntime())
        XCTAssertEqual(report.lines, [
            "aori_plugin=loaded id=aori-js",
            "aori_plugin_js=greeting=Plugin greeting. files=denied",
        ])
    }

    #if canImport(JavaScriptCore)
    func testJavaScriptCoreRunsThePermissionedCall() {
        let directory = appKitRoot().appendingPathComponent("plugins/aori-js")
        let report = PluginHost.run(directory: directory, scriptRuntime: JavaScriptCorePluginRuntime())
        XCTAssertEqual(report.lines, [
            "aori_plugin=loaded id=aori-js",
            "aori_plugin_js=greeting=Plugin greeting. files=denied",
        ])
    }
    #endif

    func testHostRangeAndBooleanVersionFail() throws {
        let package = try makePackage(manifest: manifest(airi: "^2.0.0"))
        XCTAssertEqual(PluginHost.run(directory: package).lines, ["aori_plugin=error"])
        let boolean = try makePackage(manifest: manifest(manifestVersion: "true"))
        XCTAssertEqual(PluginHost.run(directory: boolean).lines, ["aori_plugin=error"])
        try FileManager.default.removeItem(at: package)
        try FileManager.default.removeItem(at: boolean)
    }

    private func rejects(_ data: Data) -> Bool {
        if case .invalid = PluginManifestReader.parse(data) {
            return true
        }
        return false
    }

    private func appKitRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func permissions(key: String, actions: [String]) -> PluginPermissions {
        PluginPermissions(
            apis: [],
            resources: [],
            capabilities: [PluginPermission(key: key, actions: actions)],
            processors: [],
            pipelines: []
        )
    }

    private func makePackage(manifest data: Data) throws -> URL {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-plugin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: parent.appendingPathComponent("extension.airi.json"))
        try Data("{\"calls\":[]}".utf8).write(to: parent.appendingPathComponent("commands.json"))
        return parent
    }

    private func manifest(
        manifestVersion: String = "2",
        id: String = "aori-greeting",
        version: String = "1.0.0",
        airi: String = "*",
        runtimes: String = "[\"node\"]",
        entrypoints: String = "{ \"node\": \"./commands.json\" }",
        actions: String = "[\"snapshot\"]",
        extraRoot: String = ""
    ) -> Data {
        let text = """
        {
          "manifestVersion": \(manifestVersion),
          "kind": "manifest.extension.airi.moeru.ai",
          "id": "\(id)",
          "version": "\(version)",
          "engines": {
            "airi": "\(airi)",
            "runtimes": \(runtimes)
          },
          "entrypoints": \(entrypoints),
          "permissions": {
            "capabilities": [
              { "key": "aori.companion.greeting", "actions": \(actions) }
            ]
          }\(extraRoot)
        }
        """
        return Data(text.utf8)
    }
}
