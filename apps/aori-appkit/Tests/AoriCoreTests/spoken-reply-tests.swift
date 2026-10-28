import XCTest
@testable import AoriCore

final class SpokenReplyTests: XCTestCase {
    func testPlainTextStays() {
        XCTAssertEqual(SpokenReply.prepare("Hello. I am here."), "Hello. I am here.")
        XCTAssertEqual(SpokenReply.prepare("fairing"), "fairing")
        XCTAssertEqual(SpokenReply.prepare("```\ncode\n```"), "")
    }

    func testMarkdownAndTheOldBrandLeaveTheSpeechText() {
        let raw = """
        # Title
        ```
        secret-looking
        ```
        **wow** see [note](https://example.test). Airi says hi.
        """
        let text = SpokenReply.prepare(raw)
        XCTAssertFalse(text.contains("```"))
        XCTAssertFalse(text.contains("secret-looking"))
        XCTAssertFalse(text.contains("https://"))
        XCTAssertFalse(text.lowercased().contains("airi"))
        XCTAssertTrue(text.contains("Title"))
        XCTAssertTrue(text.contains("wow"))
        XCTAssertTrue(text.contains("Aori says hi."))
        XCTAssertEqual(CompanionEmotion.infer(from: text), .surprised)
    }

    func testThreeSentencesAndACharacterCap() {
        let long = "One. Two. Three. Four stays out."
        XCTAssertEqual(SpokenReply.prepare(long), "One. Two. Three.")
        let words = Array(repeating: "word", count: 200).joined(separator: " ")
        let capped = SpokenReply.prepare(words)
        XCTAssertLessThanOrEqual(capped.count, SpokenReply.characterLimit)
        XCTAssertFalse(capped.hasSuffix(" "))
    }

    func testANumberKeepsItsDecimal() {
        XCTAssertEqual(SpokenReply.prepare("The value is 3.14 today."), "The value is 3.14 today.")
    }
}
