import XCTest
@testable import AoriCore

final class SettingsPagesTests: XCTestCase {
    func testReportNamesEachPageAndTheGaps() {
        let text = SettingsPages.report(
            sceneTitle: "Butter",
            sceneDetail: "2714 vertices.",
            avatar: "live2d",
            provider: "openai",
            messageCount: 2,
            noteCount: 1,
            locale: "ja",
            model: "mock",
            voice: "System default",
            keySource: "environment",
            baseURL: "http://127.0.0.1:8765/v1",
            personaName: "Aori",
            cardModules: "chat, speech, vision, memory, plugins",
            lorebookCount: 2
        )
        XCTAssertEqual(SettingsPages.ids.count, 9)
        for name in ["Scene:", "Providers:", "Modules:", "Character card:", "Memory:", "Data:", "Connection:", "Models:", "System:"] {
            XCTAssertTrue(text.contains(name), name)
        }
        XCTAssertTrue(text.contains("Cubism, MMD, and Spine are absent."))
        XCTAssertTrue(text.contains("Selected OpenAI-compatible."))
        XCTAssertTrue(text.contains("MLX-Serve"))
        XCTAssertTrue(text.contains("TensorFold"))
        XCTAssertTrue(text.contains("Ollama"))
        XCTAssertTrue(text.contains("LM Studio"))
        XCTAssertTrue(text.contains("Other catalogs are absent."))
        XCTAssertTrue(text.contains("Games: Factorio and Minecraft."))
        XCTAssertTrue(text.contains("Factorio accepts a local hello."))
        XCTAssertTrue(text.contains("Minecraft accepts a local hello."))
        XCTAssertTrue(text.contains("A remote host is refused."))
        XCTAssertFalse(text.contains("Minecraft is not connected."))
        XCTAssertFalse(text.contains("Each game is not connected."))
        XCTAssertFalse(text.contains("Games are absent."))
        XCTAssertTrue(text.contains("Fields: name, nickname, description, personality, scenario, greeting, alternate greetings, creator notes, lore, tags, system prompt, post-history instructions, card version, modules, and a keyword lorebook."))
        XCTAssertTrue(text.contains("Card modules: chat, speech, vision, memory, plugins."))
        XCTAssertTrue(text.contains("Keyword lorebook: 2 entries."))
        XCTAssertFalse(text.contains("A keyword lorebook is absent."))
        XCTAssertFalse(text.contains("Creator notes and lore are absent."))
        XCTAssertTrue(text.contains("1 saved facts."))
        XCTAssertTrue(text.contains("2 messages in companion.sqlite."))
        XCTAssertTrue(text.contains("The chat server receives the latest 24 lines."))
        XCTAssertTrue(text.contains("locale ja."))
        XCTAssertTrue(text.contains("Chat protocols: Discord is a message draft only. Telegram is a preview only. Satori is an event draft only."))
        XCTAssertTrue(text.contains("X is unavailable."))
        XCTAssertTrue(text.contains("Credential fields are dropped."))
        XCTAssertTrue(text.contains("No token is stored."))
        XCTAssertTrue(text.contains("Account sync is absent."))
        XCTAssertTrue(text.contains("Integrations: VS Code is a context draft only."))
        XCTAssertTrue(text.contains("Home Assistant is an entity draft only."))
        XCTAssertTrue(text.contains("Web search is unavailable."))
        XCTAssertTrue(text.contains("Chess stores a move draft only."))
        XCTAssertTrue(text.contains("The web extension is a page draft only."))
        XCTAssertTrue(text.contains("Stickers list emotions only."))
        XCTAssertTrue(text.contains("No image is stored."))
        XCTAssertTrue(text.contains("Beat sync names a style from a tempo."))
        XCTAssertTrue(text.contains("The microphone stays off."))
        XCTAssertTrue(text.contains("Screen capture stays off."))
        XCTAssertTrue(text.contains("MCP is unavailable."))
        XCTAssertTrue(text.contains("A server command is dropped."))
        XCTAssertFalse(text.lowercased().contains("airi"))
        XCTAssertTrue(text.contains("Credential fields are dropped."))
        XCTAssertTrue(text.contains("No token is stored."))
    }
}
