import XCTest
@testable import AoriCore

final class CompanionBehaviorTests: XCTestCase {
    func testRememberDedupesAndDropsTheOldestNote() {
        var memory = UserMemory.empty
        XCTAssertTrue(memory.remember("I like tea", now: Date(timeIntervalSince1970: 1)))
        XCTAssertFalse(memory.remember("  i like tea  ", now: Date(timeIntervalSince1970: 2)))
        XCTAssertNil(MemoryCapture.note(from: "hello"))
        XCTAssertEqual(MemoryCapture.note(from: "Remember that I work nights"), "I work nights")
        XCTAssertEqual(MemoryCapture.note(from: "remember: blue mug"), "blue mug")

        for index in 0..<40 {
            XCTAssertTrue(memory.remember("fact \(index)", now: Date(timeIntervalSince1970: Double(index))))
        }
        XCTAssertEqual(memory.notes.count, 40)
        XCTAssertFalse(memory.notes.contains(where: { $0.text == "I like tea" }))
        XCTAssertEqual(memory.notes.last?.text, "fact 39")
    }

    func testPromptAndGreetingUsePersonaAndMemory() {
        let persona = CompanionPersona(name: "Nova", personality: "Stay calm.")
        var memory = UserMemory.empty
        XCTAssertTrue(memory.remember("I like tea"))
        let prompt = CompanionPrompt.system(persona: persona, memory: memory)
        XCTAssertTrue(prompt.contains("You are Nova, a desktop companion on macOS."))
        XCTAssertTrue(prompt.contains("Stay calm."))
        XCTAssertTrue(prompt.contains("I like tea"))
        XCTAssertEqual(
            CompanionGreeting.opening(persona: persona, memory: memory),
            "Hello. I am Nova. I still remember this. I like tea."
        )
        XCTAssertEqual(
            CompanionGreeting.opening(persona: .standard, memory: .empty),
            "Hello. I am Aori. I am here on your desktop."
        )
    }

    func testEmotionWords() {
        XCTAssertEqual(CompanionEmotion.infer(from: "Wow, that is new."), .surprised)
        XCTAssertEqual(CompanionEmotion.infer(from: "I am sorry."), .sad)
        XCTAssertEqual(CompanionEmotion.infer(from: "I am glad."), .happy)
        XCTAssertEqual(CompanionEmotion.infer(from: "The window is open."), .neutral)
    }

    func testProfileFileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-profile-\(UUID().uuidString)", isDirectory: true)
        let store = FileCompanionProfileStore(fileURL: directory.appendingPathComponent("companion.json"))
        XCTAssertEqual(try store.load(), .standard)
        var memory = UserMemory.empty
        XCTAssertTrue(memory.remember("I like tea"))
        let profile = CompanionProfile(
            persona: CompanionPersona(name: "Nova", personality: "Stay calm."),
            memory: memory
        )
        try store.save(profile)
        XCTAssertEqual(try store.load(), profile)
        try FileManager.default.removeItem(at: directory)
    }
}
