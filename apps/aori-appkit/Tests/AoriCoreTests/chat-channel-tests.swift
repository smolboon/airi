import XCTest
@testable import AoriCore

final class ChatChannelTests: XCTestCase {
    func testTelegramFlagBuildsASendMessageBody() throws {
        XCTAssertEqual(ChatChannelFlag.kind(raw: nil), .openai)
        XCTAssertEqual(ChatChannelFlag.kind(raw: "discord"), .openai)
        XCTAssertEqual(ChatChannelFlag.kind(raw: "telegram"), .telegram)
        XCTAssertNil(TelegramSend.make(token: "", chatID: "ci", text: "Hello"))
        XCTAssertNil(TelegramSend.make(token: "ci-token", chatID: "ci", text: ""))
        let message = TelegramSend.make(token: "ci-token", chatID: "ci", text: "Mock reply from CI.")
        XCTAssertEqual(message?.path, "botci-token/sendMessage")
        let object = try JSONSerialization.jsonObject(with: message?.body ?? Data()) as? [String: String]
        XCTAssertEqual(object?["chat_id"], "ci")
        XCTAssertEqual(object?["text"], "Mock reply from CI.")
    }
}
