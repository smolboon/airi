import Foundation
import XCTest
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
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
        let card = CompanionPersona(
            name: "Nova",
            personality: "Stay calm.",
            scenario: "A night desk.",
            greeting: "Good evening.",
            creatorNotes: "draft only",
            lore: "An old lamp.",
            tags: ["archive"]
        )
        let cardPrompt = CompanionPrompt.system(persona: card, memory: .empty)
        XCTAssertTrue(cardPrompt.contains("The scene is A night desk."))
        XCTAssertTrue(cardPrompt.contains("The lore is An old lamp."))
        XCTAssertFalse(cardPrompt.contains("draft only"))
        XCTAssertFalse(cardPrompt.contains("archive"))
        XCTAssertEqual(CompanionGreeting.opening(persona: card, memory: memory), "Good evening.")
        XCTAssertFalse(prompt.contains("The scene is"))
        XCTAssertFalse(prompt.contains("The lore is"))
    }

    func testCardFieldsEnterThePromptOrStayOut() {
        let card = CompanionPersona(
            name: "Nova",
            personality: "Stay calm.",
            nickname: "Nia",
            description: "A night clerk.",
            alternateGreetings: ["Hi again.", " Hi again. ", ""],
            systemPrompt: "Speak softly.",
            postHistoryInstructions: "Stay in scene.",
            cardVersion: "1.2.0",
            modules: ["chat", "games", "chat"]
        )
        XCTAssertEqual(card.alternateGreetings, ["Hi again."])
        XCTAssertEqual(card.modules, ["chat"])
        XCTAssertEqual(CompanionPersona.modules(from: ""), CompanionModule.defaultIDs)
        let prompt = CompanionPrompt.system(persona: card, memory: .empty)
        XCTAssertTrue(prompt.contains("Speak softly."))
        XCTAssertTrue(prompt.contains("The description is A night clerk."))
        XCTAssertFalse(prompt.contains("Nia"))
        XCTAssertFalse(prompt.contains("Hi again."))
        XCTAssertFalse(prompt.contains("Stay in scene."))
        XCTAssertFalse(prompt.contains("1.2.0"))
        XCTAssertFalse(prompt.contains("chat"))
        let sent = CompanionPrompt.messages(
            persona: card,
            memory: .empty,
            history: [ChatMessage(role: .user, content: "Hello")]
        )
        XCTAssertEqual(sent.first?.role, .system)
        XCTAssertTrue(sent.first?.content.contains("Speak softly.") ?? false)
        XCTAssertEqual(sent.last?.role, .system)
        XCTAssertEqual(sent.last?.content, "Stay in scene.")
        XCTAssertEqual(CompanionGreeting.opening(persona: card, memory: .empty), "Hello. I am Nova. I am here on your desktop.")
    }

    func testTagsKeepTheFirstSpelling() {
        XCTAssertEqual(CompanionPersona.tags(from: " Night, night, , Desk "), ["Night", "Desk"])
        XCTAssertEqual(CompanionPersona.tags(fromJSON: "not-json"), [])
    }

    func testOlderCardJSONOmitsScenarioAndGreeting() throws {
        let json = #"{"persona":{"name":"Nova","personality":"Stay calm."},"memory":{"notes":[]}}"#
        let profile = try JSONDecoder().decode(CompanionProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.persona.scenario, "")
        XCTAssertEqual(profile.persona.greeting, "")
        XCTAssertEqual(profile.persona.creatorNotes, "")
        XCTAssertEqual(profile.persona.lore, "")
        XCTAssertEqual(profile.persona.tags, [])
        XCTAssertEqual(profile.persona.nickname, "")
        XCTAssertEqual(profile.persona.description, "")
        XCTAssertEqual(profile.persona.alternateGreetings, [])
        XCTAssertEqual(profile.persona.systemPrompt, "")
        XCTAssertEqual(profile.persona.postHistoryInstructions, "")
        XCTAssertEqual(profile.persona.cardVersion, "")
        XCTAssertEqual(profile.persona.modules, CompanionModule.defaultIDs)
        XCTAssertEqual(profile.persona.lorebook, [])
    }

    func testChatProtocolsStayDisconnected() {
        XCTAssertEqual(ChatProtocol.catalog.map(\.id), ["discord", "telegram", "satori", "x"])
        XCTAssertEqual(ChatProtocolScaffold.status, "not connected")
        XCTAssertEqual(ChatProtocolScaffold.unavailableID, "x")
        let text = ChatProtocolScaffold.report()
        XCTAssertTrue(text.contains("No token is stored."))
        XCTAssertTrue(text.contains("X is unavailable."))
        XCTAssertTrue(text.contains("Discord is a message draft only."))
        XCTAssertTrue(text.contains("Telegram is a preview only."))
        XCTAssertTrue(text.contains("Satori is an event draft only."))
        XCTAssertFalse(text.contains("token="))
        let draft = DiscordScaffold.draft(channel: " general ", text: " Hello ")
        XCTAssertEqual(draft, DiscordScaffold.Draft(channel: "general", text: "Hello"))
        XCTAssertNil(DiscordScaffold.draft(channel: " ", text: "Hello"))
        let preview = TelegramScaffold.preview(chatID: " ci ", text: " Hello ")
        XCTAssertEqual(preview, TelegramScaffold.Preview(chatID: "ci", text: "Hello"))
        XCTAssertNil(TelegramScaffold.preview(chatID: "ci", text: " "))
        let event = SatoriScaffold.draft(platform: " qq ", text: " Hello ")
        XCTAssertEqual(event, SatoriScaffold.Draft(platform: "qq", text: "Hello"))
        XCTAssertNil(SatoriScaffold.draft(platform: "qq", text: " "))
        XCTAssertTrue(text.contains("Credential fields are dropped."))
        let kept = XScaffold.kept([
            "api_key": "secret",
            "access_token": "secret",
            "note": "public",
        ])
        XCTAssertEqual(kept, ["note": "public"])
    }

    func testGameScaffoldListsFactorioAndMinecraft() {
        XCTAssertEqual(CompanionGame.catalog.map(\.id), ["factorio", "minecraft"])
        let text = GameScaffold.report()
        XCTAssertTrue(text.contains("Factorio accepts a local hello."))
        XCTAssertTrue(text.contains("A remote host is refused."))
        XCTAssertTrue(text.contains("Minecraft is not connected."))
        XCTAssertFalse(text.contains("Each game is not connected."))
    }

    func testFactorioAcceptsALocalHello() {
        XCTAssertTrue(LocalHello.allows(" localhost "))
        XCTAssertTrue(LocalHello.allows("127.0.0.1"))
        XCTAssertFalse(LocalHello.allows("127.0.0.2"))
        XCTAssertFalse(LocalHello.allows("example.com"))
        XCTAssertEqual(
            FactorioLink.hello(host: "203.0.113.10", port: 34197, player: "Aori"),
            .failure(.refused)
        )
        XCTAssertEqual(
            FactorioLink.hello(host: "127.0.0.1", port: 34197, player: " "),
            .failure(.refused)
        )
        XCTAssertEqual(
            FactorioLink.hello(host: "127.0.0.1", port: 34197, player: "Aori\nadmin"),
            .failure(.refused)
        )
        guard let server = LocalHelloServer.bind() else {
            XCTFail("bind")
            return
        }
        let box = HelloBox()
        DispatchQueue.global().async {
            box.set(FactorioLink.hello(host: "localhost", port: server.port, player: " Aori "))
        }
        let served = server.serveOne()
        XCTAssertEqual(served, "OK Aori")
        XCTAssertEqual(box.wait(), .success(FactorioLink.Hello(player: "Aori", reply: "OK Aori")))
    }

    func testLorebookEntersThePromptOnlyOnAKeyword() {
        let entries = Lorebook.parse("lamp, Lamp | An old lamp. ;;  | missing ;; desk | A night desk")
        XCTAssertEqual(entries.map(\.keywords), [["lamp"], ["desk"]])
        XCTAssertEqual(entries.map(\.content), ["An old lamp.", "A night desk"])
        let card = CompanionPersona(name: "Nova", personality: "Stay calm.", lorebook: entries)
        let miss = CompanionPrompt.system(persona: card, memory: .empty, context: "Hello there")
        XCTAssertFalse(miss.contains("The lorebook says"))
        let hit = CompanionPrompt.system(persona: card, memory: .empty, context: "Look at the lamp.")
        XCTAssertTrue(hit.contains("The lorebook says An old lamp."))
        XCTAssertFalse(hit.contains("A night desk"))
        let sent = CompanionPrompt.messages(
            persona: card,
            memory: .empty,
            history: [ChatMessage(role: .user, content: "The lamp is on.")]
        )
        XCTAssertTrue(sent.first?.content.contains("The lorebook says An old lamp.") ?? false)
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
        let oldJSON = #"{"baseURL":"https://example.test/v1","model":"demo"}"#.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(ProviderSettings.self, from: oldJSON)
        XCTAssertEqual(decoded.provider, "openai")
        XCTAssertEqual(decoded.voice, "")
        try FileManager.default.removeItem(at: directory)
    }

    func testSQLiteImportsJSONOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-sqlite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var memory = UserMemory.empty
        XCTAssertTrue(memory.remember("I like tea", now: Date(timeIntervalSince1970: 20)))
        let profile = CompanionProfile(
            persona: CompanionPersona(name: "Nova", personality: "Stay calm."),
            memory: memory
        )
        let profileURL = directory.appendingPathComponent("companion.json")
        try FileCompanionProfileStore(fileURL: profileURL).save(profile)
        let message = ChatMessage(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee") ?? UUID(),
            role: .user,
            content: "Hello",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let chatURL = directory.appendingPathComponent("chat.json")
        try FileChatTranscriptStore(fileURL: chatURL).save([message])
        let settingsURL = directory.appendingPathComponent("settings.json")
        let stored = ProviderSettings(baseURL: "https://example.test/v1", model: "demo")
        try FileProviderSettingsStore(fileURL: settingsURL).save(stored)
        let localeURL = directory.appendingPathComponent("locale.json")
        try FileLocalePreferenceStore(fileURL: localeURL).save(id: "ja")
        let expectedProfile = try FileCompanionProfileStore(fileURL: profileURL).load()
        let expectedMessages = try FileChatTranscriptStore(fileURL: chatURL).load()
        let database = directory.appendingPathComponent("companion.sqlite")
        let store = try SQLiteCompanionStore(fileURL: database)
        XCTAssertEqual(store.migrated, ["persona", "chat", "settings", "locale"])
        XCTAssertEqual(try store.load(), expectedProfile)
        XCTAssertEqual(try store.loadMessages(), expectedMessages)
        XCTAssertEqual(try store.loadSettings(), stored)
        XCTAssertEqual(try store.loadLocale(), "ja")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: chatURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: localeURL.path))
        try store.saveLocale(id: "fr")
        XCTAssertEqual(try store.loadLocale(), "fr")
        let again = try SQLiteCompanionStore(fileURL: database)
        XCTAssertTrue(again.migrated.isEmpty)
        XCTAssertEqual(try again.loadLocale(), "fr")
        XCTAssertEqual(try again.loadMessages(), expectedMessages)
        XCTAssertEqual(try again.load(), expectedProfile)
        let card = CompanionPersona(
            name: "Nova",
            personality: "Stay calm.",
            scenario: "A night desk.",
            greeting: "Good evening."
        )
        try again.save(CompanionProfile(persona: card, memory: memory))
        XCTAssertEqual(try again.load().persona, card)
        try FileManager.default.removeItem(at: directory)
    }

    func testSQLiteAddsCardColumnsToAnOlderFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-sqlite-card-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("companion.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &handle), SQLITE_OK)
        let sql = "CREATE TABLE persona (id INTEGER PRIMARY KEY, name TEXT NOT NULL, personality TEXT NOT NULL);"
        XCTAssertEqual(sqlite3_exec(handle, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        let store = try SQLiteCompanionStore(fileURL: database)
        let card = CompanionPersona(
            name: "Nova",
            personality: "Stay calm.",
            scenario: "A night desk.",
            greeting: "Good evening.",
            creatorNotes: "draft only",
            lore: "An old lamp.",
            tags: ["Night", "night", " Desk "],
            nickname: "Nia",
            description: "A night clerk.",
            alternateGreetings: ["Hi again."],
            systemPrompt: "Speak softly.",
            postHistoryInstructions: "Stay in scene.",
            cardVersion: "1.2.0",
            modules: ["chat", "speech"],
            lorebook: [LoreEntry(keywords: ["lamp", "Lamp"], content: " An old lamp. ")]
        )
        try store.save(CompanionProfile(persona: card, memory: .empty))
        XCTAssertEqual(try store.load().persona.tags, ["Night", "Desk"])
        XCTAssertEqual(try store.load().persona, card)
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
        XCTAssertEqual(AoriCopy.language, "Language")
        XCTAssertEqual(table.values["menu.clickThrough"], "Click Through")
        XCTAssertEqual(AoriCopy.clickThrough, "Click Through")
    }

    func testSearchNotesAndChat() {
        let messages = [
            ChatMessage(role: .user, content: "The garden topic is roses"),
            ChatMessage(role: .assistant, content: "I like rain"),
        ]
        let notes = [MemoryNote(text: "Papa likes roses")]
        let hit = TranscriptSearch.match(query: "roses", messages: messages, notes: notes)
        XCTAssertEqual(hit.messages.map(\.content), ["The garden topic is roses"])
        XCTAssertEqual(hit.notes.map(\.text), ["Papa likes roses"])
        let miss = TranscriptSearch.match(query: "roses rain", messages: messages, notes: notes)
        XCTAssertTrue(miss.messages.isEmpty)
        XCTAssertTrue(miss.notes.isEmpty)
    }

    func testSpeechAuthLogNamesTheGrantOrWhisper() {
        XCTAssertEqual(SpeechAuthLog.line(permission: .granted, whisperAvailable: true), "aori_stt_auth=authorized")
        XCTAssertEqual(SpeechAuthLog.line(permission: .unknown, whisperAvailable: true), "aori_stt_auth=whisper")
        XCTAssertEqual(SpeechAuthLog.line(permission: .denied, whisperAvailable: true), "aori_stt_auth=whisper")
        XCTAssertEqual(SpeechAuthLog.line(permission: .denied, whisperAvailable: false), "aori_stt_auth=denied")
        XCTAssertEqual(SpeechRoute.engine(permission: .granted, whisperAvailable: true), .speech)
        XCTAssertEqual(
            SpeechRoute.transcript(
                permission: .granted,
                whisperAvailable: true,
                speechText: "from speech",
                whisperText: "from whisper"
            ),
            "from speech"
        )
        XCTAssertEqual(SpeechRoute.engine(permission: .denied, whisperAvailable: true), .whisper)
        XCTAssertEqual(
            SpeechRoute.transcript(
                permission: .denied,
                whisperAvailable: true,
                speechText: "from speech",
                whisperText: "from whisper"
            ),
            "from whisper"
        )
        XCTAssertEqual(SpeechRoute.engine(permission: .unknown, whisperAvailable: false), .missing)
        XCTAssertEqual(
            SpeechRoute.transcript(
                permission: .unknown,
                whisperAvailable: false,
                speechText: "from speech",
                whisperText: "from whisper"
            ),
            ""
        )
    }

    func testVoiceActivityFindsAQuietTail() {
        let activity = VoiceActivity(threshold: 0.05, silenceSeconds: 0.3, sampleRate: 1_000)
        var samples = [Float](repeating: 0.2, count: 400)
        samples.append(contentsOf: [Float](repeating: 0, count: 400))
        XCTAssertTrue(activity.containsSpeech(samples))
        XCTAssertTrue(activity.endpoint(samples))
        XCTAssertFalse(activity.endpoint([Float](repeating: 0, count: 800)))
    }

    func testRuntimeMetricsLogFpsLatencyAndMemory() {
        let fps = RuntimeMetrics.framesPerSecond(frameMilliseconds: 16.67)
        XCTAssertEqual(fps, 1000 / 16.67, accuracy: 0.01)
        XCTAssertEqual(RuntimeMetrics.framesPerSecond(frameMilliseconds: 0), 0)
        let lines = RuntimeMetrics.lines(
            RuntimeSample(framesPerSecond: fps, latencyMilliseconds: 12.5, memoryMegabytes: 40)
        )
        XCTAssertEqual(lines[0], "aori_fps=59.99")
        XCTAssertEqual(lines[1], "aori_latency_ms=12.50")
        XCTAssertEqual(lines[2], "aori_memory_mb=40.00")
        XCTAssertGreaterThan(RuntimeMetrics.memoryMegabytes(), 0)
    }

    func testFrameLogIsJson() throws {
        let line = AoriLog.frame(milliseconds: 8.21)
        let data = Data(line.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["event"] as? String, "frame")
        XCTAssertEqual(object?["ms"] as? Double ?? 0, 8.21, accuracy: 0.001)
    }

    func testEveryLocaleDirectoryLoads() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("packages/i18n/src/locales")
        let loaded = LocaleCatalog.loadAll(root: root)
        XCTAssertEqual(loaded.map(\.id), LocaleCatalog.ids)
        XCTAssertTrue(loaded.allSatisfy(\.directoryExists))
        XCTAssertTrue(loaded.allSatisfy { !$0.proof.isEmpty })
        let japanese = try XCTUnwrap(loaded.first { $0.id == "ja" })
        XCTAssertEqual(LocaleTable.parse(japanese.menuText ?? "").values["menu.memory"], "記憶")
        XCTAssertEqual(LocaleTable.parse(japanese.menuText ?? "").values["menu.showCompanion"], "コンパニオンを表示")
        XCTAssertEqual(LocaleTable.parse(japanese.menuText ?? "").values["menu.clickThrough"], "クリックを透過")
        XCTAssertTrue(japanese.proof.contains("設定"))
        for item in loaded where item.id != "en" {
            let values = LocaleTable.parse(item.menuText ?? "").values
            let value = values["menu.showCompanion"]
            XCTAssertNotEqual(value, "Show Companion")
            XCTAssertFalse(value?.isEmpty ?? true)
            let memory = values["menu.memory"]
            XCTAssertNotEqual(memory, "Memory")
            XCTAssertFalse(memory?.isEmpty ?? true)
        }
        let english = try XCTUnwrap(loaded.first { $0.id == "en" })
        XCTAssertEqual(LocaleTable.parse(english.menuText ?? "").values["menu.showCompanion"], "Show Companion")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aori-locale-\(UUID().uuidString)", isDirectory: true)
        let store = FileLocalePreferenceStore(fileURL: directory.appendingPathComponent("locale.json"))
        XCTAssertEqual(try store.load(), "en")
        try store.save(id: "ja")
        XCTAssertEqual(try store.load(), "ja")
        try FileManager.default.removeItem(at: directory)
    }
}

private final class HelloBox: @unchecked Sendable {
    private let lock = NSLock()
    private let ready = DispatchSemaphore(value: 0)
    private var value: Result<FactorioLink.Hello, LocalHelloError>?

    func set(_ value: Result<FactorioLink.Hello, LocalHelloError>) {
        lock.lock()
        self.value = value
        lock.unlock()
        ready.signal()
    }

    func wait() -> Result<FactorioLink.Hello, LocalHelloError>? {
        ready.wait()
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
