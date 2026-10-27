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
            personaName: "Aori"
        )
        XCTAssertEqual(SettingsPages.ids.count, 9)
        for name in ["Scene:", "Providers:", "Modules:", "Character card:", "Memory:", "Data:", "Connection:", "Models:", "System:"] {
            XCTAssertTrue(text.contains(name), name)
        }
        XCTAssertTrue(text.contains("Cubism, MMD, and Spine are absent."))
        XCTAssertTrue(text.contains("Selected OpenAI-compatible."))
        XCTAssertTrue(text.contains("MLX-Serve"))
        XCTAssertTrue(text.contains("TensorFold"))
        XCTAssertTrue(text.contains("Other catalogs are absent."))
        XCTAssertTrue(text.contains("Games are absent."))
        XCTAssertTrue(text.contains("Fields: name, personality, scenario, greeting, creator notes, lore, and tags."))
        XCTAssertTrue(text.contains("A keyword lorebook is absent."))
        XCTAssertFalse(text.contains("Creator notes and lore are absent."))
        XCTAssertTrue(text.contains("1 saved facts."))
        XCTAssertTrue(text.contains("2 messages in companion.sqlite."))
        XCTAssertTrue(text.contains("locale ja."))
        XCTAssertTrue(text.contains("Account sync is absent."))
    }
}
