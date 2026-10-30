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

    func testReviewNotesNameTheEditsAndDoNotCopyTheSource() {
        let plain = SpokenReply.review("Hello. I am here.")
        XCTAssertEqual(plain.notes, [])
        XCTAssertEqual(plain.text, SpokenReply.prepare("Hello. I am here."))

        let fairing = SpokenReply.review("fairing")
        XCTAssertEqual(fairing.notes, [])
        XCTAssertEqual(fairing.text, "fairing")

        let openFence = SpokenReply.review("Hello ``` tail")
        XCTAssertEqual(openFence.notes, ["fence dropped"])
        XCTAssertEqual(openFence.text, "Hello tail")
        XCTAssertTrue(openFence.text.contains("tail"))
        XCTAssertFalse(openFence.text.contains("```"))

        let closedTail = SpokenReply.review("Hello ```\ncode\n``` tail")
        XCTAssertEqual(closedTail.notes, ["fence dropped"])
        XCTAssertEqual(closedTail.text, "Hello tail")
        XCTAssertFalse(closedTail.text.contains("code"))

        let mixedFence = SpokenReply.review("One ```\nhide\n``` two ``` three")
        XCTAssertEqual(mixedFence.text, "One two three")
        XCTAssertFalse(mixedFence.text.contains("hide"))
        XCTAssertFalse(mixedFence.text.contains("```"))

        let fenced = SpokenReply.review("```\nairi\n```")
        XCTAssertEqual(fenced.notes, ["fence dropped", "empty reply"])
        XCTAssertEqual(fenced.text, "")
        XCTAssertFalse(fenced.notes.joined(separator: " ").contains("airi"))

        let branded = SpokenReply.review("Hello airi.")
        XCTAssertEqual(branded.notes, ["brand renamed"])
        XCTAssertEqual(branded.text, "Hello Aori.")

        let cut = SpokenReply.review("One. Two. Three. Four stays out.")
        XCTAssertEqual(cut.notes, ["sentences cut"])
        XCTAssertEqual(cut.text, "One. Two. Three.")

        let words = Array(repeating: "word", count: 200).joined(separator: " ")
        let capped = SpokenReply.review(words)
        XCTAssertEqual(capped.notes, ["characters cut"])
        XCTAssertEqual(capped.text, SpokenReply.prepare(words))
        XCTAssertLessThanOrEqual(capped.text.count, SpokenReply.characterLimit)

        let mixed = """
        # Title
        ```
        secret-looking
        ```
        **wow** see [note](https://example.test). Airi says hi.
        """
        let review = SpokenReply.review(mixed)
        XCTAssertEqual(review.notes, ["fence dropped", "markdown removed", "brand renamed"])
        XCTAssertEqual(review.text, SpokenReply.prepare(mixed))
        XCTAssertFalse(review.notes.joined(separator: " ").contains("secret-looking"))
        XCTAssertFalse(review.text.contains("secret-looking"))
    }
}
