import XCTest
@testable import AoriCore

final class DiscordCommandTests: XCTestCase {
    func testDraftUsesTheScaffoldAndDropsNothingUseful() {
        XCTAssertEqual(
            DiscordCommand.reply(to: "discord general Hello there"),
            "Discord draft for general: Hello there."
        )
        XCTAssertEqual(DiscordCommand.reply(to: "discord"), "Discord needs a channel and text.")
        XCTAssertEqual(DiscordCommand.reply(to: "discord general"), "Discord needs a channel and text.")
        XCTAssertNil(DiscordCommand.reply(to: "hello"))
        XCTAssertNil(DiscordCommand.reply(to: "Discord general Hello"))
    }

    func testCredentialAndURLDoNotReturnTheValue() {
        let credential = DiscordCommand.reply(to: "discord general token=secret")
        XCTAssertEqual(credential, "Discord dropped a credential.")
        XCTAssertFalse(credential?.contains("secret") == true)
        let key = DiscordCommand.reply(to: "discord general api_key=secret")
        XCTAssertEqual(key, "Discord dropped a credential.")
        XCTAssertFalse(key?.contains("secret") == true)

        let url = DiscordCommand.reply(to: "discord general see https://example.test")
        XCTAssertEqual(url, "Discord refused a URL.")
        XCTAssertFalse(url?.contains("https") == true)
        XCTAssertFalse(url?.contains("example.test") == true)
    }
}
