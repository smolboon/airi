import XCTest
@testable import AoriCore

final class LocalToolTests: XCTestCase {
    func testGreetingCommandReturnsTheFixedText() {
        XCTAssertEqual(LocalTool.reply(to: "tool greeting"), "Plugin greeting.")
        XCTAssertEqual(LocalTool.reply(to: "tool greeting"), PluginHost.greetingText)
        XCTAssertNil(LocalTool.reply(to: "tool greetings"))
        XCTAssertNil(LocalTool.reply(to: "Tool greeting"))
        XCTAssertNil(LocalTool.reply(to: "hello"))
    }
}
