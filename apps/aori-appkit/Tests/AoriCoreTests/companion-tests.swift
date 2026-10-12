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

    func testChatAndSettingsRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-files-\(UUID().uuidString)", isDirectory: true)
        let transcript = FileChatTranscriptStore(fileURL: directory.appendingPathComponent("chat.json"))
        XCTAssertTrue(try transcript.load().isEmpty)
        let message = ChatMessage(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee") ?? UUID(),
            role: .user,
            content: "Hello",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        try transcript.save([message])
        XCTAssertEqual(try transcript.load(), [message])

        let settings = FileProviderSettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        XCTAssertNil(try settings.load())
        let stored = ProviderSettings(baseURL: "https://example.test/v1", model: "demo")
        try settings.save(stored)
        XCTAssertEqual(try settings.load(), stored)
        try FileManager.default.removeItem(at: directory)
    }

    func testEnglishMenuComesFromPackagesI18n() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("packages/i18n/src/locales/en/aori.yaml")
        let linked = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AoriCore/Resources/aori.yaml")
        let text = try String(contentsOf: source, encoding: .utf8)
        let copied = try String(contentsOf: linked, encoding: .utf8)
        XCTAssertEqual(copied, text)
        let table = LocaleTable.parse(text)
        XCTAssertEqual(table.values["menu.showCompanion"], "Show Companion")
        AoriCopy.load(text)
        XCTAssertEqual(AoriCopy.showCompanion, "Show Companion")
        XCTAssertEqual(AoriCopy.settings, "Settings…")
    }
}
