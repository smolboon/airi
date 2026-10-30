import XCTest
@testable import AoriCore

final class McpCommandTests: XCTestCase {
    func testGreetingAndDeniedTools() {
        XCTAssertEqual(McpCommand.reply(to: "mcp tools"), "MCP tools: greeting.")
        XCTAssertEqual(McpCommand.reply(to: "mcp call greeting"), PluginHost.greetingText)
        XCTAssertEqual(McpCommand.reply(to: "mcp call aori.files.read"), "MCP denied aori.files.read.")
        XCTAssertEqual(McpCommand.reply(to: "mcp call aori.speech.speak"), "MCP denied aori.speech.speak.")
        XCTAssertEqual(McpCommand.reply(to: "mcp"), "MCP needs a local tool call.")
        XCTAssertNil(McpCommand.reply(to: "Mcp tools"))
        XCTAssertNil(McpCommand.reply(to: "hello"))
    }

    func testServerCommandIsDroppedAndNotCopied() {
        let dropped = McpCommand.reply(to: "mcp server-cmd local-tool")
        XCTAssertEqual(dropped, "MCP dropped the server command.")
        XCTAssertFalse(dropped?.contains("local-tool") == true)

        let secret = McpCommand.reply(to: "mcp token=secret")
        XCTAssertEqual(secret, "MCP dropped the server command.")
        XCTAssertFalse(secret?.contains("secret") == true)

        let kept = McpCommand.reply(to: "mcp note public")
        XCTAssertEqual(kept, "MCP kept note.")
        XCTAssertFalse(kept?.contains("public") == true)
    }
}
